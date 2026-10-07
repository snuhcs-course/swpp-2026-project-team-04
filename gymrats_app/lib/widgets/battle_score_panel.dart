import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reject_reason_korean.dart';
import '../models/rep_event.dart';
import '../theme/app_theme.dart';
import '../viewmodels/battle_viewmodel.dart';
import 'grid_background.dart';

/// The clock and the time bar turn amber once this many seconds are left.
const _warningSeconds = 10;

bool _isLastSeconds(BattleState state) => state.secondsLeft <= _warningSeconds;

/// The battle's bottom panel: the time bar, both scores with the clock
/// between them, the share of reps, and the verdict on the user's latest
/// rep.
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
            padding: EdgeInsets.fromLTRB(16, 22, 16, 22 + bottomInset),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Scoreboard(opponentName: opponentName),
                const _ShareBar(),
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
    final (left, warn) = context.select<BattleViewModel, (double, bool)>(
      (vm) => (
        vm.state.remaining.inMicroseconds /
            vm.counter.roundLength.inMicroseconds,
        _isLastSeconds(vm.state),
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
            child: ColoredBox(
              color: warn ? AppColors.warning : AppColors.accent,
            ),
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
    final (mine, theirs) = context.select<BattleViewModel, (int, int)>(
      (vm) => (vm.state.myReps, vm.state.opponentReps),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _Score(
            label: '나',
            score: mine,
            color: AppColors.accent,
            alignment: CrossAxisAlignment.start,
          ),
        ),
        const Expanded(child: _Clock()),
        Expanded(
          child: _Score(
            label: opponentName,
            score: theirs,
            color: AppColors.opponent,
            alignment: CrossAxisAlignment.end,
          ),
        ),
      ],
    );
  }
}

/// A player's label over their score in big numbers.
class _Score extends StatelessWidget {
  const _Score({
    required this.label,
    required this.score,
    required this.color,
    required this.alignment,
  });

  final String label;
  final int score;
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
        // Two digits fill a column on a narrow phone; shrink rather than
        // overflow.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$score',
            style: text.displayLarge?.copyWith(
              fontSize: 92,
              height: 0.9,
              letterSpacing: -2.8,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Time left over "남은 시간", then who leads by how much.
class _Clock extends StatelessWidget {
  const _Clock();

  @override
  Widget build(BuildContext context) {
    final (seconds, warn, lead) = context
        .select<BattleViewModel, (int, bool, int)>(
          (vm) =>
              (vm.state.secondsLeft, _isLastSeconds(vm.state), vm.state.lead),
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
              color: warn ? AppColors.warning : AppColors.accent,
            ),
          ),
          const SizedBox(height: 4),
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

/// The user's share of all valid reps: lime from the left, pink for the
/// rest. Half and half before anyone scores.
class _ShareBar extends StatelessWidget {
  const _ShareBar();

  @override
  Widget build(BuildContext context) {
    final share = context.select<BattleViewModel, double>((vm) {
      final total = vm.state.myReps + vm.state.opponentReps;
      return total == 0 ? 0.5 : vm.state.myReps / total;
    });
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 10,
        child: ColoredBox(
          color: AppColors.opponent,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: share,
              heightFactor: 1,
              child: const ColoredBox(color: AppColors.accent),
            ),
          ),
        ),
      ),
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
    final (rep, count) = context.select<BattleViewModel, (RepEvent?, int)>(
      (vm) => (vm.state.feedback, vm.state.feedbackCount),
    );
    if (rep == null) return const SizedBox(height: _height);
    final reason = rep.reason;
    return _PopIn(
      key: ValueKey(count),
      child: reason == null
          ? const _GoodBanner()
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

/// "+1 GOOD 좋아요, 그 깊이 그대로!" on a lime tint.
class _GoodBanner extends StatelessWidget {
  const _GoodBanner();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
          const Icon(
            Icons.volume_up_outlined,
            size: 22,
            color: AppColors.accent,
          ),
          const SizedBox(width: 12),
          Text(
            '+1 GOOD',
            style: text.displaySmall?.copyWith(
              fontSize: 20,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              '좋아요, 그 깊이 그대로!',
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
