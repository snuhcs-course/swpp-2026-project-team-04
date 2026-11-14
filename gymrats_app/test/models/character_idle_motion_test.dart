import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/character_idle_motion.dart';
import 'package:gymrats_app/models/character_rig.dart';

/// The design's idle motion values (`idle_golden.json` of the W3 package):
/// six characters and W2's breathing at eleven times each.
const _goldenPath = 'test/models/character_idle_golden.json';

void main() {
  final golden =
      jsonDecode(File(_goldenPath).readAsStringSync()) as Map<String, dynamic>;
  final tolerance = golden['tolerance'] as Map<String, dynamic>;
  final samples = golden['samples'] as Map<String, dynamic>;
  final rig = CharacterRig.standard;

  group('against idle_golden.json', () {
    test('covers the six characters and W2\'s breathing', () {
      expect(samples.keys, [...rig.order, 'w2default']);
    });

    void check(String name, CharacterIdleMotion motion, List<dynamic> rows) {
      expect(rows, hasLength(11));
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final t = (row['t'] as num).toDouble();
        final sample = motion.sampleAt(t);
        final at = '$name at $t ms';
        expect(
          sample.up,
          closeTo(row['up'] as num, tolerance['up']),
          reason: at,
        );
        expect(
          sample.rockDeg,
          closeTo(row['rockDeg'] as num, tolerance['rockDeg']),
          reason: at,
        );
        expect(
          sample.scaleX,
          closeTo(row['scaleX'] as num, tolerance['scale']),
          reason: at,
        );
        expect(
          sample.scaleY,
          closeTo(row['scaleY'] as num, tolerance['scale']),
          reason: at,
        );
      }
    }

    for (final id in const [
      'mouse',
      'kangaroo',
      'bear',
      'penguin',
      'seal',
      'bot',
    ]) {
      test('$id moves as the design computed', () {
        check(id, rig.art(id).idleMotion, samples[id] as List);
      });
    }

    test('the W2 default (exact and as the rig rounds it) breathes as the '
        'design computed', () {
      check('w2Default', CharacterIdleMotion.w2Default, samples['w2default']);
      check('rig w2Default', rig.idleMotionW2Default, samples['w2default']);
    });
  });

  test('the W2 default is W2\'s breathing: height 1 + 0.02 sin(t / 280), '
      'nothing else', () {
    for (var t = 0.0; t < 30000; t += 37.3) {
      final sample = CharacterIdleMotion.w2Default.sampleAt(t);
      expect(sample.scaleY, closeTo(1 + 0.02 * math.sin(t / 280), 1e-12));
      expect(sample.scaleX, 1);
      expect(sample.up, 0);
      expect(sample.rockDeg, 0);
    }
  });

  test('a period of 0 turns its part off', () {
    const motion = CharacterIdleMotion(
      hopAmp: 5,
      rockDeg: 3,
      stretch: 0.1,
      squash: 0.1,
    );
    final sample = motion.sampleAt(123);
    expect(
      (sample.up, sample.rockDeg, sample.scaleX, sample.scaleY),
      (0, 0, 1, 1),
    );
  });

  test('a hop goes up and comes back, never below the floor', () {
    const hop = CharacterIdleMotion(hopAmp: 6, hopPeriodMs: 460);
    expect(hop.sampleAt(0).up, closeTo(0, 1e-9));
    expect(hop.sampleAt(230).up, closeTo(6, 1e-9));
    expect(hop.sampleAt(460).up, closeTo(0, 1e-9));
    for (var t = 0.0; t < 2000; t += 13) {
      expect(hop.sampleAt(t).up, inInclusiveRange(0, 6));
    }
  });

  test('a stepped rock snaps between the two sides; a smooth one sways', () {
    const stepped = CharacterIdleMotion(
      rockDeg: 1.5,
      rockPeriodMs: 1200,
      stepped: true,
    );
    expect(stepped.sampleAt(50).rockDeg, 1.5);
    expect(stepped.sampleAt(599).rockDeg, 1.5);
    expect(stepped.sampleAt(601).rockDeg, -1.5);
    expect(stepped.sampleAt(1150).rockDeg, -1.5);
    const smooth = CharacterIdleMotion(rockDeg: 1.5, rockPeriodMs: 1200);
    expect(
      smooth.sampleAt(50).rockDeg,
      closeTo(1.5 * math.sin(math.pi / 12), 1e-9),
    );
  });

  test('a stretch makes the body taller and narrower together', () {
    const seal = CharacterIdleMotion(
      stretch: 0.03,
      squash: 0.03,
      stretchPeriodMs: 1100,
    );
    final top = seal.sampleAt(275);
    expect(top.scaleY, closeTo(1.03, 1e-9));
    expect(top.scaleX, closeTo(0.97, 1e-9));
    final bottom = seal.sampleAt(825);
    expect(bottom.scaleY, closeTo(0.97, 1e-9));
    expect(bottom.scaleX, closeTo(1.03, 1e-9));
  });

  test('reads a missing value as 0 or false', () {
    final motion = CharacterIdleMotion.fromJson(const {'hopAmp': 3});
    expect(motion.hopAmp, 3);
    expect([
      motion.hopPeriodMs,
      motion.rockDeg,
      motion.rockPeriodMs,
      motion.stretch,
      motion.squash,
      motion.stretchPeriodMs,
    ], everyElement(0));
    expect(motion.stepped, isFalse);
  });

  test('rest is no motion at all', () {
    const rest = IdleSample.rest;
    expect((rest.up, rest.rockDeg, rest.scaleX, rest.scaleY), (0, 0, 1, 1));
    expect(
      rest.toString(),
      'IdleSample(up: 0.0, rockDeg: 0.0, scaleX: 1.0, '
      'scaleY: 1.0)',
    );
  });
}
