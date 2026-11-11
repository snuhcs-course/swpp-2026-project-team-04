import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage_hud.dart';

import 'battle_test_support.dart';

Future<void> _pumpHud(
  WidgetTester tester, {
  String myName = 'hellohello',
  String opponentName = 'AI 봇 · 고수',
  int secondsLeft = 18,
  double elapsed = 0.4,
  ({String text, BattleFxTone tone})? chip = (
    text: '+15 앞섬',
    tone: BattleFxTone.me,
  ),
  int myScore = 60,
  int opponentScore = 45,
  int myReps = 5,
  int opponentReps = 4,
  double myScoreBump = 1,
  double opponentScoreBump = 1,
  double myRepsBump = 1,
  double opponentRepsBump = 1,
  TextScaler textScaler = TextScaler.noScaling,
}) => tester.pumpWidget(
  battleTestApp(
    MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: BattleFx.stageWidth,
            height: BattleFx.stageHeight,
            child: BattleStageHud(
              myName: myName,
              opponentName: opponentName,
              secondsLeft: secondsLeft,
              elapsed: elapsed,
              chip: chip,
              myScore: myScore,
              opponentScore: opponentScore,
              myReps: myReps,
              opponentReps: opponentReps,
              myScoreBump: myScoreBump,
              opponentScoreBump: opponentScoreBump,
              myRepsBump: myRepsBump,
              opponentRepsBump: opponentRepsBump,
            ),
          ),
        ],
      ),
    ),
  ),
);

/// The line of text of a nickname, clock or number.
RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    );

/// The chip's box around [text].
Rect _chip(WidgetTester tester, String text) => tester.getRect(
  find.ancestor(of: find.text(text), matching: find.byType(DecoratedBox)),
);

/// The 12-letter Korean nicknames of the design's tightest case.
const _longMe = '새벽네시푸쉬업하는사람들';
const _longOpponent = '스쿼트만삼백개하는고양이';

