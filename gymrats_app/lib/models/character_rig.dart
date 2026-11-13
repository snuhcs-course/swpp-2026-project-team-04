import 'dart:convert';

import 'character_idle_motion.dart';
import 'character_rig_data.dart';

/// The characters' drawing data (W3 spec 3): for each character a list of
/// shapes drawn in order, and a table per pose of where the moving parts go.
///
/// It is plain data read once from [characterRigJson]; the widget
/// `CharacterFigure` turns it into paths and paints it.
class CharacterRig {
  const CharacterRig({
    required this.version,
    required this.boxWidth,
    required this.boxHeight,
    required this.anchorX,
    required this.anchorY,
    required this.ink,
    required this.teamMe,
    required this.teamOpponent,
    required this.poses,
    required this.order,
    required this.defaultCharacter,
    required this.idleOpponentOffsetMs,
    required this.idleMotionW2Default,
    required this.hitStarDx,
    required this.hitStarUp,
    required this.characters,
  });

  /// Reads a rig in the `w3_rig.json` format; anything malformed throws a
  /// [FormatException].
  factory CharacterRig.parse(String source) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(source) as Map<String, dynamic>;
    } on TypeError {
      throw const FormatException('the rig is not a JSON object');
    }
    return _read('rig', () {
      final box = json['box'] as Map<String, dynamic>;
      final anchor = json['anchor'] as Map<String, dynamic>;
      final colors = json['colors'] as Map<String, dynamic>;
      final hitStar = json['hitStar'] as Map<String, dynamic>;
      final poses = List<String>.from(json['poses'] as List);
      final order = List<String>.from(json['order'] as List);
      final characters = json['characters'] as Map<String, dynamic>;
      final defaultCharacter = json['defaultCharacter'] as String;
      for (final id in order) {
        if (!characters.containsKey(id)) {
          throw FormatException('"$id" is in the order but not drawn');
        }
      }
      if (!order.contains(defaultCharacter)) {
        throw FormatException('no default character "$defaultCharacter"');
      }
      return CharacterRig(
        version: json['version'] as String,
        boxWidth: _number(box['w']),
        boxHeight: _number(box['h']),
        anchorX: _number(anchor['x']),
        anchorY: _number(anchor['y']),
        ink: _color(colors['ink']),
        teamMe: _color(colors['teamMe']),
        teamOpponent: _color(colors['teamOp']),
        poses: poses,
        order: order,
        defaultCharacter: defaultCharacter,
        idleOpponentOffsetMs: _number(json['idleOpponentOffsetMs']),
        idleMotionW2Default: CharacterIdleMotion.fromJson(
          json['idleMotionW2Default'] as Map<String, dynamic>,
        ),
        hitStarDx: _number(hitStar['dx']),
        hitStarUp: _number(hitStar['up']),
        characters: {
          for (final id in order)
            id: CharacterArt._fromJson(
              id,
              characters[id] as Map<String, dynamic>,
              poses,
            ),
        },
      );
    });
  }

  /// The app's characters, read from [characterRigJson] on first use.
  static final standard = CharacterRig.parse(characterRigJson);

  /// The default character's id (`standard.defaultCharacter`), for a
  /// constant default value.
  static const defaultId = 'mouse';

  /// RepBot's id: the AI battle's opponent, which no person picks.
  static const botId = 'bot';

  final String version;

  /// The box every pose is drawn in (140 x 160); drawings may leave it.
  final double boxWidth;
  final double boxHeight;

  /// The feet in that box (70, 150): the point the stage stands on the floor.
  final double anchorX;
  final double anchorY;

  /// Colors as 0xAARRGGBB: the outline ink and the two team colors.
  final int ink;
  final int teamMe;
  final int teamOpponent;

  /// The pose keys: idle, atk, hit, ko, win.
  final List<String> poses;

  /// Every character id in display order (RepBot last).
  final List<String> order;

  /// The character drawn when the one asked for is unknown: `mouse`.
  final String defaultCharacter;

  /// How much later the opponent's idle motion runs, so two equal characters
  /// do not move as one mirror image.
  final double idleOpponentOffsetMs;

  /// W2's breathing written as an idle motion (see
  /// [CharacterIdleMotion.w2Default]).
  final CharacterIdleMotion idleMotionW2Default;

  /// Where the stage's hit star sits: [hitStarDx] px from the middle of the
  /// two fighters toward the one hit, [hitStarUp] px above the floor.
  final double hitStarDx;
  final double hitStarUp;

  final Map<String, CharacterArt> characters;

  /// The characters a person can pick, in display order (all but RepBot).
  List<CharacterArt> get selectable => [
    for (final id in order)
      if (characters[id]!.selectable) characters[id]!,
  ];

  /// The character [id], or the default one when [id] is unknown.
  CharacterArt art(String? id) =>
      characters[id] ?? characters[defaultCharacter]!;

  /// [id] when a person may pick it, or else the default (`mouse`). Saved
  /// choices and the online opponent's id pass through this, so `bot`, a
  /// missing value and an unknown one all draw `mouse`.
  String selectableOrDefault(String? id) {
    final art = characters[id];
    return art != null && art.selectable ? art.id : defaultCharacter;
  }
}

