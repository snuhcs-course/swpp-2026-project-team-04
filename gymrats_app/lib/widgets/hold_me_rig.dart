import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import '../models/arcade_stage.dart' show HoldPose;
import '../models/character_rig.dart';
import 'character_motion.dart' show readKeyPoses;
import 'hold_me_drawing_data.dart';
import 'hold_me_rig_data.dart';

/// The user's character on a hold stage (A8 spec 2, 3), read once from
/// [holdMeRigJson] and [holdMeDrawingJson]: where each character stands in
/// the high plank and the chair pose, its key poses (the home rig's form,
/// so `CharacterFigurePainter` draws them), the three drawings that stand
/// in for a rig pose (곰탱이's high plank, 펭뚱이's and 물렁범's lying pose),
/// and the art of the effects around the character.
class HoldMeRig {
  const HoldMeRig({
    required this.version,
    required this.drawingVersion,
    required this.groundY,
    required this.box,
    required this.feet,
    required this.characters,
    required this.drawings,
    required this.fx,
  });

  /// Reads a rig in the `hold_me_rig.json` format and drawings in the
  /// `hold_me_drawing_data.dart` format; anything malformed throws a
  /// [FormatException].
  factory HoldMeRig.parse(String rigSource, String drawingSource) {
    final rig = _object(jsonDecode(rigSource), 'the hold rig');
    final art = _object(jsonDecode(drawingSource), 'the hold drawings');
    return _read('hold rig', () {
      final stage = rig['stage'] as Map<String, dynamic>;
      final box = _pair(stage['rigBox']);
      final feet = _pair(stage['rigFeet']);
      final drawings = {
        for (final MapEntry(:key, :value)
            in (art['drawings'] as Map<String, dynamic>).entries)
          key: _shapes('drawing "$key"', value),
      };
      final characters = <String, Map<HoldPose, HoldMePlace>>{};
      for (final MapEntry(key: id, :value)
          in (rig['characters'] as Map<String, dynamic>).entries) {
        final json = value as Map<String, dynamic>;
        characters[id] = {
          for (final pose in HoldPose.values)
            pose: HoldMePlace._fromJson(
              id,
              pose,
              json[pose.name] as Map<String, dynamic>,
              drawings,
            ),
        };
      }
      return HoldMeRig(
        version: rig['version'] as String,
        drawingVersion: art['version'] as String,
        groundY: _number(stage['groundY']),
        box: Size(box.dx, box.dy),
        feet: feet,
        characters: characters,
        drawings: drawings,
        fx: HoldMeFxArt._fromJson(art['fx'] as Map<String, dynamic>),
      );
    });
  }

  /// The app's hold rig, read on first use.
  static final standard = HoldMeRig.parse(holdMeRigJson, holdMeDrawingJson);

  /// hold-me-rig-1.
  final String version;

  /// hold-me-drawing-1.
  final String drawingVersion;

  /// The stage's floor line, where the feet stand: the owner's too (346).
  final double groundY;

  /// The W3 rig's box (140 x 160) that a character is drawn in.
  final Size box;

  /// The feet in the box (70, 150).
  final Offset feet;

  /// Character id -> pose -> where and how it is drawn.
  final Map<String, Map<HoldPose, HoldMePlace>> characters;

  /// The drawings by name (bearPlank, penguinLie, sealLie).
  final Map<String, List<HoldMeShape>> drawings;

  final HoldMeFxArt fx;

  /// How [characterId] holds [pose]; a character a person may not pick
  /// (RepBot's) or an unknown one holds as the default does (`mouse`).
  HoldMePlace placeOf(String characterId, HoldPose pose) =>
      (characters[CharacterRig.standard.selectableOrDefault(characterId)] ??
      characters[CharacterRig.defaultId]!)[pose]!;
}

/// One character in one pose on the stage (A8 spec 3): its box [scale]d
/// with [left] and its feet on the floor line, and what draws it: the rig
/// from [keyPoses], or the drawing [drawing].
class HoldMePlace {
  const HoldMePlace({
    required this.characterId,
    required this.pose,
    required this.scale,
    required this.left,
    required this.keyPoses,
    required this.flags,
    required this.drawing,
    required this.drawingName,
    required this.nearArm,
    required this.headTilt,
    required this.sweat,
    required this.spark,
  });

