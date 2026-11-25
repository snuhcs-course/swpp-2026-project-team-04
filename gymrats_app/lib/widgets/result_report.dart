import 'package:flutter/material.dart';

import '../models/battle_result.dart';
import '../models/bot_difficulty.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/match_record.dart';
import '../models/matchup.dart';
import '../theme/app_theme.dart';
import 'lobby_parts.dart';
import 'result_cards.dart';

/// Everything the result report draws, as the screen is given it. The
/// report computes nothing: it only words and draws these values.
///
/// A null [best], [recent] or [coach] leaves its card out; while
/// [comparisonLoading], one placeholder stands where [best] and [recent] go.
class ResultReportData {
  const ResultReportData({
    required this.outcome,
    required this.byKo,
    required this.exercise,
    required this.opponent,
    required this.played,
    required this.myScore,
    required this.opponentScore,
    required this.myValidReps,
    required this.myInvalidReps,
    required this.opponentValidReps,
    required this.endedAt,
    this.departure = BattleDeparture.none,
    this.hasFeedback = false,
    this.comparisonLoading = false,
    this.best,
    this.recent,
    this.coach,
  });

  final MatchOutcome outcome;

  /// Whether a KO ended the battle.
  final bool byKo;

  final ExerciseType exercise;
  final Opponent opponent;

  /// How long the battle ran: the whole round, or up to the KO. Null when it
  /// is not known: an online battle a player left carries the whole round's
  /// length, not when they left.
  final Duration? played;

  /// The two big numbers.
  final int myScore;
  final int opponentScore;

  /// The user's reps that counted and that did not; null [myInvalidReps]
  /// (not known) leaves 무효 out.
  final int myValidReps;
  final int? myInvalidReps;

  /// The opponent's reps that counted: with equal scores at time-up, they
  /// decide the battle.
  final int opponentValidReps;

  /// When the battle ended, for the header.
  final DateTime endedAt;

  /// Whether a player leaving ended an online battle.
  final BattleDeparture departure;

  /// Whether this battle's form feedback can be opened.
  final bool hasFeedback;

  /// Whether the earlier battles that [best] and [recent] compare with are
  /// still loading.
  final bool comparisonLoading;

  /// A personal best this battle set; null when it set none.
  final ResultNewBest? best;

  /// This battle among the latest ones; null without earlier battles. An
  /// empty list of scores leaves the card out too.
  final ResultRecent? recent;

  /// The character card (A10): the way into the talk about this battle;
  /// null without a form report.
  final ResultCoachEntry? coach;
}

/// The result report (BResult): the verdict, both scores and the user's
/// reps, the character card with 자세 기록 표로 보기 under it (A10, as the
/// UxGoal report places it), then the cards the data has, and 홈으로 /
/// 다시 대결 at the bottom. On a short screen or with large text the page
/// scrolls.
class ResultReport extends StatelessWidget {
  const ResultReport({
    super.key,
    required this.data,
    required this.onGoHome,
    required this.onRematch,
    required this.onOpenFeedback,
    this.onHearCoach,
    this.onSkipCoach,
    this.seat,
  });

  final ResultReportData data;

  /// What sits in the victory scene's seat (W5), as [ResultSeatRows] places
  /// it at the right end of the headline's rows; null leaves no seat.
  final Widget? seat;

  /// The back button and 홈으로.
  final VoidCallback onGoHome;

  /// 다시 대결.
  final VoidCallback onRematch;

  /// 자세 기록 표로 보기, shown when [ResultReportData.hasFeedback].
  final VoidCallback onOpenFeedback;

  /// The character card's 이야기 듣기 and 건너뛰기 (to the goal question);
  /// the card shows with [ResultReportData.coach] when both are given.
  final VoidCallback? onHearCoach;
  final VoidCallback? onSkipCoach;