/// One character: its names, its idle motion, its shapes and its poses.
class CharacterArt {
  const CharacterArt({
    required this.id,
    required this.name,
    required this.species,
    required this.selectable,
    required this.idleMotion,
    required this.ops,
    required this.poses,
  });

  factory CharacterArt._fromJson(
    String id,
    Map<String, dynamic> json,
    List<String> poseKeys,
  ) {
    return _read('character "$id"', () {
      final poses = json['poses'] as Map<String, dynamic>;
      return CharacterArt(
        id: id,
        name: json['name'] as String,
        species: json['species'] as String,
        selectable: json['selectable'] as bool,
        idleMotion: CharacterIdleMotion.fromJson(
          json['idleMotion'] as Map<String, dynamic>,
        ),
        ops: [
          for (final op in json['ops'] as List)
            RigOp._fromJson(op as Map<String, dynamic>),
        ],
        poses: {
          for (final key in poseKeys)
            key: RigPoseTable._fromJson(
              (poses[key] ?? (throw FormatException('no pose "$key"')))
                  as Map<String, dynamic>,
            ),
        },
      );
    });
  }

  /// The id saved and sent to the server: `mouse`, `kangaroo`, `bear`,
  /// `penguin`, `seal` or `bot`.
  final String id;

  /// The name on screen (GYM마우스, 그루, ...).
  final String name;

  /// The animal (쥐, 캥거루, ...), for the one-line description and the
  /// accessibility label.
  final String species;

  /// Whether a person may pick it (RepBot may not).
  final bool selectable;

  final CharacterIdleMotion idleMotion;

  /// The shapes in drawing order: later ones cover earlier ones.
  final List<RigOp> ops;

  /// The table of each pose, by pose key.
  final Map<String, RigPoseTable> poses;
}

/// One shape of a character: where it is moved to, in which poses it shows,
/// and what it is.
class RigOp {
  const RigOp({required this.chain, required this.show, required this.prim});

  factory RigOp._fromJson(Map<String, dynamic> json) {
    final show = json['show'] as List?;
    return RigOp(
      chain: [
        for (final part in json['chain'] as List) RigChainPart._fromJson(part),
      ],
      show: show == null ? null : Set<String>.from(show),
      prim: RigPrim._fromJson(json['prim'] as Map<String, dynamic>),
    );
  }

  /// The moves applied before drawing, outermost first.
  final List<RigChainPart> chain;

  /// The poses it shows in, or null for every pose.
  final Set<String>? show;

  final RigPrim prim;

  bool showsIn(String pose) => show == null || show!.contains(pose);

  /// The moves of [chain] with the pose's values filled in.
  List<RigTransform> transformsIn(RigPoseTable table) => [
    for (final part in chain) ...part.resolve(table),
  ];
}

/// A part of a shape's chain: fixed moves, or the moves a pose gives a key.
class RigChainPart {
  const RigChainPart.fixed(this.transforms) : key = null;
  const RigChainPart.posed(String this.key) : transforms = const [];

  factory RigChainPart._fromJson(Object? json) {
    if (json is Map<String, dynamic>) {
      return RigChainPart.posed(json['key'] as String);
    }
    return RigChainPart.fixed(_transforms(json));
  }

  /// The pose-table key (torso, head, g2, ...), or null for fixed moves.
  final String? key;
  final List<RigTransform> transforms;

  List<RigTransform> resolve(RigPoseTable table) =>
      key == null ? transforms : table.transform(key!);
}

