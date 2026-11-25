// The golden values (`auth_cast_golden.json`) come from the design itself:
// the P8 bundle's `ChL.dc.html` (2026-11-25) run in node, its own
// `Component.RIGX.vals` on `Component.DATA` `motions.d1` for each of the six
// characters (RepBot on the pink team, as LoginB draws it). The times are
// every segment's start and end, 25 %, 50 % and 80 % into it (the eased
// middles), 1 ms either side of each expression, hop or rock range start and
// end and flag change, each effect's start, 10 %, middle, 85 % and end,
// and 0, 1, -1, -1000, -5000, 17999, 18000, 18001 and 36500 (the wrap).
// The script and the bundle are not in the repo.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/widgets/auth_cast.dart';
import 'package:gymrats_app/widgets/auth_cast_data.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/character_draw_patch.dart';
import 'package:gymrats_app/widgets/character_motion.dart';

final _golden = jsonDecode(
  File('test/widgets/auth_cast_golden.json').readAsStringSync(),
) as Map<String, dynamic>;

const _gKeys = {'tail', 'torso', 'head', 'belly'};
const _sKeys = {'s1', 's2', 'g1', 'g2', 'p1', 'p2'};

/// A pose key's numbers as ChL keeps them: G [tx, ty, deg, cx, cy, sx, sy],
/// S [tx, ty, deg, sx, sy], a path's points in order.
List<double> _chlNumbers(RigPoseTable pose, String key) {
  if (_gKeys.contains(key)) {
    final m = pose.transform(key);
    return [...m[0].values, ...m[1].values, ...m[3].values];
  }
  if (_sKeys.contains(key)) {
    final m = pose.transform(key);
    return [...m[0].values, m[1].values[0], ...m[2].values];
  }
  return [for (final step in pose.path(key)) ...step.values];
}

/// The cast's json, to break on purpose.
Map<String, dynamic> _source() =>
    jsonDecode(authCastJson) as Map<String, dynamic>;

void _expectRejected(void Function(Map<String, dynamic> json) breakIt) {
  final json = _source();
  breakIt(json);
  expect(() => AuthCast.parse(jsonEncode(json)), throwsFormatException);
}

/// The key pose a character holds at [tMs]: p0, p1 or p2, the nearer end
/// of a change under way.
String _held(AuthCastCharacter c, double tMs) {
  final t = c.motion.wrap(tMs);
  final segments = c.motion.segments;
  var key = segments.first.fromKey;
  for (final s in segments) {
    if (t < s.fromMs) break;
    final u = s.toMs == s.fromMs ? 1 : (t - s.fromMs) / (s.toMs - s.fromMs);
    key = t <= s.toMs && u < 0.5 ? s.fromKey : s.toKey;
  }
  return key.substring(0, 2);
}

Widget _stage({bool still = false}) => MediaQuery(
  data: MediaQueryData(size: const Size(360, 780), disableAnimations: still),
  child: const Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 360,
        height: 520,
        child: AuthCastStage(place: AuthCastPlace.login),
      ),
    ),
  ),
);

AuthCastStageState _clock(WidgetTester tester) =>
    tester.state<AuthCastStageState>(find.byType(AuthCastStage));

