import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/bot_difficulty.dart';
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
    this.difficulty = BotDifficulty.expert,
    this.createViewModel,
  });

  final ExerciseType exercise;

  /// How hard the bot will play, as chosen before the search.
  final BotDifficulty difficulty;

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
  bool _openedVersus = false;

  /// True while the cancel dialog is open. A found opponent waits for it:
  /// moving on would replace the dialog, not this screen.
  bool _askingToLeave = false;

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
          difficulty: widget.difficulty,
        );
    _viewModel.addListener(_onViewModelChanged);
    _radar = AnimationController(vsync: this, duration: _radarPeriod)..repeat();
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
    if (matchup == null || _openedVersus || _askingToLeave || !mounted) return;
    _openedVersus = true;
    Navigator.pushReplacementNamed(
      context,
      GymRatsApp.versusRoute,
      arguments: matchup,
    );
  }

  /// Asks before leaving on a back attempt. 계속하기 keeps searching, or
  /// moves on if an opponent was found meanwhile.
  Future<void> _askToLeave() async {
    _askingToLeave = true;
    final leave = await confirmExit(context, const ExitDialog.matching());
    _askingToLeave = false;
    if (!mounted) return;
    if (leave) {
      _leave();
    } else {
      _openVersusIfFound();
    }
  }

  /// Goes home. The search stops first, so a result arriving while this
  /// screen slides away cannot replace home.
  void _leave() {
    _viewModel.cancel();
    popToHome(context);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _radar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MatchingViewModel>.value(
      value: _viewModel,
      child: PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _askToLeave();
        },
        child: Scaffold(
          body: GridBackground(
            child: SafeArea(
              child: BattleSearchView(
                exercise: widget.exercise,
                title: '${widget.difficulty.label} AI 상대를 찾는 중',
                searchArea: _SearchArea(radar: _radar),
                onCancel: _leave,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared pre-match presentation; AI and live matching keep separate logic.
class BattleSearchView extends StatelessWidget {
  const BattleSearchView({
    super.key,
    required this.exercise,
    required this.title,
    required this.searchArea,
    required this.onCancel,
    this.duration = battleDuration,
  });

  final ExerciseType exercise;
  final String title;
  final Widget searchArea;
  final VoidCallback onCancel;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          _BattleChip(exercise: exercise, duration: duration),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Expanded(child: searchArea),
          const SizedBox(height: 24),
          _GuideCard(exercise: exercise),
          const SizedBox(height: 16),
          _CancelButton(onPressed: onCancel),
        ],
      ),
    );
  }
}

/// "● 푸쉬업 · 30초 · 1v1" on a pill.
class _BattleChip extends StatelessWidget {
  const _BattleChip({required this.exercise, required this.duration});

  final ExerciseType exercise;
  final Duration duration;

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
              dimension: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: AppColors.ink, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${exercise.koreanName} · ${duration.inSeconds}초 · 1v1',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
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
    final state = context.watch<MatchingViewModel>().state;
    return BattleSearchRadar(
      animation: radar,
      elapsed: state.elapsed,
      playerName: state.playerName,
    );
  }
}

/// The same elapsed timer and animated radar for either matching service.
class BattleSearchRadar extends StatelessWidget {
  const BattleSearchRadar({
    super.key,
    required this.animation,
    required this.elapsed,
    required this.playerName,
  });
  final Animation<double> animation;
  final Duration elapsed;
  final String? playerName;

  @override
  Widget build(BuildContext context) {
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Column(
      children: [
        Text(
          '${elapsed.inMinutes}:$seconds',
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontSize: 22, color: AppColors.ink),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _Radar(animation: animation, name: playerName),
        ),
      ],
    );
  }
}

/// Spinning radar with the user's avatar in the middle.
class _Radar extends StatelessWidget {
  const _Radar({required this.animation, required this.name});

  final Animation<double> animation;
  final String? name;

  @override
  Widget build(BuildContext context) {
    // With the system's "reduce motion" on, the sweep holds still, as the
    // design's CSS does.
    final sweep = MediaQuery.disableAnimationsOf(context)
        ? const AlwaysStoppedAnimation<double>(0)
        : animation;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AspectRatio(
          aspectRatio: 1,
          // One picture to a screen reader, named as in the design.
          child: Semantics(
            container: true,
            image: true,
            label: '상대를 찾는 레이더',
            child: ExcludeSemantics(
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(painter: _RadarPainter(sweep)),
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
        ),
      ),
    );
  }
}