/// A move of the canvas: translate (dx, dy), rotate clockwise by degrees
/// about (cx, cy), or scale (sx, sy).
class RigTransform {
  const RigTransform._(this.kind, this.values);

  factory RigTransform._fromJson(Object? json) {
    final list = json as List;
    if (list.isEmpty) throw const FormatException('an empty move');
    final kind = switch (list.first) {
      't' => RigTransformKind.translate,
      'r' => RigTransformKind.rotate,
      's' => RigTransformKind.scale,
      final other => throw FormatException('unknown move "$other"'),
    };
    final values = [for (final v in list.skip(1)) _number(v)];
    if (values.length != kind.arity) {
      throw FormatException('"${list.first}" takes ${kind.arity} numbers');
    }
    return RigTransform._(kind, values);
  }

  final RigTransformKind kind;

  /// translate: dx, dy; rotate: degrees, cx, cy; scale: sx, sy.
  final List<double> values;
}

enum RigTransformKind {
  translate(2),
  rotate(3),
  scale(2);

  const RigTransformKind(this.arity);

  final int arity;
}

/// One step of a path, in absolute coordinates: move, line, quadratic and
/// cubic curve, elliptical arc, close.
class RigSegment {
  const RigSegment._(this.command, this.values);

  factory RigSegment._fromJson(Object? json) {
    final list = json as List;
    if (list.isEmpty) throw const FormatException('an empty path step');
    final command = switch (list.first) {
      'M' => RigCommand.move,
      'L' => RigCommand.line,
      'Q' => RigCommand.quad,
      'C' => RigCommand.cubic,
      'A' => RigCommand.arc,
      'Z' => RigCommand.close,
      final other => throw FormatException('unknown path step "$other"'),
    };
    final values = [for (final v in list.skip(1)) _number(v)];
    if (values.length != command.arity) {
      throw FormatException('"${list.first}" takes ${command.arity} numbers');
    }
    return RigSegment._(command, values);
  }

  final RigCommand command;

  /// M, L: x, y; Q: x1, y1, x, y; C: x1, y1, x2, y2, x, y;
  /// A: rx, ry, rotation, large arc (1/0), clockwise (1/0), x, y; Z: none.
  final List<double> values;
}

enum RigCommand {
  move(2),
  line(2),
  quad(4),
  cubic(6),
  arc(7),
  close(0);

  const RigCommand(this.arity);

  final int arity;
}

enum RigShape { path, circle, ellipse, rect }

/// The drawn part of a shape: its geometry, fill and outline.
class RigPrim {
  const RigPrim({
    required this.shape,
    this.pathKey,
    this.segments = const [],
    this.cx = 0,
    this.cy = 0,
    this.r = 0,
    this.rx = 0,
    this.ry = 0,
    this.x = 0,
    this.y = 0,
    this.w = 0,
    this.h = 0,
    this.fill,
    this.stroke,
    this.strokeWidth = 0,
    this.roundCap = true,
    this.strokeOpacity = 1,
  });

  factory RigPrim._fromJson(Map<String, dynamic> json) {
    final shape = switch (json['type']) {
      'path' => RigShape.path,
      'circle' => RigShape.circle,
      'ellipse' => RigShape.ellipse,
      'rect' => RigShape.rect,
      final other => throw FormatException('unknown shape "$other"'),
    };
    // The geometry each shape needs; the rest is 0.
    final needs = switch (shape) {
      RigShape.path => const <String>[],
      RigShape.circle => const ['cx', 'cy', 'r'],
      RigShape.ellipse => const ['cx', 'cy', 'rx', 'ry'],
      RigShape.rect => const ['x', 'y', 'w', 'h', 'rx'],
    };
    for (final key in needs) {
      if (!json.containsKey(key)) {
        throw FormatException('a ${shape.name} without "$key"');
      }
    }
    double number(String key) => _number(json[key] ?? 0);
    final d = json['d'];
    if (shape == RigShape.path && d is! List && d is! Map) {
      throw const FormatException('a path without "d"');
    }
    final stroke = RigPaint._fromJson(json['stroke']);
    final cap = json['cap'] as String? ?? 'round';
    if (cap != 'round' && cap != 'butt') {
      throw FormatException('unknown line end "$cap"');
    }
    return RigPrim(
      shape: shape,
      pathKey: d is Map<String, dynamic> ? d['key'] as String : null,
      segments: d is List ? _segments(d) : const [],
      cx: number('cx'),
      cy: number('cy'),
      r: number('r'),
      rx: number('rx'),
      ry: number('ry'),
      x: number('x'),
      y: number('y'),
      w: number('w'),
      h: number('h'),
      fill: RigPaint._fromJson(json['fill']),
      stroke: stroke,
      strokeWidth: stroke == null ? 0 : _number(json['strokeWidth']),
      roundCap: cap == 'round',
      strokeOpacity: _number(json['strokeOpacity'] ?? 1),
    );
  }

