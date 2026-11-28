import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_banner.dart';
import 'package:gymrats_app/widgets/battle_fighter.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage.dart';
import 'package:gymrats_app/widgets/battle_stage_hud.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/models/feedback_goal.dart';
import 'package:gymrats_app/services/feedback/goal_progress.dart';

import 'battle_test_support.dart';

BattleStageState _state({
  BattleStagePhase phase = BattleStagePhase.playing,
  int me = 0,
  int op = 0,
  int myReps = 0,
  int opReps = 0,
  bool fever = false,
  double? share,
}) => BattleStageState(
  phase: phase,
  myName: 'hellohello',
  opponentName: 'AI 봇 · 고수',
  remaining: const Duration(seconds: 18),
  roundLength: const Duration(seconds: 30),
  myScore: me,
  opponentScore: op,
  myReps: myReps,
  opponentReps: opReps,
  barShare: share ?? 0.5,
  fever: fever,
);

const _hit = BattleStageEvent(
  side: BattleSide.me,
  grade: GameGrade.good,
  points: 10,
  combo: 1,
);

Future<void> _pump(
  WidgetTester tester,
  BattleFxFrame frame,
  BattleStageState state, {
  BattleFighterBuilder fighterBuilder = BattleFighter.standIn,
  BattleCharacters? characters,
  double setupShift = 0,
  int? round,
}) => tester.pumpWidget(
  battleTestApp(
    Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: BattleStage(
            frame: frame,
            state: state,
            fighterBuilder: fighterBuilder,
            characters: characters,
            setupShift: setupShift,
            round: round,
          ),
        ),
      ],
    ),
  ),
);

Finder _fighter(BattleSide side) =>
    find.byWidgetPredicate((w) => w is BattleFighter && w.side == side);

/// The pill around a tag's or a chip's [text], and its look.
Rect _pillRect(WidgetTester tester, Finder text) => tester.getRect(
  find.ancestor(of: text, matching: find.byType(DecoratedBox)).first,
);
BoxDecoration _pillLook(WidgetTester tester, Finder text) =>
    tester
            .widget<DecoratedBox>(
              find
                  .ancestor(of: text, matching: find.byType(DecoratedBox))
                  .first,
            )
            .decoration
        as BoxDecoration;

/// The inside of the bar the fighters stand on.
Finder _bar() => find.byWidgetPredicate(
  (w) => w is ClipRRect && w.borderRadius == BorderRadius.circular(4),
);

/// A fill of [color] in the bar.
Finder _box(Color color) => find.descendant(
  of: _bar(),
  matching: find.byWidgetPredicate((w) => w is ColoredBox && w.color == color),
);

