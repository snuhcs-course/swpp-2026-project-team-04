import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/bot_difficulty.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/result_cards.dart';
import 'package:gymrats_app/widgets/result_report.dart';

const _bot = Opponent(
  name: 'AI 봇 · 고수',
  isBot: true,
  difficulty: BotDifficulty.expert,
);

/// The design's battle: a KO win, 240 : 125 in 25 s.
ResultReportData _data({
  MatchOutcome outcome = MatchOutcome.win,
  bool byKo = true,
  ExerciseType exercise = ExerciseType.pushUp,
  Opponent opponent = _bot,
  Duration? played = const Duration(seconds: 25),
  int myScore = 240,
  int opponentScore = 125,
  int myValidReps = 12,
  int opponentValidReps = 6,
  BattleDeparture departure = BattleDeparture.none,
  bool hasFeedback = false,
  bool comparisonLoading = false,
  int? myInvalidReps = 0,
  ResultNewBest? best,
  ResultRecent? recent,
  ResultTip? tip,
}) => ResultReportData(
  outcome: outcome,
  byKo: byKo,
  exercise: exercise,
  opponent: opponent,
  played: played,
  myScore: myScore,
  opponentScore: opponentScore,
  myValidReps: myValidReps,
  myInvalidReps: myInvalidReps,
  opponentValidReps: opponentValidReps,
  endedAt: DateTime(2026, 11, 4, 14, 30),
  departure: departure,
  hasFeedback: hasFeedback,
  comparisonLoading: comparisonLoading,
  best: best,
  recent: recent,
  tip: tip,
);

const _best = ResultNewBest(previous: 185, current: 240, gain: 55);
final _recent = ResultRecent(
  scores: const [80, 95, 110, 105, 130, 150, 185, 240],
  firstPlayedAt: DateTime(2026, 10, 28),
  average: 136,
  averageCount: 5,
  difference: 104,
);
const _tip = ResultTip(
  title: '팔꿈치를 90°까지 굽혀 보세요',
  reason: '이번 판 평균 123° · 더 깊게 내려가면 Excellent +15',
);

/// The design's whole report, every card on.
ResultReportData _full() =>
    _data(hasFeedback: true, best: _best, recent: _recent, tip: _tip);

var _fontsLoaded = false;

/// Tests otherwise draw every letter as the same square, and the widths
/// this file checks (one line, cut nicknames, the reps beside the scores)
/// would not be the phone's. Loaded once; they stay for the whole run.
Future<void> _loadAppFonts(WidgetTester tester) async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  await tester.runAsync(() async {
    for (final entry in const {
      AppFonts.number: [
        'assets/fonts/Oxanium-Bold.ttf',
        'assets/fonts/Oxanium-ExtraBold.ttf',
      ],
      AppFonts.headline: ['assets/fonts/BlackHanSans-Regular.ttf'],
      AppFonts.body: [
        'assets/fonts/IBMPlexSansKR-Regular.ttf',
        'assets/fonts/IBMPlexSansKR-Medium.ttf',
        'assets/fonts/IBMPlexSansKR-SemiBold.ttf',
        'assets/fonts/IBMPlexSansKR-Bold.ttf',
      ],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final asset in entry.value) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }
  });
}