  final RigShape shape;

  /// A path's pose-table key (l1, a2, ...), or null for a fixed path.
  final String? pathKey;

  /// A fixed path's steps.
  final List<RigSegment> segments;

  /// circle: cx, cy, r; ellipse: cx, cy, rx, ry; rect: x, y, w, h and the
  /// corner radius rx.
  final double cx, cy, r, rx, ry, x, y, w, h;

  /// Null draws no fill / no outline.
  final RigPaint? fill;
  final RigPaint? stroke;

  final double strokeWidth;

  /// Round line ends, or flat (butt) ones. Corners are always round.
  final bool roundCap;

  /// The outline's opacity (glove seams 0.45, swing lines 0.5).
  final double strokeOpacity;

  /// A path's steps in a pose (fixed, or from the pose's table).
  List<RigSegment> segmentsIn(RigPoseTable table) =>
      pathKey == null ? segments : table.path(pathKey!);
}

/// A fill or outline color: the team's, or a fixed one.
class RigPaint {
  const RigPaint.team() : team = true, argb = 0;
  const RigPaint.color(this.argb) : team = false;

  static RigPaint? _fromJson(Object? json) => switch (json) {
    null => null,
    'team' => const RigPaint.team(),
    final String hex => RigPaint.color(_color(hex)),
    _ => throw FormatException('unknown color $json'),
  };

  /// The player's team color goes here (lime for me, pink for the opponent).
  final bool team;

  /// The fixed color as 0xAARRGGBB (0 for a team color).
  final int argb;
}

/// Where the moving parts go in one pose: eight moves (tail, s1, s2, torso,
/// head, g1, g2, fx) and six paths (l1, l2, a1, a2, wb, wc).
class RigPoseTable {
  const RigPoseTable({required this.transforms, required this.paths});

  factory RigPoseTable._fromJson(Map<String, dynamic> json) {
    List<Object?> value(String key) =>
        (json[key] ?? (throw FormatException('no "$key" in a pose'))) as List;
    return RigPoseTable(
      transforms: {
        for (final key in transformKeys) key: _transforms(value(key)),
      },
      paths: {for (final key in pathKeys) key: _segments(value(key))},
    );
  }

  static const transformKeys = [
    'tail',
    's1',
    's2',
    'torso',
    'head',
    'g1',
    'g2',
    'fx',
  ];
  static const pathKeys = ['l1', 'l2', 'a1', 'a2', 'wb', 'wc'];

  final Map<String, List<RigTransform>> transforms;
  final Map<String, List<RigSegment>> paths;

  List<RigTransform> transform(String key) =>
      transforms[key] ?? (throw FormatException('no move "$key" in a pose'));

  List<RigSegment> path(String key) =>
      paths[key] ?? (throw FormatException('no path "$key" in a pose'));
}

List<RigTransform> _transforms(Object? json) => [
  for (final t in json as List) RigTransform._fromJson(t),
];

List<RigSegment> _segments(Object? json) => [
  for (final s in json as List) RigSegment._fromJson(s),
];

double _number(Object? value) {
  if (value is num) return value.toDouble();
  throw FormatException('not a number: $value');
}

/// "#RRGGBB" as an opaque 0xAARRGGBB.
int _color(Object? value) {
  final match = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch('$value');
  if (match == null) throw FormatException('not a color: $value');
  return 0xFF000000 | int.parse(match[1]!, radix: 16);
}

/// Runs [read] and turns a wrong JSON type into a [FormatException] that
/// says where it was.
T _read<T>(String where, T Function() read) {
  try {
    return read();
  } on TypeError catch (error) {
    throw FormatException('$where: $error');
  }
}