  factory HoldMePlace._fromJson(
    String id,
    HoldPose pose,
    Map<String, dynamic> json,
    Map<String, List<HoldMeShape>> drawings,
  ) {
    return _read('$id ${pose.name}', () {
      final kind = json['kind'] as String;
      final keyPoses = kind == 'rig'
          ? readKeyPoses(json['keyposes'] as Map<String, dynamic>)
          : const <String, RigPoseTable>{};
      final name = kind == 'drawing' ? json['drawing'] as String : null;
      if (kind != 'rig' && name == null) {
        throw FormatException('unknown kind "$kind"');
      }
      final needed = switch ((kind, pose)) {
        ('rig', HoldPose.plank) => const ['hold', 'sag'],
        ('rig', HoldPose.chair) => const ['hold', 'up', 'rise'],
        _ => const <String>[],
      };
      for (final key in needed) {
        if (!keyPoses.containsKey(key)) throw FormatException('no "$key"');
      }
      final drawing = name == null
          ? null
          : drawings[name] ?? (throw FormatException('no drawing "$name"'));
      final flags = (json['flags'] as Map<String, dynamic>?) ?? const {};
      return HoldMePlace(
        characterId: id,
        pose: pose,
        scale: _number(json['scale']),
        left: _number(json['left']),
        keyPoses: keyPoses,
        flags: {
          for (final MapEntry(:key, :value) in flags.entries)
            if (value as bool) key,
        },
        drawing: drawing,
        drawingName: name,
        nearArm: HoldMeTurn._fromJson(json['nearArm'], 'swingDeg'),
        headTilt: HoldMeTurn._fromJson(json['headTilt'], 'deg'),
        sweat: _pair(json['sweat']),
        spark: _pair(json['spark']),
      );
    });
  }

  final String characterId;
  final HoldPose pose;

  /// How many times the 140 x 160 box is drawn.
  final double scale;

  /// The box's left on the 360-point stage.
  final double left;

  /// The rig's key poses: hold and sag for the high plank, hold, up and
  /// rise for the chair pose; none for a drawing.
  final Map<String, RigPoseTable> keyPoses;

  /// The home rig's drawing flags that are on (gBack, pa).
  final Set<String> flags;

  /// The drawing's shapes when a drawing stands in for the rig, else null.
  final List<HoldMeShape>? drawing;
  final String? drawingName;

  /// How a drawing's near arm turns at the top of a star's pop, and its
  /// head (펭뚱이 and 물렁범); null for none.
  final HoldMeTurn? nearArm;
  final HoldMeTurn? headTilt;

  /// Where the sweat drops leave from and where a star's rays are, in the
  /// box.
  final Offset sweat;
  final Offset spark;

  /// Whether the character stands (the chair pose) rather than lies low.
  bool get standing => pose == HoldPose.chair;

  /// The box's top on the stage: the feet on the floor line.
  double topOn(HoldMeRig rig) => rig.groundY - rig.feet.dy * scale;
}

/// A turn of a drawing's part: [deg] degrees about [pivot] at its fullest.
class HoldMeTurn {
  const HoldMeTurn(this.pivot, this.deg);

  static HoldMeTurn? _fromJson(Object? json, String degKey) {
    if (json == null) return null;
    final map = json as Map<String, dynamic>;
    return HoldMeTurn(_pair(map['pivot']), _number(map[degKey]));
  }

  final Offset pivot;
  final double deg;
}

/// A link of a shape's chain of moves: a part the scene moves (tilt,
/// farArm, head, nearArm) or a fixed matrix.
class HoldMeLink {
  const HoldMeLink.part(String this.part) : matrix = null;

  HoldMeLink.fixed(List<double> m)
    : part = null,
      matrix = Float64List.fromList([
        m[0], m[1], 0, 0, m[2], m[3], 0, 0, 0, 0, 1, 0, m[4], m[5], 0, 1, //
      ]);

