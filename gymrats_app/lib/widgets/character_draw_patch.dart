import 'dart:convert';

import '../models/character_rig.dart';

/// A change to a character's W3 drawing list (W4 spec 5, "drawPatch"): the
/// home's push-ups add a glove behind the body, 물렁범's paddle fins and so
/// on, without changing `w3_rig.json`. W5 adds its own patches after W4's.
///
/// The shape it is aimed at ([target]) is found among the character's W3
/// shapes, never among added ones: the first with the same chain and the same
/// drawn part.
class CharacterDrawPatch {
  const CharacterDrawPatch._({
    required this.kind,
    required this.target,
    this.group,
    this.ops = const [],
    this.condition,
    this.append = const [],
  });

  /// Reads one `drawPatch` item; anything malformed throws a
  /// [FormatException].
  factory CharacterDrawPatch.fromJson(Map<String, dynamic> json) {
    return _read('a drawPatch', () {
      final kind = switch (json['kind']) {
        'insertAfter' => CharacterPatchKind.insertAfter,
        'onlyWhen' => CharacterPatchKind.onlyWhen,
        'appendChain' => CharacterPatchKind.appendChain,
        final other => throw FormatException('unknown patch "$other"'),
      };
      final target = readRigOps([
        json[kind == CharacterPatchKind.insertAfter ? 'after' : 'match'],
      ]).single;
      switch (kind) {
        case CharacterPatchKind.insertAfter:
          final ops = json['ops'] as List;
          final read = readRigOps(ops);
          return CharacterDrawPatch._(
            kind: kind,
            target: target,
            group: json['group'] as String?,
            ops: [
              for (var i = 0; i < ops.length; i++)
                CharacterDrawOp(
                  read[i],
                  condition: CharacterFlagTest.parse(
                    (ops[i] as Map<String, dynamic>)['when'] as String?,
                  ),
                ),
            ],
          );
        case CharacterPatchKind.onlyWhen:
          return CharacterDrawPatch._(
            kind: kind,
            target: target,
            condition: CharacterFlagTest.parse(json['flag'] as String),
          );
        case CharacterPatchKind.appendChain:
          return CharacterDrawPatch._(
            kind: kind,
            target: target,
            append: [
              for (final part in json['append'] as List)
                (part as Map<String, dynamic>)['key'] as String,
            ],
          );
      }
    });
  }

  final CharacterPatchKind kind;

  /// The W3 shape it is aimed at (`after` or `match`).
  final RigOp target;

  /// What the added shapes are for (backGlove, tailInner, paddle, ...);
  /// null when the file names none.
  final String? group;

  /// [CharacterPatchKind.insertAfter]: the shapes put right after [target].
  final List<CharacterDrawOp> ops;

  /// [CharacterPatchKind.onlyWhen]: when [target] is drawn.
  final CharacterFlagTest? condition;

  /// [CharacterPatchKind.appendChain]: the pose keys added to the end of
  /// [target]'s chain.
  final List<String> append;

  /// Applies this patch to [list]: the W3 shapes in their order, with the
  /// shapes earlier patches added among them. Throws a [StateError] when no
  /// W3 shape matches [target].
  void _applyTo(List<_Entry> list) {
    final index = list.indexWhere(
      (entry) => entry.w3 != null && sameRigOp(entry.w3!, target),
    );
    if (index < 0) {
      throw StateError('no W3 shape for a ${kind.name} patch');
    }
    final entry = list[index];
    switch (kind) {
      case CharacterPatchKind.insertAfter:
        list.insertAll(index + 1, [
          for (final op in ops)
            _Entry(op.op, condition: op.condition, w3: null),
        ]);
      case CharacterPatchKind.onlyWhen:
        entry.condition = condition;
      case CharacterPatchKind.appendChain:
        entry.op = RigOp(
          chain: [
            ...entry.op.chain,
            for (final key in append) RigChainPart.posed(key),
          ],
          show: entry.op.show,
          prim: entry.op.prim,
        );
    }
  }
}

enum CharacterPatchKind {
  /// Puts shapes right after a W3 shape.
  insertAfter,

  /// Draws a W3 shape only when a motion flag says so.
  onlyWhen,

  /// Adds pose keys to a W3 shape's chain (물렁범's belly).
  appendChain,
}

/// A motion flag test: `gBack`, or `!pa` for "pa is off".
class CharacterFlagTest {
  const CharacterFlagTest(this.flag, {required this.on});