  @override
  Widget build(BuildContext context) {
    final best = data.best;
    final recent = data.recent;
    final coach = data.coach;
    final hear = onHearCoach, skip = onSkipCoach;
    final feedback = data.hasFeedback ? onOpenFeedback : null;
    final seat = this.seat;
    final headline = ResultHeadline(outcome: data.outcome, byKo: data.byKo);
    final subLine = ResultSubLine(
      exercise: data.exercise,
      opponent: data.opponent,
      played: data.played,
      reason: ResultSubLine.reasonOf(data),
    );
    return LobbyPage.fill(
      behind: const ResultBackdrop(),
      above: [
        ResultHeader(endedAt: data.endedAt, onGoHome: onGoHome),
        const SizedBox(height: AppSpacing.s20),
        if (seat == null) ...[
          headline,
          const SizedBox(height: AppSpacing.s8),
          subLine,
          const SizedBox(height: AppSpacing.s12),
        ] else
          ResultSeatRows(
            seat: seat,
            leastWidth: ResultSubLine.leastWidthIn(
              context,
              exercise: data.exercise,
              played: data.played,
            ),
            rows: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                headline,
                const SizedBox(height: AppSpacing.s8),
                subLine,
              ],
            ),
          ),
        ResultScoreRow(
          myScore: data.myScore,
          opponentScore: data.opponentScore,
          validReps: data.myValidReps,
          invalidReps: data.myInvalidReps,
        ),
        if (coach != null && hear != null && skip != null) ...[
          const SizedBox(height: AppSpacing.s16),
          ResultCoachCard(entry: coach, onListen: hear, onSkip: skip),
        ],
        if (feedback != null) ResultFeedbackLink(onPressed: feedback),
        // The link is a tap target tall: the next card sits close under it,
        // as in the design (UxGoal report).
        if (data.comparisonLoading) ...[
          SizedBox(height: feedback != null ? AppSpacing.s4 : AppSpacing.s12),
          const ResultComparisonPlaceholder(),
        ],
        if (best != null) ...[
          SizedBox(height: feedback != null ? AppSpacing.s4 : AppSpacing.s12),
          ResultBestCard(best),
        ],
        if (recent != null && recent.scores.isNotEmpty) ...[
          SizedBox(
            height: feedback != null && best == null
                ? AppSpacing.s4
                : AppSpacing.s12,
          ),
          ResultRecentCard(recent),
        ],
      ],
      fill: const SizedBox.shrink(),
      fillMinHeight: AppSpacing.s16,
      below: [
        ResultButtons(onGoHome: onGoHome, onRematch: onRematch),
        // The frame pads home's 8 below; the report keeps the design's 24.
        const SizedBox(height: AppSpacing.s16),
      ],
    );
  }
}

/// The report's backdrop: one slanted facet, a step lighter than the
/// screen, in the top right.
class ResultBackdrop extends StatelessWidget {
  const ResultBackdrop({super.key});

  @override
  Widget build(BuildContext context) =>
      const Positioned.fill(child: CustomPaint(painter: _FacetPainter()));
}

class _FacetPainter extends CustomPainter {
  const _FacetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // The design's polygon, as shares of the screen's width and height.
    Offset at(double x, double y) => Offset(x * size.width, y * size.height);
    canvas.drawPath(
      Path()..addPolygon([at(0.4, 0), at(1, 0), at(1, 0.26)], true),
      Paint()..color = AppColors.facetLight,
    );
  }

  @override
  bool shouldRepaint(_FacetPainter oldDelegate) => false;
}

/// The back button (home), then "REPORT" over when the battle ended.
class ResultHeader extends StatelessWidget {
  const ResultHeader({
    super.key,
    required this.endedAt,
    required this.onGoHome,
  });

  final DateTime endedAt;
  final VoidCallback onGoHome;