void main() {
  setUpAll(loadBattleFonts);

  group('BattleStage', () {
    testWidgets('is the design\'s 360 x 390 and shows the HUD of its state', (
      tester,
    ) async {
      await _pump(
        tester,
        BattleFxTimeline(share: 0.575).frame(0),
        _state(me: 60, op: 45, myReps: 5, opReps: 4, share: 0.575),
      );
      expect(tester.getSize(find.byType(BattleStage)), const Size(360, 390));
      final hud = tester.widget<BattleStageHud>(find.byType(BattleStageHud));
      expect(hud.myName, 'hellohello');
      expect(hud.opponentName, 'AI 봇 · 고수');
      expect(hud.secondsLeft, 18);
      expect(hud.elapsed, closeTo(0.4, 1e-9));
      expect((hud.myScore, hud.opponentScore), (60, 45));
      expect((hud.myReps, hud.opponentReps), (5, 4));
      expect(hud.chip, (text: '+15 앞섬', tone: BattleFxTone.me));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the chip is hidden before the start and says fever in fever', (
      tester,
    ) async {
      final setup = BattleFxTimeline(setup: true);
      await _pump(
        tester,
        setup.frame(0),
        _state(phase: BattleStagePhase.setup),
      );
      expect(
        tester.widget<BattleStageHud>(find.byType(BattleStageHud)).chip,
        isNull,
      );
      final fever = BattleFxTimeline()..setFever(true, 0);
      await _pump(tester, fever.frame(500), _state(fever: true));
      expect(
        tester.widget<BattleStageHud>(find.byType(BattleStageHud)).chip!.text,
        'FEVER ×2',
      );
    });

    testWidgets('the bar: lime up to where the two meet, then an ink line, '
        'pink beyond, a white tick in the middle', (tester) async {
      await _pump(tester, BattleFxTimeline().frame(0), _state());
      final track = tester.getRect(_box(AppColors.opponent));
      // Inside a 3 wide ink edge from 24 to 336, 22 tall from 346.
      expect(track, const Rect.fromLTRB(27, 349, 333, 365));
      expect(tester.getRect(_box(AppColors.accent)).left, 27);
      expect(tester.getRect(_box(AppColors.accent)).right, 180);
      final divider = tester.getRect(_box(AppColors.ink));
      expect((divider.left, divider.right), (180, 183));
      final tick = tester.getRect(_box(AppColors.card.withValues(alpha: 0.9)));
      expect((tick.left, tick.right), (179, 181));
    });

    testWidgets('the lime follows the meeting point and stops at the ends', (
      tester,
    ) async {
      await _pump(
        tester,
        BattleFxTimeline(share: 0.8).frame(0),
        _state(share: 0.8),
      );
      expect(tester.getRect(_box(AppColors.accent)).right, 240);
      await _pump(
        tester,
        BattleFxTimeline(share: 1).frame(0),
        _state(share: 1),
      );
      expect(tester.getRect(_box(AppColors.accent)).right, 280);
      await _pump(
        tester,
        BattleFxTimeline(share: 0).frame(0),
        _state(share: 0),
      );
      expect(tester.getRect(_box(AppColors.accent)).right, 80);
    });

    testWidgets('"KO" is written under both ends of the bar', (tester) async {
      await _pump(tester, BattleFxTimeline().frame(0), _state());
      final ends = find.text('KO');
      expect(ends, findsNWidgets(2));
      expect(tester.getTopLeft(ends.first), const Offset(24, 371));
      expect(tester.getTopRight(ends.last), const Offset(336, 371));
    });

    testWidgets('the fighters stand on the bar, 56 either side of the '
        'meeting point, the opponent mirrored', (tester) async {
      await _pump(tester, BattleFxTimeline().frame(0), _state());
      // The picture's box is 140 x 160 with its feet at (70, 150), so its
      // middle is 70 above the feet.
      final me = _fighter(BattleSide.me);
      final opponent = _fighter(BattleSide.opponent);
      expect(tester.getCenter(me).dx, closeTo(180 - 56, 0.01));
      expect(tester.getCenter(opponent).dx, closeTo(180 + 56, 0.01));
      expect(tester.getCenter(me).dy, closeTo(346 - 70, 2));
      expect(
        tester.getTopLeft(me).dx,
        lessThan(tester.getTopRight(me).dx),
        reason: 'facing right',
      );
      expect(
        tester.getTopLeft(opponent).dx,
        greaterThan(tester.getTopRight(opponent).dx),
        reason: 'mirrored to face left',
      );
    });

    testWidgets('a blow shows as poses: the attacker lunging in front, the '
        'other hit and flashing white', (tester) async {
      final fx = BattleFxTimeline()..rep(_hit, 0);
      await _pump(tester, fx.frame(100), _state());
      final drawn = tester
          .widgetList<BattleFighter>(find.byType(BattleFighter))
          .toList();
      // Later in the list is drawn on top.
      expect(drawn.last.side, BattleSide.me);
      expect(drawn.last.pose, BattlePose.attack);
      expect(
        drawn.where((f) => f.side == BattleSide.opponent).first.pose,
        BattlePose.hit,
      );
      // The flash: the hit fighter as a white shape over two soft ink ones.
      final tints = tester
          .widgetList<ColorFiltered>(find.byType(ColorFiltered))
          .map((w) => w.colorFilter)
          .toList();
      expect(tints, [
        const ColorFilter.mode(AppColors.ink, BlendMode.srcIn),
        const ColorFilter.mode(AppColors.ink, BlendMode.srcIn),
        const ColorFilter.mode(AppColors.card, BlendMode.srcIn),
      ]);
      expect(find.byType(ImageFiltered), findsNWidgets(2));
    });

    testWidgets('the opponent attacking is drawn over me', (tester) async {
      final fx = BattleFxTimeline()
        ..rep(
          const BattleStageEvent(
            side: BattleSide.opponent,
            grade: GameGrade.good,
            points: 10,
            combo: 1,
          ),
          0,
        );
      await _pump(tester, fx.frame(40), _state());
      expect(
        tester.widgetList<BattleFighter>(find.byType(BattleFighter)).last.side,
        BattleSide.opponent,
      );
    });

    testWidgets('no flash and no aura on a quiet stage; a white aura on both '
        'in fever', (tester) async {
      await _pump(tester, BattleFxTimeline().frame(0), _state());
      expect(find.byType(ColorFiltered), findsNothing);
      expect(find.byType(ImageFiltered), findsNothing);

      final fever = BattleFxTimeline()..setFever(true, 0);
      await _pump(tester, fever.frame(500), _state(fever: true));
      expect(find.byType(ImageFiltered), findsNWidgets(2));
      expect(
        tester
            .widgetList<ColorFiltered>(find.byType(ColorFiltered))
            .map((w) => w.colorFilter),
        everyElement(const ColorFilter.mode(AppColors.card, BlendMode.srcIn)),
      );
      // The picture itself is still there, over its aura.
      expect(find.byType(BattleFighter), findsNWidgets(4));
    });

    testWidgets('a fighter who has left the screen is not drawn', (
      tester,
    ) async {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.playerLeft,
            winner: BattleSide.me,
          ),
          0,
        );
      await _pump(tester, fx.frame(200), _state());
      expect(_fighter(BattleSide.opponent), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: _fighter(BattleSide.opponent),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        closeTo(0.125, 1e-9),
      );
      await _pump(tester, fx.frame(900), _state());
      expect(_fighter(BattleSide.opponent), findsNothing);
      expect(
        tester.widget<BattleFighter>(_fighter(BattleSide.me)).pose,
        BattlePose.win,
      );
    });

    testWidgets('the fighters\' layer shakes and zooms; the HUD holds still', (
      tester,
    ) async {
      await _pump(tester, BattleFxTimeline().frame(0), _state());
      final clock = tester.getRect(find.text('0:18'));
      final bar = tester.getRect(_box(AppColors.opponent));

      final fx = BattleFxTimeline()
        ..rep(
          const BattleStageEvent(
            side: BattleSide.me,
            grade: GameGrade.excellent,
            points: 15,
            combo: 1,
            knockout: true,
          ),
          0,
        );
      final frame = fx.frame(280);
      expect(frame.zoom, greaterThan(1.1));
      await _pump(tester, frame, _state());
      expect(tester.getRect(find.text('0:18')), clock);
      final zoomed = tester.getRect(_box(AppColors.opponent));
      expect(zoomed.width, closeTo(bar.width * frame.zoom, 0.01));
      // It grows around the meeting point at height 300.
      expect(
        zoomed.top,
        closeTo(300 + (bar.top - 300) * frame.zoom + frame.shakeY, 0.01),
      );
      expect(
        zoomed.left,
        closeTo(
          frame.meetX + (bar.left - frame.meetX) * frame.zoom + frame.shakeX,
          0.01,
        ),
      );
    });

    testWidgets('the tags sit over the fighters\' heads in their tones, as '
        'visible as the fighters', (tester) async {
      // More than 3 s before the start: both ready, over their heads.
      final fx = BattleFxTimeline(setup: true)..countDown(5000, 0);
      await _pump(
        tester,
        fx.frame(1000),
        _state(phase: BattleStagePhase.countdown),
      );
      final ready = find.text('준비 완료');
      expect(ready, findsNWidgets(2));
      final mine = ready.first;
      final theirs = ready.last;
      expect(tester.getCenter(mine).dx, closeTo(124, 0.01));
      expect(tester.getCenter(theirs).dx, closeTo(236, 0.01));
      expect(_pillRect(tester, mine).top, 200);
      // A 16 line with 2 above and below inside a 1.5 edge.
      expect(_pillRect(tester, mine).height, 16 + 2 * (2 + 1.5));
      expect(
        _pillRect(tester, mine).width,
        closeTo(tester.getSize(mine).width + 2 * (9 + 1.5), 0.01),
      );
      expect(_pillLook(tester, mine).color, AppColors.accent);
      expect(_pillLook(tester, theirs).color, AppColors.opponent);
      expect(
        _pillLook(tester, mine).border,
        Border.all(color: AppColors.ink, width: 1.5),
      );
      expect(_pillLook(tester, mine).borderRadius, BorderRadius.circular(11));
      // While the fighters pop up, the tags show as much as they do.
      await _pump(
        tester,
        fx.frame(385),
        _state(phase: BattleStagePhase.countdown),
      );
      expect(
        tester
            .widgetList<Opacity>(
              find.ancestor(of: ready.first, matching: find.byType(Opacity)),
            )
            .first
            .opacity,
        closeTo(0.5, 1e-9),
      );
    });

    testWidgets('while setting up: no fighters and no tags, and the ready '
        'chips under the cue board, at the stage\'s sides (A12 SfSq top)', (
      tester,
    ) async {
      final fx = BattleFxTimeline(setup: true)
        ..setSetup(active: true, opponentReady: true, now: 0);
      final handle = tester.ensureSemantics();
      await _pump(tester, fx.frame(0), _state(phase: BattleStagePhase.setup));
      expect(_fighter(BattleSide.me), findsNothing);
      expect(_fighter(BattleSide.opponent), findsNothing);
      expect(find.text('유효 횟수'), findsNothing);
      final mine = find.text('나 · 세팅 중');
      final theirs = find.text('상대 · 준비 완료');
      expect(mine, findsOneWidget);
      expect(theirs, findsOneWidget);
      // In a row 24 tall from 162, 12 from the sides.
      expect(_pillRect(tester, mine).left, 12);
      expect(_pillRect(tester, theirs).right, 348);
      expect(_pillRect(tester, mine).center.dy, closeTo(162 + 12, 0.01));
      expect(_pillRect(tester, theirs).center.dy, closeTo(162 + 12, 0.01));
      expect(_pillRect(tester, mine).height, 16 + 2 * (2 + 1.5));
      // The design's room: 10 beside the edge, the square 10 and 6 after it.
      for (final chip in [mine, theirs]) {
        expect(
          _pillRect(tester, chip).width,
          closeTo(tester.getSize(chip).width + 10 + 6 + 2 * (10 + 1.5), 0.01),
        );
      }
      expect(_pillLook(tester, mine).color, AppColors.card);
      expect(_pillLook(tester, theirs).color, AppColors.opponent);
      expect(_pillLook(tester, mine).borderRadius, BorderRadius.circular(11));
      // The squares: the user's first, lime on white; the opponent's last,
      // white on its pink once ready.
      Rect square(Finder chip) => tester.getRect(
        find
            .descendant(
              of: find.ancestor(of: chip, matching: find.byType(Row)).first,
              matching: find.byWidgetPredicate(
                (w) => w is SizedBox && w.width == 10 && w.height == 10,
              ),
            )
            .first,
      );
      Color squareColor(Finder chip) =>
          (tester
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: find
                                  .ancestor(
                                    of: chip,
                                    matching: find.byType(Row),
                                  )
                                  .first,
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      expect(square(mine).size, const Size.square(10));
      expect(square(mine).right, lessThan(tester.getRect(mine).left));
      expect(square(theirs).left, greaterThan(tester.getRect(theirs).right));
      expect(squareColor(mine), AppColors.accent);
      expect(squareColor(theirs), AppColors.card);
      // Whose each is, for a screen reader.
      expect(find.bySemanticsLabel('나 세팅 중'), findsOneWidget);
      expect(find.bySemanticsLabel('상대 준비 완료'), findsOneWidget);
      // Waiting for the opponent: mine lime with a white square, theirs
      // white with a pink one.
      fx.setSetup(active: true, meReady: true, now: 10);
      await _pump(tester, fx.frame(10), _state(phase: BattleStagePhase.setup));
      final ready = find.text('나 · 준비 완료');
      final waiting = find.text('상대 · 세팅 중');
      expect(_pillLook(tester, ready).color, AppColors.accent);
      expect(squareColor(ready), AppColors.card);
      expect(_pillLook(tester, waiting).color, AppColors.card);
      expect(squareColor(waiting), AppColors.opponent);
      expect(_pillRect(tester, ready).left, 12);
      handle.dispose();
    });

    testWidgets('while setting up the top holds only the chips: the names, '
        'the clock, the scores and the time bar are hidden, from a screen '
        'reader too, and come back as the line comes down (A12 spec 2)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      Opacity around(Finder finder) => tester
          .widgetList<Opacity>(
            find.ancestor(of: finder, matching: find.byType(Opacity)),
          )
          .first;
      final fx = BattleFxTimeline(setup: true)..setSetup(active: true, now: 0);
      await _pump(tester, fx.frame(0), _state(phase: BattleStagePhase.setup));
      for (final text in ['0:18', 'hellohello', 'AI 봇 · 고수', '0']) {
        final found = find.text(text);
        expect(found, findsWidgets, reason: text);
        for (final element in found.evaluate()) {
          expect(
            around(find.byWidget(element.widget)).opacity,
            0,
            reason: text,
          );
        }
      }
      expect(find.bySemanticsLabel(RegExp('남은 시간')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('내 점수')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('상대 점수')), findsNothing);
      fx.countDown(3000, 1000);
      // Half way through the setup's 150 ms fade.
      await _pump(
        tester,
        fx.frame(1075),
        _state(phase: BattleStagePhase.countdown),
      );
      expect(
        around(find.bySemanticsLabel(RegExp('남은 시간'))).opacity,
        closeTo(0.5, 1e-9),
      );
      await _pump(
        tester,
        fx.frame(1400),
        _state(phase: BattleStagePhase.countdown),
      );
      expect(around(find.bySemanticsLabel(RegExp('남은 시간'))).opacity, 1);
      expect(find.bySemanticsLabel(RegExp('내 점수')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('상대 점수')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('under a status bar the chips move down with the setup\'s '
        'top (task.md W12 decision 1)', (tester) async {
      final fx = BattleFxTimeline(setup: true)..setSetup(active: true, now: 0);
      await _pump(
        tester,
        fx.frame(0),
        _state(phase: BattleStagePhase.setup),
        setupShift: 24,
      );
      expect(
        _pillRect(tester, find.text('나 · 세팅 중')).center.dy,
        closeTo(162 + 24 + 12, 0.01),
      );
    });

    testWidgets('the valid counts fade in as the line comes down, and the '
        'chips fade out', (tester) async {
      final fx = BattleFxTimeline(setup: true)..countDown(3000, 0);
      await _pump(
        tester,
        fx.frame(100),
        _state(phase: BattleStagePhase.countdown),
      );
      Opacity around(Finder finder) => tester
          .widgetList<Opacity>(
            find.ancestor(of: finder, matching: find.byType(Opacity)),
          )
          .first;
      expect(around(find.text('유효 횟수')).opacity, closeTo(0.5, 1e-9));
      expect(around(find.text('나 · 준비 완료')).opacity, closeTo(1 / 3, 1e-9));
      await _pump(
        tester,
        fx.frame(200),
        _state(phase: BattleStagePhase.countdown),
      );
      expect(find.text('나 · 준비 완료'), findsNothing);
      expect(around(find.text('유효 횟수')).opacity, 1);
    });

    testWidgets('the impact star sits in front of the one who is hit, as '
        'large as the effect says', (tester) async {
      final fx = BattleFxTimeline()..rep(_hit, 0);
      final frame = fx.frame(200);
      await _pump(tester, frame, _state());
      final star = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BattleStarPainter,
      );
      // It is on the fighters' layer, which is shaking from the blow.
      expect(frame.shakeX, isNot(0));
      expect(
        tester.getCenter(star).dx,
        closeTo(frame.star!.centerX + frame.shakeX, 0.01),
      );
      expect(
        tester.getCenter(star).dy,
        closeTo(frame.star!.centerY + frame.shakeY, 0.01),
      );
      // Drawn 112 wide in a 120 box, then sized to the diameter.
      final width =
          (tester.getTopRight(star) - tester.getTopLeft(star)).distance;
      expect(width, closeTo(120 * frame.star!.diameter / 112, 0.01));
    });

    testWidgets('a knockout twinkles where the loser left; a player leaving '
        'leaves a puff', (tester) async {
      final ko = BattleFxTimeline()
        ..rep(
          const BattleStageEvent(
            side: BattleSide.me,
            grade: GameGrade.good,
            points: 10,
            combo: 1,
            knockout: true,
          ),
          0,
        );
      await _pump(tester, ko.frame(80 + 1800), _state());
      final twinkle = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BattleTwinklePainter,
      );
      expect(tester.getCenter(twinkle), const Offset(320, 158));

      final left = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.playerLeft,
            winner: BattleSide.me,
          ),
          0,
        );
      await _pump(tester, left.frame(200), _state());
      final puff = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BattlePuffPainter,
      );
      expect(tester.getCenter(puff), const Offset(236, 286));
    });

    testWidgets('every band of the frame is on the stage', (tester) async {
      final fx = BattleFxTimeline()
        ..rep(
          const BattleStageEvent(
            side: BattleSide.me,
            grade: null,
            reason: RejectReason.bellyDown,
          ),
          0,
        )
        ..setFever(true, 0);
      final frame = fx.frame(300);
      expect(frame.banners.map((b) => b.text), ['MISS', 'FEVER ×2']);
      await _pump(tester, frame, _state(fever: true));
      expect(find.byType(BattleStageBanner), findsNWidgets(2));
      expect(find.text('MISS'), findsOneWidget);
      expect(find.text('FEVER ×2'), findsNWidgets(2), reason: 'band and chip');
    });

    testWidgets('the fighters come from the builder it is given: the slot '
        'for the characters', (tester) async {
      final asked = <(BattlePose, BattleSide)>[];
      final fx = BattleFxTimeline()..rep(_hit, 0);
      await _pump(
        tester,
        fx.frame(40),
        _state(),
        fighterBuilder: (pose, side) {
          asked.add((pose, side));
          return SizedBox.fromSize(
            size: BattleFighter.size,
            child: Text('${side.name} ${pose.name}'),
          );
        },
      );
      expect(asked.toSet(), {
        (BattlePose.attack, BattleSide.me),
        (BattlePose.idle, BattleSide.opponent),
      });
      expect(find.byType(BattleFighter), findsNothing);
      expect(find.text('me attack'), findsOneWidget);
      expect(find.text('opponent idle'), findsOneWidget);
    });

    testWidgets('with characters the fighters are the characters, in their '
        'poses and team colors, the hit one flashing on its own', (
      tester,
    ) async {
      final fx = BattleFxTimeline()..rep(_hit, 0);
      await _pump(
        tester,
        fx.frame(100),
        _state(),
        characters: const BattleCharacters(me: 'penguin', opponent: 'bot'),
      );
      expect(find.byType(BattleFighter), findsNothing);
      final drawn = tester
          .widgetList<CharacterFigure>(find.byType(CharacterFigure))
          .toList();
      expect(drawn, hasLength(2));
      final me = drawn.singleWhere((f) => f.side == BattleSide.me);
      final opponent = drawn.singleWhere((f) => f.side == BattleSide.opponent);
      expect(
        (me.characterId, me.pose, me.flash),
        ('penguin', BattlePose.attack, false),
      );
      expect(
        (opponent.characterId, opponent.pose, opponent.flash),
        ('bot', BattlePose.hit, true),
      );
      // The character paints its own flash: no white tint, no ink blur.
      expect(find.byType(ColorFiltered), findsNothing);
      expect(find.byType(ImageFiltered), findsNothing);
      // Later in the list is drawn on top: the attacker.
      expect(drawn.last.side, BattleSide.me);
    });

    testWidgets('with characters fever still puts the white aura on both', (
      tester,
    ) async {
      final fx = BattleFxTimeline()..setFever(true, 0);
      await _pump(
        tester,
        fx.frame(500),
        _state(fever: true),
        characters: const BattleCharacters(me: 'mouse', opponent: 'seal'),
      );
      expect(find.byType(ImageFiltered), findsNWidgets(2));
      expect(find.byType(CharacterFigure), findsNWidgets(4));
    });

    testWidgets('a screen reader gets the bar and the HUD, not the pictures', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        BattleFxTimeline(share: 0.6).frame(0),
        _state(me: 60, op: 40, share: 0.6),
      );
      expect(find.bySemanticsLabel('체력 바'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('체력 바')),
        matchesSemantics(label: '체력 바', value: '내 쪽 60%'),
      );
      expect(find.bySemanticsLabel('내 점수 60점'), findsOneWidget);
      expect(find.bySemanticsLabel('KO'), findsNothing);
      handle.dispose();
    });
  });

  group('the effect pictures', () {
    test('every number of the reviewed drawings is kept', () {
      expectReviewedDrawing(
        'star',
        paintedOps(const BattleStarPainter(), BattleStarPainter.box),
      );
      expectReviewedDrawing(
        'twinkle',
        paintedOps(const BattleTwinklePainter(), BattleTwinklePainter.box),
      );
      expectReviewedDrawing(
        'puff',
        paintedOps(const BattlePuffPainter(), BattlePuffPainter.box),
      );
    });

    testWidgets('the star is amber with an ink edge and white inside, 112 '
        'from tip to tip', (tester) async {
      final picture = await paintPicture(
        tester,
        const CustomPaint(
          size: BattleStarPainter.box,
          painter: BattleStarPainter(),
        ),
        size: BattleStarPainter.box,
        ground: AppColors.background,
      );
      expect(picture.at(60, 60), AppColors.card);
      expect(picture.at(60, 24), AppColors.warning);
      expect(picture.at(60, 5), AppColors.ink, reason: 'the top tip');
      expect(picture.at(114, 60), AppColors.ink, reason: 'the right tip');
      expect(picture.at(8, 8), AppColors.background);
      expect(BattleStarPainter.width, 112);
    });

    testWidgets('the twinkle and the puff are white with ink edges', (
      tester,
    ) async {
      final twinkle = await paintPicture(
        tester,
        const CustomPaint(
          size: BattleTwinklePainter.box,
          painter: BattleTwinklePainter(),
        ),
        size: BattleTwinklePainter.box,
        ground: AppColors.background,
      );
      expect(twinkle.at(20, 20), AppColors.card);
      expect(twinkle.at(4, 4), AppColors.background);
      final puff = await paintPicture(
        tester,
        const CustomPaint(
          size: BattlePuffPainter.box,
          painter: BattlePuffPainter(),
        ),
        size: BattlePuffPainter.box,
        ground: AppColors.background,
      );
      expect(puff.at(28, 46), AppColors.card);
      expect(puff.at(42, 20), AppColors.card);
      expect(puff.at(28, 28), AppColors.ink, reason: 'a cloud\'s edge');
    });
  });

  group('BattleStageBackdrop', () {
    Future<PaintedPicture> paint(
      WidgetTester tester, {
      double fever = 0,
      double shift = 0,
      double scale = 1,
      Offset origin = Offset.zero,
    }) => paintPicture(
      tester,
      SizedBox(
        width: 200,
        height: 120,
        child: BattleStageBackdrop(
          feverOpacity: fever,
          stripeShift: shift,
          scale: scale,
          origin: origin,
        ),
      ),
      size: const Size(200, 120),
    );

    testWidgets('a faint line every 28 points on the light ground', (
      tester,
    ) async {
      final picture = await paint(tester);
      expect(picture.at(14, 14), AppColors.background);
      for (final x in [28.0, 56.0, 84.0]) {
        expect(picture.at(x, 14), isNot(AppColors.background), reason: '$x');
      }
      expect(picture.at(14, 28), isNot(AppColors.background));
      expect(picture.at(42, 70), AppColors.background);
    });

    testWidgets('the grid starts at the stage\'s corner and grows with it', (
      tester,
    ) async {
      final picture = await paint(tester, scale: 2, origin: const Offset(6, 4));
      expect(picture.at(6, 30), isNot(AppColors.background));
      expect(picture.at(62, 30), isNot(AppColors.background));
      expect(picture.at(34, 30), AppColors.background, reason: 'a 56 cell');
      expect(picture.at(30, 4), isNot(AppColors.background));
      expect(picture.at(30, 32), AppColors.background);
    });

    testWidgets('fever washes it cyan with lighter stripes that drift', (
      tester,
    ) async {
      final plain = await paint(tester, fever: 1);
      final colors = {for (var x = 0.0; x < 200; x += 1) plain.at(x, 60)};
      expect(colors, contains(AppColors.fever));
      expect(colors.length, greaterThan(1), reason: 'stripes over the cyan');
      final drifted = await paint(tester, fever: 1, shift: 20);
      expect([
        for (var x = 0.0; x < 200; x += 1) drifted.at(x, 60),
      ], isNot([for (var x = 0.0; x < 200; x += 1) plain.at(x, 60)]));
      // One period along the stage later it looks the same again.
      final looped = await paint(tester, fever: 1, shift: 61.79);
      expect(looped.at(100, 60), plain.at(100, 60));
    });

    testWidgets('without fever there is no cyan at all', (tester) async {
      await paint(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.fever,
        ),
        findsNothing,
      );
    });

    test('the grid and the stripes repaint only when they change', () {
      const grid = BattleGridPainter(scale: 1, origin: Offset.zero);
      expect(
        grid.shouldRepaint(
          const BattleGridPainter(scale: 1, origin: Offset.zero),
        ),
        isFalse,
      );
      expect(
        grid.shouldRepaint(
          const BattleGridPainter(scale: 2, origin: Offset.zero),
        ),
        isTrue,
      );
      const stripes = BattleFeverStripesPainter(
        shift: 0,
        scale: 1,
        origin: Offset.zero,
      );
      expect(
        stripes.shouldRepaint(
          const BattleFeverStripesPainter(
            shift: 3,
            scale: 1,
            origin: Offset.zero,
          ),
        ),
        isTrue,
      );
      expect(
        const BattleStarPainter().shouldRepaint(const BattleStarPainter()),
        isFalse,
      );
    });
  });

  group('BattleStage, what a frame says and nothing else', () {
    /// Where the corner [local] of a fighter's 140 x 160 picture goes: sized
    /// and turned (clockwise) around the feet at (70, 150), which stand at
    /// the fighter's foot point.
    Offset corner(BattleFxFighter f, Offset local) {
      final x = (local.dx - 70) * f.scaleX;
      final y = (local.dy - 150) * f.scaleY;
      final a = f.rotation * math.pi / 180;
      return Offset(
        f.footX + x * math.cos(a) - y * math.sin(a),
        f.footY + x * math.sin(a) + y * math.cos(a),
      );
    }

    void expectPlaced(WidgetTester tester, BattleSide side, BattleFxFighter f) {
      final picture = _fighter(side).first;
      for (final (local, actual) in [
        (Offset.zero, tester.getTopLeft(picture)),
        (const Offset(140, 0), tester.getTopRight(picture)),
        (const Offset(0, 160), tester.getBottomLeft(picture)),
      ]) {
        final want = corner(f, local);
        expect(actual.dx, closeTo(want.dx, 0.01), reason: '$side $local x');
        expect(actual.dy, closeTo(want.dy, 0.01), reason: '$side $local y');
      }
    }

    testWidgets('at rest my fighter is drawn over the opponent\'s, as in '
        'the design', (tester) async {
      await _pump(tester, BattleFxTimeline().frame(0), _state());
      expect(
        tester
            .widgetList<BattleFighter>(find.byType(BattleFighter))
            .map((f) => f.side),
        [BattleSide.opponent, BattleSide.me],
      );
    });

    testWidgets('if both were in the attack pose at once, mine would still '
        'be on top', (tester) async {
      // The effect math never gives this (a later rep takes over), so the
      // frame is put together by hand.
      final base = BattleFxTimeline().frame(0);
      BattleFxFighter attacking(BattleFxFighter f) => BattleFxFighter(
        pose: BattlePose.attack,
        footX: f.footX,
        footY: f.footY,
        rotation: f.rotation,
        scaleX: f.scaleX,
        scaleY: f.scaleY,
        opacity: f.opacity,
        flash: false,
        glow: false,
        front: true,
      );
      final frame = BattleFxFrame(
        meetX: base.meetX,
        me: attacking(base.me),
        opponent: attacking(base.opponent),
        myTag: null,
        opponentTag: null,
        shakeX: 0,
        shakeY: 0,
        zoom: 1,
        star: null,
        twinkle: null,
        puff: null,
        sign: null,
        banners: const [],
        combos: const [],
        myScoreBump: 1,
        opponentScoreBump: 1,
        myRepsBump: 1,
        opponentRepsBump: 1,
        feverOpacity: 0,
        stripeShift: 0,
        glowRadius: 9,
        dangerOpacity: 0,
        beforeStart: false,
        resultButton: null,
      );
      await _pump(tester, frame, _state());
      expect(
        tester.widgetList<BattleFighter>(find.byType(BattleFighter)).last.side,
        BattleSide.me,
      );
    });

    testWidgets('I stay in front while I am hit, once the opponent\'s '
        'attack pose is over', (tester) async {
      final fx = BattleFxTimeline()
        ..rep(
          const BattleStageEvent(
            side: BattleSide.opponent,
            grade: GameGrade.good,
            points: 10,
            combo: 1,
          ),
          0,
        );
      // The attack pose ends 350 after the event; my hit pose lasts to 570.
      final frame = fx.frame(450);
      expect(frame.opponent.front, isFalse);
      expect(frame.me.pose, BattlePose.hit);
      await _pump(tester, frame, _state());
      expect(
        tester.widgetList<BattleFighter>(find.byType(BattleFighter)).last.side,
        BattleSide.me,
      );
    });

    testWidgets('a miss leans the fighter forward: clockwise for me, the '
        'other way for the mirrored opponent', (tester) async {
      final mine = BattleFxTimeline()
        ..rep(
          const BattleStageEvent(
            side: BattleSide.me,
            grade: null,
            reason: RejectReason.kneesDown,
          ),
          0,
        );
      final myFrame = mine.frame(300);
      expect(myFrame.me.rotation, greaterThan(15));
      await _pump(tester, myFrame, _state());
      expectPlaced(tester, BattleSide.me, myFrame.me);
      expectPlaced(tester, BattleSide.opponent, myFrame.opponent);

      final theirs = BattleFxTimeline()
        ..rep(
          const BattleStageEvent(side: BattleSide.opponent, grade: null),
          0,
        );
      final theirFrame = theirs.frame(300);
      expect(theirFrame.opponent.rotation, lessThan(-15));
      await _pump(tester, theirFrame, _state());
      expectPlaced(tester, BattleSide.opponent, theirFrame.opponent);
    });

    testWidgets('breathing changes the height only, from the feet', (
      tester,
    ) async {
      // A quarter of the way through a breath: as tall as it gets.
      final frame = BattleFxTimeline().frame(280 * math.pi / 2);
      expect(frame.me.scaleY, closeTo(1.02, 1e-9));
      await _pump(tester, frame, _state());
      expectPlaced(tester, BattleSide.me, frame.me);
      final picture = _fighter(BattleSide.me);
      expect(
        (tester.getBottomLeft(picture) - tester.getTopLeft(picture)).distance,
        closeTo(160 * 1.02, 0.01),
      );
      expect(
        (tester.getTopRight(picture) - tester.getTopLeft(picture)).distance,
        closeTo(140, 0.01),
      );
    });

    testWidgets('a knocked-out fighter spins and grows as it flies', (
      tester,
    ) async {
      final fx = BattleFxTimeline()
        ..rep(
          const BattleStageEvent(
            side: BattleSide.me,
            grade: GameGrade.good,
            points: 10,
            combo: 1,
            knockout: true,
          ),
          0,
        );
      final frame = fx.frame(80 + 700);
      expect(frame.opponent.rotation, greaterThan(40));
      expect(frame.zoom, greaterThan(1));
      await _pump(tester, frame, _state());
      // On the zoomed layer: measure the picture's own size, which the zoom
      // scales evenly.
      final picture = _fighter(BattleSide.opponent);
      final width =
          (tester.getTopRight(picture) - tester.getTopLeft(picture)).distance;
      final height =
          (tester.getBottomLeft(picture) - tester.getTopLeft(picture)).distance;
      expect(
        width,
        closeTo(140 * frame.opponent.scaleX.abs() * frame.zoom, 0.01),
      );
      expect(height, closeTo(160 * frame.opponent.scaleY * frame.zoom, 0.01));
      // Turned clockwise for the opponent, who flies off to the right.
      final top = tester.getTopRight(picture) - tester.getTopLeft(picture);
      expect(
        math.atan2(top.dy, top.dx) * 180 / math.pi,
        // The mirrored picture's top edge points left when upright.
        closeTo(frame.opponent.rotation - 180, 0.01),
      );
    });

    testWidgets('the aura is as wide as the frame says', (tester) async {
      final fx = BattleFxTimeline()..setFever(true, 0);
      final frame = fx.frame(120 * math.pi / 2);
      expect(frame.glowRadius, closeTo(13, 1e-9));
      await _pump(tester, frame, _state(fever: true));
      expect(
        tester
            .widgetList<ImageFiltered>(find.byType(ImageFiltered))
            .map((w) => w.imageFilter),
        everyElement(ui.ImageFilter.blur(sigmaX: 6.5, sigmaY: 6.5)),
      );
    });

    testWidgets('the twinkle turns and the puff fades as the frame says', (
      tester,
    ) async {
      final ko = BattleFxTimeline()
        ..rep(
          const BattleStageEvent(
            side: BattleSide.me,
            grade: GameGrade.good,
            points: 10,
            combo: 1,
            knockout: true,
          ),
          0,
        );
      final frame = ko.frame(80 + 1700);
      await _pump(tester, frame, _state());
      final twinkle = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BattleTwinklePainter,
      );
      final top = tester.getTopRight(twinkle) - tester.getTopLeft(twinkle);
      expect(frame.twinkle!.rotation, closeTo(52.9, 0.1));
      expect(
        math.atan2(top.dy, top.dx) * 180 / math.pi,
        closeTo(frame.twinkle!.rotation, 0.01),
      );
      expect(top.distance, closeTo(40 * frame.twinkle!.scale, 0.01));

      final left = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.playerLeft,
            winner: BattleSide.me,
          ),
          0,
        );
      final leaving = left.frame(460);
      expect(leaving.puff!.opacity, closeTo(0.5, 1e-9));
      await _pump(tester, leaving, _state());
      final puff = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BattlePuffPainter,
      );
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(of: puff, matching: find.byType(Opacity)).first,
            )
            .opacity,
        closeTo(0.5, 1e-9),
      );
      expect(
        (tester.getTopRight(puff) - tester.getTopLeft(puff)).distance,
        closeTo(80 * leaving.puff!.scale, 0.01),
      );
    });

    testWidgets('the chip takes the fever multiplier of the battle\'s rules', (
      tester,
    ) async {
      final fx = BattleFxTimeline()..setFever(true, 0);
      await _pump(
        tester,
        fx.frame(2000),
        const BattleStageState(
          phase: BattleStagePhase.playing,
          myName: 'A',
          opponentName: 'B',
          remaining: Duration(seconds: 5),
          roundLength: Duration(seconds: 30),
          fever: true,
          feverMultiplier: 3,
        ),
      );
      expect(find.text('FEVER ×3'), findsOneWidget);
    });
  });

  group('the fever stripes', () {
    /// Fever at full strength over a box whose corner is the stage's.
    Future<PaintedPicture> stripes(WidgetTester tester, {double shift = 0}) =>
        paintPicture(
          tester,
          SizedBox(
            width: 200,
            height: 120,
            child: BattleStageBackdrop(feverOpacity: 1, stripeShift: shift),
          ),
          size: const Size(200, 120),
        );

    testWidgets('are 22 wide every 56, counted along a line 25 degrees below '
        'the horizontal', (tester) async {
      final picture = await stripes(tester);
      bool striped(double x, double y) => picture.at(x, y) != AppColors.fever;
      // Along the top edge a stripe is 22 / cos 25 = 24.3 wide and comes
      // every 56 / cos 25 = 61.8.
      expect(striped(10, 0), isTrue);
      expect(striped(22, 0), isTrue);
      expect(striped(28, 0), isFalse);
      expect(striped(58, 0), isFalse);
      expect(striped(66, 0), isTrue);
      expect(striped(84, 0), isTrue);
      expect(striped(90, 0), isFalse);
      // 100 further down the same stripes are 100 x tan 25 = 46.6 further
      // left: they lean.
      expect(striped(5, 100), isFalse);
      expect(striped(20, 100), isTrue);
      expect(striped(36, 100), isTrue);
      expect(striped(44, 100), isFalse);
    });

    testWidgets('drift to the right by the shift', (tester) async {
      final picture = await stripes(tester, shift: 30);
      bool striped(double x, double y) => picture.at(x, y) != AppColors.fever;
      expect(striped(10, 0), isFalse);
      expect(striped(40, 0), isTrue);
      expect(striped(52, 0), isTrue);
      expect(striped(58, 0), isFalse);
    });
  });

  group('the goal (A11 spec 5)', () {
    testWidgets("the HUD shows the state's goal as a chip", (tester) async {
      await _pump(
        tester,
        BattleFxTimeline().frame(0),
        _state(myReps: 3).withGoal(
          const GoalProgress(kind: GoalKind.reps, target: 20, value: 3),
        ),
      );
      expect(find.byType(BattleGoalChip), findsOneWidget);
      expect(find.text('미션 3/20'), findsOneWidget);
    });

    testWidgets("'미션 성공!' shows as the frame says: Do Hyeon 48 on a lime "
        'band 64 tall at 148, turned -4°', (tester) async {
      const reach = BattleStageEvent(
        side: BattleSide.me,
        grade: GameGrade.good,
        points: 10,
        combo: 1,
        reachesGoal: true,
      );
      final fx = BattleFxTimeline()..rep(reach, 0);
      final start =
          BattleFx.impactDelay +
          BattleFx.gradeWord(GameGrade.good).pointsAfter +
          880;
      await _pump(tester, fx.frame(0), _state());
      expect(find.text('미션 성공!'), findsNothing);
      await _pump(tester, fx.frame(start + 600), _state());
      final words = find.text('미션 성공!');
      expect(words, findsOneWidget);
      final style = tester.widget<Text>(words).style!;
      expect(style.fontFamily, AppFonts.display);
      expect(style.fontSize, 48);
      final band = find.ancestor(of: words, matching: find.byType(Stack)).first;
      expect(tester.getSize(band).height, closeTo(64, 0.01));
      // Lime with its own 3.5 ink edge (spec 5), slanted as the other bands.
      final fill =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: band,
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(fill.color, AppColors.accent);
      expect(
        fill.border!.top,
        const BorderSide(color: AppColors.ink, width: 3.5),
      );
      expect(
        tester
            .widget<Transform>(
              find
                  .ancestor(
                    of: find.descendant(
                      of: band,
                      matching: find.byType(DecoratedBox),
                    ),
                    matching: find.byType(Transform),
                  )
                  .first,
            )
            .transform,
        AppHighlight.battleSlant,
      );
      final turn = tester.widget<Transform>(
        find.ancestor(of: band, matching: find.byType(Transform)).first,
      );
      expect(
        math.atan2(turn.transform.entry(1, 0), turn.transform.entry(0, 0)),
        closeTo(-4 * math.pi / 180, 1e-6),
      );
      expect(
        tester
            .getTopLeft(
              find.ancestor(of: band, matching: find.byType(Positioned)).first,
            )
            .dy,
        148,
      );
      // A picture to a screen reader: the chip says it.
      expect(find.bySemanticsLabel('미션 성공!'), findsNothing);
    });
  });
  group('an arcade boss round and floor (P16 spec 6 and 7)', () {
    BattleStageHud hud(WidgetTester tester) =>
        tester.widget<BattleStageHud>(find.byType(BattleStageHud));

    testWidgets('the chip says ROUND n in place of the lead, on white', (
      tester,
    ) async {
      await _pump(
        tester,
        BattleFxTimeline(share: 0.575).frame(0),
        _state(me: 60, op: 45),
        round: 2,
      );
      expect(hud(tester).chip, (text: 'ROUND 2', tone: BattleFxTone.plain));
      expect(find.text('ROUND 2'), findsOneWidget);
    });

    testWidgets('fever still says fever, and before the start there is no '
        'chip', (tester) async {
      final fever = BattleFxTimeline()..setFever(true, 0);
      await _pump(tester, fever.frame(500), _state(fever: true), round: 1);
      expect(hud(tester).chip!.text, 'FEVER ×2');
      await _pump(
        tester,
        BattleFxTimeline(setup: true).frame(0),
        _state(phase: BattleStagePhase.setup),
        round: 1,
      );
      expect(hud(tester).chip, isNull);
    });

    testWidgets('the backdrop lays a floor picture over the grid, the stage\'s '
        'size and place, under the fever', (tester) async {
      Future<PaintedPicture> paint({double fever = 0}) => paintPicture(
        tester,
        SizedBox(
          width: 200,
          height: 220,
          child: BattleStageBackdrop(
            feverOpacity: fever,
            stripeShift: 0,
            scale: 0.5,
            origin: const Offset(10, 20),
            scenery: const ColoredBox(color: AppColors.opponent),
          ),
        ),
        size: const Size(200, 220),
      );
      final plain = await paint();
      // The stage's 360 x 390 at half size from (10, 20): to (190, 215).
      expect(plain.at(12, 22), AppColors.opponent);
      expect(plain.at(188, 213), AppColors.opponent);
      // Off the grid's lines (every 14 from the stage's corner).
      expect(plain.at(3, 12), AppColors.background);
      expect(plain.at(195, 100), isNot(AppColors.opponent));
      final fever = await paint(fever: 1);
      expect(fever.at(100, 100), isNot(AppColors.opponent));
    });

    testWidgets('without a picture the backdrop is as before', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BattleStageBackdrop(feverOpacity: 0, stripeShift: 0),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(BattleStageBackdrop),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
    });
  });
}
