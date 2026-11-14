import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Canvas, Offset, Rect, Size;

import '../models/character_rig.dart';
import 'character_draw_patch.dart';
import 'character_motion_data.dart';

/// The home's exercise motions (W4 spec 4 and 5), read once from
/// [characterMotionJson]: for each character its key poses, its timetable,
/// the room its motion takes and the shapes it adds to the W3 drawing.
///
/// Poses are tables in the W3 rig's form ([RigPoseTable]) with three more
/// keys (belly, p1, p2), so `CharacterFigurePainter` draws a frame of a
/// motion as it draws a stage pose.
class CharacterMotionRig {
  const CharacterMotionRig({
    required this.version,
    required this.extendsVersion,
    required this.expressionTags,
    required this.effects,
    required this.characters,
  });

  /// Reads a rig in the `w4_home_rig.json` format; anything malformed throws
  /// a [FormatException].
  factory CharacterMotionRig.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('the home rig is not a JSON object');
    }
    final Map<String, dynamic> json = decoded;
    return _read('home rig', () {
      final expressions = json['expressions'] as Map<String, dynamic>;
      final characters = json['characters'] as Map<String, dynamic>;
      return CharacterMotionRig(
        version: json['version'] as String,
        extendsVersion: json['extends'] as String,
        expressionTags: readExpressionTags(
          expressions['map'] as Map<String, dynamic>,
        ),
        effects: [
          for (final effect in expressions['effectsSkipped'] as List)
            CharacterOpMatch.fromJson(
              (effect as Map<String, dynamic>)['match'] as Map<String, dynamic>,
            ),
        ],
        characters: {
          for (final MapEntry(:key, :value) in characters.entries)
            key: CharacterHomeMotion._fromJson(
              key,
              value as Map<String, dynamic>,
            ),
        },
      );
    });
  }

  /// The app's home motions, read from [characterMotionJson] on first use.
  static final standard = CharacterMotionRig.parse(characterMotionJson);

  final String version;

  /// The W3 rig version this one adds to (w3-rig-2).
  final String extendsVersion;

  /// Expression name -> character id (or `default`) -> the `show` tags it
  /// draws.
  final Map<String, Map<String, List<String>>> expressionTags;

  /// The stage effects a motion does not draw (W4 spec 5, item 2).
  final List<CharacterOpMatch> effects;

  final Map<String, CharacterHomeMotion> characters;

  /// [id]'s home motion, or the default character's (`mouse`) when [id] has
  /// none.
  CharacterHomeMotion motionOf(String id) =>
      characters[id] ?? characters[CharacterRig.defaultId]!;

  /// What the stage and 캐릭터 선택 add to [id]'s W3 drawing (see
  /// [CharacterHomeMotion.stageGroups]); nothing for a character without a
  /// home motion (RepBot).
  List<CharacterDrawPatch> stagePatchOf(String id) =>
      characters[id]?.stagePatch ?? const [];

  /// The `show` tags [expression] draws on [characterId].
  Set<String> tagsOf(String expression, String characterId) {
    final byCharacter =
        expressionTags[expression] ??
        (throw ArgumentError.value(expression, 'expression'));
    return (byCharacter[characterId] ?? byCharacter['default'])!.toSet();
  }
}

/// Reads `expressions.map`: a list of tags for every character, or (W5) an
/// object of lists by character id with a `default`.
Map<String, Map<String, List<String>>> readExpressionTags(
  Map<String, dynamic> json,
) {
  return {
    for (final MapEntry(:key, :value) in json.entries)
      key: switch (value) {
        final List<dynamic> tags => {'default': List<String>.from(tags)},
        final Map<String, dynamic> byId when byId.containsKey('default') => {
          for (final MapEntry(:key, :value) in byId.entries)
            key: List<String>.from(value as List),
        },
        _ => throw FormatException('no tags for the expression "$key"'),
      },
  };
}

/// One character's exercise on home: the key poses, the timetable, the
/// room it takes and the shapes it adds.
class CharacterHomeMotion {
  CharacterHomeMotion({
    required this.id,
    required this.exercise,
    required this.exerciseName,
    required this.motion,
    required this.keyPoses,
    required this.bounds,
    required this.drawPatch,
  });