  /// [time] as the header writes it, e.g. "11월 4일 14:30".
  static String dateText(DateTime time) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${time.month}월 ${time.day}일 '
        '${twoDigits(time.hour)}:${twoDigits(time.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        ResultBackButton(onPressed: onGoHome),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LobbyTag('REPORT', color: AppColors.textMuted),
              Text(
                dateText(endedAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.reportLine.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A 44-point white square with a gray edge and a left chevron, named
/// 홈으로. Its tap area reaches 48 points.
class ResultBackButton extends StatelessWidget {
  const ResultBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const size = 44.0;
  static const edge = 1.5;
  static const _iconSize = 22.0;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: '홈으로',
      color: AppColors.ink,
      iconSize: _iconSize,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(size),
        minimumSize: const Size.square(size),
        tapTargetSize: MaterialTapTargetSize.padded,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
          side: BorderSide(color: AppColors.line, width: edge),
        ),
      ),
      icon: const Icon(Icons.chevron_left_rounded),
    );
  }
}

/// The verdict on one line, slanted, over a marker band that leans with it
/// (BResultHeads A): KO 승리 and 승리 on lime, KO 패배 and 패배 on pink,
/// 무승부 on gray. Ink on every band. It follows the system text size and
/// shrinks only when the line would not fit.
class ResultHeadline extends StatelessWidget {
  const ResultHeadline({super.key, required this.outcome, required this.byKo});

  final MatchOutcome outcome;
  final bool byKo;

  /// The words for [outcome]; a KO says so before 승리 or 패배.
  static String wordFor(MatchOutcome outcome, {required bool byKo}) =>
      switch (outcome) {
        MatchOutcome.win => byKo ? 'KO 승리' : '승리',
        MatchOutcome.lose => byKo ? 'KO 패배' : '패배',
        MatchOutcome.draw => '무승부',
      };

  /// The band's color for [outcome].
  static Color bandFor(MatchOutcome outcome) => switch (outcome) {
    MatchOutcome.win => AppColors.accent,
    MatchOutcome.lose => AppColors.opponent,
    MatchOutcome.draw => AppColors.border,
  };

  /// The letters' slant and the band's, as the design's `skewX`.
  static const textLean = 10.0;
  static const bandLean = 14.0;

  /// The band against the words at the design's 46-point size: it starts a
  /// little before them, runs on past them, and covers their lower part.
  static const _bandBefore = 4.0;
  static const _bandAfter = 10.0;
  static const _bandBottom = 3.0;
  static const _bandHeight = 20.0;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.reportHeadline;
    final word = wordFor(outcome, byKo: byKo);
    // The band grows with the letters when the system text is larger.
    final scale =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) /
        style.fontSize!;
    return Semantics(
      header: true,
      label: word,
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Padding(
              // Room for the band past the words, so shrinking keeps it.
              padding: EdgeInsets.only(right: _bandAfter * scale),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -_bandBefore * scale,
                    right: -_bandAfter * scale,
                    bottom: _bandBottom * scale,
                    height: _bandHeight * scale,
                    child: LobbySkew(
                      degrees: bandLean,
                      alignment: Alignment.center,
                      child: ColoredBox(color: bandFor(outcome)),
                    ),
                  ),
                  LobbySkew(
                    degrees: textLean,
                    child: Text(
                      word,
                      maxLines: 1,
                      softWrap: false,
                      style: style.copyWith(color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The headline's [rows] with the victory scene's [seat] (W5) at their
/// right end, as W5 spec 2 and 11.2 place it: a [seatSize] cell whose
/// bottom meets the score row's top (the report's gap under the rows is
/// part of this widget) and whose right end reaches [overhang] into the
/// page's margin, so on a 360 phone it is x 200-344. The cell reaches up
/// beside the header; the rows keep left of it, so a long nickname is cut
/// and a large headline shrinks before they reach it.
///
/// When even the sub line's least width ([leastWidth]) does not fit left
/// of the cell (very large text), the cell gets a row of its own above
/// the rows, at the same right end, and the rows take the whole width.
class ResultSeatRows extends StatelessWidget {
  const ResultSeatRows({
    super.key,
    required this.seat,
    required this.rows,
    required this.leastWidth,
  });

  /// What sits in the cell; it is given the cell's size.
  final Widget seat;

  /// The headline, the sub line and the reason line.
  final Widget rows;

  /// The narrowest the rows may be beside the cell.
  final double leastWidth;

  /// The cell (W5 spec 2; the scene's `VictoryOverlay.seatSize`).
  static const seatWidth = 144.0;
  static const seatHeight = 148.0;
  static const seatSize = Size(seatWidth, seatHeight);

  /// How far the cell reaches past the column's right end: the design's
  /// seat ends at x 344 of a 360 screen with 20-point margins.
  static const overhang = 4.0;

  /// The width the cell takes from the rows.
  static const reserved = seatWidth - overhang;

  /// The report's gap between the rows and the score row.
  static const _gapBelow = AppSpacing.s12;

  @override
  Widget build(BuildContext context) {
    final cell = SizedBox.fromSize(size: seatSize, child: seat);
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth - reserved >= leastWidth) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  right: reserved,
                  bottom: _gapBelow,
                ),
                child: rows,
              ),
              Positioned(right: -overhang, bottom: 0, child: cell),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: seatHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [Positioned(top: 0, right: -overhang, child: cell)],
              ),
            ),
            rows,
            const SizedBox(height: _gapBelow),
          ],
        );
      },
    );
  }
}