/// The radar of the design (BMatching), drawn in its 288 x 288 points and
/// sized to the box: a white disc with an ink edge, a lime sweep of six
/// wedges that grow stronger toward its ink edge and turn once per cycle,
/// two gray rings, a dashed gray crosshair, and three pink blips with ink
/// edges. The avatar in the middle is a widget over it.
class _RadarPainter extends CustomPainter {
  _RadarPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  /// The avatar's diameter as a fraction of the radar's.
  static const avatarRatio = 0.36;

  /// The design's box.
  static const _view = 288.0;
  static const _center = Offset(144, 144);
  static const _discRadius = 142.0;
  static const _discEdge = 2.0;

  /// The sweep: six wedges of ten degrees, from 30 to 90 degrees (pointing
  /// down) before it turns, out to [_sweepRadius], lime at these opacities
  /// toward the leading edge, which is an ink line.
  static const _sweepRadius = 143.0;
  static const _wedgeOpacities = [0.12, 0.24, 0.36, 0.5, 0.66, 0.85];
  static const _sweepEdgeLength = 142.0;
  static const _sweepEdgeWidth = 2.0;

  static const _rings = [103.0, 62.9];
  static const _ringWidth = 1.25;
  static const _crossWidth = 1.0;
  static const _dash = 4.0;

  /// Decoration only: (x, y, radius, fill opacity) in the design's box.
  static const _blips = [
    (220.8, 67.2, 6.0, 1.0),
    (55.5, 199.3, 4.6, 0.55),
    (241.6, 217.6, 3.8, 1.0),
  ];
  static const _blipEdge = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / _view, size.height / _view);

    canvas
      ..drawCircle(_center, _discRadius, Paint()..color = AppColors.card)
      ..drawCircle(
        _center,
        _discRadius,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = _discEdge,
      );

    // The sweep turns clockwise, one turn per cycle, over the disc's edge
    // as the design draws it.
    canvas
      ..save()
      ..translate(_center.dx, _center.dy)
      ..rotate(animation.value * 2 * math.pi);
    final sweepBox = Rect.fromCircle(center: Offset.zero, radius: _sweepRadius);
    const wedge = math.pi / 18;
    for (var i = 0; i < _wedgeOpacities.length; i++) {
      canvas.drawArc(
        sweepBox,
        math.pi / 6 + i * wedge,
        wedge,
        true,
        Paint()..color = AppColors.accent.withValues(alpha: _wedgeOpacities[i]),
      );
    }
    canvas
      ..drawLine(
        Offset.zero,
        const Offset(0, _sweepEdgeLength),
        Paint()
          ..color = AppColors.ink
          ..strokeWidth = _sweepEdgeWidth
          ..strokeCap = StrokeCap.round,
      )
      ..restore();

    final ring = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringWidth;
    for (final radius in _rings) {
      canvas.drawCircle(_center, radius, ring);
    }

    final cross = Paint()
      ..color = AppColors.line
      ..strokeWidth = _crossWidth;
    for (var at = 2.0; at < 286; at += 2 * _dash) {
      final to = math.min(at + _dash, 286.0);
      canvas
        ..drawLine(Offset(at, 144), Offset(to, 144), cross)
        ..drawLine(Offset(144, at), Offset(144, to), cross);
    }

    for (final (x, y, radius, opacity) in _blips) {
      final at = Offset(x, y);
      canvas
        ..drawCircle(
          at,
          radius,
          Paint()..color = AppColors.opponent.withValues(alpha: opacity),
        )
        ..drawCircle(
          at,
          radius,
          Paint()
            ..color = AppColors.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = _blipEdge,
        );
    }
    canvas.restore();
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

/// What to do while waiting: set up the phone for [exercise].
class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.exercise});

  final ExerciseType exercise;

  /// The lime box behind the phone icon (palette B: the color fills).
  static final _iconFill = AppColors.accent.withValues(alpha: 0.55);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _iconFill,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: const Icon(
                  Icons.smartphone_rounded,
                  size: 22,
                  color: AppColors.ink,
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
                    // Line breaks set by hand: Flutter may break Korean
                    // inside a word ("화 / 면" on a 360-wide phone).
                    switch (exercise) {
                      ExerciseType.pushUp =>
                        '휴대폰을 머리 앞 약 1m 바닥에 세워\n'
                            '화면이 나를 보게 두세요.',
                      // squat-judge-design.md section 3, the placement.
                      ExerciseType.squat =>
                        '휴대폰을 세로로 세워 내 앞 2~3m에\n'
                            '두세요. 의자나 선반 위면 더 좋아요.\n'
                            '머리부터 발목까지\n'
                            '화면에 들어와야 해요.',
                    },
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
        side: const BorderSide(color: AppColors.line, width: 1.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppTheme.cardRadius)),
        ),
        textStyle: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      child: const Text('매칭 취소'),
    );
  }
}
