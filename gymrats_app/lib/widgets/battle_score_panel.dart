import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_score.dart';
import '../models/reject_reason_korean.dart';
import '../models/rep_event.dart';
import '../theme/app_theme.dart';
import '../viewmodels/battle_viewmodel.dart';
import 'game_fever_chip.dart';
import 'game_health_bar.dart';
import 'grid_background.dart';

/// The clock and the time bar turn amber once this many seconds are left.
const _warningSeconds = 5;

bool _isLastSeconds(BattleState state) => state.secondsLeft <= _warningSeconds;

/// The clock's and the time bar's color: amber at the very end, cyan in
/// fever, and lime before that.
Color _timeColor(BattleState state) {
  if (_isLastSeconds(state)) return AppColors.warning;
  return state.fever ? AppColors.fever : AppColors.accent;
}

/// The battle's bottom panel: the time bar, both game scores with the clock
/// between them, the health bar, and the verdict on the user's latest rep.
///
/// It reads the battle from the [BattleViewModel] provided above it. Each
/// part watches only its own values; the time left changes every frame.
class BattleScorePanel extends StatelessWidget {
  const BattleScorePanel({super.key, required this.opponentName});

  final String opponentName;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return GridBackground(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Scoreboard(opponentName: opponentName),
                const _HealthBar(),
                const _FeedbackBanner(),
              ],
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: _TimeBar()),
        ],
      ),
    );
  }
}

/// Time left as a 4 px bar along the panel's top edge.
class _TimeBar extends StatelessWidget {
  const _TimeBar();

  @override
  Widget build(BuildContext context) {
    final (left, color) = context.select<BattleViewModel, (double, Color)>(
      (vm) => (
        vm.state.remaining.inMicroseconds /
            vm.counter.roundLength.inMicroseconds,
        _timeColor(vm.state),
      ),
    );
    return SizedBox(
      height: 4,
      child: ColoredBox(
        color: AppColors.border,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: left.clamp(0.0, 1.0),
            heightFactor: 1,
            child: ColoredBox(color: color),
          ),
        ),
      ),
    );
  }
}

/// My score, the clock, and the opponent's score, along one bottom line.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.opponentName});

  final String opponentName;

  @override
  Widget build(BuildContext context) {
    final (mine, theirs, myReps, theirReps) = context
        .select<BattleViewModel, (int, int, int, int)>(
          (vm) => (
            vm.state.myScore,
            vm.state.opponentScore,
            vm.state.myReps,
            vm.state.opponentReps,
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _Score(
            label: '나',
            score: mine,
            reps: myReps,
            color: AppColors.accent,
            alignment: CrossAxisAlignment.start,
          ),
        ),
        const Expanded(child: _Clock()),
        Expanded(
          child: _Score(
            label: opponentName,
            score: theirs,
            reps: theirReps,
            color: AppColors.opponent,
            alignment: CrossAxisAlignment.end,
          ),
        ),
      ],
    );
  }
}

/// A player's label over their game score in big numbers, over their valid
/// reps.
class _Score extends StatelessWidget {
  const _Score({
    required this.label,
    required this.score,
    required this.reps,
    required this.color,
    required this.alignment,
  });

  final String label;
  final int score;
  final int reps;
  final Color color;