/// The WCAG contrast ratio of two opaque colors, from 1 to 21.
double _contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  late List<String> taps;

  Future<void> show(
    WidgetTester tester,
    ResultReportData data, {
    Size size = const Size(360, 780),
    double textScale = 1,
  }) async {
    await _loadAppFonts(tester);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    taps = [];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ResultReport(
          data: data,
          onGoHome: () => taps.add('home'),
          onRematch: () => taps.add('rematch'),
          onOpenFeedback: () => taps.add('feedback'),
        ),
      ),
    );
  }

  /// Where [finder]'s first line sits on the screen: its alphabetic
  /// baseline.
  double baselineOf(WidgetTester tester, Finder finder) {
    final rich = find
        .descendant(of: finder, matching: find.byType(RichText))
        .first;
    final paragraph = tester.renderObject<RenderParagraph>(rich);
    // A painter set up as the paragraph is: only its parent may ask the
    // paragraph itself for its baseline.
    final text = tester.widget<RichText>(rich);
    final painter = TextPainter(
      text: text.text,
      textDirection: TextDirection.ltr,
      textScaler: text.textScaler,
      strutStyle: text.strutStyle,
    )..layout(maxWidth: paragraph.size.width);
    addTearDown(painter.dispose);
    return paragraph.localToGlobal(Offset.zero).dy +
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  }

  /// Every color text is painted in; icons left out.
  Set<Color> textColors(WidgetTester tester) {
    final colors = <Color>{};
    void walk(InlineSpan span, Color? around) {
      if (span is! TextSpan) return;
      final color = span.style?.color ?? around;
      final isIcon = span.style?.fontFamily == Icons.home.fontFamily;
      if (!isIcon && (span.text ?? '').trim().isNotEmpty && color != null) {
        colors.add(color);
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        walk(child, color);
      }
    }

    for (final paragraph in tester.renderObjectList<RenderParagraph>(
      find.byType(RichText),
    )) {
      walk(paragraph.text, null);
    }
    return colors;
  }

  group('the headline (BResultHeads A)', () {
    for (final (outcome, byKo, word, band) in const [
      (MatchOutcome.win, true, 'KO 승리', AppColors.accent),
      (MatchOutcome.win, false, '승리', AppColors.accent),
      (MatchOutcome.lose, true, 'KO 패배', AppColors.opponent),
      (MatchOutcome.lose, false, '패배', AppColors.opponent),
      (MatchOutcome.draw, false, '무승부', AppColors.border),
      (MatchOutcome.draw, true, '무승부', AppColors.border),
    ]) {
      testWidgets('${outcome.name}${byKo ? ' by KO' : ''}: "$word" in ink on '
          'a slanted band, 4.5:1 or more', (tester) async {
        await show(tester, _data(outcome: outcome, byKo: byKo));
        final headline = find.byType(ResultHeadline);
        final words = find.descendant(of: headline, matching: find.text(word));
        expect(words, findsOneWidget);
        final style = tester.widget<Text>(words).style!;
        expect(style.color, AppColors.ink);
        expect(style.fontSize, 46);
        final fill = tester.widget<ColoredBox>(
          find.descendant(of: headline, matching: find.byType(ColoredBox)),
        );
        expect(fill.color, band);
        expect(_contrast(AppColors.ink, band), greaterThanOrEqualTo(4.5));
        // Both lean: the letters 10°, the band 14°.
        final leans = tester
            .widgetList<Transform>(
              find.descendant(of: headline, matching: find.byType(Transform)),
            )
            .map((t) => t.transform.entry(0, 1));
        expect(leans, everyElement(isNot(0)));
        expect(leans.toSet(), hasLength(2));
        expect(find.bySemanticsLabel(word), findsOneWidget);
      });
    }

    testWidgets('the band covers the lower part of the words and runs past '
        'their end', (tester) async {
      await show(tester, _data());
      // The boxes before their slants: the slant moves the top corners.
      Rect unslanted(Finder inside) => tester.getRect(
        find.ancestor(of: inside, matching: find.byType(Transform)).first,
      );
      final words = unslanted(find.text('KO 승리'));
      final band = unslanted(
        find.descendant(
          of: find.byType(ResultHeadline),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(band.bottom, closeTo(words.bottom - 3, 0.5));
      expect(band.height, 20);
      expect(band.left, closeTo(words.left - 4, 0.5));
      expect(band.right, closeTo(words.right + 10, 0.5));
    });

    testWidgets('one line at its full size on a 360 phone', (tester) async {
      await show(tester, _data());
      // Not shrunk: as tall as a 46-point line.
      final words = tester.getRect(find.text('KO 승리'));
      expect(words.height, closeTo(46 * 1.05, 1));
    });

    testWidgets('with large system text it grows, and shrinks only to stay on '
        'one line', (tester) async {
      await show(tester, _data(), size: const Size(320, 640), textScale: 2);
      expect(tester.takeException(), isNull);
      final words = tester.getRect(find.text('KO 승리'));
      // Larger than at 1x, and within the page's 20-point margins.
      expect(words.height, greaterThan(46 * 1.05));
      expect(words.right, lessThanOrEqualTo(320 - 20));
      final line = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('KO 승리'),
          matching: find.byType(RichText),
        ),
      );
      // Every letter on the same line.
      final tops = line
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 'KO 승리'.length),
          )
          .map((box) => box.top)
          .toSet();
      expect(tops, hasLength(1));
    });
  });

  group('the sub line', () {
    testWidgets('a bot: the exercise, "RepBot" and its level, the seconds', (
      tester,
    ) async {
      await show(tester, _data());
      expect(find.text('푸쉬업 · vs '), findsOneWidget);
      expect(find.text('RepBot 고수'), findsOneWidget);
      expect(find.text(' · 25초'), findsOneWidget);
      expect(find.bySemanticsLabel('푸쉬업, RepBot 고수 상대, 25초'), findsOneWidget);
    });

    test('each level by its name; a bot without one plays as 고수', () {
      for (final level in BotDifficulty.values) {
        expect(
          ResultSubLine.opponentText(
            const Opponent(name: 'x', isBot: true).at(level),
          ),
          'RepBot ${level.label}',
        );
      }
      expect(
        ResultSubLine.opponentText(const Opponent(name: 'x', isBot: true)),
        'RepBot 고수',
      );
      expect(
        ResultSubLine.opponentText(const Opponent(name: '민아', isBot: false)),
        '민아',
      );
    });

    testWidgets('a squat battle against a person, to the end', (tester) async {
      await show(
        tester,
        _data(
          exercise: ExerciseType.squat,
          opponent: const Opponent(name: '민아', isBot: false),
          played: const Duration(seconds: 30),
        ),
      );
      expect(find.text('스쿼트 · vs '), findsOneWidget);
      expect(find.text('민아'), findsOneWidget);
      expect(find.text(' · 30초'), findsOneWidget);
    });

    for (final textScale in const [1.0, 2.0]) {
      testWidgets('at ${textScale}x a long nickname alone is cut; the '
          'exercise and the seconds stay whole', (tester) async {
        const name = 'VeryLongNicknameOfTheOpponent';
        await show(
          tester,
          _data(opponent: const Opponent(name: name, isBot: false)),
          size: const Size(320, 640),
          textScale: textScale,
        );
        expect(tester.takeException(), isNull);
        final nickname = tester.widget<Text>(find.text(name));
        expect(nickname.overflow, TextOverflow.ellipsis);
        expect(nickname.maxLines, 1);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: find.text(name), matching: find.byType(RichText)),
        );
        expect(paragraph.didExceedMaxLines, isTrue);
        expect(
          tester.getRect(find.text(' · 25초')).right,
          lessThanOrEqualTo(320 - 20),
        );
        expect(
          tester.getRect(find.text('푸쉬업 · vs ')).left,
          greaterThanOrEqualTo(20),
        );
      });
    }
  });

  group('the reason under the sub line', () {
    const person = Opponent(name: '진영', isBot: false);

    /// A time-up battle with equal scores, decided by [mine] : [theirs]
    /// valid reps.
    ResultReportData tied(MatchOutcome outcome, int mine, int theirs) => _data(
      outcome: outcome,
      byKo: false,
      played: const Duration(seconds: 60),
      myScore: 150,
      opponentScore: 150,
      myValidReps: mine,
      opponentValidReps: theirs,
    );

    test('equal scores at time-up: the valid reps decided it', () {
      expect(
        ResultSubLine.reasonOf(tied(MatchOutcome.win, 11, 10)),
        '점수 같음 · 횟수로 승리',
      );
      expect(
        ResultSubLine.reasonOf(tied(MatchOutcome.lose, 9, 10)),
        '점수 같음 · 횟수로 패배',
      );
    });

    test('a player leaving an online battle', () {
      expect(
        ResultSubLine.reasonOf(
          _data(departure: BattleDeparture.opponentLeft, opponent: person),
        ),
        '상대가 나갔어요',
      );
      expect(
        ResultSubLine.reasonOf(
          _data(
            outcome: MatchOutcome.lose,
            departure: BattleDeparture.myConnectionLost,
            opponent: person,
          ),
        ),
        '연결이 끊겼어요',
      );
      // Leaving says why even when the scores were equal.
      expect(
        ResultSubLine.reasonOf(
          _data(
            byKo: false,
            myScore: 50,
            opponentScore: 50,
            departure: BattleDeparture.opponentLeft,
          ),
        ),
        '상대가 나갔어요',
      );
    });

    test('no reason: a draw, different scores, a KO, or values that do not '
        'agree with the outcome', () {
      for (final data in [
        // Equal scores and equal reps: a draw stays as it is.
        tied(MatchOutcome.draw, 10, 10),
        // The scores decided it.
        _data(byKo: false, myValidReps: 11, opponentValidReps: 10),
        _data(byKo: true, myScore: 150, opponentScore: 150),
        // The reps do not back the outcome.
        tied(MatchOutcome.win, 10, 10),
        tied(MatchOutcome.win, 9, 10),
        tied(MatchOutcome.lose, 11, 10),
        // A departure that does not match the outcome.
        _data(departure: BattleDeparture.myConnectionLost),
        _data(
          outcome: MatchOutcome.lose,
          departure: BattleDeparture.opponentLeft,
        ),
      ]) {
        expect(ResultSubLine.reasonOf(data), isNull);
      }
    });

    testWidgets('the reason goes on its own line under the sub line, which '
        'keeps its seconds', (tester) async {
      await show(tester, tied(MatchOutcome.win, 11, 10));
      final line = tester.getRect(find.text('푸쉬업 · vs '));
      expect(find.text(' · 60초'), findsOneWidget);
      final reason = tester.getRect(find.text('점수 같음 · 횟수로 승리'));
      expect(reason.left, line.left);
      expect(reason.top, greaterThanOrEqualTo(line.bottom));
      expect(
        reason.bottom,
        lessThan(tester.getRect(find.text('150').first).top),
      );
      final style = tester.widget<Text>(find.text('점수 같음 · 횟수로 승리')).style;
      expect(style, tester.widget<Text>(find.text('푸쉬업 · vs ')).style);
      expect(
        find.bySemanticsLabel('푸쉬업, RepBot 고수 상대, 60초, 점수 같음, 횟수로 승리'),
        findsOneWidget,
      );
    });

    testWidgets('a battle a player left, without its length: no seconds', (
      tester,
    ) async {
      await show(
        tester,
        _data(
          byKo: false,
          played: null,
          opponent: person,
          departure: BattleDeparture.opponentLeft,
        ),
      );
      expect(find.text('상대가 나갔어요'), findsOneWidget);
      expect(find.textContaining('초'), findsNothing);
      expect(find.bySemanticsLabel('푸쉬업, 진영 상대, 상대가 나갔어요'), findsOneWidget);
    });

    testWidgets('no second line without a reason', (tester) async {
      await show(tester, tied(MatchOutcome.draw, 10, 10));
      final sub = find.byType(ResultSubLine);
      expect(
        find.descendant(of: sub, matching: find.byType(Text)),
        findsNWidgets(3),
      );
      expect(
        tester.getRect(sub).height,
        tester.getRect(find.text('푸쉬업 · vs ')).height,
      );
    });

    // W5 seats the victory character in a 144-point cell at the right end
    // of the headline's rows: the reason stays left of it.
    for (final textScale in const [1.0, 1.3]) {
      testWidgets('at ${textScale}x on a 360 phone the reason line stays '
          'clear of the seat at the right end', (tester) async {
        const seatLeft = 360 - 20 - 144;
        for (final data in [
          tied(MatchOutcome.win, 11, 10),
          tied(MatchOutcome.lose, 9, 10),
          _data(departure: BattleDeparture.opponentLeft, opponent: person),
          _data(
            outcome: MatchOutcome.lose,
            departure: BattleDeparture.myConnectionLost,
            opponent: person,
          ),
        ]) {
          await show(tester, data, textScale: textScale);
          final reason = ResultSubLine.reasonOf(data)!;
          expect(
            tester.getRect(find.text(reason)).right,
            lessThanOrEqualTo(seatLeft),
          );
        }
      });
    }

    testWidgets('the design\'s bot line stays left of the seat too', (
      tester,
    ) async {
      await show(tester, _data());
      expect(
        tester.getRect(find.text(' · 25초')).right,
        lessThanOrEqualTo(360 - 20 - 144),
      );
    });
  });

  group('the score row', () {
    testWidgets('my score big, ":", theirs smaller, a lime swatch before and '
        'a pink one after, all ink', (tester) async {
      await show(tester, _data());
      final mine = tester.widget<Text>(find.text('240'));
      final theirs = tester.widget<Text>(find.text('125'));
      expect(mine.style?.fontSize, 40);
      expect(mine.style?.fontWeight, FontWeight.w800);
      expect(mine.style?.color, AppColors.ink);
      expect(theirs.style?.fontSize, 24);
      expect(theirs.style?.color, AppColors.ink);
      expect(
        tester.widget<Text>(find.text(':')).style?.color,
        AppColors.textMuted,
      );

      final swatches = find.descendant(
        of: find.byType(ResultScoreRow),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration ==
                  AppHighlight.swatch(
                    (widget.decoration as BoxDecoration).color!,
                  ),
        ),
      );
      final colors = tester
          .widgetList<DecoratedBox>(swatches)
          .map((box) => (box.decoration as BoxDecoration).color);
      expect(colors, [AppColors.accent, AppColors.opponent]);
      expect(
        tester.getRect(swatches.first).right,
        lessThan(tester.getRect(find.text('240')).left),
      );
      expect(
        tester.getRect(swatches.last).left,
        greaterThan(tester.getRect(find.text('125')).right),
      );
      // Each swatch sits in the middle of the big score's line.
      final big = tester.getRect(find.text('240'));
      expect(
        tester.getRect(swatches.first).center.dy,
        closeTo(big.center.dy, 2),
      );
      expect(find.bySemanticsLabel('내 점수 240점, 상대 점수 125점'), findsOneWidget);
    });

    testWidgets('on a 360 phone the reps sit at the far right on the scores\' '
        'baseline', (tester) async {
      await show(tester, _data());
      final reps = find.text('인정 12회 · 무효 0회');
      expect(tester.getRect(reps).right, closeTo(360 - 20, 0.5));
      for (final score in ['240', '125']) {
        expect(
          baselineOf(tester, reps),
          closeTo(baselineOf(tester, find.text(score)), 1),
          reason: score,
        );
      }
    });

    testWidgets('at 2x on a 320 phone the reps go under the scores', (
      tester,
    ) async {
      await show(tester, _data(), size: const Size(320, 640), textScale: 2);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text('인정 12회 · 무효 0회')).top,
        greaterThanOrEqualTo(tester.getRect(find.text('240')).bottom),
      );
    });

    test('the reps line', () {
      expect(ResultScoreRow.repsText(3, 1), '인정 3회 · 무효 1회');
      expect(ResultScoreRow.repsText(3, null), '인정 3회');
    });

    testWidgets('rejected reps not known: only the counted ones', (
      tester,
    ) async {
      await show(tester, _data(myInvalidReps: null));
      expect(find.text('인정 12회'), findsOneWidget);
      expect(find.textContaining('무효'), findsNothing);
    });
  });

  group('the header', () {
    testWidgets('REPORT over the end time; the back button goes home', (
      tester,
    ) async {
      await show(tester, _data());
      expect(find.text('REPORT'), findsOneWidget);
      expect(find.text('11월 4일 14:30'), findsOneWidget);
      expect(tester.getSize(find.byType(ResultBackButton)), const Size(48, 48));
      await tester.tap(find.byTooltip('홈으로'));
      expect(taps, ['home']);
    });

    test('dates and times as the header writes them', () {
      expect(ResultHeader.dateText(DateTime(2026, 1, 9, 7, 5)), '1월 9일 07:05');
      expect(
        ResultHeader.dateText(DateTime(2026, 12, 31, 23, 59)),
        '12월 31일 23:59',
      );
    });
  });

  group('the cards', () {
    testWidgets('none shows without values or feedback', (tester) async {
      await show(tester, _data());
      expect(find.byType(ResultBestCard), findsNothing);
      expect(find.byType(ResultRecentCard), findsNothing);
      expect(find.byType(ResultTipCard), findsNothing);
      expect(find.text('자세 피드백 전체 보기'), findsNothing);
    });

    testWidgets('with feedback and no tip, only the feedback link shows', (
      tester,
    ) async {
      await show(tester, _data(hasFeedback: true));
      expect(find.byType(ResultTipCard), findsOneWidget);
      expect(find.text('다음 판 한 가지'), findsNothing);
      await tester.tap(find.text('자세 피드백 전체 보기'));
      expect(taps, ['feedback']);
    });

    testWidgets('each card the values have, in the design\'s order', (
      tester,
    ) async {
      await show(tester, _full());
      final best = tester.getRect(find.byType(ResultBestCard));
      final recent = tester.getRect(find.byType(ResultRecentCard));
      final tip = tester.getRect(find.byType(ResultTipCard));
      expect(best.top, greaterThan(tester.getRect(find.text('240')).bottom));
      expect(recent.top, best.bottom + AppSpacing.s12);
      expect(tip.top, recent.bottom + AppSpacing.s12);
      expect(find.text('팔꿈치를 90°까지 굽혀 보세요'), findsOneWidget);
    });

    testWidgets('a card without a value leaves no gap: the next moves up', (
      tester,
    ) async {
      await show(tester, _data(recent: _recent, tip: _tip));
      expect(find.byType(ResultBestCard), findsNothing);
      expect(
        tester.getRect(find.byType(ResultRecentCard)).top,
        closeTo(
          tester.getRect(find.byType(ResultScoreRow)).bottom + AppSpacing.s12,
          0.5,
        ),
      );
    });

    testWidgets('while the earlier battles load, one placeholder stands under '
        'the scores, and the tip card follows it', (tester) async {
      await show(
        tester,
        _data(comparisonLoading: true, hasFeedback: true, tip: _tip),
      );
      final placeholder = tester.getRect(
        find.byType(ResultComparisonPlaceholder),
      );
      expect(
        placeholder.top,
        closeTo(
          tester.getRect(find.byType(ResultScoreRow)).bottom + AppSpacing.s12,
          0.5,
        ),
      );
      expect(
        tester.getRect(find.byType(ResultTipCard)).top,
        closeTo(placeholder.bottom + AppSpacing.s12, 0.5),
      );
      expect(find.byType(ResultBestCard), findsNothing);
      expect(find.byType(ResultRecentCard), findsNothing);
    });

    testWidgets('no placeholder once they are in', (tester) async {
      await show(tester, _full());
      expect(find.byType(ResultComparisonPlaceholder), findsNothing);
    });

    testWidgets('latest battles with no scores leave their card out', (
      tester,
    ) async {
      await show(
        tester,
        _data(
          recent: ResultRecent(
            scores: const [],
            firstPlayedAt: DateTime(2026, 10, 28),
            average: 0,
            averageCount: 0,
            difference: 0,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ResultRecentCard), findsNothing);
    });
  });

  group('the buttons', () {
    testWidgets('홈으로 and 다시 대결 call their actions', (tester) async {
      await show(tester, _data());
      await tester.tap(find.text('홈으로'));
      await tester.tap(find.text('다시 대결'));
      expect(taps, ['home', 'rematch']);
    });

    testWidgets('다시 대결 is white on ink with a lime arrow; 홈으로 is ink on '
        'white with a gray edge', (tester) async {
      await show(tester, _data());
      expect(
        tester.widget<Text>(find.text('다시 대결')).style?.color,
        AppColors.onInk,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.arrow_forward_rounded)).color,
        AppColors.accent,
      );
      final rematch = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(rematch.style?.backgroundColor?.resolve(const {}), AppColors.ink);
      final home = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(
        home.style?.side?.resolve(const {}),
        const BorderSide(color: AppColors.line, width: 1.5),
      );
      expect(
        tester.widget<Text>(find.text('홈으로')).style?.color,
        isNot(isIn([AppColors.accent, AppColors.opponent])),
      );
    });
  });

  group('on the screen', () {
    testWidgets('no text in a palette B fill color, every card on', (
      tester,
    ) async {
      await show(tester, _full());
      final colors = textColors(tester);
      expect(colors, isNotEmpty);
      for (final fill in const [
        AppColors.accent,
        AppColors.opponent,
        AppColors.warning,
        AppColors.fever,
        AppColors.danger,
      ]) {
        expect(colors, isNot(contains(fill)));
      }
    });

    testWidgets('every card fits a 360x780 phone with the buttons at the '
        'bottom, no scrolling', (tester) async {
      await show(tester, _full());
      expect(tester.takeException(), isNull);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, 0);
      expect(
        tester.getRect(find.byType(ResultButtons)).bottom,
        closeTo(780 - AppSpacing.s24, 0.5),
      );
    });

    testWidgets('a short phone scrolls down to the buttons', (tester) async {
      await show(tester, _full(), size: const Size(360, 640));
      expect(tester.takeException(), isNull);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expect(
        tester.getRect(find.byType(ResultButtons)).bottom,
        closeTo(640 - AppSpacing.s24, 0.5),
      );
    });

    for (final textScale in const [1.3, 2.0]) {
      testWidgets('at ${textScale}x on a 320x640 phone nothing overflows', (
        tester,
      ) async {
        await show(
          tester,
          _full(),
          size: const Size(320, 640),
          textScale: textScale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