  /// Reads `flag` or `!flag`; null stays null (always drawn).
  static CharacterFlagTest? parse(String? text) {
    if (text == null) return null;
    final off = text.startsWith('!');
    final flag = off ? text.substring(1) : text;
    if (flag.isEmpty) throw const FormatException('an empty flag');
    return CharacterFlagTest(flag, on: !off);
  }

  final String flag;

  /// Whether [flag] must be on (true) or off (false).
  final bool on;

  /// Whether the motion's [flags] (the ones that are on) pass.
  bool passes(Set<String> flags) => flags.contains(flag) == on;

  @override
  String toString() => on ? flag : '!$flag';
}

/// A shape of the drawing list: drawn when its [condition] passes, and left
/// out of a motion when it is one of the stage's [effect]s.
class CharacterDrawOp {
  const CharacterDrawOp(this.op, {this.condition, this.effect = false});

  final RigOp op;
  final CharacterFlagTest? condition;

  /// One of the stage effects a motion does not draw (W4 spec 5).
  final bool effect;
}

/// Which W3 shapes are stage effects (`expressions.effectsSkipped`): every
/// field given must match. [chainKey] is a pose key in the chain, [prim]
/// some of the drawn part's fields (type, cx, cy, r, rx, ry, x, y, w, h), and
/// [pathStartsWith] the first step of a fixed path.
class CharacterOpMatch {
  const CharacterOpMatch({
    this.chainKey,
    this.prim = const {},
    this.pathStartsWith,
  });

  factory CharacterOpMatch.fromJson(Map<String, dynamic> json) {
    return _read('an effect match', () {
      final prim = (json['prim'] as Map<String, dynamic>?) ?? const {};
      for (final key in prim.keys) {
        if (!_primFields.containsKey(key)) {
          throw FormatException('cannot match a shape by "$key"');
        }
      }
      final start = json['pathStartsWith'] as List?;
      final match = CharacterOpMatch(
        chainKey: json['chainKey'] as String?,
        prim: prim,
        pathStartsWith: start,
      );
      if (match.chainKey == null && prim.isEmpty && start == null) {
        throw const FormatException('an effect match that matches all');
      }
      return match;
    });
  }

  final String? chainKey;
  final Map<String, dynamic> prim;
  final List<Object?>? pathStartsWith;

  bool matches(RigOp op) {
    final chain = chainKey;
    if (chain != null && !op.chain.any((part) => part.key == chain)) {
      return false;
    }
    for (final MapEntry(:key, :value) in prim.entries) {
      if (!_sameValue(_primFields[key]!(op.prim), value)) return false;
    }
    final start = pathStartsWith;
    if (start != null) {
      final p = op.prim;
      if (p.shape != RigShape.path || p.pathKey != null || p.segments.isEmpty) {
        return false;
      }
      final first = p.segments.first;
      if (!_sameValue(rigCommandLetter(first.command), start.first) ||
          !_sameValue(first.values, start.sublist(1))) {
        return false;
      }
    }
    return true;
  }

  static final _primFields = <String, Object Function(RigPrim)>{
    'type': (p) => p.shape.name,
    'cx': (p) => p.cx,
    'cy': (p) => p.cy,
    'r': (p) => p.r,
    'rx': (p) => p.rx,
    'ry': (p) => p.ry,
    'x': (p) => p.x,
    'y': (p) => p.y,
    'w': (p) => p.w,
    'h': (p) => p.h,
  };
}

/// [art]'s shapes in drawing order with [patches] applied in turn, each
/// marked when [effects] matches it. Built once per art and patch list.
/// Throws a [StateError] when a patch finds no W3 shape.
List<CharacterDrawOp> characterDrawList(
  CharacterArt art,
  List<CharacterDrawPatch> patches,
  List<CharacterOpMatch> effects,
) {
  if (patches.isEmpty && effects.isEmpty) {
    return _plain[art] ??= [for (final op in art.ops) CharacterDrawOp(op)];
  }
  final key = _ListKey(art, patches, effects);
  return _built[key] ??= () {
    final list = [for (final op in art.ops) _Entry(op, w3: op)];
    for (final patch in patches) {
      patch._applyTo(list);
    }
    return List<CharacterDrawOp>.unmodifiable([
      for (final entry in list)
        CharacterDrawOp(
          entry.op,
          condition: entry.condition,
          effect: effects.any((match) => match.matches(entry.op)),
        ),
    ]);
  }();
}

