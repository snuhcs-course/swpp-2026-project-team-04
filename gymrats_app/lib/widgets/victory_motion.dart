import 'dart:convert';
import 'dart:ui' show Rect;

import '../models/character_rig.dart';
import 'character_draw_patch.dart';
import 'character_motion.dart';
import 'victory_rig_data.dart';
import 'victory_scene.dart';

/// The victory rig (W5 spec), read once from [victoryRigJson]: for each
/// character its celebration and its frustration, the face shapes W5 adds,
/// and the values of the scene around them.
///
/// It reads its motions as the home rig does (W4 spec 5, `character_motion
/// .dart`), so a frame of a celebration is a [RigPoseTable] that
/// `CharacterFigurePainter` draws as it draws a stage pose. Its drawing list
/// is the W3 one with the home rig's drawPatch first and this rig's after it
/// (spec 7).
class VictoryRig {
  const VictoryRig({
    required this.version,
    required this.extendsVersions,
    required this.expressionTags,
    required this.effects,
    required this.scene,
    required this.characters,
  });

  /// Reads a rig in the `w5_victory_rig.json` format on top of the [home]
  /// rig (whose drawPatch and stage effects it takes); anything malformed
  /// throws a [FormatException].
  factory VictoryRig.parse(String source, {required CharacterMotionRig home}) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('the victory rig is not a JSON object');
    }
    final Map<String, dynamic> json = decoded;
    return _read('victory rig', () {
      final expressions = json['expressions'] as Map<String, dynamic>;
      final scene = json['scene'] as Map<String, dynamic>;
      final characters = json['characters'] as Map<String, dynamic>;
      return VictoryRig(
        version: json['version'] as String,
        extendsVersions: List<String>.from(json['extends'] as List),
        expressionTags: readExpressionTags(
          expressions['map'] as Map<String, dynamic>,
        ),
        // W5 leaves out the same five stage effects as home (spec 7).
        effects: home.effects,
        scene: VictorySceneValues.fromJson(scene),
        characters: {
          for (final MapEntry(:key, :value) in characters.entries)
            key: VictoryCharacter._fromJson(
              key,
              value as Map<String, dynamic>,
              home.characters[key]?.drawPatch ?? const [],
            ),
        },
      );
    });
  }

  /// The app's victory rig, read from [victoryRigJson] on first use.
  static final standard = VictoryRig.parse(
    victoryRigJson,
    home: CharacterMotionRig.standard,
  );

  final String version;

  /// The rig versions this one adds to (w3-rig-2, w4-home-rig-1).
  final List<String> extendsVersions;

  /// Expression name -> character id (or `default`) -> the `show` tags it
  /// draws (spec 7 "표정").
  final Map<String, Map<String, List<String>>> expressionTags;

  /// The stage effects a motion does not draw (the home rig's five).
  final List<CharacterOpMatch> effects;

  /// The scene's values: seat, big scene, band, panel, stand, confetti.
  final VictorySceneValues scene;

  final Map<String, VictoryCharacter> characters;

  /// [id]'s celebration and frustration; a character a person may not pick
  /// (RepBot's) or an unknown one gets the default's (`mouse`, spec 8).
  VictoryCharacter characterOf(String? id) =>
      characters[CharacterRig.standard.selectableOrDefault(id)] ??
      characters[CharacterRig.defaultId]!;

  /// The `show` tags [expression] draws on [characterId].
  Set<String> tagsOf(String expression, String characterId) {
    final byCharacter =
        expressionTags[expression] ??
        (throw ArgumentError.value(expression, 'expression'));
    return (byCharacter[characterId] ?? byCharacter['default'])!.toSet();
  }
}

/// One character's two motions in the victory scene and what it adds to
/// its drawing.
class VictoryCharacter {
  const VictoryCharacter({
    required this.id,
    required this.name,
    required this.celebrate,
    required this.frustrate,
    required this.bigFootX,
    required this.ownPatch,
    required this.drawPatch,
  });

  factory VictoryCharacter._fromJson(
    String id,
    Map<String, dynamic> json,
    List<CharacterDrawPatch> homePatch,
  ) {
    return _read('character "$id"', () {
      final own = [
        for (final patch in json['drawPatch'] as List)
          CharacterDrawPatch.fromJson(patch as Map<String, dynamic>),
      ];
      return VictoryCharacter(
        id: id,
        name: json['name'] as String,
        celebrate: VictoryMotion._fromJson(
          json['celebrate'] as Map<String, dynamic>,
          needsEnd: true,
        ),
        frustrate: VictoryMotion._fromJson(
          json['frustrate'] as Map<String, dynamic>,
          needsEnd: false,
        ),
        bigFootX: _number(json['bigFootX']),
        ownPatch: List.unmodifiable(own),
        drawPatch: List.unmodifiable([...homePatch, ...own]),
      );
    });
  }

  final String id;
  final String name;

  /// The win's motion, again and again from 520 to 1600 ms (spec 5).
  final VictoryMotion celebrate;

  /// The loss's or the draw's motion, once (spec 6).
  final VictoryMotion frustrate;

  /// Where the feet go across in the big scene (spec 2 "큰 장면").
  final double bigFootX;

  /// The shapes W5 adds (the gritted teeth; 물렁범's grin and tongue).
  final List<CharacterDrawPatch> ownPatch;

