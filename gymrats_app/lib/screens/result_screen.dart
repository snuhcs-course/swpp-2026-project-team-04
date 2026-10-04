import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/battle_result.dart';
import '../models/exercise_type_korean.dart';
import '../models/match_record.dart';
import '../theme/app_theme.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/grid_background.dart';

/// How a battle ended: who won and by how much, both scores, and the user's
/// counted and rejected reps.
///
/// Like the versus screen it has no view model: everything it shows comes
/// from [result], and its only behavior is navigation. The battle was saved
/// before this screen opened. 홈으로 and back go home; 다시 매칭 replaces
/// this screen with a new search.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.result});

  final BattleResult result;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  /// Set once a button is pressed, so a second tap does nothing.
  bool _leaving = false;

  /// Both buttons go through here, so only the first one pressed acts:
  /// after 홈으로, 다시 매칭 does nothing either.
  void _leaveOnce(VoidCallback navigate) {
    if (_leaving) return;
    _leaving = true;
    navigate();
  }

  void _goHome() => _leaveOnce(() => popToHome(context));

  void _matchAgain() => _leaveOnce(() {
    Navigator.pushReplacementNamed(
      context,
      GymRatsApp.matchingRoute,
      arguments: widget.result.matchup.exercise,
    );
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: _ResultContent(
            result: widget.result,
            onGoHome: _goHome,
            onMatchAgain: _matchAgain,
          ),
        ),
      ),
    );
  }
}

/// Everything on the screen, top to bottom. Scrolls on a short phone; on a
/// tall one the buttons sit at the bottom.
class _ResultContent extends StatelessWidget {
  const _ResultContent({
    required this.result,
    required this.onGoHome,
    required this.onMatchAgain,
  });

  final BattleResult result;
  final VoidCallback onGoHome;
  final VoidCallback onMatchAgain;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          // Padding inside the sliver, not a SliverPadding around it: the
          // sliver fills what is left of the screen, so padding after it
          // would fall below the screen.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(result: result),
                const SizedBox(height: 18),
                _Verdict(result: result),
                const SizedBox(height: 18),
                _ScoreCard(result: result),
                const SizedBox(height: 18),
                _MyStats(result: result),
                const Spacer(),
                const SizedBox(height: 18),
                _Buttons(onGoHome: onGoHome, onMatchAgain: onMatchAgain),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "RESULT" on the left; the exercise, the round length, and when it ended
/// on the right.
class _Header extends StatelessWidget {
  const _Header({required this.result});

  final BattleResult result;