void main() {
  setUpAll(loadBattleFonts);

  group('BattleStageHud.clockText', () {
    test('shows the seconds left as m:ss', () {
      expect(BattleStageHud.clockText(30), '0:30');
      expect(BattleStageHud.clockText(7), '0:07');
      expect(BattleStageHud.clockText(0), '0:00');
      expect(BattleStageHud.clockText(75), '1:15');
    });

    test('never goes below zero', () {
      expect(BattleStageHud.clockText(-3), '0:00');
    });
  });

  group('BattleStageHud', () {
    testWidgets('shows both names, the clock, the chip, the scores and the '
        'valid counts', (tester) async {
      await _pumpHud(tester);
      expect(find.text('hellohello'), findsOneWidget);
      expect(find.text('AI 봇 · 고수'), findsOneWidget);
      expect(find.text('0:18'), findsOneWidget);
      expect(find.text('+15 앞섬'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('유효 횟수'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the name row is 28 tall from 26; my name on the left with a '
        'lime swatch, the opponent\'s on the right with a pink one', (
      tester,
    ) async {
      await _pumpHud(tester);
      final mine = tester.getRect(find.text('hellohello'));
      final theirs = tester.getRect(find.text('AI 봇 · 고수'));
      expect(mine.center.dy, closeTo(26 + 14, 0.5));
      expect(theirs.center.dy, closeTo(26 + 14, 0.5));
      // Swatch 12 from the side, 6 before the name.
      expect(mine.left, 12 + 12 + 6);
      expect(theirs.right, 360 - 12 - 12 - 6);
      final swatches = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => decoration.border != null)
          .toList();
      expect(swatches.map((s) => s.color), [
        AppColors.accent,
        AppColors.opponent,
      ]);
    });

    testWidgets('the clock and its chip stay in the middle whatever the '
        'names are', (tester) async {
      await _pumpHud(tester);
      final short = tester.getRect(find.text('0:18'));
      await _pumpHud(tester, myName: _longMe, opponentName: 'A');
      expect(tester.getRect(find.text('0:18')), short);
      // The pair, clock and chip, is centered on the stage's middle.
      final chip = _chip(tester, '+15 앞섬');
      expect((short.left + chip.right) / 2, closeTo(180, 0.01));
    });

    testWidgets('the chip is its text with 8 beside and 2 above and below, '
        'inside a 1.5 ink edge, 6 after the clock', (tester) async {
      await _pumpHud(tester);
      final label = tester.getRect(find.text('+15 앞섬'));
      final chip = _chip(tester, '+15 앞섬');
      expect(chip.width, closeTo(label.width + 2 * (8 + 1.5), 0.01));
      expect(chip.height, closeTo(label.height + 2 * (2 + 1.5), 0.01));
      expect(chip.left - tester.getRect(find.text('0:18')).right, 6);
      // As measured on the design's shot for "+15 앞섬": a 61 x 22 fill
      // inside the edge.
      expect(chip.width - 2 * 1.5, closeTo(61, 0.6));
      expect(chip.height - 2 * 1.5, closeTo(22, 0.6));
    });

    testWidgets('the clock is Oxanium 26 on a line of its own height', (
      tester,
    ) async {
      await _pumpHud(tester);
      final style = tester.widget<Text>(find.text('0:18')).style!;
      expect(style.fontFamily, AppFonts.number);
      expect(style.fontSize, 26);
      expect(style.fontWeight, FontWeight.w700);
      expect(tester.getSize(find.text('0:18')).height, 26);
    });

    testWidgets('the chip has its tone\'s fill and an ink edge; none before '
        'the start', (tester) async {
      await _pumpHud(
        tester,
        chip: (text: 'FEVER ×2', tone: BattleFxTone.fever),
      );
      final shape =
          tester
                  .widget<DecoratedBox>(
                    find.ancestor(
                      of: find.text('FEVER ×2'),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as ShapeDecoration;
      expect(shape.color, AppColors.fever);
      expect(
        shape.shape,
        const StadiumBorder(side: BorderSide(color: AppColors.ink, width: 1.5)),
      );

      await _pumpHud(tester, chip: null);
      expect(find.text('FEVER ×2'), findsNothing);
      expect(find.text('0:18'), findsOneWidget);
    });

    testWidgets('a nickname wider than 80 ends in "…"; a screen reader still '
        'gets all of it', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHud(tester, myName: _longMe, opponentName: _longOpponent);
      expect(tester.getSize(find.text(_longMe)).width, lessThanOrEqualTo(80));
      expect(
        tester.getSize(find.text(_longOpponent)).width,
        lessThanOrEqualTo(80),
      );
      expect(_paragraph(tester, _longMe).didExceedMaxLines, isTrue);
      final name = tester.widget<Text>(find.text(_longMe));
      expect(name.overflow, TextOverflow.ellipsis);
      expect(name.maxLines, 1);
      // Whose name it is, which the eye reads from the swatch.
      expect(find.bySemanticsLabel('나 $_longMe'), findsOneWidget);
      expect(find.bySemanticsLabel('상대 $_longOpponent'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the cut is by width, not by letters: six Korean letters fit '
        'whole and a seventh is cut', (tester) async {
      bool cut(String name) => _paragraph(tester, name).didExceedMaxLines;
      await _pumpHud(tester, myName: '푸쉬업하는곰', opponentName: 'hellohello');
      expect(cut('푸쉬업하는곰'), isFalse);
      expect(cut('hellohello'), isFalse);
      await _pumpHud(tester, myName: '푸쉬업하는곰들', opponentName: 'iiiiiiiiiiii');
      expect(cut('푸쉬업하는곰들'), isTrue);
      expect(cut('iiiiiiiiiiii'), isFalse, reason: 'twelve narrow letters');
    });

    testWidgets('the tightest case fits: two 12-letter names, the widest '
        'chip, two 3-digit scores', (tester) async {
      await _pumpHud(
        tester,
        myName: _longMe,
        opponentName: _longOpponent,
        secondsLeft: 7,
        chip: (text: '−99 추격 중', tone: BattleFxTone.opponent),
        myScore: 245,
        opponentScore: 310,
        myReps: 12,
        opponentReps: 14,
      );
      expect(tester.takeException(), isNull);
      // Names clear of the clock and the chip.
      expect(
        tester.getRect(find.text(_longMe)).right,
        lessThan(tester.getRect(find.text('0:07')).left),
      );
      final chip = _chip(tester, '−99 추격 중');
      expect(
        chip.right,
        lessThan(tester.getRect(find.text(_longOpponent)).left),
      );
      // The valid counts clear of both scores.
      final counts = tester
          .getRect(find.text('12'))
          .expandToInclude(tester.getRect(find.text('14')));
      expect(tester.getRect(find.text('245')).right, lessThan(counts.left));
      expect(counts.right, lessThan(tester.getRect(find.text('310')).left));
    });

    testWidgets('the scores hang from 54 at the sides, on a 32 tall slanted '
        'band of the player\'s color 6 above the bottom', (tester) async {
      await _pumpHud(tester);
      final mine = tester.getRect(find.text('60'));
      final theirs = tester.getRect(find.text('45'));
      expect(mine.top, 54);
      expect(theirs.top, 54);
      expect(mine.height, closeTo(80 * 0.92, 0.01));
      final bands = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(Transform),
              matching: find.byType(ColoredBox),
            ),
          )
          .map((box) => box.color);
      expect(bands, containsAll([AppColors.accent, AppColors.opponent]));
      final band = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.accent,
        ),
      );
      expect(band.height, 32);
      expect(band.bottom, closeTo(mine.bottom - 6, 0.01));
      final slant = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byWidgetPredicate(
                (w) => w is ColoredBox && w.color == AppColors.accent,
              ),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(slant.transform, AppHighlight.battleSlant);
      expect(slant.alignment, Alignment.center);
      // The score's box, which the band spans, reaches 2 past the 12 side
      // margin on both sides, and the number sits 6 inside it.
      Rect boxOf(String score) => tester.getRect(
        find.ancestor(of: find.text(score), matching: find.byType(Stack)).first,
      );
      expect(boxOf('60').left, 10);
      expect(boxOf('45').right, 350);
      expect(mine.left - boxOf('60').left, 6 + 1.5);
      expect(boxOf('45').right - theirs.right, 6 - 1.5);
    });

    testWidgets('a score bumps around its outer bottom corner', (tester) async {
      await _pumpHud(tester);
      final mine = tester.getRect(find.text('60'));
      final theirs = tester.getRect(find.text('45'));
      await _pumpHud(tester, myScoreBump: 1.2, opponentScoreBump: 1.2);
      final myBumped = tester.getRect(find.text('60'));
      final theirBumped = tester.getRect(find.text('45'));
      expect(myBumped.height, closeTo(mine.height * 1.2, 0.01));
      expect(myBumped.bottom, closeTo(mine.bottom, 0.01));
      expect(theirBumped.bottom, closeTo(theirs.bottom, 0.01));
      // The left score grows to the right, the right one to the left.
      expect(myBumped.right, greaterThan(mine.right));
      expect(theirBumped.left, lessThan(theirs.left));
      // The number sits 4.5 inside its box, and that room grows with it.
      expect(theirBumped.right, closeTo(theirs.right - 4.5 * 0.2, 0.01));
    });

    testWidgets('the ":" between the valid counts stays at the middle', (
      tester,
    ) async {
      await _pumpHud(tester);
      expect(tester.getCenter(find.text(':')).dx, closeTo(180, 0.01));
      final label = tester.getRect(find.text('유효 횟수'));
      expect(label.top, 68);
      expect(label.height, 14);
      // The counts are 2 under their label, on a line 20 high.
      expect(tester.getRect(find.text(':')).top, label.bottom + 2);
      expect(tester.getRect(find.text(':')).height, 20);
      // Each count has a cell 22 wide: mine ends at its right, the
      // opponent's starts at its left.
      expect(tester.getSize(find.text('5')).width, 22);
      expect(tester.widget<Text>(find.text('5')).textAlign, TextAlign.right);
      expect(tester.widget<Text>(find.text('4')).textAlign, TextAlign.left);
      await _pumpHud(tester, myReps: 9, opponentReps: 14);
      expect(tester.getCenter(find.text(':')).dx, closeTo(180, 0.01));
      // My count ends 5 before the ":", the opponent's starts 5 after it.
      final colon = tester.getRect(find.text(':'));
      expect(
        tester.getRect(find.text('9')).right,
        closeTo(colon.left - 5, 0.01),
      );
      expect(
        tester.getRect(find.text('14')).left,
        closeTo(colon.right + 5, 0.01),
      );
    });

    testWidgets('only the count that went up bumps, around a point low in '
        'its line', (tester) async {
      await _pumpHud(tester);
      final mine = tester.getRect(find.text('5'));
      final theirs = tester.getRect(find.text('4'));
      await _pumpHud(tester, myRepsBump: 1.3);
      final bumped = tester.getRect(find.text('5'));
      expect(bumped.width, closeTo(mine.width * 1.3, 0.01));
      expect(bumped.center.dx, closeTo(mine.center.dx, 0.01));
      // 85% down the line stays put.
      expect(
        bumped.top + bumped.height * 0.85,
        closeTo(mine.top + mine.height * 0.85, 0.01),
      );
      expect(tester.getRect(find.text('4')), theirs);
    });

    testWidgets('the time bar is 5 tall at 131 and fills with ink as the '
        'round passes', (tester) async {
      await _pumpHud(tester, elapsed: 0.25);
      final track = tester.getRect(find.byType(ClipRRect));
      expect(track, const Rect.fromLTWH(12, 131, 336, 5));
      expect(
        tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
        const BorderRadius.all(Radius.circular(3)),
      );
      final fill = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.ink,
        ),
      );
      expect(fill.left, 12);
      expect(fill.width, 336 * 0.25);

      await _pumpHud(tester, elapsed: 1.7);
      expect(
        tester
            .getRect(
              find.byWidgetPredicate(
                (w) => w is ColoredBox && w.color == AppColors.ink,
              ),
            )
            .width,
        336,
      );
    });

    testWidgets('does not grow with the system text size', (tester) async {
      await _pumpHud(tester);
      final score = tester.getRect(find.text('60'));
      final name = tester.getRect(find.text('hellohello'));
      await _pumpHud(tester, textScaler: const TextScaler.linear(2));
      expect(tester.getRect(find.text('60')), score);
      expect(tester.getRect(find.text('hellohello')), name);
    });

    testWidgets('a screen reader hears the scores, the valid counts and the '
        'time left', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHud(tester);
      expect(find.bySemanticsLabel('내 점수 60점'), findsOneWidget);
      expect(find.bySemanticsLabel('상대 점수 45점'), findsOneWidget);
      expect(find.bySemanticsLabel('유효 횟수 나 5회, 상대 4회'), findsOneWidget);
      expect(find.bySemanticsLabel('남은 시간 18초'), findsOneWidget);
      expect(find.bySemanticsLabel('나 hellohello'), findsOneWidget);
      expect(find.bySemanticsLabel('상대 AI 봇 · 고수'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('time that has run past zero is read as 0 seconds', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpHud(tester, secondsLeft: -2);
      expect(find.text('0:00'), findsOneWidget);
      expect(find.bySemanticsLabel('남은 시간 0초'), findsOneWidget);
      handle.dispose();
    });
  });
}