/// "푸쉬업 · vs RepBot 고수 · 25초" on one line. A long nickname alone is
/// cut with "…"; the exercise and the seconds stay whole. A [reason] goes
/// on a line of its own below, so the line keeps clear of the right end of
/// the headline's rows (the victory scene's seat, W5).
class ResultSubLine extends StatelessWidget {
  const ResultSubLine({
    super.key,
    required this.exercise,
    required this.opponent,
    required this.played,
    this.reason,
  });

  final ExerciseType exercise;
  final Opponent opponent;

  /// Null leaves the seconds out.
  final Duration? played;

  /// Why the battle went as it did, when the headline and the scores do not
  /// say it; null for no second line.
  final String? reason;

  /// The narrowest the line can be at [context]'s text size: its words but
  /// the name whole, and the "…" a cut name shrinks to.
  static double leastWidthIn(
    BuildContext context, {
    required ExerciseType exercise,
    required Duration? played,
  }) {
    final style = _styleOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    var width = 0.0;
    for (final words in [
      _before(exercise),
      '…',
      if (played != null) _after(played),
    ]) {
      final painter = TextPainter(
        text: TextSpan(text: words, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      width += painter.width;
      painter.dispose();
    }
    return width;
  }

  static TextStyle _styleOf(BuildContext context) =>
      Theme.of(context).textTheme.reportLine
          .copyWith(color: AppColors.textSecondary);

  /// The words before the name, and the seconds after it.
  static String _before(ExerciseType exercise) =>
      '${exercise.koreanName} · vs ';
  static String _after(Duration played) => ' · ${played.inSeconds}초';

  /// A bot as "RepBot" and its level (a bot without one plays as 고수); a
  /// person by their nickname; an arcade stage's bot by the name its record
  /// keeps, "STAGE 8 · 물렁범" (P16 spec 13.3).
  static String opponentText(Opponent opponent) =>
      opponent.isBot && !opponent.isArcade
      ? 'RepBot ${(opponent.difficulty ?? BotDifficulty.expert).label}'
      : opponent.name;

  /// The [reason] for [data], from its values: a player leaving an online
  /// battle, or equal scores at time-up that the valid reps decided. Null
  /// otherwise; a draw (equal scores and reps) needs none.
  static String? reasonOf(ResultReportData data) {
    final repsDecided = !data.byKo && data.myScore == data.opponentScore;
    final repsLead = data.myValidReps.compareTo(data.opponentValidReps);
    return switch ((data.outcome, data.departure)) {
      (MatchOutcome.win, BattleDeparture.opponentLeft) => '상대가 나갔어요',
      (MatchOutcome.lose, BattleDeparture.myConnectionLost) => '연결이 끊겼어요',
      (MatchOutcome.win, BattleDeparture.none)
          when repsDecided && repsLead > 0 =>
        '점수 같음 · 횟수로 승리',
      (MatchOutcome.lose, BattleDeparture.none)
          when repsDecided && repsLead < 0 =>
        '점수 같음 · 횟수로 패배',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final style = _styleOf(context);
    final name = opponentText(opponent);
    final played = this.played;
    final seconds = played == null ? null : '${played.inSeconds}초';
    final reason = this.reason;
    return Semantics(
      label: [
        exercise.koreanName,
        '$name 상대',
        ?seconds,
        ?reason?.replaceAll(' · ', ', '),
      ].join(', '),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(_before(exercise), style: style),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
                if (played != null) Text(_after(played), style: style),
              ],
            ),
            if (reason != null) Text(reason, style: style),
          ],
        ),
      ),
    );
  }
}