  /// [time] as hours and minutes, e.g. "14:32".
  static String _clockTime(DateTime time) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(time.hour)}:${twoDigits(time.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontSize: 13, color: AppColors.textSecondary);
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Text(
            'RESULT',
            style: labelStyle?.copyWith(
              fontFamily: AppFonts.number,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.6,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${result.matchup.exercise.koreanName} · '
              '${result.roundLength.inSeconds}초 · '
              '오늘 ${_clockTime(result.endedAt)}',
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// WIN, LOSE, or DRAW, slanted and glowing, over how it went.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.result});

  final BattleResult result;

  /// The slant of the design's verdict, as a skew.
  static final _slant = Matrix4.skewX(-8 * math.pi / 180);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (word, color, message) = switch (result.outcome) {
      MatchOutcome.win => (
        'WIN',
        AppColors.accent,
        '${result.margin}개 차이로 이겼어요!',
      ),
      MatchOutcome.lose => (
        'LOSE',
        AppColors.opponent,
        '${result.margin}개 차이로 졌어요',
      ),
      MatchOutcome.draw => ('DRAW', AppColors.textPrimary, '비겼어요!'),
    };
    return Column(
      children: [
        Transform(
          transform: _slant,
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              word,
              style: text.displayLarge?.copyWith(
                fontSize: 108,
                height: 1,
                letterSpacing: 2.2,
                color: color,
                shadows: [
                  Shadow(color: color.withValues(alpha: 0.35), blurRadius: 40),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontSize: 22),
        ),
      ],
    );
  }
}

/// Both players with their scores: the user on the left in lime, the
/// opponent on the right in pink.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.result});

  final BattleResult result;

  /// The design's dark pink behind the opponent's icon.
  static final _opponentFill = Color.alphaBlend(
    AppColors.opponent.withValues(alpha: 0.13),
    AppColors.background,
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final playerName = result.matchup.playerName;
    final opponent = result.matchup.opponent;
    final myAvatar = _Avatar(
      color: AppColors.accent,
      fill: AppColors.cardHigh,
      child: playerName.isEmpty
          ? const Icon(Icons.person_rounded, size: 22)
          : Text(
              playerName.characters.first,
              style: text.headlineSmall?.copyWith(fontSize: 16),
            ),
    );
    final opponentAvatar = _Avatar(
      color: AppColors.opponent,
      fill: _opponentFill,
      child: Icon(
        opponent.isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
        size: 22,
        color: AppColors.opponent,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Score(
              name: playerName,
              score: result.myReps,
              color: AppColors.accent,
              avatar: myAvatar,
            ),
          ),
          Text(
            ':',
            style: text.displayLarge?.copyWith(
              fontSize: 32,
              color: AppColors.textMuted,
            ),
          ),
          Expanded(
            child: _Score(
              name: opponent.name,
              score: result.opponentReps,
              color: AppColors.opponent,
              avatar: opponentAvatar,
            ),
          ),
        ],
      ),
    );
  }
}

/// One side of the score card: the avatar over the name and the score.
class _Score extends StatelessWidget {
  const _Score({
    required this.name,
    required this.score,
    required this.color,
    required this.avatar,
  });

  final String name;
  final int score;
  final Color color;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        avatar,
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$score',
          style: text.displayLarge?.copyWith(
            fontSize: 48,
            height: 1,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// A 40 px circle with a colored ring around [child].
class _Avatar extends StatelessWidget {
  const _Avatar({required this.color, required this.fill, required this.child});

  final Color color;
  final Color fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: color, width: 2),
      ),
      child: child,
    );
  }
}

/// The user's counted reps, rejected reps, and accuracy, side by side.
class _MyStats extends StatelessWidget {
  const _MyStats({required this.result});

  final BattleResult result;

  @override
  Widget build(BuildContext context) {
    final accuracy = result.accuracy;
    return Row(
      children: [
        Expanded(
          child: _StatCard(label: '인정', value: result.myReps, unit: '회'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: '무효',
            value: result.myInvalidReps,
            unit: '회',
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: '정확도',
            value: accuracy == null ? null : (accuracy * 100).round(),
            unit: '%',
          ),
        ),
      ],
    );
  }
}

/// A small card: a gray label over a number and its unit.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    this.color = AppColors.textPrimary,
  });

  final String label;

  /// Null shows "—" without [unit]: accuracy has nothing to measure before
  /// a judged rep.
  final int? value;

  /// After the number in small gray letters, e.g. "회".
  final String unit;

  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final value = this.value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: value == null ? '—' : '$value',
              style: text.displaySmall?.copyWith(fontSize: 24, color: color),
              children: [
                if (value != null)
                  TextSpan(
                    text: unit,
                    style: text.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 홈으로 and 다시 매칭, side by side.
class _Buttons extends StatelessWidget {
  const _Buttons({required this.onGoHome, required this.onMatchAgain});

  final VoidCallback onGoHome;
  final VoidCallback onMatchAgain;

  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onGoHome,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border, width: 1.5),
              shape: _shape,
              textStyle: labelStyle,
            ),
            child: const Text('홈으로'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: onMatchAgain,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: _shape,
              textStyle: labelStyle,
            ),
            child: const Text('다시 매칭'),
          ),
        ),
      ],
    );
  }
}
