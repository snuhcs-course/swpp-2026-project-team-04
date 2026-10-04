import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/battle_result.dart';
import '../models/match_record.dart';
import '../theme/app_theme.dart';

/// Covers the battle when time is up: the final score, who won, and the way
/// to the result screen.
class TimeUpOverlay extends StatelessWidget {
  const TimeUpOverlay({
    super.key,
    required this.result,
    required this.onShowResult,
  });

  final BattleResult result;

  /// Called by the 결과 보기 button.
  final VoidCallback onShowResult;

  /// The slant of the design's "TIME UP", as a skew.
  static final _slant = Matrix4.skewX(-8 * math.pi / 180);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (verdict, verdictColor) = switch (result.outcome) {
      MatchOutcome.win => ('승리!', AppColors.accent),
      MatchOutcome.lose => ('아쉽게 졌어요', AppColors.opponent),
      MatchOutcome.draw => ('무승부', AppColors.textPrimary),
    };
    final score = text.displayLarge?.copyWith(fontSize: 44, height: 1);
    return ColoredBox(
      color: AppColors.background.withValues(alpha: 0.93),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform(
                transform: _slant,
                alignment: Alignment.center,
                child: Text(
                  'TIME UP',
                  style: text.displayLarge?.copyWith(fontSize: 60, height: 1),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${result.myReps}',
                    style: score?.copyWith(color: AppColors.accent),
                  ),
                  const SizedBox(width: 18),
                  Text(
                    ':',
                    style: score?.copyWith(
                      fontSize: 30,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Text(
                    '${result.opponentReps}',
                    style: score?.copyWith(color: AppColors.opponent),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                verdict,
                style: text.headlineSmall?.copyWith(
                  fontSize: 24,
                  color: verdictColor,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onShowResult,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  textStyle: text.titleSmall?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('결과 보기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