void main() {
  final cast = AuthCast.standard;
  final rig = CharacterRig.standard;

  group('the cast data', () {
    test('six characters back to front at LoginB CAST.b1 with TIMING.d1', () {
      expect(
        [
          for (final m in cast.members)
            (m.id, m.x, m.y, m.scale, m.flip, m.side, m.phMs, m.ftMs),
        ],
        [
          ('mouse', 180, 316, 1.05, false, BattleSide.me, 0, 4000),
          ('bear', 86, 412, 1.0, false, BattleSide.me, -2000, 10000),
          ('kangaroo', 270, 412, 1.0, true, BattleSide.me, -4000, 16000),
          ('penguin', 66, 502, 1.0, false, BattleSide.me, -5000, 4000),
          ('bot', 296, 502, 1.0, true, BattleSide.opponent, -3000, 16000),
          ('seal', 180, 502, 1.05, false, BattleSide.me, -1000, 10000),
        ],
      );
      expect(cast.label, 'GYM마우스, 그루, 곰탱이, 펭뚱이, 물렁범, RepBot이 세 칸 단 위에 선 단체 사진');
    });

    test('the podium and planes of LoginB', () {
      final stage = cast.stage;
      expect((stage.width, stage.height), (360, 780));
      expect((stage.dyLogin, stage.dySignup), (40, 0));
      expect(
        [for (final s in stage.steps) s.rect.outerRect],
        [
          const Rect.fromLTWH(122, 316, 116, 236),
          const Rect.fromLTWH(30, 412, 300, 140),
          const Rect.fromLTWH(6, 502, 348, 50),
        ],
      );
      expect(stage.stepStroke, 3);
      expect(
        stage.podiumShadow.oval,
        Rect.fromCenter(center: const Offset(180, 553), width: 372, height: 18),
      );
      expect(stage.planes.map((p) => p.points.length), [4, 3]);
      expect(
        (stage.castShadow.rx, stage.castShadow.ry, stage.castShadow.dy),
        (42, 7, 2),
      );
    });

    test('every loop is 18 s and holds each pose 6 s', () {
      for (final c in cast.characters.values) {
        expect(c.motion.durMs, 18000, reason: c.id);
        expect(c.motion.loop, isTrue, reason: c.id);
        expect(
          [
            for (final s in c.motion.segments)
              if (s.toKey.endsWith('a') &&
                  !s.fromKey.startsWith(s.toKey.substring(0, 2)))
                s.fromMs,
          ],
          [0, 6000, 12000],
          reason: c.id,
        );
      }
    });

    test('every face a loop shows has shapes in its drawing', () {
      for (final c in cast.characters.values) {
        final list = characterDrawList(
          rig.art(c.id),
          c.drawPatch,
          CharacterMotionRig.standard.effects,
        );
        for (final e in c.motion.expressions) {
          final tags = cast.tagsOf(e.expression, c.id);
          expect(
            list.where(
              (item) =>
                  !item.effect && (item.op.show?.any(tags.contains) ?? false),
            ),
            isNotEmpty,
            reason: '${c.id} ${e.expression}',
          );
        }
        for (final f in c.flagTimes.expand((f) => f.flags)) {
          expect(
            list.where((item) => item.condition?.flag == f),
            isNotEmpty,
            reason: '${c.id} $f',
          );
        }
      }
    });

    test('the new faces show only in their own expression', () {
      final mouse = cast.characters['mouse']!;
      final list = characterDrawList(
        rig.art('mouse'),
        mouse.drawPatch,
        CharacterMotionRig.standard.effects,
      );
      bool shows(String expression, String tag) => list.any(
        (item) =>
            (item.op.show?.contains(tag) ?? false) &&
            cast.tagsOf(expression, 'mouse').contains(tag),
      );
      expect(shows('wink', 'wink'), isTrue);
      expect(shows('laugh', 'wink'), isFalse);
      expect(cast.tagsOf('grin', 'seal'), {'grin'});
      expect(cast.tagsOf('grin', 'mouse'), {'win'});
    });

    test('a malformed cast is rejected', () {
      expect(() => AuthCast.parse('[]'), throwsFormatException);
      _expectRejected((j) => (j['cast'] as List).first['id'] = 'cat');
      _expectRejected((j) => (j['cast'] as List).first['team'] = 'blue');
      _expectRejected((j) => j['stage']['steps'][0]['fill'] = '#C6FF3D');
      _expectRejected((j) => (j['expressions']['map'] as Map).remove('wink'));
      Map<String, dynamic> mouse(Map<String, dynamic> j) =>
          j['characters']['mouse'] as Map<String, dynamic>;
      _expectRejected((j) => (mouse(j)['glob'] as List).first['k'] = 'land');
      _expectRejected((j) => (mouse(j)['glob'] as List).first['ms'] = 0);
      _expectRejected((j) => (mouse(j)['fx'] as List).first['k'] = 'zzz');
      _expectRejected((j) => (mouse(j)['fx'] as List).first['follow'] = true);
      _expectRejected((j) => (mouse(j)['fx'] as List).first['to'] = 0);
      _expectRejected((j) => mouse(j)['motion']['loop'] = false);
      _expectRejected((j) => mouse(j)['flagT'] = 'gBack');
      _expectRejected(
        (j) => j['fxShapes']['spark']['d'] = [
          ['Q', 0, 0, 1, 1],
        ],
      );
    });
  });

  group('the loops match the design (ChL d1)', () {
    for (final MapEntry(key: id, value: rows)
        in (_golden['characters'] as Map<String, dynamic>).entries) {
      test('$id at ${(rows as List).length} times', () {
        final c = cast.characters[id]!;
        for (final row in rows.cast<Map<String, dynamic>>()) {
          final t = (row['t'] as num).toDouble();
          final frame = c.frameAt(t, cast);
          final why = '$id at $t ms';
          for (final MapEntry(:key, :value)
              in (row['P'] as Map<String, dynamic>).entries) {
            final want = [for (final v in value as List) (v as num).toDouble()];
            final got = _chlNumbers(frame.pose, key);
            expect(got.length, want.length, reason: '$why $key');
            for (var i = 0; i < want.length; i++) {
              expect(got[i], closeTo(want[i], 2e-6), reason: '$why $key[$i]');
            }
          }
          expect(frame.expression, row['expr'], reason: why);
          final g = row['g'] as Map<String, dynamic>;
          expect(
            frame.global.up,
            closeTo((g['up'] as num).toDouble(), 2e-6),
            reason: why,
          );
          expect(
            frame.global.rotDeg,
            closeTo((g['rot'] as num).toDouble(), 2e-6),
            reason: why,
          );
          expect(
            (frame.global.sx, frame.global.sy),
            (g['sx'], g['sy']),
            reason: why,
          );
          expect(
            frame.flags,
            Set<String>.from(row['flags'] as List),
            reason: why,
          );
          final shown = row['shown'] as Map<String, dynamic>;
          if (rig.art(id).ops.any((op) => op.chain.any((p) => p.key == 'g1'))) {
            expect(
              frame.flags.contains('gBack'),
              shown['gB'] == 'inline',
              reason: why,
            );
            expect(
              frame.flags.contains('th2'),
              shown['th2'] == 'inline',
              reason: why,
            );
          }
          final fx = (row['fx'] as List).cast<Map<String, dynamic>>();
          expect(frame.effects.length, fx.length, reason: '$why effects');
          for (var i = 0; i < fx.length; i++) {
            final got = frame.effects[i];
            expect(got.kind.name, fx[i]['k'], reason: why);
            expect(
              got.center.dx,
              closeTo((fx[i]['x'] as num).toDouble(), 0.006),
              reason: why,
            );
            expect(
              got.center.dy,
              closeTo((fx[i]['y'] as num).toDouble(), 0.006),
              reason: why,
            );
            expect(
              got.scale,
              closeTo((fx[i]['s'] as num).toDouble(), 6e-5),
              reason: why,
            );
            expect(
              got.opacity,
              closeTo((fx[i]['o'] as num).toDouble(), 6e-5),
              reason: why,
            );
          }
        }
      });
    }

    test('the golden covers all six and each change of its loop', () {
      final characters = _golden['characters'] as Map<String, dynamic>;
      expect(characters.keys.toSet(), cast.characters.keys.toSet());
      for (final c in cast.characters.values) {
        final times = {
          for (final row in characters[c.id] as List)
            ((row as Map<String, dynamic>)['t'] as num).toDouble(),
        };
        for (final g in c.global) {
          expect(
            times,
            containsAll([g.fromMs - 1, g.fromMs + 1, g.toMs - 1, g.toMs + 1]),
          );
        }
        for (final f in c.flagTimes.skip(1)) {
          expect(times, containsAll([f.atMs - 1, f.atMs + 1]));
        }
        expect(times, containsAll([17999, 18000, 18001]));
      }
    });
  });

  group('one at a time (SPEC 2)', () {
    test('each second from 1 s to 6 s, exactly one more changes pose', () {
      Map<String, String> held(double nowMs) => {
        for (final m in cast.members)
          m.id: _held(cast.characters[m.id]!, nowMs + m.phMs),
      };
      const order = ['mouse', 'seal', 'bear', 'bot', 'kangaroo', 'penguin'];
      for (var s = 1; s <= 6; s++) {
        final before = held((s - 1) * 1000.0);
        final after = held(s * 1000.0);
        expect(
          [
            for (final id in order)
              if (before[id] != after[id]) id,
          ],
          [order[s - 1]],
          reason: '${s - 1} s -> $s s',
        );
      }
      // 0 s and 1 s: only GYM마우스 differs, and it holds a pose 6 s.
      expect(held(1000)['mouse'], 'p0');
      expect(held(6000)['mouse'], 'p0');
      expect(held(7000)['mouse'], 'p1');
    });

    test('animations off: each character shows its LoginB ft moment', () {
      for (final m in cast.members) {
        final still = cast.frameOf(m, nowMs: 12345, still: true);
        final at = cast.characters[m.id]!.frameAt(m.ftMs, cast);
        expect(still.expression, at.expression, reason: m.id);
        expect(
          _chlNumbers(still.pose, 'torso'),
          _chlNumbers(at.pose, 'torso'),
          reason: m.id,
        );
      }
    });
  });

  group('the stage', () {
    testWidgets('reads as one picture with the cast label', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_stage());
      expect(find.bySemanticsLabel(cast.label), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('starts at 0 and runs with time', (tester) async {
      await tester.pumpWidget(_stage());
      expect(_clock(tester).nowMs, 0);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_clock(tester).nowMs, closeTo(1500, 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('animations off: never ticks', (tester) async {
      await tester.pumpWidget(_stage(still: true));
      await tester.pump(const Duration(seconds: 3));
      expect(_clock(tester).still, isTrue);
      expect(_clock(tester).nowMs, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('stops while the app is in the background, then goes on', (
      tester,
    ) async {
      await tester.pumpWidget(_stage());
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final before = _clock(tester).nowMs;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 5));
      expect(_clock(tester).nowMs, before);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_clock(tester).nowMs, closeTo(before + 500, 1));
    });

    testWidgets('stops while another screen covers it, then goes on', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(
            body: AuthCastStage(place: AuthCastPlace.signup),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final covered = _clockOffstage(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(_clockOffstage(tester), covered);
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_clock(tester).nowMs, inInclusiveRange(covered + 1, covered + 1001));
    });

    testWidgets('a sheet on top does not stop it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  const Expanded(
                    child: AuthCastStage(place: AuthCastPlace.login),
                  ),
                  TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => const SizedBox(height: 100),
                    ),
                    child: const Text('open'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final before = _clock(tester).nowMs;
      await tester.pump(const Duration(seconds: 1));
      expect(_clock(tester).nowMs, closeTo(before + 1000, 1));
    });

    test('draws the band as large as fits, up to the given largest', () {
      final painter = AuthCastPainter(
        cast: cast,
        place: AuthCastPlace.login,
        now: ValueNotifier(0),
        still: false,
        maxScale: 1.2,
      );
      expect(painter.scaleIn(const Size(360, 520)), 1);
      expect(painter.scaleIn(const Size(360, 260)), 0.5);
      expect(painter.scaleIn(const Size(180, 520)), 0.5);
      expect(painter.scaleIn(const Size(720, 1040)), 1.2);
    });
  });
}

/// The clock of a stage that is offstage (under an opaque screen).
double _clockOffstage(WidgetTester tester) => tester
    .state<AuthCastStageState>(find.byType(AuthCastStage, skipOffstage: false))
    .nowMs;