final _plain = Expando<List<CharacterDrawOp>>();
final _built = <_ListKey, List<CharacterDrawOp>>{};

class _ListKey {
  const _ListKey(this.art, this.patches, this.effects);

  final CharacterArt art;
  final List<CharacterDrawPatch> patches;
  final List<CharacterOpMatch> effects;

  @override
  bool operator ==(Object other) =>
      other is _ListKey &&
      identical(other.art, art) &&
      _sameItems(other.patches, patches) &&
      _sameItems(other.effects, effects);

  @override
  int get hashCode => Object.hash(
    identityHashCode(art),
    Object.hashAll(patches.map(identityHashCode)),
    Object.hashAll(effects.map(identityHashCode)),
  );

  static bool _sameItems(List<Object> a, List<Object> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }
}

class _Entry {
  _Entry(this.op, {required this.w3, this.condition});

  RigOp op;

  /// The W3 shape this entry was, as read (a patch aims at it); null for an
  /// added shape.
  final RigOp? w3;
  CharacterFlagTest? condition;
}

/// Whether [a] and [b] are the same shape: the same chain (a fixed move
/// written alone or in a list alike) and the same drawn part. Which poses
/// they show in is not compared.
bool sameRigOp(RigOp a, RigOp b) =>
    _sameValue(_chainOf(a), _chainOf(b)) && _sameValue(_primOf(a), _primOf(b));

List<Object?> _chainOf(RigOp op) => [
  for (final part in op.chain)
    if (part.key case final key?)
      key
    else
      for (final move in part.transforms) [move.kind.name, ...move.values],
];

List<Object?> _primOf(RigOp op) {
  final p = op.prim;
  Object? paint(RigPaint? paint) =>
      paint == null ? null : (paint.team ? 'team' : paint.argb);
  return [
    p.shape.name,
    p.pathKey,
    for (final step in p.segments) [step.command.name, ...step.values],
    p.cx,
    p.cy,
    p.r,
    p.rx,
    p.ry,
    p.x,
    p.y,
    p.w,
    p.h,
    paint(p.fill),
    paint(p.stroke),
    p.strokeWidth,
    p.roundCap,
    p.strokeOpacity,
  ];
}

bool _sameValue(Object? a, Object? b) {
  if (a is num && b is num) return a == b;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameValue(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// The letter a path step is written with in the rigs (M, L, Q, C, A, Z).
String rigCommandLetter(RigCommand command) => switch (command) {
  RigCommand.move => 'M',
  RigCommand.line => 'L',
  RigCommand.quad => 'Q',
  RigCommand.cubic => 'C',
  RigCommand.arc => 'A',
  RigCommand.close => 'Z',
};

/// Reads shapes written as in `w3_rig.json` with the W3 rig's own reader,
/// so an added shape is read exactly as a W3 one: they become the one
/// character of an otherwise empty rig. A fixed move written alone in a
/// chain (`["t", -4, 1]`, as W5's file has it) is read as a list of one.
List<RigOp> readRigOps(List<Object?> ops) {
  final rig = CharacterRig.parse(
    jsonEncode({
      'version': 'patch',
      'box': {'w': 0, 'h': 0},
      'anchor': {'x': 0, 'y': 0},
      'colors': {'ink': '#000000', 'teamMe': '#000000', 'teamOp': '#000000'},
      'poses': <String>[],
      'order': ['patch'],
      'defaultCharacter': 'patch',
      'idleOpponentOffsetMs': 0,
      'idleMotionW2Default': <String, Object>{},
      'hitStar': {'dx': 0, 'up': 0},
      'characters': {
        'patch': {
          'name': '',
          'species': '',
          'selectable': false,
          'idleMotion': <String, Object>{},
          'ops': [for (final op in ops) _withListedMoves(op)],
          'poses': <String, Object>{},
        },
      },
    }),
  );
  return rig.art('patch').ops;
}

Object? _withListedMoves(Object? op) {
  if (op is! Map<String, dynamic>) return op;
  final chain = op['chain'];
  if (chain is! List) return op;
  return {
    ...op,
    'chain': [
      for (final part in chain)
        if (part is List && part.isNotEmpty && part.first is String)
          [part]
        else
          part,
    ],
  };
}

T _read<T>(String where, T Function() read) {
  try {
    return read();
  } on TypeError catch (error) {
    throw FormatException('$where: $error');
  }
}