  factory CharacterHomeMotion._fromJson(String id, Map<String, dynamic> json) {
    return _read('character "$id"', () {
      final bounds = json['bounds'] as Map<String, dynamic>;
      final motion = CharacterMotion.fromJson(
        json['motion'] as Map<String, dynamic>,
      );
      final keyPoses = readKeyPoses(json['keyposes'] as Map<String, dynamic>);
      motion.checkKeyPoses(keyPoses);
      return CharacterHomeMotion(
        id: id,
        exercise: json['exercise'] as String,
        exerciseName: json['exerciseName'] as String,
        motion: motion,
        keyPoses: keyPoses,
        bounds: Rect.fromLTRB(
          _number(bounds['x0']),
          _number(bounds['y0']),
          _number(bounds['x1']),
          _number(bounds['y1']),
        ),
        drawPatch: [
          for (final patch in json['drawPatch'] as List)
            CharacterDrawPatch.fromJson(patch as Map<String, dynamic>),
        ],
      );
    });
  }

  final String id;

  /// push, squat or bOne (the bear's one-two punch).
  final String exercise;

  /// 푸시업, 스쿼트, 원투 펀치.
  final String exerciseName;

  final CharacterMotion motion;

  /// The key poses by name (up, down; g, j, s).
  final Map<String, RigPoseTable> keyPoses;

  /// The most room one rep takes, in the box's coordinates: the scale and
  /// the place on home come from it.
  final Rect bounds;

  /// What this motion adds to the W3 drawing list.
  final List<CharacterDrawPatch> drawPatch;

  /// The patch groups the stage and 캐릭터 선택 draw too: 그루's inner tail
  /// fur, so 그루 looks the same on every screen (user, 2026-11-14, W4 spec
  /// 10.1). It is drawn in every pose and does not move on its own.
  static const stageGroups = {'tailInner'};

  /// The part of [drawPatch] in [stageGroups].
  late final List<CharacterDrawPatch> stagePatch = List.unmodifiable(
    drawPatch.where((patch) => stageGroups.contains(patch.group)),
  );

  /// The frame [tMs] ms into the motion.
  CharacterMotionFrame frameAt(double tMs) => motion.frameAt(tMs, keyPoses);

  /// The one picture shown when the device asks for less motion.
  late final CharacterMotionFrame rest = motion.restFrame(keyPoses);

  /// The scale and the feet's place in a room of [area] (W4 spec 3), for a
  /// box whose feet are at [anchor] (the W3 rig's (70, 150)): the feet on an
  /// unseen floor [floorLift] above the room's bottom, the motion's [bounds]
  /// centred across, as large as fits up to [maxScale], rounded down to
  /// hundredths. A room too small for any picture gives the scale 0 (nothing
  /// drawn): the menu does not scroll for it (W4 spec 10.2).
  CharacterPlacement placeIn(Size area, Offset anchor) {
    final floor = area.height - floorLift;
    final fit = [
      maxScale,
      (floor - topRoom) / (anchor.dy - bounds.top),
      (area.width - sideRoom) / bounds.width,
    ].reduce(math.min);
    final scale = math.max(0.0, (fit * 100).floorToDouble() / 100);
    return CharacterPlacement(
      scale: scale,
      foot: Offset(
        area.width / 2 - (bounds.center.dx - anchor.dx) * scale,
        floor,
      ),
    );
  }

  /// The largest scale on home, near 캐릭터 선택's 1.5x preview.
  static const maxScale = 1.6;

  /// The room kept free above the motion's top.
  static const topRoom = 6.0;

  /// How far the floor is above the room's bottom (the menu's top).
  static const floorLift = 16.0;

  /// The room's width less what the motion may use across (the design's
  /// 320 wide room, 300 used).
  static const sideRoom = 20.0;
}

/// Where a motion's character stands in its room: [foot] is where the box's
/// feet (70, 150) go, in the room's coordinates, and the box is [scale]
/// times its size.
class CharacterPlacement {
  const CharacterPlacement({required this.scale, required this.foot});