  /// The home rig's drawPatch, then [ownPatch]: what the victory scene
  /// applies to the W3 drawing list (spec 7).
  final List<CharacterDrawPatch> drawPatch;

  VictoryMotion motionOf(VictoryMotionKind kind) => switch (kind) {
    VictoryMotionKind.celebrate => celebrate,
    VictoryMotionKind.frustrate => frustrate,
  };
}

/// The two motions of the victory scene.
enum VictoryMotionKind { celebrate, frustrate }

/// A motion of the victory scene: the home rig's timetable form (W4 spec 5)
/// plus, for a celebration, the end pose it blends into (spec 3 "끝 자세
/// 섞기").
class VictoryMotion {
  VictoryMotion({
    required this.motion,
    required this.keyPoses,
    required this.bounds,
    this.endKey,
    this.endExpression,
  });

  factory VictoryMotion._fromJson(
    Map<String, dynamic> json, {
    required bool needsEnd,
  }) {
    final motionJson = json['motion'] as Map<String, dynamic>;
    final motion = CharacterMotion.fromJson(motionJson);
    final keyPoses = readKeyPoses(json['keyposes'] as Map<String, dynamic>);
    motion.checkKeyPoses(keyPoses);
    final end = motionJson['end'] as Map<String, dynamic>?;
    if (end == null && needsEnd) {
      throw const FormatException('a celebration without an end pose');
    }
    final endKey = end?['key'] as String?;
    if (endKey != null && !keyPoses.containsKey(endKey)) {
      throw FormatException('no key pose "$endKey"');
    }
    final bounds = json['bounds'] as Map<String, dynamic>;
    return VictoryMotion(
      motion: motion,
      keyPoses: keyPoses,
      bounds: Rect.fromLTRB(
        _number(bounds['x0']),
        _number(bounds['y0']),
        _number(bounds['x1']),
        _number(bounds['y1']),
      ),
      endKey: endKey,
      endExpression: end?['expr'] as String?,
    );
  }

  final CharacterMotion motion;

  /// The key poses by name (a, b, e; up, hit; f0, f1, f2).
  final Map<String, RigPoseTable> keyPoses;

  /// The most room the motion takes, in the box's coordinates.
  final Rect bounds;

  /// The key pose and expression a celebration ends in; null for a
  /// frustration, which stops by itself.
  final String? endKey;
  final String? endExpression;

  /// The frame [tMs] ms into the motion, blended [endBlend] (0 to 1) of the
  /// way into the end pose: the pose blended with [endKey], the end
  /// expression from 0.5 on, and the whole picture's move weakened by
  /// (1 - [endBlend]) (spec 3; `endBlend` in the rig).
  CharacterMotionFrame frameAt(double tMs, {double endBlend = 0}) {
    final frame = motion.frameAt(tMs, keyPoses);
    final endKey = this.endKey;
    if (endBlend <= 0 || endKey == null) return frame;
    final keep = 1 - endBlend;
    final global = frame.global;
    return CharacterMotionFrame(
      pose: blendPoseTables(frame.pose, keyPoses[endKey]!, endBlend),
      expression: endBlend >= 0.5 ? endExpression! : frame.expression,
      // The rig weakens each part: a hop's height and a rock's degrees
      // (sums, so their total scales the same), a landing's squash (one per
      // motion in the rig, so scaling its total is the same too).
      global: MotionGlobal(
        up: global.up * keep,
        rotDeg: global.rotDeg * keep,
        sx: 1 + (global.sx - 1) * keep,
        sy: 1 + (global.sy - 1) * keep,
      ),
    );
  }

  /// The one picture of the end (reduced motion, a skip, the end of the
  /// scene): the rest key pose and expression, no whole-picture move. For a
  /// celebration the rest is its end pose.
  late final CharacterMotionFrame rest = motion.restFrame(keyPoses);
}

/// [a] blended [u] (0 to 1) of the way to [b]: every number of every key,
/// letters kept. The two must have the same keys and steps (key poses of
/// one motion do; `CharacterMotion.checkKeyPoses` checks them).
RigPoseTable blendPoseTables(RigPoseTable a, RigPoseTable b, double u) {
  if (u <= 0) return a;
  if (u >= 1) return b;
  return RigPoseTable(
    transforms: {
      for (final MapEntry(:key, :value) in a.transforms.entries)
        key: [
          for (final (i, move) in value.indexed)
            _Move(
              move.kind,
              _blend(move.values, b.transform(key)[i].values, u),
            ),
        ],
    },
    paths: {
      for (final MapEntry(:key, :value) in a.paths.entries)
        key: [
          for (final (i, step) in value.indexed)
            _Step(step.command, _blend(step.values, b.path(key)[i].values, u)),
        ],
    },
  );
}

List<double> _blend(List<double> a, List<double> b, double u) => [
  for (var i = 0; i < a.length; i++) a[i] + (b[i] - a[i]) * u,
];

/// A move blended between two poses.
class _Move implements RigTransform {
  const _Move(this.kind, this.values);

  @override
  final RigTransformKind kind;

  @override
  final List<double> values;
}

/// A path step blended between two poses.
class _Step implements RigSegment {
  const _Step(this.command, this.values);

  @override
  final RigCommand command;

  @override
  final List<double> values;
}

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
