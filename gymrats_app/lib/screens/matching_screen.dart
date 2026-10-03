import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../services/matching/matchmaker.dart';
import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/matching_viewmodel.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/grid_background.dart';
import '../widgets/player_avatar.dart';

/// Searches for an AI opponent while a radar spins, then moves on to the
/// versus screen.
///
/// Back only asks whether to cancel; the 매칭 취소 button goes home right
/// away. The versus screen replaces this one rather than covering it.
class MatchingScreen extends StatefulWidget {
  const MatchingScreen({
    super.key,
    required this.exercise,
    this.createViewModel,
  });

  final ExerciseType exercise;

  /// Builds the view model; replaces the default one in tests.
  final MatchingViewModel Function()? createViewModel;

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen>
    with SingleTickerProviderStateMixin {
  late final MatchingViewModel _viewModel;

  /// One radar turn per cycle.
  late final AnimationController _radar;
  bool _navigated = false;

  /// True while the cancel dialog is open. A found opponent waits for it:
  /// moving on would replace the dialog, not this screen.
  bool _confirming = false;

  static const _radarPeriod = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.createViewModel?.call() ??
        MatchingViewModel(
          matchmaker: context.read<Matchmaker>(),
          repository: context.read<UserRepository>(),
          exercise: widget.exercise,
        );
    _viewModel.addListener(_onViewModelChanged);
    _radar = AnimationController(vsync: this, duration: _radarPeriod)
      ..repeat();
    _viewModel.start();
  }

  void _onViewModelChanged() {
    // The radar only shows while searching.
    if (_viewModel.state.phase == MatchingPhase.searching) {
      if (!_radar.isAnimating) _radar.repeat();
    } else {
      _radar.stop();
    }
    _openVersusIfFound();
  }

  /// Replaces this screen with the versus screen once an opponent is found.
  void _openVersusIfFound() {
    final matchup = _viewModel.state.matchup;
    if (matchup == null || _navigated || _confirming || !mounted) return;
    _navigated = true;
    Navigator.pushReplacementNamed(
      context,
      GymRatsApp.versusRoute,
      arguments: matchup,
    );
  }

  /// Asks before leaving on a back attempt. 계속하기 keeps searching, or
  /// moves on if an opponent was found meanwhile.
  Future<void> _confirmCancel() async {
    _confirming = true;
    final cancel = await confirmExit(context, const ExitDialog.matching());
    _confirming = false;
    if (!mounted) return;
    if (cancel) {
      _close();
    } else {
      _openVersusIfFound();
    }
  }

