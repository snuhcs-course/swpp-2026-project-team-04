import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_catalog.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/hold_progress.dart';
import 'package:gymrats_app/screens/hold_stage_art.dart';
import 'package:gymrats_app/screens/hold_stage_brief.dart';
import 'package:gymrats_app/screens/hold_stage_play.dart';
import 'package:gymrats_app/services/pose/high_plank_hold.dart';
import 'package:gymrats_app/services/pose/hold_judge.dart';
import 'package:gymrats_app/services/pose/hold_poses.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/hold_stage_viewmodel.dart';
import 'package:gymrats_app/widgets/gym_owner_figure.dart';
import 'package:gymrats_app/widgets/hold_me_figure.dart';
import 'package:gymrats_app/widgets/hold_me_rig.dart';
import 'package:gymrats_app/widgets/hold_me_scene.dart';

/// The stage of a hold, played by hand: [show] the state the view model
/// would give, then pump the time (A8 spec 9).
class _Play {
  _Play({
    this.stage = 3,
    this.character = 'mouse',
    this.goAge,
    this.size = const Size(412, 915),
    this.textScale = 1,
    this.ticking = true,
  });

  /// Stage 3 is the first floor's high plank (15, 20 and 30 s), 5 its chair
  /// pose (10, 15 and 20 s).
  final int stage;
  final String character;
  final double? goAge;
  final Size size;
  final double textScale;

  /// Whether the screen's tickers run: off when another screen covers it.
  final bool ticking;

  ArcadeHoldStage get hold => ArcadeCatalog.stage(stage) as ArcadeHoldStage;