/// The user's score big with a lime swatch, ":", the opponent's smaller
/// with a pink swatch, and the user's reps at the far right. When they do
/// not fit one line, the reps go under the scores, and the scores shrink
/// only when even they alone would not fit.
class ResultScoreRow extends StatelessWidget {
  const ResultScoreRow({
    super.key,
    required this.myScore,
    required this.opponentScore,
    required this.validReps,
    required this.invalidReps,
  });

  final int myScore;
  final int opponentScore;
  final int validReps;

  /// Null when not known: the line then names only the counted reps.
  final int? invalidReps;

  /// The reps line, e.g. "인정 12회 · 무효 0회", or "인정 12회".
  static String repsText(int valid, int? invalid) =>
      invalid == null ? '인정 $valid회' : '인정 $valid회 · 무효 $invalid회';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final big = text.reportMyScore.copyWith(color: AppColors.ink);
    Widget swatch(Color color) => DecoratedBox(
      decoration: AppHighlight.swatch(color),
      child: const SizedBox.square(dimension: AppHighlight.swatchSize),
    );
    // The numbers share a baseline; the swatches sit in the middle of the
    // numbers' line, as the design centers them.
    final scores = Semantics(
      label: '내 점수 $myScore점, 상대 점수 $opponentScore점',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              swatch(AppColors.accent),
              const SizedBox(width: AppSpacing.s8),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$myScore', style: big),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    ':',
                    style: text.reportScoreColon.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    '$opponentScore',
                    style: text.reportTheirScore.copyWith(color: AppColors.ink),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.s8),
              swatch(AppColors.opponent),
            ],
          ),
        ),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s4,
      children: [
        scores,
        Text(
          repsText(validReps, invalidReps),
          // Lines as tall as the big score's, so on the scores' line the
          // two share a baseline.
          strutStyle: StrutStyle.fromTextStyle(big, forceStrutHeight: true),
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// 홈으로 and 다시 대결, side by side.
class ResultButtons extends StatelessWidget {
  const ResultButtons({
    super.key,
    required this.onGoHome,
    required this.onRematch,
  });

  final VoidCallback onGoHome;
  final VoidCallback onRematch;

  static const height = 54.0;
  static const _homeEdge = 1.5;
  static const _arrowSize = 18.0;
  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onGoHome,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(height),
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.line, width: _homeEdge),
              shape: _shape,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '홈으로',
                maxLines: 1,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: FilledButton(
            onPressed: onRematch,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(height),
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.onInk,
              shape: _shape,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LobbySkew(
                    degrees: ResultHeadline.textLean,
                    child: Text(
                      '다시 대결',
                      maxLines: 1,
                      style: text.reportButton.copyWith(color: AppColors.onInk),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: _arrowSize,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