  /// Which side of the panel the score stands on.
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        // Three digits about fill a column on a narrow phone; shrink rather
        // than overflow.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$score',
            style: text.displayLarge?.copyWith(
              fontSize: 64,
              height: 0.95,
              letterSpacing: -2,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          '유효 $reps회',
          maxLines: 1,
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Time left over "남은 시간" or, in fever, the fever chip; then who leads by
/// how much.
class _Clock extends StatelessWidget {
  const _Clock();

  @override
  Widget build(BuildContext context) {
    final (seconds, color, lead, fever) = context
        .select<BattleViewModel, (int, Color, int, bool)>(
          (vm) => (
            vm.state.secondsLeft,
            _timeColor(vm.state),
            vm.state.lead,
            vm.state.fever,
          ),
        );
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        children: [
          Text(
            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
            style: text.displaySmall?.copyWith(
              fontSize: 34,
              height: 1,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          if (fever)
            GameFeverChip(
              multiplier: context.read<BattleViewModel>().rules.feverMultiplier,
            )
          else
            Text(
              '남은 시간',
              style: text.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 8),
          _LeadPill(lead: lead),
        ],
      ),
    );
  }
}

/// "+2 리드" in lime, "−1 추격 중" in pink, or "동점", on an outlined pill.
class _LeadPill extends StatelessWidget {
  const _LeadPill({required this.lead});

  final int lead;

  @override
  Widget build(BuildContext context) {
    final (words, color) = switch (lead) {
      > 0 => ('+$lead 리드', AppColors.accent),
      < 0 => ('−${-lead} 추격 중', AppColors.opponent),
      _ => ('동점', AppColors.textPrimary),
    };
    return DecoratedBox(
      decoration: const ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          words,
          maxLines: 1,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFamily: AppFonts.number,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// The health bar, from the game.
class _HealthBar extends StatelessWidget {
  const _HealthBar();

  @override
  Widget build(BuildContext context) {
    final (share, mine, theirs) = context
        .select<BattleViewModel, (double, GameRepScore?, GameRepScore?)>(
          (vm) => (
            vm.state.myBarShare,
            vm.state.myLastScore,
            vm.state.opponentLastScore,
          ),
        );
    return GameHealthBar(
      myShare: share,
      myLastScore: mine,
      opponentLastScore: theirs,
    );
  }
}

/// The verdict on the user's latest rep, which stays until the next one.
/// Each verdict pops in; before the first, the space stays empty.
class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner();

  static const _height = 60.0;

  @override
  Widget build(BuildContext context) {
    final (rep, count, score) = context
        .select<BattleViewModel, (RepEvent?, int, GameRepScore?)>(
          (vm) =>
              (vm.state.feedback, vm.state.feedbackCount, vm.state.myLastScore),
        );
    if (rep == null) return const SizedBox(height: _height);
    final reason = rep.reason;
    if (reason == null && score == null) {
      return const SizedBox(height: _height);
    }
    return _PopIn(
      key: ValueKey(count),
      child: reason == null
          ? _GoodBanner(score: score!)
          : _RejectedBanner(reason: reason),
    );
  }
}

/// Rises a little and grows to full size as it fades in, like the design's
/// banners.
class _PopIn extends StatelessWidget {
  const _PopIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - t)),
          child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
        ),
      ),
    );
  }
}

/// "+15 EXCELLENT 깊게 잘 내려갔어요!" or "+40 EXCELLENT 콤보 2 · 점수 2배" on a
/// lime tint.
class _GoodBanner extends StatelessWidget {
  const _GoodBanner({required this.score});

  final GameRepScore score;

  /// The combo and fever when there are any, else a word on the depth.
  String _words(int feverMultiplier) {
    final extras = [
      if (score.combo > 1) '콤보 ${score.combo}',
      if (score.fever) '점수 $feverMultiplier배',
    ];
    if (extras.isNotEmpty) return extras.join(' · ');
    return switch (score.grade) {
      GameGrade.good => '좋아요, 그 깊이 그대로!',
      GameGrade.excellent => '깊게 잘 내려갔어요!',
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final feverMultiplier = context
        .read<BattleViewModel>()
        .rules
        .feverMultiplier;
    return Container(
      constraints: const BoxConstraints(minHeight: _FeedbackBanner._height),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Text(
            '+${score.points} ${score.grade.label.toUpperCase()}',
            style: text.displaySmall?.copyWith(
              fontSize: 20,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              _words(feverMultiplier),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "카운트 안 됨" and what to fix, in dark letters on amber.
class _RejectedBanner extends StatelessWidget {
  const _RejectedBanner({required this.reason});

  final RejectReason reason;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: _FeedbackBanner._height),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: AppColors.background,
          ),
          const SizedBox(width: 12),
          Text(
            '카운트 안 됨',
            style: text.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.background,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              reason.koreanMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.background,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