  final double scale;
  final Offset foot;

  @override
  bool operator ==(Object other) =>
      other is CharacterPlacement && other.scale == scale && other.foot == foot;

  @override
  int get hashCode => Object.hash(scale, foot);

  @override
  String toString() => 'CharacterPlacement($scale, $foot)';
}

/// A motion's timetable (W4 spec 4 and 5, "timing"): when the key poses
/// change and how, the expressions, the parts that run late, the moves of
/// the whole picture, the flags, and the pose shown at rest.
class CharacterMotion {
  const CharacterMotion({
    required this.label,
    required this.durMs,
    required this.loop,
    required this.keys,
    required this.segments,
    required this.expressions,
    required this.delayMs,
    required this.global,
    required this.flags,
    required this.restKey,
    required this.restExpression,
  });

  /// Reads a `motion` object; anything malformed throws a [FormatException].
  factory CharacterMotion.fromJson(Map<String, dynamic> json) {
    return _read('a motion', () {
      final segments = [
        for (final s in json['seg'] as List)
          MotionSegment._fromJson(s as Map<String, dynamic>),
      ];
      if (segments.isEmpty) throw const FormatException('a motion of nothing');
      final expressions = [
        for (final e in json['expr'] as List)
          (
            atMs: _number((e as Map<String, dynamic>)['atMs']),
            expression: e['expr'] as String,
          ),
      ];
      if (expressions.isEmpty) {
        throw const FormatException('a motion without an expression');
      }
      final flags = json['flags'] as Map<String, dynamic>;
      final rest = json['rest'] as Map<String, dynamic>;
      return CharacterMotion(
        label: json['label'] as String,
        durMs: _number(json['durMs']),
        loop: json['loop'] as bool,
        keys: List<String>.from(json['keys'] as List),
        segments: segments,
        expressions: expressions,
        delayMs: {
          for (final MapEntry(:key, :value)
              in (json['delayMs'] as Map<String, dynamic>).entries)
            key: _number(value),
        },
        global: [
          for (final g in json['global'] as List)
            MotionGlobalPart._fromJson(g as Map<String, dynamic>),
        ],
        flags: {
          for (final MapEntry(:key, :value) in flags.entries)
            if (value as bool) key,
        },
        restKey: rest['key'] as String,
        restExpression: rest['expr'] as String,
      );
    });
  }

  /// 푸시업, 스쿼트, ...
  final String label;

  /// The time of one rep.
  final double durMs;

  /// Whether it runs again and again (home's do); a motion that does not
  /// holds its last pose.
  final bool loop;

  /// The key poses it uses.
  final List<String> keys;
  final List<MotionSegment> segments;

  /// From [atMs] on, until the next one, the face shows [expression].
  final List<({double atMs, String expression})> expressions;

  /// Pose keys that follow the rest of the body this many ms late.
  final Map<String, double> delayMs;

  final List<MotionGlobalPart> global;

  /// The flags that are on (gBack, pa): which of the patches' shapes show.
  final Set<String> flags;

  /// The key pose and expression of the one picture at rest.
  final String restKey;
  final String restExpression;

  /// Throws a [FormatException] unless [keyPoses] has every key pose the
  /// timetable names, and all of them give each pose key the same steps
  /// (count, order, kinds), so any two can be blended.
  void checkKeyPoses(Map<String, RigPoseTable> keyPoses) {
    final named = {
      ...keys,
      for (final s in segments) ...[s.fromKey, s.toKey],
      restKey,
    };
    for (final name in named) {
      if (!keyPoses.containsKey(name)) {
        throw FormatException('no key pose "$name"');
      }
    }
    final first = keyPoses.values.first;
    for (final MapEntry(key: name, value: pose) in keyPoses.entries) {
      _checkSameShape(first, pose, name);
    }
  }

  /// The wrapped time: within one rep for a looping motion.
  double wrap(double tMs) =>
      loop ? ((tMs % durMs) + durMs) % durMs : tMs;

