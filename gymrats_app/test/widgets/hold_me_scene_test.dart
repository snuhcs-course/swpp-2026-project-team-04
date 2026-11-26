// The character's pictures against the mockup (A8 spec 8, 9.3, 9.7 to 9.9,
// 9.11).
//
// test/widgets/hold_me_golden.json holds the values of the A8 design
// bundle's data/hold_me_golden.json that the app can be compared with,
// parsed into numbers by a script outside the repo, plus star 220, 460, 620,
// 1200, 1225 ms and warning 45, 90, 135 ms with the rig's values: those
// came from the mockup's own renderVals() (HoldMe.dc.html, canvas version
// 1795674999-e13f) run in node with props dir=a act=pop lie=a coach=seal
// live=false, after the same run reproduced the bundle's moments exactly.
// The mockup prints 2 decimals, hence the tolerance.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/widgets/character_draw_patch.dart';
import 'package:gymrats_app/widgets/hold_me_rig.dart';
import 'package:gymrats_app/widgets/hold_me_scene.dart';
import 'package:gymrats_app/widgets/victory_motion.dart';

const _tol = 0.0051;

final Map<String, dynamic> _golden = jsonDecode(
  File('test/widgets/hold_me_golden.json').readAsStringSync(),
);

final _rig = HoldMeRig.standard;

HoldPose _pose(String name) =>
    name == 'plank' ? HoldPose.plank : HoldPose.chair;

HoldMeMoment _moment(String kind, double t) => switch (kind) {
  'go' => const HoldMeMoment.go(),
  'hold' => const HoldMeMoment.hold(),
  'strain' => const HoldMeMoment.strain(),
  'star' => HoldMeMoment.star(1, t),
  'star2' => HoldMeMoment.star(2, t),
  'warn' => HoldMeMoment.warn(t),
  _ => throw ArgumentError(kind),
};

double _n(Object? v) => (v as num).toDouble();

void _close(double actual, Object? expected, String reason) =>
    expect(actual, closeTo(_n(expected), _tol), reason: reason);

/// [pose]'s moves and path steps against the mockup's, key by key.
void _expectPose(RigPoseTable pose, Map<String, dynamic> golden, String at) {
  for (final MapEntry(:key, :value) in golden.entries) {
    final steps = value as List;
    if (pose.transforms.containsKey(key)) {
      final moves = pose.transform(key);
      expect(moves, hasLength(steps.length), reason: '$at $key');
      for (final (i, move) in moves.indexed) {
        final step = steps[i] as List;
        expect(move.kind.name[0], step.first, reason: '$at $key');
        final numbers = step.skip(1).toList();
        // The mockup prints rotate(a) for a turn about (0, 0).
        if (move.kind == RigTransformKind.rotate && numbers.length == 1) {
          expect(move.values.skip(1), [0, 0], reason: '$at $key');
        }
        for (final (j, v) in numbers.indexed) {
          _close(move.values[j], v, '$at $key $i');
        }
      }
    } else {
      final segments = pose.path(key);
      expect(segments, hasLength(steps.length), reason: '$at $key');
      for (final (i, segment) in segments.indexed) {
        final step = steps[i] as List;
        expect(rigCommandLetter(segment.command), step.first);
        for (final (j, v) in step.skip(1).indexed) {
          _close(segment.values[j], v, '$at $key $i');
        }
      }
    }
  }
}

