import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/user_profile.dart';
import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/accent_button.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/grid_background.dart';
import '../widgets/match_record_card.dart';

/// First screen after login: online is primary; AI practice stays below history.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.createViewModel, this.onLogOut});

  /// Builds the view model; replaces the default one in tests.
  final HomeViewModel Function()? createViewModel;

  /// Logs out after the user confirms. No logout button when null.
  final Future<void> Function()? onLogOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    GymRatsApp.routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  /// Home shows again after a battle or a cancelled match: the latest
  /// battle and the best record may have changed.
  @override
  void didPopNext() => _viewModel.load();

  @override
  void dispose() {
    GymRatsApp.routeObserver.unsubscribe(this);
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

  /// History may show battles saved since home loaded, so home reloads
  /// when it comes back (didPopNext).
  void _openHistory() => Navigator.pushNamed(context, GymRatsApp.historyRoute);

  Future<void> _confirmLogOut() async {
    final logOut = widget.onLogOut;
    if (logOut == null) return;
    final confirmed = await confirmExit(
      context,
      const ExitDialog(
        title: '로그아웃할까요?',
        message: '다시 들어오려면\n아이디와 비밀번호가 필요해요.',
        leaveLabel: '로그아웃',
      ),
    );
    if (confirmed) await logOut();
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
                HomePhase.failed => _LoadFailed(
                  message: vm.state.errorMessage,
                  onRetry: vm.load,
                ),
                HomePhase.ready => _HomeContent(
                  profile: vm.state.profile!,
                  onStart: _startMatching,
                  onOpenHistory: _openHistory,
                  onLogOut: widget.onLogOut == null ? null : _confirmLogOut,
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
  const _HomeContent({
    required this.profile,
    required this.onStart,
    required this.onOpenHistory,
    this.onLogOut,
  });

  final UserProfile profile;
  final VoidCallback onStart;
  final VoidCallback onOpenHistory;
  final VoidCallback? onLogOut;

  @override
  Widget build(BuildContext context) {
    final lastMatch = profile.lastMatch;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        _Greeting(name: profile.name, onLogOut: onLogOut),
        const SizedBox(height: 32),
        _SectionHeader('종목 선택', detail: '${battleDuration.inSeconds}초 · 1v1'),
        const SizedBox(height: 12),
        _ExerciseCard(
          exercise: ExerciseType.pushUp,
          bestReps: profile.bestReps,
        ),
        const SizedBox(height: 20),
        AccentButton(
          title: '온라인 1v1 대결',
          hint: '${battleDuration.inSeconds}초 안에 더 많이 하면 승리',
          onPressed: () =>
              Navigator.pushNamed(context, GymRatsApp.onlineBattleRoute),
        ),
        const SizedBox(height: AppSpacing.s32),
        _SectionHeader('최근 경기', detail: '전체 기록', onDetail: onOpenHistory),
        const SizedBox(height: AppSpacing.s12),
        if (lastMatch != null)
          MatchRecordCard(match: lastMatch, onTap: onOpenHistory)
        else
          _NoMatchYet(onTap: onOpenHistory),
        if (profile.unsentMatches > 0) ...[
          const SizedBox(height: AppSpacing.s8),
          _UnsentNote(count: profile.unsentMatches),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.smart_toy_rounded),
          label: const Text('AI와 1v1 대결'),
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, this.onLogOut});

  final String name;
  final VoidCallback? onLogOut;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final onLogOut = this.onLogOut;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '안녕하세요, $name님',
                style: text.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            IconButton(
              onPressed: () =>
                  Navigator.pushNamed(context, GymRatsApp.profileRoute),
              tooltip: '프로필',
              color: AppColors.textSecondary,
              icon: const Icon(Icons.account_circle_outlined),
            ),
            if (onLogOut != null)
              IconButton(
                onPressed: onLogOut,
                tooltip: '로그아웃',
                color: AppColors.textSecondary,
                icon: const Icon(Icons.logout_rounded),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Line break set by hand: Flutter may break Korean inside a word.
        Text('오늘도 한 판,\n붙어볼까요?', style: text.headlineLarge),
      ],
    );
  }
}

/// Bold title above a card, with an optional gray note at the right end.
/// The note is a link when [onDetail] is set.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.detail, this.onDetail});

  final String title;
  final String? detail;
  final VoidCallback? onDetail;

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
        if (detail != null && onDetail != null)
          TextButton(
            onPressed: onDetail,
            child: Text(
              '$detail ›',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          )
        else if (detail != null)
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

/// The "최근 경기" card before the first battle.
class _NoMatchYet extends StatelessWidget {
  const _NoMatchYet({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Text(
            '아직 경기 기록이 없어요. 첫 대결을 시작해 보세요!',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// Battles that are not on the server yet, in amber: they are retried on
/// the next load, so the user knows the record is not lost.
class _UnsentNote extends StatelessWidget {
  const _UnsentNote({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.cloud_off_rounded, color: AppColors.warning),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            '저장하지 못한 경기 $count개 · 연결되면 다시 저장해요',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.warning),
          ),
        ),
      ],
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  /// Why loading failed; null for no extra line.
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('정보를 불러오지 못했어요', style: Theme.of(context).textTheme.titleMedium),
          if (message case final message?) ...[
            const SizedBox(height: AppSpacing.s8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
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