  final String? part;

  /// Column-major 4 x 4, as [Canvas.transform] takes it.
  final Float64List? matrix;
}

/// A fill or an outline's color: the team's lime, or its own.
class HoldMeColor {
  const HoldMeColor(int this.argb);
  const HoldMeColor.team() : argb = null;

  /// 0xFFRRGGBB; null for the team's color.
  final int? argb;

  bool get team => argb == null;
}

/// One shape of a drawing or of the effect art: a path under a chain of
/// moves, filled and then outlined, shown when every tag of [face] is on.
class HoldMeShape {
  HoldMeShape({
    required this.chain,
    required this.face,
    required this.path,
    this.fill,
    this.stroke,
    this.width = 0,
    this.cap = StrokeCap.round,
    this.join = StrokeJoin.round,
    this.strokeOpacity = 1,
    this.opacity = 1,
  });

  factory HoldMeShape._fromJson(Map<String, dynamic> json) {
    final stroke = _color(json['stroke']);
    return HoldMeShape(
      chain: [
        for (final link in (json['chain'] as List?) ?? const [])
          link is String
              ? HoldMeLink.part(link)
              : HoldMeLink.fixed(_numbers(link, 6)),
      ],
      face: {...((json['face'] as List?) ?? const []).cast<String>()},
      path: _geometry(json),
      fill: _color(json['fill']),
      stroke: stroke,
      width: stroke == null ? 0 : _number(json['width']),
      cap: switch (json['cap']) {
        null || 'round' => StrokeCap.round,
        'butt' => StrokeCap.butt,
        final other => throw FormatException('unknown line end "$other"'),
      },
      join: switch (json['join']) {
        null || 'round' => StrokeJoin.round,
        'miter' => StrokeJoin.miter,
        final other => throw FormatException('unknown line join "$other"'),
      },
      strokeOpacity: json['strokeOpacity'] == null
          ? 1
          : _number(json['strokeOpacity']),
      opacity: json['opacity'] == null ? 1 : _number(json['opacity']),
    );
  }

  final List<HoldMeLink> chain;

  /// The expression tags it needs, all of them; empty: always drawn.
  final Set<String> face;
  final Path path;
  final HoldMeColor? fill;
  final HoldMeColor? stroke;
  final double width;
  final StrokeCap cap;
  final StrokeJoin join;
  final double strokeOpacity;

  /// The whole shape's opacity, on top of its own.
  final double opacity;

  /// Whether it shows with the expression tags [tags].
  bool shownWith(Set<String> tags) => face.every(tags.contains);
}

/// The art of the effects around the character (A8 spec 3, 4), from the
/// mockup: the shadow, a sweat drop, the shake lines, a star's rays, the
/// landing's dust, and the flying star with its trail.
class HoldMeFxArt {
  const HoldMeFxArt({
    required this.shadowY,
    required this.shadowRy,
    required this.shadowColor,
    required this.shadowOpacity,
    required this.sweat,
    required this.shakeColor,
    required this.shakeWidth,
    required this.spark,
    required this.dust,
    required this.star,
    required this.trailColor,
    required this.trailWidth,
    required this.trailOpacity,
  });

  factory HoldMeFxArt._fromJson(Map<String, dynamic> json) {
    final shadow = json['shadow'] as Map<String, dynamic>;
    final shake = json['shake'] as Map<String, dynamic>;
    final trail = json['trail'] as Map<String, dynamic>;
    return HoldMeFxArt(
      shadowY: _number(shadow['cy']),
      shadowRy: _number(shadow['ry']),
      shadowColor: _color(shadow['fill'])!,
      shadowOpacity: _number(shadow['opacity']),
      sweat: _shapes('sweat', json['sweat']),
      shakeColor: _color(shake['stroke'])!,
      shakeWidth: _number(shake['width']),
      spark: _shapes('spark', json['spark']),
      dust: _shapes('dust', json['dust']),
      star: _shapes('star', json['star']),
      trailColor: _color(trail['stroke'])!,
      trailWidth: _number(trail['width']),
      trailOpacity: _number(trail['opacity']),
    );
  }