/// The frame of [place] at [moment] against the mockup's moment [m].
void _expectMoment(
  Map<String, dynamic> m,
  HoldMePlace place,
  String kind,
  double t,
  List<int> seconds,
  String at,
) {
  final frame = HoldMeScene.frameAt(place, _moment(kind, t));
  final box = m['box'] as List;
  expect(place.left, _n(box[0]), reason: at);
  _close(place.topOn(_rig), box[1], at);
  expect(place.scale, closeTo(_n(box[2]), 1e-9), reason: at);
  final me = m['me'] as List;
  _close(frame.jx, me[0], '$at jx');
  _close(frame.hop, me[1], '$at hop');
  _close(frame.sx, me[2], '$at sx');
  _close(frame.sy, me[3], '$at sy');
  final shadow = m['shadow'] as List;
  expect(frame.shadowX, _n(shadow[0]), reason: at);
  _close(frame.shadowRx, shadow[1], '$at shadow');
  expect(place.drawing != null, m['drawn'] == 'drawing', reason: at);
  expect(frame.pose == null, place.drawing != null, reason: at);
  if (m['face'] case final String face) {
    expect(
      place.drawing != null ? frame.drawingTags.join('+') : frame.expression,
      face,
      reason: '$at face',
    );
  }
  if (m['pose'] case final Map<String, dynamic> pose) {
    _expectPose(frame.pose!, pose, at);
  }
  if (place.drawing != null) {
    final tilt = m['tilt'] as List?;
    if (tilt == null) {
      expect(frame.tilt, 0, reason: '$at tilt');
    } else if (tilt.first == 'r') {
      // 곰탱이 tips 4° about its toes (10, 146).
      _close(4 * frame.tilt, tilt[1], '$at tilt');
      expect([tilt[2], tilt[3]], [10, 146]);
    } else {
      _close(1 + 0.05 * frame.tilt, tilt[1], '$at tilt x');
      _close(1 - 0.1 * frame.tilt, tilt[2], '$at tilt y');
    }
    final arm = m['arm'] as List?;
    _close(frame.nearArmDeg, arm?[1] ?? 0, '$at arm');
    if (arm != null) {
      expect(Offset(_n(arm[2]), _n(arm[3])), place.nearArm!.pivot, reason: at);
    }
    final head = m['head'] as List?;
    _close(frame.headDeg, head?[1] ?? 0, '$at head');
    if (head != null) {
      expect(
        Offset(_n(head[2]), _n(head[3])),
        place.headTilt!.pivot,
        reason: at,
      );
    }
  }
  final spark = m['spark'] as List?;
  expect(frame.spark == null, spark == null, reason: '$at spark');
  if (spark != null) {
    expect(frame.spark!.at, Offset(_n(spark[0]), _n(spark[1])), reason: at);
    _close(frame.spark!.scale, spark[2], '$at spark scale');
    _close(frame.spark!.opacity, spark[3], '$at spark opacity');
  }
  final dust = m['dust'] as List?;
  expect(frame.dust == null, dust == null, reason: '$at dust');
  if (dust != null) {
    _close(frame.dust!.scaleX, dust[0], '$at dust');
    _close(frame.dust!.opacity, dust[1], '$at dust opacity');
  }
  final shake = m['shake'] as List?;
  expect(frame.shake, shake != null, reason: '$at shake');
  if (shake != null) {
    expect(
      [
        for (final (a, b, c) in frame.shakeArcs) ...[
          a.dx,
          a.dy,
          b.dx,
          b.dy,
          c.dx,
          c.dy,
        ],
      ],
      [for (final v in shake) _n(v)],
      reason: at,
    );
  }
  final sweat = m['sweat'] as List?;
  expect(frame.sweat, hasLength(sweat?.length ?? 0), reason: '$at sweat');
  for (final (i, drop) in frame.sweat.indexed) {
    final g = sweat![i] as List;
    _close(drop.at.dx, g[0], '$at sweat $i x');
    _close(drop.at.dy, g[1], '$at sweat $i y');
    _close(drop.rotDeg, g[2], '$at sweat $i rot');
    _close(drop.scale, g[3], '$at sweat $i scale');
    _close(drop.opacity, g[4], '$at sweat $i opacity');
  }
  if (kind == 'star' || kind == 'star2') {
    final n = kind == 'star' ? 1 : 2;
    final target = Offset(22 + 316 * seconds[n - 1] / seconds.last, 107);
    final flight = HoldMeScene.flightAt(place, place.topOn(_rig), t, target);
    final star = m['star'] as List?;
    expect(flight == null, star == null, reason: '$at flight');
    if (star != null) {
      _close(flight!.at.dx, star[0], '$at flight x');
      _close(flight.at.dy, star[1], '$at flight y');
      _close(flight.rotDeg, star[2], '$at flight rot');
      _close(flight.scale, star[3], '$at flight scale');
      for (final (i, d) in (star[4] as List).indexed) {
        final back = flight.trail[i] - flight.at;
        _close(back.dx, (d as List)[0], '$at trail $i x');
        _close(back.dy, d[1], '$at trail $i y');
      }
    }
    final lit = m['lit'] as List;
    expect(lit[n - 1], HoldMeCheer.litAt(t), reason: '$at bar star');
    for (var i = 0; i < n - 1; i++) {
      expect(lit[i], isTrue, reason: at);
    }
  }
}