  /// The frame [tMs] ms into the motion, blending [keyPoses].
  CharacterMotionFrame frameAt(
    double tMs,
    Map<String, RigPoseTable> keyPoses,
  ) {
    final t = wrap(tMs);
    final base = keyPoses[segments.first.fromKey]!;
    final transforms = <String, List<RigTransform>>{};
    final paths = <String, List<RigSegment>>{};
    for (final key in base.transforms.keys) {
      final (from, to, u) = _blendAt(wrap(tMs - (delayMs[key] ?? 0)));
      transforms[key] = _blendMoves(
        keyPoses[from]!.transform(key),
        keyPoses[to]!.transform(key),
        u,
      );
    }
    for (final key in base.paths.keys) {
      final (from, to, u) = _blendAt(wrap(tMs - (delayMs[key] ?? 0)));
      paths[key] = _blendSteps(
        keyPoses[from]!.path(key),
        keyPoses[to]!.path(key),
        u,
      );
    }
    return CharacterMotionFrame(
      pose: RigPoseTable(transforms: transforms, paths: paths),
      expression: expressionAt(t),
      global: globalAt(t),
    );
  }

  /// The rest picture: [restKey] as it is, [restExpression], no whole-picture
  /// move.
  CharacterMotionFrame restFrame(Map<String, RigPoseTable> keyPoses) =>
      CharacterMotionFrame(
        pose: keyPoses[restKey]!,
        expression: restExpression,
        global: MotionGlobal.none,
      );

  /// The key poses to blend at the wrapped time [t], and how far.
  (String, String, double) _blendAt(double t) {
    final first = segments.first;
    if (t < first.fromMs) return (first.fromKey, first.fromKey, 0);
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (t < s.fromMs) {
        // Between two segments: the one before has ended.
        final before = segments[i - 1].toKey;
        return (before, before, 0);
      }
      if (t <= s.toMs) {
        final span = s.toMs - s.fromMs;
        final x = span == 0 ? 1.0 : (t - s.fromMs) / span;
        return (s.fromKey, s.toKey, s.ease.at(x));
      }
    }
    final last = segments.last.toKey;
    return (last, last, 0);
  }

  /// The expression at the wrapped time [t]: the last one begun by then.
  String expressionAt(double t) {
    var expression = expressions.first.expression;
    for (final e in expressions) {
      if (e.atMs <= t) expression = e.expression;
    }
    return expression;
  }

  /// The whole picture's move at the wrapped time [t]: every [global] part
  /// added.
  MotionGlobal globalAt(double t) {
    var up = 0.0;
    var rotDeg = 0.0;
    var sx = 1.0;
    var sy = 1.0;
    for (final g in global) {
      switch (g.kind) {
        case MotionGlobalKind.hop:
          up += g.amount * math.sin(math.pi * (t - g.phaseMs) / g.ms).abs();
        case MotionGlobalKind.rock:
          rotDeg += g.amount * math.sin(2 * math.pi * (t - g.phaseMs) / g.ms);
        case MotionGlobalKind.land:
          if (g.atMs <= t && t < g.atMs + g.ms) {
            final w = math.sin(math.pi * (t - g.atMs) / g.ms);
            sy *= 1 - g.sy * w;
            sx *= 1 + g.sx * w;
          }
      }
    }
    return MotionGlobal(up: up, rotDeg: rotDeg, sx: sx, sy: sy);
  }
}

/// From [fromMs] to [toMs] the pose goes from [fromKey] to [toKey], eased.
class MotionSegment {
  const MotionSegment({
    required this.fromMs,
    required this.toMs,
    required this.fromKey,
    required this.toKey,
    required this.ease,
  });

  factory MotionSegment._fromJson(Map<String, dynamic> json) {
    final segment = MotionSegment(
      fromMs: _number(json['fromMs']),
      toMs: _number(json['toMs']),
      fromKey: json['fromKey'] as String,
      toKey: json['toKey'] as String,
      ease: MotionEase.values.byName(json['ease'] as String),
    );
    if (segment.toMs < segment.fromMs) {
      throw const FormatException('a segment that ends before it starts');
    }
    return segment;
  }