  /// The shadow: an ellipse under the feet, [shadowRy] high, at
  /// [shadowY] of the box.
  final double shadowY;
  final double shadowRy;
  final HoldMeColor shadowColor;
  final double shadowOpacity;

  /// A drop about its own (0, 0).
  final List<HoldMeShape> sweat;
  final HoldMeColor shakeColor;
  final double shakeWidth;

  /// Eight rays about (0, 0).
  final List<HoldMeShape> spark;

  /// Puffs either side of x = 0 at the feet's height.
  final List<HoldMeShape> dust;

  /// A star about (0, 0).
  final List<HoldMeShape> star;
  final HoldMeColor trailColor;
  final double trailWidth;
  final double trailOpacity;
}

List<HoldMeShape> _shapes(String where, Object? json) => _read(where, () {
  final list = json as List;
  if (list.isEmpty) throw const FormatException('no shapes');
  return [
    for (final shape in list)
      HoldMeShape._fromJson(shape as Map<String, dynamic>),
  ];
});

Path _geometry(Map<String, dynamic> json) {
  if (json['circle'] case final List c) {
    final v = _numbers(c, 3);
    return Path()
      ..addOval(Rect.fromCircle(center: Offset(v[0], v[1]), radius: v[2]));
  }
  if (json['ellipse'] case final List e) {
    final v = _numbers(e, 4);
    return Path()..addOval(
      Rect.fromCenter(
        center: Offset(v[0], v[1]),
        width: v[2] * 2,
        height: v[3] * 2,
      ),
    );
  }
  if (json['rect'] case final List r) {
    final v = _numbers(r, 5);
    return Path()..addRRect(
      RRect.fromRectXY(Rect.fromLTWH(v[0], v[1], v[2], v[3]), v[4], v[4]),
    );
  }
  final steps =
      json['path'] as List? ?? (throw const FormatException('no shape'));
  final path = Path();
  for (final step in steps) {
    final list = step as List;
    final letter = list.first;
    final v = [for (final n in list.skip(1)) _number(n)];
    final arity = _arity[letter] ?? (throw FormatException('step "$letter"'));
    if (v.length != arity) throw FormatException('"$letter" takes $arity');
    switch (letter) {
      case 'M':
        path.moveTo(v[0], v[1]);
      case 'L':
        path.lineTo(v[0], v[1]);
      case 'Q':
        path.quadraticBezierTo(v[0], v[1], v[2], v[3]);
      case 'C':
        path.cubicTo(v[0], v[1], v[2], v[3], v[4], v[5]);
      case 'A':
        path.arcToPoint(
          Offset(v[5], v[6]),
          radius: Radius.elliptical(v[0], v[1]),
          rotation: v[2],
          largeArc: v[3] != 0,
          clockwise: v[4] != 0,
        );
      case 'Z':
        path.close();
    }
  }
  return path;
}

const _arity = {'M': 2, 'L': 2, 'Q': 4, 'C': 6, 'A': 7, 'Z': 0};

HoldMeColor? _color(Object? value) {
  if (value == null) return null;
  if (value == 'team') return const HoldMeColor.team();
  final match = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch('$value');
  if (match == null) throw FormatException('not a #RRGGBB color: $value');
  return HoldMeColor(0xFF000000 | int.parse(match[1]!, radix: 16));
}

Offset _pair(Object? json) {
  final v = _numbers(json, 2);
  return Offset(v[0], v[1]);
}

List<double> _numbers(Object? json, int count) {
  final list = json as List;
  if (list.length != count) throw FormatException('$count numbers: $list');
  return [for (final n in list) _number(n)];
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  throw FormatException('not a number: $value');
}

Map<String, dynamic> _object(Object? json, String what) =>
    json is Map<String, dynamic>
    ? json
    : throw FormatException('$what is not a JSON object');

T _read<T>(String where, T Function() read) {
  try {
    return read();
  } on TypeError catch (error) {
    throw FormatException('$where: $error');
  }
}
