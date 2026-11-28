import 'package:flutter/material.dart';

import '../services/rankings/rankings_repository.dart';
import '../theme/app_theme.dart';
import 'accent_button.dart';
import 'lobby_parts.dart';

/// Opens the points rules over the weekly rankings ('?', A13 design
/// `RankRules`); 확인 closes them.
Future<void> showWeeklyRankingsRules(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      // Taller than the default limit with a large system text size.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (_) => const WeeklyRankingsRulesSheet(),
    );

/// How a week's points are counted: five results with their points, as
/// the server counts them ([RankingPoints]), and four notes.
class WeeklyRankingsRulesSheet extends StatelessWidget {
  const WeeklyRankingsRulesSheet({super.key});

  /// The five results: name, points, what it means ('' for none) and the
  /// points box's fill.
  static List<(String, int, String, Color)> get rules => [
    ('KO승', RankingPoints.koWin, '체력 바를 끝까지 밀어 이긴 경기', AppColors.accent),
    ('승리', RankingPoints.win, '상대가 나가거나 연결이 끊겨도 승리', AppColors.card),
    ('무승부', RankingPoints.draw, '', AppColors.card),
    (
      '패배',
      RankingPoints.loss,
      '끝까지 하면 져도 ${RankingPoints.loss}점',
      AppColors.card,
    ),
    (
      '중간에 나감',
      RankingPoints.leftBattle,
      '내가 나가거나 연결이 끊긴 경기',
      AppColors.cardHigh,
    ),
  ];

  static const notes = [
    '· 친구 대결과 아케이드는 점수에 들어가지 않아요.',
    '· 푸시업과 스쿼트 순위는 따로 매겨요.',
    '· 매주 월요일 0시에 새로 시작해요.',
    '· 점수가 같으면 같은 등수예요.',
  ];

  static const _top = 10.0;
  static const _bottom = AppSpacing.s24;
  static const _handleWidth = 40.0;
  static const _handleHeight = 4.0;
  static const _handleCorner = 2.0;
  static const _handleGap = 14.0;
  static const _leadGap = AppSpacing.s4;
  static const _rulesGap = AppSpacing.s8;
  static const _notesGap = AppSpacing.s12;
  static const _noteGap = 6.0;
  static const _buttonGap = AppSpacing.s16;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          _top,
          AppSpacing.s20,
          _bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: _handleWidth,
                height: _handleHeight,
                decoration: const BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.all(
                    Radius.circular(_handleCorner),
                  ),
                ),
              ),
            ),
            const SizedBox(height: _handleGap),
            Semantics(
              header: true,
              child: Align(
                alignment: Alignment.centerLeft,
                child: LobbySkew(
                  degrees: 8,
                  child: Text('점수 규칙', style: text.rankingSheetTitle),
                ),
              ),
            ),
            const SizedBox(height: _leadGap),
            Text(
              '이번 주 온라인 대결 결과로 점수를 모아요.',
              style: text.rankingLead.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: _rulesGap),
            for (final (name, points, detail, fill) in rules)
              _RuleRow(name: name, points: points, detail: detail, fill: fill),
            const SizedBox(height: _notesGap),
            for (final (index, note) in notes.indexed) ...[
              if (index > 0) const SizedBox(height: _noteGap),
              Text(
                note,
                style: text.rankingRuleNote.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: _buttonGap),
            AccentButton(
              title: '확인',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// One result: its points in a 52 x 34 box, its name and what it means,
/// over a gray line.
class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.name,
    required this.points,
    required this.detail,
    required this.fill,
  });

  final String name;
  final int points;
  final String detail;
  final Color fill;

  static const minHeight = 46.0;
  static const box = Size(52, 34);
  static const _vertical = 6.0;
  static const _gap = AppSpacing.s12;
  static const _boxEdge = 2.0;
  static const _boxCorner = 9.0;
  static const _boxTop = 6.0;
  static const _detailGap = 1.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: [name, '$points점', if (detail.isNotEmpty) detail].join(', '),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.symmetric(vertical: _vertical),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Container(
              width: box.width,
              height: box.height,
              padding: const EdgeInsets.only(top: _boxTop),
              decoration: BoxDecoration(
                color: fill,
                border: Border.all(color: AppColors.ink, width: _boxEdge),
                borderRadius: const BorderRadius.all(
                  Radius.circular(_boxCorner),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$points', style: text.archiveScore),
                    Text('점', style: text.rankingTiny),
                  ],
                ),
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: text.rankingRuleName),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: _detailGap),
                    Text(
                      detail,
                      style: text.rankingRuleDetail.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