  Future<void> show(WidgetTester tester, HoldStageState state) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TickerMode(
            enabled: ticking,
            child: HoldStagePlay(
              stage: hold,
              floor: ArcadeCatalog.floorOf(hold),
              definition: HoldPoses.of(hold.pose),
              state: state,
              setup: null,
              frame: null,
              myCharacter: character,
              goAge: goAge,
              onLeave: null,
              onGuideCrop: (_) {},
              onCameraBox: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  /// Holding for [heldMs], the owner's [callout] over the stage.
  static HoldStageState holding(int heldMs, {HoldCallout? callout}) =>
      HoldStageState(
        phase: HoldStagePhase.hold,
        progress: HoldProgress(held: Duration(milliseconds: heldMs)),
        callout: callout,
      );

  /// Paused by a warning after [heldMs].
  static HoldStageState paused(int heldMs) => HoldStageState(
    phase: HoldStagePhase.hold,
    progress: HoldProgress(
      state: HoldState.paused,
      held: Duration(milliseconds: heldMs),
      warnings: const [HighPlankFaults.kneeDown],
      fault: HighPlankFaults.kneeDown,
    ),
  );

  /// The second warning's end with no star: "실패!".
  static HoldStageState failing(int heldMs) => HoldStageState(
    phase: HoldStagePhase.hold,
    progress: HoldProgress(
      state: HoldState.ended,
      held: Duration(milliseconds: heldMs),
      warnings: const [HighPlankFaults.kneeDown, HighPlankFaults.kneeDown],
      end: HoldEnd.warnings,
    ),
    ending: true,
    callout: const HoldCallout.fail(),
  );

  /// Holds up to the star at [seconds] with its cheer: the star's moment
  /// starts at this pump.
  Future<void> star(WidgetTester tester, int seconds, {int n = 1}) async {
    await show(tester, holding(seconds * 1000 - 100));
    await show(tester, holding(seconds * 1000, callout: HoldCallout.cheer(n)));
  }
}

HoldMeFrame _me(WidgetTester tester) =>
    tester.widget<HoldMeFigure>(find.byKey(const ValueKey('hold-me'))).frame;

GymOwnerFace _face(WidgetTester tester) =>
    tester.widget<HoldOwner>(find.byKey(const ValueKey('hold-owner'))).face;

List<bool> _lit(WidgetTester tester) => [
  for (var i = 0; i < 3; i++)
    tester.widget<HoldStar>(find.byKey(ValueKey('hold-mark-star-$i'))).lit,
];

Positioned _placeOf(WidgetTester tester, Key key) => tester.widget<Positioned>(
  find.ancestor(of: find.byKey(key), matching: find.byType(Positioned)).first,
);

void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

const _cheer = ValueKey('hold-cheer');

void main() {
  final rig = HoldMeRig.standard;

  group('the character on the stage (A8 spec 3, 9.1)', () {
    for (final id in ['mouse', 'kangaroo', 'bear', 'penguin', 'seal']) {
      for (final stage in [3, 5]) {
        testWidgets('$id in stage $stage: on the floor line at the left', (
          tester,
        ) async {
          final play = _Play(stage: stage, character: id);
          await play.show(tester, _Play.holding(1000));
          final place = rig.placeOf(id, play.hold.pose);
          final positioned = _placeOf(tester, const ValueKey('hold-me'));
          expect(positioned.left, place.left);
          expect(positioned.top, closeTo(346 - 150 * place.scale, 1e-9));
          final frame = _me(tester);
          expect(frame.place, same(place));
          expect(
            frame.place.drawing != null,
            stage == 3 && id != 'mouse' && id != 'kangaroo',
          );
          expect(frame.expression, 'atk');
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('not while setting up; idle in the 3·2·1 and a chair '
        'pose\'s entry', (tester) async {
      final play = _Play(stage: 5);
      await play.show(
        tester,
        const HoldStageState(phase: HoldStagePhase.setup),
      );
      expect(find.byKey(const ValueKey('hold-me')), findsNothing);
      await play.show(
        tester,
        const HoldStageState(
          phase: HoldStagePhase.countdown,
          startIn: Duration(seconds: 2),
        ),
      );
      expect(_me(tester).expression, 'idle');
      await play.show(
        tester,
        const HoldStageState(
          phase: HoldStagePhase.hold,
          progress: HoldProgress(state: HoldState.entering),
        ),
      );
      expect(_me(tester).expression, 'idle');
      await play.show(tester, _Play.holding(100));
      expect(_me(tester).expression, 'atk');
    });

    testWidgets('the unknown or RepBot character holds as GYM마우스', (
      tester,
    ) async {
      await _Play(character: 'bot').show(tester, _Play.holding(500));
      expect(_me(tester).place.characterId, 'mouse');
    });

    testWidgets('drawn bottom to top: gym, character, owner, bar, flying '
        'star, bubble, GO', (tester) async {
      final play = _Play(goAge: 100);
      await play.star(tester, 15);
      await tester.pump(const Duration(milliseconds: 850));
      final order = [
        for (final key in [
          'hold-me',
          'hold-owner',
          'hold-track',
          'hold-flying-star-0',
          'hold-cheer',
          'hold-go',
        ])
          tester.allElements.toList().indexOf(
            tester.element(find.byKey(ValueKey(key))),
          ),
      ];
      expect(order, everyElement(greaterThanOrEqualTo(0)));
      expect([...order]..sort(), order);
    });

    testWidgets('a star that comes while the stage is covered, just after the '
        'setup, starts at its beginning (reviewer run 3)', (tester) async {
      await _Play().show(
        tester,
        const HoldStageState(phase: HoldStagePhase.setup),
      );
      // The clock ticks on while setting up, then a screen covers the stage.
      await tester.pump(const Duration(seconds: 2));
      await _Play(ticking: false).show(tester, _Play.holding(14900));
      await _Play(ticking: false)
          .show(tester, _Play.holding(15000, callout: HoldCallout.cheer(1)));
      // The star's first moment: the crouch has not begun (not 2 s before it).
      expect(_me(tester).expression, 'atk');
      expect(_me(tester).sy, closeTo(1, 1e-9));
      await _Play().show(tester, _Play.holding(15000));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_me(tester).sy, inInclusiveRange(0.9, 1.1));
    });

    testWidgets('a covered stage stands still, even as the play changes, and '
        'goes on after (reviewer run 2)', (tester) async {
      // Breathing is 1.2 % over 1.5 s: 300 ms in, it would be 1.011.
      await _Play(ticking: false).show(tester, _Play.holding(5000));
      final before = _me(tester).sy;
      await tester.pump(const Duration(milliseconds: 150));
      await _Play(ticking: false).show(tester, _Play.holding(5100));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_me(tester).sy, before);
      await _Play().show(tester, _Play.holding(5200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_me(tester).sy, isNot(before));
    });

    testWidgets('it breathes on the stage\'s own clock', (tester) async {
      await _Play().show(tester, _Play.holding(1000));
      final before = _me(tester).sy;
      await tester.pump(const Duration(milliseconds: 375));
      expect(_me(tester).sy, isNot(before));
    });
  });

  group('a star (A8 spec 4, 5, 9.3, 9.4)', () {
    testWidgets('the character pops, the star flies, the bar star lights and '
        'pops as it lands at 0.9 s', (tester) async {
      final play = _Play();
      await play.star(tester, 15);
      expect(_me(tester).expression, 'atk');
      expect(_lit(tester), [false, false, false]);
      await tester.pump(const Duration(milliseconds: 460));
      expect(_me(tester).hop, closeTo(16, 1e-9));
      expect(_me(tester).expression, 'win');
      expect(find.byKey(const ValueKey('hold-flying-star-0')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 439));
      expect(_lit(tester), [false, false, false]);
      expect(find.byKey(const ValueKey('hold-star-pop-0')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_lit(tester), [true, false, false]);
      expect(find.byKey(const ValueKey('hold-star-pop-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('hold-flying-star-0')), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
      expect(_me(tester).expression, 'atk');
      expect(_me(tester).hop, 0);
    });

    testWidgets('the star lands on its bar mark', (tester) async {
      final play = _Play();
      await play.star(tester, 15);
      await tester.pump(const Duration(milliseconds: 899));
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('hold-flying-star-0')),
                  )
                  .painter!
              as HoldMeFlightPainter;
      // The mark's centre: the bar from 22 to 338, its stars 22 wide from
      // 6 over the bar at 102.
      expect(painter.flight.at.dx, closeTo(22 + 316 * 15 / 30, 0.01));
      expect(painter.flight.at.dy, closeTo(107, 0.01));
    });

    testWidgets('stars already earned when the stage appears are lit', (
      tester,
    ) async {
      await _Play().show(tester, _Play.holding(21000));
      expect(_lit(tester), [true, true, false]);
      expect(_me(tester).expression, 'grit');
    });
  });

  group('the owner\'s cheer (A8 spec 6, 9.5)', () {
    testWidgets('the bubble from 0.8 s to 2.4 s, the smile from 0.7 s', (
      tester,
    ) async {
      final play = _Play();
      await play.star(tester, 15);
      await tester.pump(const Duration(milliseconds: 699));
      expect(_face(tester), GymOwnerFace.watch);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_face(tester), GymOwnerFace.ok);
      await tester.pump(const Duration(milliseconds: 99));
      expect(find.byKey(_cheer), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        find.descendant(of: find.byKey(_cheer), matching: find.text('좋아!')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 1599));
      expect(find.byKey(_cheer), findsOneWidget);
      expect(_face(tester), GymOwnerFace.ok);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(_cheer), findsNothing);
      expect(_face(tester), GymOwnerFace.watch);
    });

    testWidgets('the second star\'s says "잘한다!"', (tester) async {
      final play = _Play();
      await play.star(tester, 20, n: 2);
      await tester.pump(HoldTiming.cheerBubble);
      expect(
        find.descendant(of: find.byKey(_cheer), matching: find.text('잘한다!')),
        findsOneWidget,
      );
    });
  });

  group('the bubbles\' place (A8 spec 6, 9.6)', () {
    for (final (stage, owner) in [
      (3, 'seal'),
      (9, 'penguin'),
      (15, 'kangaroo'),
      (21, 'bear'),
    ]) {
      testWidgets('$owner: every bubble ends at the owner, 148 down', (
        tester,
      ) async {
        final play = _Play(stage: stage);
        final hold = play.hold;
        final cases =
            <(String, Future<void> Function(), TextStyle Function(TextTheme))>[
              (
                'hold-start',
                () => play.show(
                  tester,
                  HoldStageState(
                    phase: HoldStagePhase.hold,
                    callout: HoldCallout.start(
                      HoldPoses.of(hold.pose).startWords,
                    ),
                  ),
                ),
                (t) => t.holdStartBubble,
              ),
              (
                'hold-whistle',
                () => play.show(tester, _Play.paused(1000)),
                (t) => t.holdWhistle,
              ),
              (
                'hold-cheer',
                () async {
                  await play.star(tester, hold.starSeconds.first);
                  await tester.pump(HoldTiming.cheerBubble);
                },
                (t) => t.holdBigBubble.copyWith(color: AppColors.ink),
              ),
              (
                'hold-fail',
                () => play.show(tester, _Play.failing(1000)),
                (t) => t.holdBigBubble.copyWith(color: AppColors.onInk),
              ),
            ];
        for (final (key, open, style) in cases) {
          await open();
          await tester.pump(const Duration(milliseconds: 300));
          final positioned = _placeOf(tester, ValueKey(key));
          expect(positioned.right, holdBigBubbleRight[owner], reason: key);
          expect(positioned.left, isNull, reason: key);
          expect(positioned.top, 148, reason: key);
          final context = tester.element(find.byKey(ValueKey(key)));
          final text = tester.widget<Text>(
            find
                .descendant(
                  of: find.byKey(ValueKey(key)),
                  matching: find.byType(Text),
                )
                .first,
          );
          expect(text.style, style(Theme.of(context).textTheme), reason: key);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      });
    }

    testWidgets('the big bubble\'s padding is 5, 22 and 7; the small one\'s '
        'as before', (tester) async {
      final play = _Play();
      await play.show(tester, _Play.failing(1000));
      expect(
        tester
            .widget<Container>(find.byKey(const ValueKey('hold-fail')))
            .padding,
        const EdgeInsets.fromLTRB(22, 5, 22, 7),
      );
      await play.show(tester, _Play.paused(1000));
      expect(
        tester
            .widget<Container>(find.byKey(const ValueKey('hold-whistle')))
            .padding,
        const EdgeInsets.fromLTRB(16, 6, 16, 8),
      );
    });
  });

  group('the strain (A8 spec 4, 9.7)', () {
    testWidgets('no grit before the second star; grit 1.35 s after it, to '
        'the end', (tester) async {
      final play = _Play();
      for (var ms = 0; ms < 20000; ms += 500) {
        await play.show(tester, _Play.holding(ms));
        await tester.pump(const Duration(milliseconds: 100));
        expect(_me(tester).expression, isNot('grit'), reason: '$ms');
      }
      await play.show(
        tester,
        _Play.holding(20000, callout: HoldCallout.cheer(2)),
      );
      await tester.pump(const Duration(milliseconds: 1349));
      expect(_me(tester).expression, 'win');
      await tester.pump(const Duration(milliseconds: 1));
      expect(_me(tester).expression, 'grit');
      expect(_me(tester).sweat, hasLength(3));
      expect(_me(tester).shake, isTrue);
      await play.show(tester, _Play.holding(29000));
      await tester.pump(const Duration(seconds: 3));
      expect(_me(tester).expression, 'grit');
    });
  });

  group('a warning (A8 spec 4, 9.8)', () {
    testWidgets('the sag and the whistle; back to the hold in 180 ms', (
      tester,
    ) async {
      final play = _Play();
      final place = rig.placeOf('mouse', HoldPose.plank);
      await play.show(tester, _Play.holding(5000));
      await play.show(tester, _Play.paused(5000));
      await tester.pump(const Duration(milliseconds: 180));
      expect(_me(tester).expression, 'hit');
      // Sagged 0.85 of the way (the mockup's warning pose).
      final sag = HoldMeScene.frameAt(place, const HoldMeMoment.warn(180));
      expect(
        [for (final m in _me(tester).pose!.transform('torso')) ...m.values],
        [for (final m in sag.pose!.transform('torso')) ...m.values],
      );
      expect(find.byKey(const ValueKey('hold-whistle')), findsOneWidget);
      expect(_face(tester), GymOwnerFace.blow);
      await play.show(tester, _Play.holding(5000));
      await tester.pump(const Duration(milliseconds: 90));
      expect(_me(tester).expression, 'atk');
      expect(_me(tester).pose, isNot(same(place.keyPoses['hold'])));
      await tester.pump(const Duration(milliseconds: 90));
      expect(_me(tester).pose, same(place.keyPoses['hold']));
    });

    testWidgets('a second warning with no star: the warning look and '
        '"실패!" in the new place', (tester) async {
      final play = _Play(stage: 5);
      await play.show(tester, _Play.paused(3000));
      await play.show(tester, _Play.failing(3000));
      await tester.pump(HoldTiming.endShow - const Duration(milliseconds: 1));
      expect(_me(tester).expression, 'hit');
      expect(find.byKey(const ValueKey('hold-whistle')), findsNothing);
      final fail = _placeOf(tester, const ValueKey('hold-fail'));
      expect(fail.top, 148);
      expect(fail.right, holdBigBubbleRight['seal']);
    });
  });

  group('nothing starts over when the flying star comes or goes (reviewer '
      'run 1)', () {
    testWidgets('the cheer stays one bubble, popped in once, past the '
        'landing at 0.9 s', (tester) async {
      final play = _Play();
      await play.star(tester, 15);
      await tester.pump(const Duration(milliseconds: 850));
      final bubble = tester.element(find.byKey(_cheer));
      await tester.pump(const Duration(milliseconds: 49));
      expect(tester.element(find.byKey(_cheer)), same(bubble));
      await tester.pump(const Duration(milliseconds: 2));
      expect(tester.element(find.byKey(_cheer)), same(bubble));
      // Its 220 ms entrance from 0.8 s is over by 1.03 s.
      await tester.pump(const Duration(milliseconds: 129));
      final settled = tester.getSize(find.byKey(_cheer));
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.element(find.byKey(_cheer)), same(bubble));
      expect(tester.getSize(find.byKey(_cheer)), settled);
    });

    testWidgets('a warning\'s whistle stays one bubble as the star flies and '
        'lands', (tester) async {
      final play = _Play();
      await play.star(tester, 15);
      await tester.pump(const Duration(milliseconds: 100));
      await play.show(tester, _Play.paused(15000));
      await tester.pump(const Duration(milliseconds: 50));
      final whistle = tester.element(
        find.byKey(const ValueKey('hold-whistle')),
      );
      for (final ms in [100, 600, 100]) {
        // Past 220 ms (the star leaves) and 900 ms (it lands).
        await tester.pump(Duration(milliseconds: ms));
        expect(
          tester.element(find.byKey(const ValueKey('hold-whistle'))),
          same(whistle),
        );
      }
    });

    testWidgets('the owner keeps breathing on from the setup to the 3·2·1', (
      tester,
    ) async {
      final play = _Play();
      await play.show(
        tester,
        const HoldStageState(phase: HoldStagePhase.setup),
      );
      final owner = tester.element(find.byKey(const ValueKey('hold-owner')));
      await play.show(
        tester,
        const HoldStageState(
          phase: HoldStagePhase.countdown,
          startIn: Duration(seconds: 2),
        ),
      );
      expect(
        tester.element(find.byKey(const ValueKey('hold-owner'))),
        same(owner),
      );
    });
  });

  group('against the mockup\'s cheer timeline (A8 spec 8)', () {
    final golden = jsonDecode(
      File('test/widgets/hold_me_golden.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    testWidgets('the bubble, its words, the owner\'s face and the first bar '
        'star at every sampled time from the star', (tester) async {
      final play = _Play();
      await play.star(tester, 15);
      var at = 0;
      for (final row in golden['cheer'] as List) {
        final [ms as int, shown as bool, words, face, lit as bool] =
            row as List;
        await tester.pump(Duration(milliseconds: ms - at));
        at = ms;
        expect(find.byKey(_cheer).evaluate().isNotEmpty, shown, reason: '$ms');
        if (shown) {
          expect(
            find.descendant(
              of: find.byKey(_cheer),
              matching: find.text('$words'),
            ),
            findsOneWidget,
          );
        }
        expect(_face(tester).name, face, reason: '$ms');
        expect(_lit(tester).first, lit, reason: '$ms');
      }
    });

    test('the bubbles end where the mockup\'s do', () {
      final ends = golden['bubbleRight'] as Map<String, dynamic>;
      for (final MapEntry(:key, :value) in ends.entries) {
        expect(holdBigBubbleRight[key], (value as num).toDouble(), reason: key);
      }
    });
  });

  testWidgets('a warning in a star\'s moment: the character warns, the star '
      'still flies and lights the bar, the warning takes the cheer (A8 spec '
      '4, 9.9)', (tester) async {
    final play = _Play();
    await play.star(tester, 15);
    await tester.pump(const Duration(milliseconds: 300));
    // The view model drops the cheer for the warning.
    await play.show(tester, _Play.paused(15000));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_me(tester).expression, 'hit');
    expect(_me(tester).hop, 0);
    expect(find.byKey(const ValueKey('hold-flying-star-0')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_lit(tester), [true, false, false]);
    expect(find.byKey(const ValueKey('hold-star-pop-0')), findsOneWidget);
    expect(find.byKey(_cheer), findsNothing);
    expect(_face(tester), GymOwnerFace.blow);
    // Holding again, the star's moment does not come back.
    await play.show(tester, _Play.holding(15000));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_me(tester).expression, 'atk');
  });

  group('reduced motion (A8 spec 7, 9.11)', () {
    testWidgets('a chair star: arms up with the smile at once for 1.6 s, the '
        'bar star lit at once, nothing flies', (tester) async {
      _reduceMotion(tester);
      final play = _Play(stage: 5);
      final place = rig.placeOf('mouse', HoldPose.chair);
      await play.star(tester, 10);
      expect(_me(tester).pose, same(place.keyPoses['up']));
      expect(_me(tester).expression, 'win');
      expect(_lit(tester), [true, false, false]);
      expect(find.byKey(_cheer), findsOneWidget);
      expect(_face(tester), GymOwnerFace.ok);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('hold-flying-star-0')), findsNothing);
      expect(find.byKey(const ValueKey('hold-star-pop-0')), findsNothing);
      expect(_me(tester).hop, 0);
      await tester.pump(const Duration(milliseconds: 1099));
      expect(find.byKey(_cheer), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(_cheer), findsNothing);
      expect(_face(tester), GymOwnerFace.watch);
      expect(_me(tester).pose, same(place.keyPoses['hold']));
      expect(_me(tester).expression, 'atk');
    });

    testWidgets('the second star\'s look lasts the cheer\'s 1.6 s too, then '
        'the strain', (tester) async {
      _reduceMotion(tester);
      final play = _Play(stage: 5);
      final place = rig.placeOf('mouse', HoldPose.chair);
      await play.star(tester, 15, n: 2);
      await tester.pump(const Duration(milliseconds: 1400));
      expect(_me(tester).pose, same(place.keyPoses['up']));
      expect(_me(tester).expression, 'win');
      expect(_face(tester), GymOwnerFace.ok);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_me(tester).expression, 'grit');
      expect(_face(tester), GymOwnerFace.watch);
    });

    testWidgets('no breath; a warning\'s pose at once', (tester) async {
      _reduceMotion(tester);
      final play = _Play();
      await play.show(tester, _Play.holding(5000));
      await tester.pump(const Duration(milliseconds: 375));
      expect(_me(tester).sy, 1);
      await play.show(tester, _Play.paused(5000));
      expect(_me(tester).expression, 'hit');
      expect(_me(tester).jx, 0);
    });
  });

  group('fits (A8 spec 9.12)', () {
    for (final stage in [3, 5]) {
      testWidgets('stage $stage: every character stays on the 360 × 390 stage, '
          'at the top of its hop too', (tester) async {
        for (final id in ['mouse', 'kangaroo', 'bear', 'penguin', 'seal']) {
          final play = _Play(stage: stage, character: id);
          await play.star(tester, play.hold.starSeconds.first);
          await tester.pump(const Duration(milliseconds: 460));
          final frame = _me(tester);
          final place = frame.place;
          final positioned = _placeOf(tester, const ValueKey('hold-me'));
          final scale = place.scale;
          final box = Rect.fromLTWH(
            positioned.left!,
            positioned.top! - frame.hop * scale,
            140 * scale,
            160 * scale,
          );
          const stageRect = Rect.fromLTWH(0, 0, 360, 390);
          expect(stageRect.intersect(box), box, reason: id);
          // A drawing may leave its box: its shapes at rest stay on the
          // stage too.
          for (final shape in place.drawing ?? const <HoldMeShape>[]) {
            var bounds = shape.path.getBounds().inflate(shape.width / 2);
            for (final link in shape.chain) {
              final m = link.matrix;
              if (m != null) {
                bounds = MatrixUtils.transformRect(
                  Matrix4.fromFloat64List(m),
                  bounds,
                );
              }
            }
            final onStage = Rect.fromLTRB(
              box.left + bounds.left * scale,
              box.top + bounds.top * scale,
              box.left + bounds.right * scale,
              box.top + bounds.bottom * scale,
            );
            expect(stageRect.intersect(onStage), onStage, reason: id);
          }
          await tester.pumpWidget(const SizedBox());
        }
      });
    }

    for (final (size, scale) in [
      (const Size(360, 780), 1.3),
      (const Size(320, 640), 1.0),
      (const Size(320, 640), 1.3),
    ]) {
      testWidgets('${size.width.toInt()} × ${size.height.toInt()} at '
          '${scale}x: the character and every bubble', (tester) async {
        for (final id in ['seal', 'kangaroo']) {
          final play = _Play(
            stage: 21,
            character: id,
            size: size,
            textScale: scale,
          );
          await play.show(
            tester,
            HoldStageState(
              phase: HoldStagePhase.hold,
              callout: HoldCallout.start(
                HoldPoses.of(HoldPose.plank).startWords,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await play.star(tester, 30);
          await tester.pump(const Duration(milliseconds: 460));
          await tester.pump(HoldTiming.cheerBubble);
          await play.show(tester, _Play.paused(31000));
          await tester.pump(const Duration(milliseconds: 300));
          await play.show(tester, _Play.failing(31000));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  });
}
