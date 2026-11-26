import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/widgets/character_motion.dart';
import 'package:gymrats_app/widgets/hold_me_drawing_data.dart';
import 'package:gymrats_app/widgets/hold_me_rig.dart';
import 'package:gymrats_app/widgets/hold_me_rig_data.dart';

/// Every number of every key of [a] and [b] the same, and the same steps.
void expectSamePose(RigPoseTable a, RigPoseTable b, String reason) {
  expect(a.transforms.keys.toSet(), b.transforms.keys.toSet(), reason: reason);
  expect(a.paths.keys.toSet(), b.paths.keys.toSet(), reason: reason);
  for (final key in a.transforms.keys) {
    final x = a.transform(key);
    final y = b.transform(key);
    expect([for (final m in x) m.kind], [for (final m in y) m.kind]);
    expect(
      [for (final m in x) ...m.values],
      [for (final m in y) ...m.values],
      reason: '$reason $key',
    );
  }
  for (final key in a.paths.keys) {
    final x = a.path(key);
    final y = b.path(key);
    expect([for (final s in x) s.command], [for (final s in y) s.command]);
    expect(
      [for (final s in x) ...s.values],
      [for (final s in y) ...s.values],
      reason: '$reason $key',
    );
  }
}

void main() {
  final rig = HoldMeRig.standard;

  test('the app\'s hold rig: its versions, box, feet and floor line', () {
    expect(rig.version, 'hold-me-rig-1');
    expect(rig.drawingVersion, 'hold-me-drawing-1');
    expect(rig.box, const Size(140, 160));
    expect(rig.feet, const Offset(70, 150));
    // The owner's feet: the 390-point stage less its bottom 34, the box
    // 160 high with the feet at 150 of it (A8 spec 3).
    expect(rig.groundY, 390 - 34 - 160 + 150);
    expect(
      rig.characters.keys,
      unorderedEquals(CharacterRig.standard.selectable.map((a) => a.id)),
    );
  });

  group('where each character stands (A8 spec 3, 9.1)', () {
    const places = {
      ('mouse', HoldPose.plank): (1.12, 11.0, null),
      ('kangaroo', HoldPose.plank): (1.12, 24.0, null),
      ('bear', HoldPose.plank): (1.12, 15.0, 'bearPlank'),
      ('penguin', HoldPose.plank): (1.28, 5.0, 'penguinLie'),
      ('seal', HoldPose.plank): (1.28, 8.0, 'sealLie'),
      ('mouse', HoldPose.chair): (1.05, 18.0, null),
      ('kangaroo', HoldPose.chair): (1.05, 18.0, null),
      ('bear', HoldPose.chair): (1.05, 18.0, null),
      ('penguin', HoldPose.chair): (1.05, 18.0, null),
      ('seal', HoldPose.chair): (1.05, 18.0, null),
    };
    for (final MapEntry(key: (id, pose), value: (scale, left, drawing))
        in places.entries) {
      test('$id ${pose.name}: scale $scale, left $left, '
          '${drawing ?? 'the rig'}', () {
        final place = rig.placeOf(id, pose);
        expect(place.characterId, id);
        expect(place.pose, pose);
        expect(place.scale, scale);
        expect(place.left, left);
        expect(place.topOn(rig), closeTo(346 - 150 * scale, 1e-9));
        expect(place.drawingName, drawing);
        expect(place.drawing == null, drawing == null);
        expect(place.standing, pose == HoldPose.chair);
        if (drawing == null) {
          expect(
            place.keyPoses.keys,
            pose == HoldPose.plank ? ['hold', 'sag'] : ['hold', 'up', 'rise'],
          );
        } else {
          expect(place.keyPoses, isEmpty);
        }
      });
    }

    test('the home rig\'s flags: gBack in a rig plank, pa for 물렁범 seated', () {
      expect(rig.placeOf('mouse', HoldPose.plank).flags, {'gBack'});
      expect(rig.placeOf('kangaroo', HoldPose.plank).flags, {'gBack'});
      expect(rig.placeOf('seal', HoldPose.chair).flags, {'pa'});
      for (final id in ['mouse', 'kangaroo', 'bear', 'penguin']) {
        expect(rig.placeOf(id, HoldPose.chair).flags, isEmpty, reason: id);
      }
    });

    test('RepBot and an unknown character hold as GYM마우스', () {
      for (final pose in HoldPose.values) {
        expect(rig.placeOf('bot', pose).characterId, 'mouse');
        expect(rig.placeOf('nobody', pose).characterId, 'mouse');
      }
    });
  });

  group('key poses (A8 spec 1, 9.2)', () {
    final home = CharacterMotionRig.standard;

    test('GYM마우스 and 그루 hold and sag as home\'s push-up up and down', () {
      for (final id in ['mouse', 'kangaroo']) {
        final place = rig.placeOf(id, HoldPose.plank);
        final pushUp = home.motionOf(id).keyPoses;
        expectSamePose(place.keyPoses['hold']!, pushUp['up']!, '$id hold');
        expectSamePose(place.keyPoses['sag']!, pushUp['down']!, '$id sag');
      }
    });

    test('펭뚱이 and 물렁범 sit as home\'s squat down', () {
      for (final id in ['penguin', 'seal']) {
        expectSamePose(
          rig.placeOf(id, HoldPose.chair).keyPoses['hold']!,
          home.motionOf(id).keyPoses['down']!,
          '$id hold',
        );
      }
    });

    test('every rig pose has the home rig\'s keys and one shape, so its key '
        'poses blend', () {
      final keys = home.motionOf('mouse').keyPoses['up']!;
      for (final places in rig.characters.values) {
        for (final place in places.values) {
          final first = place.keyPoses['hold'];
          if (first == null) continue;
          expect(first.transforms.keys, unorderedEquals(keys.transforms.keys));
          expect(first.paths.keys, unorderedEquals(keys.paths.keys));
          for (final pose in place.keyPoses.values) {
            for (final key in first.transforms.keys) {
              expect(
                [for (final m in pose.transform(key)) m.kind],
                [for (final m in first.transform(key)) m.kind],
              );
            }
            for (final key in first.paths.keys) {
              expect(
                [for (final s in pose.path(key)) s.command],
                [for (final s in first.path(key)) s.command],
              );
            }
          }
        }
      }
    });
  });

  group('the three drawings (A8 spec 2)', () {
    test('곰탱이\'s plank: its arms turn, no head tilt', () {
      final place = rig.placeOf('bear', HoldPose.plank);
      expect(place.nearArm!.pivot, const Offset(102, 104));
      expect(place.nearArm!.deg, -28);
      expect(place.headTilt, isNull);
      expect(place.sweat, const Offset(132, 52));
      expect(place.spark, const Offset(72, 104));
    });

    test('펭뚱이 and 물렁범 lie with the head up (candidate A)', () {
      final penguin = rig.placeOf('penguin', HoldPose.plank);
      expect(penguin.nearArm!.pivot, const Offset(62, 116));
      expect(penguin.nearArm!.deg, -50);
      expect(penguin.headTilt!.pivot, const Offset(112, 112));
      expect(penguin.headTilt!.deg, -6);
      expect(penguin.spark, const Offset(78, 118));
      final seal = rig.placeOf('seal', HoldPose.plank);
      expect(seal.nearArm!.pivot, const Offset(98, 126));
      expect(seal.nearArm!.deg, -55);
      expect(seal.headTilt!.deg, -6);
      expect(seal.sweat, const Offset(144, 62));
    });

    test('their shapes: every one in the mockup, in order, with its faces '
        'and the team lime', () {
      const counts = {'bearPlank': 37, 'penguinLie': 22, 'sealLie': 37};
      expect(rig.drawings.keys, unorderedEquals(counts.keys));
      for (final MapEntry(:key, :value) in counts.entries) {
        final shapes = rig.drawings[key]!;
        expect(shapes, hasLength(value), reason: key);
        final faces = {for (final s in shapes) s.face.join('+')};
        expect(faces, containsAll(['', 'idle', 'atk', 'win', 'hit']));
        // The gritted teeth sit inside the atk face: both must be on.
        expect(faces.contains('atk+teeth'), key != 'bearPlank', reason: key);
        expect(shapes.any((s) => s.fill?.team ?? false), isTrue);
        expect(shapes.first.chain.first.part, 'tilt');
        final parts = {
          for (final s in shapes)
            for (final link in s.chain)
              if (link.part != null) link.part!,
        };
        expect(
          parts,
          key == 'bearPlank'
              ? {'tilt', 'farArm', 'head', 'nearArm'}
              : {'tilt', 'head', 'nearArm'},
        );
      }
    });

    test('a shape shows when every tag of its face is on', () {
      final teeth = rig.drawings['penguinLie']!.firstWhere(
        (s) => s.face.length == 2,
      );
      expect(teeth.shownWith({'atk'}), isFalse);
      expect(teeth.shownWith({'atk', 'teeth'}), isTrue);
      final body = rig.drawings['penguinLie']!.first;
      expect(body.face, isEmpty);
      expect(body.shownWith(const {}), isTrue);
    });
  });

  test('the effect art from the mockup', () {
    final fx = rig.fx;
    expect(fx.shadowY, 152);
    expect(fx.shadowRy, 5);
    expect(fx.shadowColor.argb, 0xFF141A26);
    expect(fx.shadowOpacity, 0.14);
    expect(fx.sweat.single.fill!.argb, 0xFF9FDCFF);
    expect(fx.sweat.single.width, 2.2);
    expect(fx.shakeWidth, 2.4);
    expect(fx.spark.single.width, 3.2);
    expect(fx.dust, hasLength(4));
    expect(fx.star.single.fill!.argb, 0xFFFFB547);
    expect(fx.trailColor.argb, 0xFFFFB547);
    expect(fx.trailWidth, 5);
    expect(fx.trailOpacity, 0.7);
  });

  group('malformed data throws a FormatException', () {
    final good = holdMeRigJson;
    final art = holdMeDrawingJson;

    test('not an object', () {
      expect(() => HoldMeRig.parse('[]', art), throwsFormatException);
      expect(() => HoldMeRig.parse(good, '1'), throwsFormatException);
    });

    test('a wrong type, a missing drawing, an unknown kind, a bad color', () {
      expect(
        () => HoldMeRig.parse(
          good.replaceFirst('"groundY": 346', '"groundY": "x"'),
          art,
        ),
        throwsFormatException,
      );
      expect(
        () => HoldMeRig.parse(good.replaceFirst('"bearPlank"', '"bearX"'), art),
        throwsFormatException,
      );
      expect(
        () => HoldMeRig.parse(
          good.replaceFirst('"kind": "drawing"', '"kind": "paint"'),
          art,
        ),
        throwsFormatException,
      );
      expect(
        () => HoldMeRig.parse(good, art.replaceFirst('"#9FDCFF"', '"blue"')),
        throwsFormatException,
      );
      expect(
        () => HoldMeRig.parse(good, art.replaceFirst('["Z"]', '["Z",1]')),
        throwsFormatException,
      );
      expect(
        () => HoldMeRig.parse(good, art.replaceFirst('["M",', '["S",')),
        throwsFormatException,
      );
      expect(
        () => HoldMeRig.parse(
          good,
          art.replaceFirst('"cap":"butt"', '"cap":"flat"'),
        ),
        throwsFormatException,
      );
    });

    test('a rig pose without one of its key poses', () {
      expect(
        () => HoldMeRig.parse(good.replaceFirst('"sag": {', '"sog": {'), art),
        throwsFormatException,
      );
    });
  });
}