  /// Leaves for home. The pop makes PopScope cancel the search.
  void _close() => popToHome(context);

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _radar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ChangeNotifierProvider<MatchingViewModel>.value(
      value: _viewModel,
      // Back only asks. The ways out (매칭 취소, 매칭 취소 in the dialog) pop
      // this route, and the pop stops the search, so a result arriving
      // while this screen slides away cannot replace home.
      child: PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            _viewModel.cancel();
          } else {
            _confirmCancel();
          }
        },
        child: Scaffold(
          body: GridBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  children: [
                    _BattleChip(exercise: widget.exercise),
                    const SizedBox(height: 28),
                    Text(
                      'AI 상대를 찾는 중',
                      textAlign: TextAlign.center,
                      style: text.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: _SearchArea(radar: _radar)),
                    const SizedBox(height: 24),
                    const _GuideCard(),
                    const SizedBox(height: 16),
                    _CancelButton(onPressed: _close),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "● 푸쉬업 · 60초 · 1v1" on a pill.
class _BattleChip extends StatelessWidget {
  const _BattleChip({required this.exercise});

  final ExerciseType exercise;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: AppColors.card,
        shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${exercise.koreanName} · ${battleDuration.inSeconds}초 · 1v1',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The elapsed time over the radar, or a retry message after a failure.
class _SearchArea extends StatelessWidget {
  const _SearchArea({required this.radar});

  final Animation<double> radar;

  @override
  Widget build(BuildContext context) {
    final failed = context.select<MatchingViewModel, bool>(
      (vm) => vm.state.phase == MatchingPhase.failed,
    );
    if (failed) {
      return _SearchFailed(onRetry: context.read<MatchingViewModel>().retry);
    }
    return Column(
      children: [
        const _ElapsedTime(),
        const SizedBox(height: 16),
        Expanded(child: _Radar(animation: radar)),
      ],
    );
  }
}

/// Time since the search started, e.g. "0:08".
class _ElapsedTime extends StatelessWidget {
  const _ElapsedTime();

  @override
  Widget build(BuildContext context) {
    final elapsed = context.select<MatchingViewModel, Duration>(
      (vm) => vm.state.elapsed,
    );
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      '${elapsed.inMinutes}:$seconds',
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
        fontSize: 22,
        color: AppColors.accent,
      ),
    );
  }
}

/// Spinning radar with the user's avatar in the middle.
class _Radar extends StatelessWidget {
  const _Radar({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final name = context.select<MatchingViewModel, String?>(
      (vm) => vm.state.playerName,
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _RadarPainter(animation)),
                  ),
                ),
                PlayerAvatar(
                  color: AppColors.accent,
                  name: name,
                  size: constraints.maxWidth * _RadarPainter.avatarRatio,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rings, a crosshair, a lime sweep turning once per cycle, a pulse
/// spreading out from the avatar, and a few pink blips.
class _RadarPainter extends CustomPainter {
  _RadarPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  /// The avatar's diameter as a fraction of the radar's.
  static const avatarRatio = 0.36;

  /// Ring radii as fractions of the outer one.
  static const _rings = [1.0, 0.72, 0.44];

  /// Angle the sweep's tail trails behind its edge.
  static const _sweepAngle = math.pi / 3;

  /// Decoration only: (distance, angle in degrees, dot radius, opacity),
  /// lengths as fractions of the outer radius.
  static const _blips = [
    (0.76, -45.0, 0.038, 0.8),
    (0.73, 148.0, 0.03, 0.45),
    (0.855, 37.0, 0.024, 0.7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 1;
    final circle = Rect.fromCircle(center: center, radius: radius);
    final t = animation.value;

    final edge = t * 2 * math.pi;
    // The gradient goes all the way round and ends at the bright edge, so
    // its wrap-around seam hides there instead of showing on the tail.
    final sweep = Paint()
      ..shader = SweepGradient(
        colors: [
          AppColors.accent.withValues(alpha: 0),
          AppColors.accent.withValues(alpha: 0),
          AppColors.accent.withValues(alpha: 0.3),
        ],
        stops: const [0, 1 - _sweepAngle / (2 * math.pi), 1],
        transform: GradientRotation(edge),
      ).createShader(circle);
    canvas.drawArc(circle, edge - _sweepAngle, _sweepAngle, true, sweep);

    final line = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final ring in _rings) {
      canvas.drawCircle(center, radius * ring, line);
    }
    canvas
      ..drawLine(circle.centerLeft, circle.centerRight, line)
      ..drawLine(circle.topCenter, circle.bottomCenter, line);

    final from = radius * avatarRatio;
    canvas.drawCircle(
      center,
      from + (radius - from) * t,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.35 * (1 - t))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (final (distance, degrees, dot, opacity) in _blips) {
      canvas.drawCircle(
        center + Offset.fromDirection(degrees * math.pi / 180, radius * distance),
        radius * dot,
        Paint()..color = AppColors.opponent.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.animation != animation;
}

class _SearchFailed extends StatelessWidget {
  const _SearchFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('상대를 찾지 못했어요', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

/// What to do while waiting: set up the phone.
class _GuideCard extends StatelessWidget {
  const _GuideCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox.square(
              dimension: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.cardHigh,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(
                  Icons.smartphone_rounded,
                  size: 22,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // One line; on narrow phones it shrinks a little rather
                  // than leave "요" alone on the next line.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '기다리는 동안 자리를 준비해 두세요',
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '휴대폰을 머리 앞 약 1m 바닥에 세워 화면이 나를 보게 두세요.',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppTheme.cardRadius)),
        ),
        textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      child: const Text('매칭 취소'),
    );
  }
}
