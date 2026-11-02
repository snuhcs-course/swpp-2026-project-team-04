import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/match_record.dart';
import '../models/matchup.dart';
import '../models/user_profile.dart';
import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/battle_mode_card.dart';
import '../widgets/bot_difficulty_sheet.dart';
import '../widgets/exercise_sheet.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/grid_background.dart';
import '../widgets/match_record_card.dart';
import 'match_feedback_screen.dart';

/// First screen after login: one card for each kind of battle, then the
/// recent battles. A card asks for the exercise, and the bot's also for the
/// level.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.createViewModel,
    this.onLogOut,
    this.onOpenHistory,
  });

  /// Builds the view model; replaces the default one in tests.
  final HomeViewModel Function()? createViewModel;

  /// Logs out after the user confirms. No logout button when null.
  final Future<void> Function()? onLogOut;

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// "전체 기록 ›": switches to the 기록 tab. Opens history as its own page
  /// when null.
  final VoidCallback? onOpenHistory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  late final HomeViewModel _viewModel;

  /// True while a sheet is open: closing it brings nothing new to load.
  bool _inSheet = false;

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
  void didPopNext() {
    if (!_inSheet) _viewModel.load();
  }

  @override
  void dispose() {
    GymRatsApp.routeObserver.unsubscribe(this);
    _viewModel.dispose();
    super.dispose();
  }

  Future<ExerciseType?> _chooseExercise(String mode) => showExerciseSheet(
    context,
    subtitle: '$mode · ${battleDuration.inSeconds}초',
    profile: _viewModel.state.profile!,
  );

  /// Asks for the exercise, then opens the lobby. Closing the sheet stays here.
  Future<void> _startOnline() async {
    _inSheet = true;
    final exercise = await _chooseExercise('온라인 1v1');
    _inSheet = false;
    if (exercise == null || !mounted) return;
    Navigator.pushNamed(
      context,
      GymRatsApp.onlineBattleRoute,
      arguments: exercise,
    );
  }

  /// Asks for the exercise and how hard the bot should play it, then starts
  /// the search. Closing either sheet stays here.
  Future<void> _startBot() async {
    _inSheet = true;
    final exercise = await _chooseExercise('AI 1v1');
    final difficulty = exercise == null || !mounted
        ? null
        : await showBotDifficultySheet(context, exercise: exercise);
    _inSheet = false;
    if (exercise == null || difficulty == null || !mounted) return;
    Navigator.pushNamed(
      context,
      GymRatsApp.matchingRoute,
      arguments: BotMatchRequest(exercise: exercise, difficulty: difficulty),
    );
  }

  /// History may show battles saved since home loaded, so home reloads
  /// when it comes back (didPopNext).
  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  void _openHistory() {
    final openTab = widget.onOpenHistory;
    if (openTab != null) {
      openTab();
    } else {
      Navigator.pushNamed(context, GymRatsApp.historyRoute);
    }
  }

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
                  recent: vm.state.recent,
                  recentIsFallback: vm.state.recentIsFallback,
                  onOnline: _startOnline,
                  onBot: _startBot,
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
    required this.onOnline,
    required this.onBot,
    required this.onOpenHistory,
    this.onLogOut,
    this.recent = const [],
    this.recentIsFallback = false,
  });

  final UserProfile profile;
  final VoidCallback onOnline;
  final VoidCallback onBot;
  final VoidCallback onOpenHistory;
  final VoidCallback? onLogOut;

  /// The newest battles, each with its feedback line; empty before the
  /// first battle.
  final List<MatchRecord> recent;

  /// [recent] is the profile's latest battle only, without feedback.
  final bool recentIsFallback;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        _Greeting(name: profile.name, onLogOut: onLogOut),
        const SizedBox(height: AppSpacing.s24),
        _SectionHeader(
          '대결 모드',
          detail: '${battleDuration.inSeconds}초 · 점수 높은 쪽 승리',
        ),
        const SizedBox(height: AppSpacing.s8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: BattleModeCard(
                  title: '온라인 1v1',
                  line: '사람과 실시간 대결',
                  picture: const BattleModePicture.online(),
                  main: true,
                  onTap: onOnline,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: BattleModeCard(
                  title: 'AI 1v1',
                  line: '봇과 난이도별 대결',
                  picture: const BattleModePicture.bot(),
                  onTap: onBot,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        _SectionHeader('최근 경기', detail: '전체 기록', onDetail: onOpenHistory),
        const SizedBox(height: AppSpacing.s8),
        // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
        if (recent.isEmpty) _NoMatchYet(onTap: onOpenHistory),
        for (final (index, match) in recent.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.s12),
          MatchRecordCard(
            match: match,
            showDate: true,
            showFeedback: !recentIsFallback,
            onTap: feedbackTap(context, match),
          ),
        ],
        if (profile.unsentMatches > 0) ...[
          const SizedBox(height: AppSpacing.s8),
          _UnsentNote(count: profile.unsentMatches),
        ],
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
                  Navigator.pushNamed(context, GymRatsApp.helpRoute),
              tooltip: '게임 규칙',
              color: AppColors.textSecondary,
              icon: const Icon(Icons.help_outline_rounded),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
        if (detail != null && onDetail != null)
          TextButton(
            onPressed: onDetail,
            child: Text(
              '$detail ›',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          )
        else if (detail != null)
          // With a large system text size it ends in "…" rather than overflow.
          Flexible(
            child: Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
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