  final double fromMs;
  final double toMs;
  final String fromKey;
  final String toKey;
  final MotionEase ease;
}

/// The easings of the rigs (W4 spec 5, "이징").
enum MotionEase {
  lin,
  eio,
  eo,
  ei,
  sin;

  /// The eased share for the time share [x] (0 to 1).
  double at(double x) => switch (this) {
    lin => x,
    eio => x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2,
    eo => 1 - math.pow(1 - x, 3).toDouble(),
    ei => x * x * x,
    sin => (1 - math.cos(math.pi * x)) / 2,
  };
}

enum MotionGlobalKind { hop, rock, land }

/// A move of the whole picture: a hop up (`amp` high, one hop per `ms`), a
/// rock (`deg` either way per `ms`), or a landing squash (from `at`, for
/// `ms`, `sx` wider and `sy` lower at its deepest). `ph` shifts a hop or a
/// rock later.
class MotionGlobalPart {
  const MotionGlobalPart({
    required this.kind,
    required this.ms,
    this.amount = 0,
    this.phaseMs = 0,
    this.atMs = 0,
    this.sx = 0,
    this.sy = 0,
  });

  factory MotionGlobalPart._fromJson(Map<String, dynamic> json) {
    double number(String key) => _number(json[key] ?? 0);
    final kind = MotionGlobalKind.values.byName(json['k'] as String);
    final part = MotionGlobalPart(
      kind: kind,
      ms: number('ms'),
      amount: switch (kind) {
        MotionGlobalKind.hop => number('amp'),
        MotionGlobalKind.rock => number('deg'),
        MotionGlobalKind.land => 0,
      },
      phaseMs: number('ph'),
      atMs: number('at'),
      sx: number('sx'),
      sy: number('sy'),
    );
    if (part.ms <= 0) throw const FormatException('a move of no time');
    return part;
  }

  final MotionGlobalKind kind;
  final double ms;

  /// A hop's height or a rock's degrees.
  final double amount;
  final double phaseMs;
  final double atMs;
  final double sx;
  final double sy;
}

/// The whole picture's move in a frame: [up] px up, [rotDeg] clockwise
/// about the feet, and scaled [sx] by [sy] about the feet.
class MotionGlobal {
  const MotionGlobal({
    required this.up,
    required this.rotDeg,
    required this.sx,
    required this.sy,
  });

  static const none = MotionGlobal(up: 0, rotDeg: 0, sx: 1, sy: 1);

  final double up;
  final double rotDeg;
  final double sx;
  final double sy;

  /// Moves [canvas] so the box drawn next makes this move about its feet
  /// ([anchorX], [anchorY]).
  void applyTo(Canvas canvas, double anchorX, double anchorY) {
    canvas
      ..translate(0, -up)
      ..translate(anchorX, anchorY)
      ..rotate(rotDeg * math.pi / 180)
      ..scale(sx, sy)
      ..translate(-anchorX, -anchorY);
  }
}

/// One frame of a motion: the pose table, the expression, the whole
/// picture's move.
class CharacterMotionFrame {
  const CharacterMotionFrame({
    required this.pose,
    required this.expression,
    required this.global,
  });

  final RigPoseTable pose;
  final String expression;
  final MotionGlobal global;
}

/// Reads `keyposes`: each key pose's moves (t, r, s) and paths (M, L, Q, C,
/// A, Z) by pose key, as [RigPoseTable]s.
Map<String, RigPoseTable> readKeyPoses(Map<String, dynamic> json) {
  return {
    for (final MapEntry(key: name, value: pose) in json.entries)
      name: _read('key pose "$name"', () {
        final transforms = <String, List<RigTransform>>{};
        final paths = <String, List<RigSegment>>{};
        for (final MapEntry(:key, :value)
            in (pose as Map<String, dynamic>).entries) {
          final items = value as List;
          if (items.isEmpty) throw FormatException('"$key" is empty');
          final letter = (items.first as List).first;
          if (_moveKinds.containsKey(letter)) {
            transforms[key] = [for (final item in items) _readMove(item)];
          } else {
            paths[key] = [for (final item in items) _readStep(item)];
          }
        }
        return RigPoseTable(transforms: transforms, paths: paths);
      }),
  };
}