void main() {
  group('every moment of the mockup (A8 spec 8, 9.3, 9.8)', () {
    final cases = _golden['cases'] as Map<String, dynamic>;
    final seconds = _golden['starSeconds'] as Map<String, dynamic>;
    test('five characters in two poses', () {
      expect(cases.keys.toSet(), {
        for (final id in ['mouse', 'kangaroo', 'bear', 'penguin', 'seal'])
          for (final pose in ['plank', 'chair']) '$id.$pose',
      });
    });
    for (final MapEntry(key: name, value: case_) in cases.entries) {
      final [id, poseName] = name.split('.');
      final place = _rig.placeOf(id, _pose(poseName));
      final stars = [for (final s in seconds[poseName] as List) s as int];
      test(name, () {
        for (final MapEntry(key: kind, :value) in (case_ as Map).entries) {
          if (value case final Map<String, dynamic> m
              when m.containsKey('box')) {
            _expectMoment(m, place, kind as String, 0, stars, '$name $kind');
            continue;
          }
          for (final MapEntry(key: t, value: m) in (value as Map).entries) {
            _expectMoment(
              m as Map<String, dynamic>,
              place,
              kind as String,
              double.parse(t as String),
              stars,
              '$name $kind $t',
            );
          }
        }
      });
    }
  });

  group('the flight to the bar (A8 spec 4, 5)', () {
    final place = _rig.placeOf('mouse', HoldPose.plank);
    final top = place.topOn(_rig);
    const target = Offset(22 + 316 * 15 / 30, 107);

    test('leaves at 220 ms from the body, and lands on the mark at 900', () {
      expect(HoldMeScene.flightAt(place, top, 219.9, target), isNull);
      final first = HoldMeScene.flightAt(place, top, 220, target)!;
      expect(
        first.at,
        Offset(
          place.left + 72 * 1.12,
          top + 84 * 1.12 - HoldMeScene.hopAt(220),
        ),
      );
      final last = HoldMeScene.flightAt(place, top, 899.999, target)!;
      expect(last.at.dx, closeTo(target.dx, 1e-6));
      expect(last.at.dy, closeTo(target.dy, 1e-6));
      expect(last.rotDeg, closeTo(360, 1e-6));
      expect(last.scale, closeTo(1, 1e-6));
      expect(HoldMeScene.flightAt(place, top, 900, target), isNull);
    });

    test('none with reduced motion', () {
      expect(
        HoldMeScene.flightAt(place, top, 500, target, still: true),
        isNull,
      );
    });
  });

  group('the timeline (A8 spec 4)', () {
    HoldMeTimeline timeline() => HoldMeTimeline(const [15, 20, 30]);

    void at(
      HoldMeTimeline line,
      double ms, {
      int heldMs = 0,
      bool counting = false,
      bool entering = false,
      bool stopped = false,
      bool ended = false,
    }) => line.look(
      ms,
      counting: counting,
      entering: entering,
      stopped: stopped,
      held: Duration(milliseconds: heldMs),
      ended: ended,
    );

    test(
      'the 3·2·1 and a chair pose\'s entry are go; a plank holds from GO',
      () {
        final line = timeline();
        at(line, 0, counting: true);
        expect(line.momentAt(0), const HoldMeMoment.go());
        at(line, 3000, entering: true);
        expect(line.momentAt(3000), const HoldMeMoment.go());
        at(line, 3600);
        expect(line.momentAt(3600), const HoldMeMoment.hold());
      },
    );

    test('a star pops for 1.6 s from when it came; the second gives way to '
        'the strain at 1.35 s', () {
      final line = timeline();
      at(line, 0, heldMs: 14900);
      at(line, 100, heldMs: 15000);
      expect(line.starAge(1, 500), 400);
      expect(line.momentAt(100), const HoldMeMoment.star(1, 0));
      expect(line.momentAt(1699), const HoldMeMoment.star(1, 1599));
      expect(line.momentAt(1700), const HoldMeMoment.hold());
      at(line, 5100, heldMs: 20000);
      expect(line.momentAt(5100 + 1349), const HoldMeMoment.star(2, 1349));
      // Spec 9.7: no grit before ★2's motion ends, and from then on.
      expect(line.momentAt(5100 + 1350), const HoldMeMoment.strain());
      expect(line.momentAt(9000), const HoldMeMoment.strain());
    });

    test('no grit before the second star', () {
      final line = timeline();
      for (var ms = 0; ms <= 19900; ms += 100) {
        at(line, ms.toDouble(), heldMs: ms);
        expect(line.momentAt(ms.toDouble()).kind, isNot(HoldMeKind.strain));
      }
    });

    test('with reduced motion a star\'s look lasts 1.6 s, the second\'s '
        'too (spec 7)', () {
      final line = timeline();
      at(line, 0, heldMs: 19900);
      at(line, 100, heldMs: 20000);
      expect(
        line.momentAt(100 + 1400, still: true),
        const HoldMeMoment.star(2, 1400),
      );
      expect(line.momentAt(100 + 1400).kind, HoldMeKind.strain);
      expect(
        line.momentAt(100 + 1600, still: true),
        const HoldMeMoment.strain(),
      );
    });

    test('the stars before the first look have no moment, and the third '
        'none at all', () {
      final line = timeline();
      at(line, 0, heldMs: 21000);
      expect(line.starAge(1, 0), isNull);
      expect(line.starAge(2, 0), isNull);
      expect(line.momentAt(0), const HoldMeMoment.strain());
      at(line, 100, heldMs: 30000, ended: true);
      expect(line.starAge(3, 100), isNull);
      final end = timeline();
      at(end, 0, heldMs: 14900);
      at(end, 100, heldMs: 15000, stopped: true, ended: true);
      expect(end.starAge(1, 100), isNull);
    });

    test(
      'a warning: its age; back to the hold in 180 ms when the time runs',
      () {
        final line = timeline();
        at(line, 0, heldMs: 5000);
        at(line, 100, heldMs: 5000, stopped: true);
        expect(line.momentAt(400), const HoldMeMoment.warn(300));
        at(line, 1500, heldMs: 5000);
        expect(line.momentAt(1500), const HoldMeMoment.hold(sinceResumeMs: 0));
        expect(
          line.momentAt(1679),
          const HoldMeMoment.hold(sinceResumeMs: 179),
        );
        expect(line.momentAt(1680), const HoldMeMoment.hold());
      },
    );

    test('a stage that starts stopped shows the warning in full', () {
      final line = timeline();
      at(line, 0, stopped: true);
      expect(line.momentAt(10).ageMs, double.infinity);
    });

    test('a warning in a star\'s moment ends it for good; the star still '
        'flies and lights the bar (spec 9.9)', () {
      final line = timeline();
      at(line, 0, heldMs: 14900);
      at(line, 100, heldMs: 15000);
      at(line, 400, heldMs: 15000, stopped: true);
      expect(line.momentAt(400), const HoldMeMoment.warn(0));
      expect(line.starAge(1, 1000), 900);
      expect(HoldMeCheer.litAt(line.starAge(1, 1000)), isTrue);
      at(line, 1100, heldMs: 15000);
      expect(line.momentAt(1100), const HoldMeMoment.hold(sinceResumeMs: 0));
      expect(line.momentAt(1500), const HoldMeMoment.hold());
    });

    test('a warning in the strain, then the strain again', () {
      final line = timeline();
      at(line, 0, heldMs: 21000);
      at(line, 10, heldMs: 21000, stopped: true);
      expect(line.momentAt(100).kind, HoldMeKind.warn);
      at(line, 900, heldMs: 21000);
      expect(line.momentAt(950), const HoldMeMoment.strain(sinceResumeMs: 50));
    });
  });

  group('reduced motion (A8 spec 7, 9.11; user 2026-11-26)', () {
    test('a star: the chair pose\'s arms up at once with the smile, no hop, '
        'rays or dust', () {
      for (final id in ['mouse', 'kangaroo', 'bear', 'penguin', 'seal']) {
        final place = _rig.placeOf(id, HoldPose.chair);
        for (final t in [0.0, 460.0, 1599.0]) {
          final frame = HoldMeScene.frameAt(
            place,
            HoldMeMoment.star(1, t),
            liveMs: 375,
            still: true,
          );
          expect(identical(frame.pose, place.keyPoses['up']), isTrue);
          expect(frame.expression, 'win');
          expect([frame.jx, frame.hop, frame.sx, frame.sy], [0, 0, 1, 1]);
          expect(frame.spark, isNull);
          expect(frame.dust, isNull);
        }
      }
    });

    test('a star in the plank or lying: the hold pose with the smile', () {
      for (final id in ['mouse', 'kangaroo', 'bear', 'penguin', 'seal']) {
        final place = _rig.placeOf(id, HoldPose.plank);
        final frame = HoldMeScene.frameAt(
          place,
          const HoldMeMoment.star(2, 460),
          still: true,
        );
        expect(frame.expression, 'win');
        expect(frame.hop, 0);
        expect(frame.armSwing, 0);
        if (place.drawing == null) {
          expect(identical(frame.pose, place.keyPoses['hold']), isTrue);
        }
      }
    });

    test('a warning: its pose at once, no jolt; back at once', () {
      final chair = _rig.placeOf('mouse', HoldPose.chair);
      final warned = HoldMeScene.frameAt(
        chair,
        const HoldMeMoment.warn(10),
        still: true,
      );
      _expectPose(
        warned.pose!,
        ((_golden['cases'] as Map)['mouse.chair']['warn']['180'] as Map)['pose']
            as Map<String, dynamic>,
        'still warn',
      );
      expect(warned.jx, 0);
      expect(warned.expression, 'hit');
      final lying = HoldMeScene.frameAt(
        _rig.placeOf('seal', HoldPose.plank),
        const HoldMeMoment.warn(10),
        still: true,
      );
      expect(lying.tilt, 1);
      final back = HoldMeScene.frameAt(
        chair,
        const HoldMeMoment.hold(sinceResumeMs: 20),
        still: true,
      );
      expect(identical(back.pose, chair.keyPoses['hold']), isTrue);
    });

    test('the strain: grit, the shake lines and still sweat, no shake or '
        'breath', () {
      final place = _rig.placeOf('mouse', HoldPose.plank);
      final golden = (_golden['cases'] as Map)['mouse.plank']['strain'] as Map;
      final frame = HoldMeScene.frameAt(
        place,
        const HoldMeMoment.strain(),
        liveMs: 1234,
        still: true,
      );
      expect(frame.expression, 'grit');
      expect(frame.jx, 0);
      expect(frame.sy, 1);
      expect(frame.shake, isTrue);
      for (final (i, drop) in frame.sweat.indexed) {
        _close(drop.at.dx, (golden['sweat'] as List)[i][0], 'sweat $i');
      }
    });

    test('the cheer at once for 1.6 s, the bar star lit at once and not '
        'popping', () {
      expect(HoldMeCheer.bubbleAt(0, still: true), isTrue);
      expect(HoldMeCheer.bubbleAt(1599, still: true), isTrue);
      expect(HoldMeCheer.bubbleAt(1600, still: true), isFalse);
      expect(HoldMeCheer.smileAt(0, still: true), isTrue);
      expect(HoldMeCheer.smileAt(1600, still: true), isFalse);
      expect(HoldMeCheer.litAt(0, still: true), isTrue);
      expect(HoldMeCheer.popAt(950, still: true), isFalse);
    });
  });

  group('in motion', () {
    final place = _rig.placeOf('kangaroo', HoldPose.plank);

    test('holding breathes 1.2 % up and down every 1.5 s', () {
      final top = HoldMeScene.frameAt(
        place,
        const HoldMeMoment.hold(),
        liveMs: 375,
      );
      expect(top.sy, closeTo(1.012, 1e-9));
      final bottom = HoldMeScene.frameAt(
        place,
        const HoldMeMoment.go(),
        liveMs: 1125,
      );
      expect(bottom.sy, closeTo(0.988, 1e-9));
      // Not in a star or a warning.
      expect(
        HoldMeScene.frameAt(
          place,
          const HoldMeMoment.star(1, 1500),
          liveMs: 375,
        ).sy,
        1,
      );
    });

    test('the strain shakes about ±0.9 across and its sweat cycles in '
        '0.76 s', () {
      for (final live in [100.0, 777.0, 2345.0]) {
        final frame = HoldMeScene.frameAt(
          place,
          const HoldMeMoment.strain(),
          liveMs: live,
        );
        expect(frame.jx.abs(), lessThanOrEqualTo(0.9));
      }
      final start = HoldMeScene.frameAt(
        place,
        const HoldMeMoment.strain(),
        liveMs: 0,
      );
      final cycled = HoldMeScene.frameAt(
        place,
        const HoldMeMoment.strain(),
        liveMs: 760,
      );
      for (var i = 0; i < 3; i++) {
        expect(start.sweat[i].at.dx, closeTo(cycled.sweat[i].at.dx, 1e-9));
        expect(start.sweat[i].opacity, closeTo(1 - 0.75 * i / 3, 1e-9));
      }
    });

    test('back from a warning: the warning\'s pose eased out over 180 ms', () {
      final chair = _rig.placeOf('bear', HoldPose.chair);
      final back = HoldMeScene.frameAt(
        chair,
        const HoldMeMoment.hold(sinceResumeMs: 90),
      );
      // Halfway back is the warning's pose halfway in (warning 90 ms).
      _expectPose(
        back.pose!,
        ((_golden['cases'] as Map)['bear.chair']['warn']['90'] as Map)['pose']
            as Map<String, dynamic>,
        'back 90',
      );
      expect(back.expression, 'atk');
      expect(back.jx, 0);
      final lying = HoldMeScene.frameAt(
        _rig.placeOf('penguin', HoldPose.plank),
        const HoldMeMoment.strain(sinceResumeMs: 135),
      );
      expect(lying.tilt, closeTo(0.25, 1e-9));
      expect(lying.expression, 'grit');
    });

    test('the chair pose\'s arms: up over 140–300 ms, down over 1100–1350', () {
      expect(HoldMeScene.armsAt(139), 0);
      expect(HoldMeScene.armsAt(220), closeTo(0.5, 1e-9));
      expect(HoldMeScene.armsAt(300), 1);
      expect(HoldMeScene.armsAt(1099), 1);
      expect(HoldMeScene.armsAt(1225), closeTo(0.5, 1e-9));
      expect(HoldMeScene.armsAt(1350), 0);
    });

    test('blending is the W5 helper: no pose of its own', () {
      final chair = _rig.placeOf('seal', HoldPose.chair);
      final frame = HoldMeScene.frameAt(chair, const HoldMeMoment.star(1, 220));
      final expected = blendPoseTables(
        chair.keyPoses['hold']!,
        chair.keyPoses['up']!,
        0.5,
      );
      expect(
        frame.pose!.transform('torso').map((m) => m.values).toList(),
        expected.transform('torso').map((m) => m.values).toList(),
      );
    });
  });

  group('the bar star', () {
    test('lit from 900 ms after the star, popping until 1.6 s', () {
      expect(HoldMeCheer.litAt(null), isTrue);
      expect(HoldMeCheer.litAt(899), isFalse);
      expect(HoldMeCheer.litAt(900), isTrue);
      expect(HoldMeCheer.popAt(899), isFalse);
      expect(HoldMeCheer.popAt(900), isTrue);
      expect(HoldMeCheer.popAt(1599), isTrue);
      expect(HoldMeCheer.popAt(1600), isFalse);
      expect(HoldMeCheer.popAt(null), isFalse);
    });
  });
}
