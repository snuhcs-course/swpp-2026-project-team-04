import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/match_record.dart';
import '../models/user_profile.dart';
import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/accent_button.dart';
import '../widgets/grid_background.dart';

/// First screen: greets the user and starts a battle against the AI.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.createViewModel});

  /// Builds the view model; replaces the default one in tests.
  final HomeViewModel Function()? createViewModel;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.createViewModel?.call() ??
        HomeViewModel(repository: context.read<UserRepository>());
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _startMatching() {
    Navigator.pushNamed(
      context,
      GymRatsApp.matchingRoute,
      arguments: ExerciseType.pushUp,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        body: GridBackground(
          child: SafeArea(
            child: Consumer<HomeViewModel>(
              builder: (context, vm, _) => switch (vm.state.phase) {
                HomePhase.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                HomePhase.failed => _LoadFailed(onRetry: vm.load),
                HomePhase.ready => _HomeContent(
                  profile: vm.state.profile!,
                  onStart: _startMatching,
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.profile, required this.onStart});

  final UserProfile profile;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final lastMatch = profile.lastMatch;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        _Greeting(name: profile.name),
        const SizedBox(height: 32),
        _SectionHeader('종목 선택', detail: '${battleDuration.inSeconds}초 · 1v1'),
        const SizedBox(height: 12),
        _ExerciseCard(
          exercise: ExerciseType.pushUp,
          bestReps: profile.bestReps,
        ),
        const SizedBox(height: 20),
        AccentButton(
          title: 'AI와 1v1 대결',
          hint: '${battleDuration.inSeconds}초 안에 더 많이 하면 승리',
          onPressed: onStart,
        ),
        if (lastMatch != null) ...[
          const SizedBox(height: 32),
          const _SectionHeader('최근 경기'),
          const SizedBox(height: 12),
          _RecentMatchRow(match: lastMatch),
        ],
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '안녕하세요, $name님',
          style: text.titleMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        // Line break set by hand: Flutter may break Korean inside a word.
        Text('오늘도 한 판,\n붙어볼까요?', style: text.headlineLarge),
      ],
    );
  }
}

/// Bold title above a card, with an optional gray note at the right end.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final detail = this.detail;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: text.titleMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (detail != null)
          Text(
            detail,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

/// The chosen exercise, drawn as selected: the drawing on the left, and the
/// name and the user's best count centered on the right.
class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise, required this.bestReps});

  final ExerciseType exercise;
  final int? bestReps;

  /// Padding around the content, and the check's distance from the corner.
  static const _inset = 18.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      // Push-up is the only exercise, so it is always the selected one.
      color: AppColors.accent.withValues(alpha: 0.08),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.cardRadius)),
        side: BorderSide(color: AppColors.accent, width: 2),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(_inset),
            child: Row(
              children: [
                CustomPaint(
                  // 1.75 times the 72×40 design.
                  size: const Size(126, 70),
                  painter: switch (exercise) {
                    ExerciseType.pushUp => const _PushUpPainter(),
                  },
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.koreanName,
                        style: text.headlineLarge?.copyWith(fontSize: 36),
                      ),
                      const SizedBox(height: 8),
                      _BestRecord(reps: bestReps),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Positioned(top: _inset, right: _inset, child: _SelectedCheck()),
        ],
      ),
    );
  }
}

/// The user's best count, e.g. "개인 최고 32회", with the number in the
/// number font. Shows "—" before the first battle.
class _BestRecord extends StatelessWidget {
  const _BestRecord({required this.reps});

  final int? reps;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = text.bodyLarge?.copyWith(
      fontSize: 18,
      color: AppColors.textSecondary,
    );
    final reps = this.reps;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: '개인 최고 '),
          TextSpan(
            text: reps == null ? '—' : '$reps',
            style: _inNumberFont(
              text,
              style,
            )?.copyWith(fontSize: 22, color: AppColors.textPrimary),
          ),
          if (reps != null) const TextSpan(text: '회'),
        ],
      ),
    );
  }
}

/// Lime circle with a check, marking the card as selected.
class _SelectedCheck extends StatelessWidget {
  const _SelectedCheck();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check_rounded, size: 16, color: AppColors.background),
      ),
    );
  }
}

/// Push-up line drawing, designed on a 72×40 box and stretched to the
/// canvas. Only the points scale; line widths stay the same.
class _PushUpPainter extends CustomPainter {
  const _PushUpPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 72;
    final sy = size.height / 40;
    Offset at(double x, double y) => Offset(x * sx, y * sy);
    final floor = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    final figure = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(at(4, 36), at(70, 36), floor)
      ..drawCircle(at(10, 15), 4.5 * sx, figure) // head
      ..drawLine(at(16, 18), at(64, 30), figure) // body
      ..drawLine(at(18, 18), at(18, 34), figure) // arm
      ..drawLine(at(64, 30), at(66, 34), figure); // feet
  }

  @override
  bool shouldRepaint(_PushUpPainter oldDelegate) => false;
}

/// The latest battle in one line: result badge, exercise and opponent, score.
class _RecentMatchRow extends StatelessWidget {
  const _RecentMatchRow({required this.match});

  final MatchRecord match;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ConstrainedBox(
        // About 72 tall, as in the design; taller only if the text needs it.
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _ResultBadge(outcome: match.outcome),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${match.exercise.koreanName} · vs ${match.opponentName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: 12),
              _MatchScores(match: match),
            ],
          ),
        ),
      ),
    );
  }
}

/// My score and the opponent's, each with a label underneath. Mine always
/// stands out, whoever won.
class _MatchScores extends StatelessWidget {
  const _MatchScores({required this.match});

  final MatchRecord match;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final number = _inNumberFont(text, text.titleLarge);
    return Row(
      mainAxisSize: MainAxisSize.min,
      // The two numbers share a baseline although their sizes differ.
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${match.myReps}',
              style: number?.copyWith(
                fontSize: 26,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            const _MeTag(),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          // Raised a little so the colon sits between the numbers rather
          // than on their baseline, as in the design.
          child: Transform.translate(
            offset: const Offset(0, -2),
            child: Text(
              ':',
              style: number?.copyWith(fontSize: 20, color: AppColors.textMuted),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${match.opponentReps}',
              style: number?.copyWith(
                fontSize: 22,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '상대',
              style: text.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

/// "나" in dark text on a lime pill, under the user's score.
class _MeTag extends StatelessWidget {
  const _MeTag();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: AppColors.accent,
        shape: StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          '나',
          style: text.labelSmall?.copyWith(color: AppColors.background),
        ),
      ),
    );
  }
}

/// 승, 패 or 무 in the outcome color on a faint tint of it: lime when the
/// user won, pink when the opponent did.
class _ResultBadge extends StatelessWidget {
  const _ResultBadge({required this.outcome});

  final MatchOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final color = switch (outcome) {
      MatchOutcome.win => AppColors.accent,
      MatchOutcome.lose => AppColors.opponent,
      MatchOutcome.draw => AppColors.textSecondary,
    };
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        outcome.label,
        // Black Han Sans, the headline font, at badge size.
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontSize: 18, color: color),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('정보를 불러오지 못했어요', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

/// [style] in the number font, taken from the theme's display styles
/// (Oxanium bold).
TextStyle? _inNumberFont(TextTheme text, TextStyle? style) => style?.copyWith(
  fontFamily: text.displayLarge?.fontFamily,
  fontWeight: text.displayLarge?.fontWeight,
);