const _moveKinds = {
  't': RigTransformKind.translate,
  'r': RigTransformKind.rotate,
  's': RigTransformKind.scale,
};

final _commands = {
  for (final command in RigCommand.values) rigCommandLetter(command): command,
};

RigTransform _readMove(Object? json) {
  final list = json as List;
  final kind =
      _moveKinds[list.first] ??
      (throw FormatException('not a move: ${list.first}'));
  final values = [for (final v in list.skip(1)) _number(v)];
  if (values.length != kind.arity) {
    throw FormatException('"${list.first}" takes ${kind.arity} numbers');
  }
  return _Move(kind, values);
}

RigSegment _readStep(Object? json) {
  final list = json as List;
  final command =
      _commands[list.first] ??
      (throw FormatException('not a path step: ${list.first}'));
  final values = [for (final v in list.skip(1)) _number(v)];
  if (values.length != command.arity) {
    throw FormatException('"${list.first}" takes ${command.arity} numbers');
  }
  return _Step(command, values);
}

/// A move read from the home rig or blended between two key poses.
class _Move implements RigTransform {
  const _Move(this.kind, this.values);

  @override
  final RigTransformKind kind;

  @override
  final List<double> values;
}

/// A path step read from the home rig or blended between two key poses.
class _Step implements RigSegment {
  const _Step(this.command, this.values);

  @override
  final RigCommand command;

  @override
  final List<double> values;
}

List<RigTransform> _blendMoves(
  List<RigTransform> a,
  List<RigTransform> b,
  double u,
) {
  if (u == 0 || identical(a, b)) return a;
  if (u == 1) return b;
  return [
    for (var i = 0; i < a.length; i++)
      _Move(a[i].kind, _blend(a[i].values, b[i].values, u)),
  ];
}

List<RigSegment> _blendSteps(
  List<RigSegment> a,
  List<RigSegment> b,
  double u,
) {
  if (u == 0 || identical(a, b)) return a;
  if (u == 1) return b;
  return [
    for (var i = 0; i < a.length; i++)
      _Step(a[i].command, _blend(a[i].values, b[i].values, u)),
  ];
}

List<double> _blend(List<double> a, List<double> b, double u) => [
  for (var i = 0; i < a.length; i++) a[i] + (b[i] - a[i]) * u,
];

/// Throws unless [pose] gives every key of [first] the same steps.
void _checkSameShape(RigPoseTable first, RigPoseTable pose, String name) {
  if (!_sameKeys(first.transforms.keys, pose.transforms.keys) ||
      !_sameKeys(first.paths.keys, pose.paths.keys)) {
    throw FormatException('key pose "$name" has other pose keys');
  }
  for (final MapEntry(:key, :value) in first.transforms.entries) {
    final other = pose.transform(key);
    if (other.length != value.length ||
        [
          for (var i = 0; i < value.length; i++) value[i].kind != other[i].kind,
        ].contains(true)) {
      throw FormatException('key pose "$name" moves "$key" otherwise');
    }
  }
  for (final MapEntry(:key, :value) in first.paths.entries) {
    final other = pose.path(key);
    if (other.length != value.length ||
        [
          for (var i = 0; i < value.length; i++)
            value[i].command != other[i].command,
        ].contains(true)) {
      throw FormatException('key pose "$name" draws "$key" otherwise');
    }
  }
}

bool _sameKeys(Iterable<String> a, Iterable<String> b) =>
    a.length == b.length && a.toSet().containsAll(b);

double _number(Object? value) {
  if (value is num) return value.toDouble();
  throw FormatException('not a number: $value');
}

T _read<T>(String where, T Function() read) {
  try {
    return read();
  } on TypeError catch (error) {
    throw FormatException('$where: $error');
  } on ArgumentError catch (error) {
    // An unknown name in an enum's byName.
    throw FormatException('$where: ${error.message}');
  }
}
