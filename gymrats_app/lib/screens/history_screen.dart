import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/history_viewmodel.dart';
import '../widgets/archive_cards.dart';
import '../widgets/archive_match_row.dart';
import '../widgets/auth_form.dart';
import '../widgets/lobby_parts.dart';
import 'match_feedback_screen.dart';

/// 기록보관소 (BArchive), opened from home's 03 / ARCHIVE: the last 7 days,
/// the score growth per exercise, and the newest battles; "전체 보기" opens
/// every battle, loaded page by page as that list scrolls. A row with
/// feedback opens it.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.createViewModel, this.now});

  /// Builds the view model; replaces the default one in tests.
  final HistoryViewModel Function()? createViewModel;

  /// Today, for the rows' "오늘" and "어제"; the clock by default.
  final DateTime Function()? now;

  /// How many of the newest battles the archive itself shows.
  static const recentCount = 3;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.createViewModel?.call() ??
        HistoryViewModel(
          repository: context.read<UserRepository>(),
          // One clock for the summary's "오늘" and the rows' words.
          now: widget.now,
        );
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  void _openAll() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider<HistoryViewModel>.value(
        value: _viewModel,
        child: _AllMatchesPage(now: _now),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HistoryViewModel>.value(
      value: _viewModel,
      child: Consumer<HistoryViewModel>(
        builder: (context, vm, _) {
          final state = vm.state;
          return LobbyPage(
            behind: const LobbyWatermark('LOG', left: _watermarkLeft),
            children: [
              const _Header(title: '기록보관소'),
              const SizedBox(height: AppSpacing.s16),
              ...switch (state.phase) {
                HistoryPhase.loading => const [
                  Expanded(child: Center(child: CircularProgressIndicator())),
                ],
                HistoryPhase.failed => [
                  Expanded(
                    child: CenteredMessage(
                      title: '기록을 불러오지 못했어요',
                      detail: state.errorMessage,
                      onRetry: vm.load,
                    ),
                  ),
                ],
                HistoryPhase.empty => const [
                  Expanded(
                    child: CenteredMessage(
                      title: '아직 경기 기록이 없어요',
                      detail: '첫 대결을 마치면 여기에 기록돼요.',
                    ),
                  ),
                ],
                HistoryPhase.ready => _ready(context, state, vm.load),
              },
            ],
          );
        },
      ),
    );
  }

  /// The cards (or "다시 시도" in their place when the summary failed; nothing
  /// while it loads or without one), then the newest battles.
  List<Widget> _ready(
    BuildContext context,
    HistoryState state,
    VoidCallback onRetry,
  ) {
    final archive = state.archive;
    final recent = state.matches.take(HistoryScreen.recentCount).toList();
    final more =
        state.matches.length > HistoryScreen.recentCount || state.hasMore;
    final now = _now();
    return [
      if (archive != null) ...[
        ArchiveWeekCard(stats: archive),
        const SizedBox(height: AppSpacing.s12),
        ArchiveGrowthCard(growth: archive.growth),
        const SizedBox(height: AppSpacing.s8),
      ] else if (state.statsFailed) ...[
        ArchiveStatsRetry(onRetry: onRetry),
        const SizedBox(height: AppSpacing.s8),
      ],
      _RecentHeader(onShowAll: more ? _openAll : null),
      for (final (index, match) in recent.indexed) ...[
        if (index > 0) const SizedBox(height: AppSpacing.s8),
        ArchiveMatchRow(
          match: match,
          now: now,
          bestGain: state.bestGainOf(match),
          onTap: feedbackTap(context, match),
        ),
      ],
    ];
  }
}

/// Where the faint "LOG" starts, as designed.
const _watermarkLeft = 178.0;

/// The back button, "03 / ARCHIVE" and the slanted [title].
class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => LobbyPageHeader(
    tag: '03 / ARCHIVE',
    title: title,
    tagColor: AppColors.textMuted,
  );
}

/// "최근 경기", and "전체 보기 ›" when there are more battles than shown.
class _RecentHeader extends StatelessWidget {
  const _RecentHeader({required this.onShowAll});

  final VoidCallback? onShowAll;

  static const _chevronSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final onShowAll = this.onShowAll;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
      child: Row(
        children: [
          Expanded(child: Text('최근 경기', style: text.lobbyRowTitle)),
          if (onShowAll != null)
            TextButton(
              onPressed: onShowAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: text.archiveLabel,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('전체 보기'),
                  Icon(Icons.chevron_right_rounded, size: _chevronSize),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Every battle, newest first, on the archive's view model; the footer
/// loads the next page as soon as the list builds it, which is when the end
/// comes near (or right away when one page does not fill the screen).
class _AllMatchesPage extends StatelessWidget {
  const _AllMatchesPage({required this.now});

  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistoryViewModel>();
    final state = vm.state;
    final matches = state.matches;
    final showFooter =
        state.hasMore || state.loadingMore || state.loadMoreFailed;
    final today = now();
    return Scaffold(
      body: Stack(
        children: [
          const LobbyWatermark('LOG', left: _watermarkLeft),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.s20,
                    AppSpacing.s4,
                    AppSpacing.s20,
                    0,
                  ),
                  child: _Header(title: '전체 경기'),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s20,
                      AppSpacing.s16,
                      AppSpacing.s20,
                      AppSpacing.s24,
                    ),
                    itemCount: matches.length + (showFooter ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.s8),
                    itemBuilder: (context, index) {
                      if (index < matches.length) {
                        // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
                        final match = matches[index];
                        return ArchiveMatchRow(
                          match: match,
                          now: today,
                          bestGain: state.bestGainOf(match),
                          onTap: feedbackTap(context, match),
                        );
                      }
                      if (state.loadMoreFailed) {
                        return CenteredMessage(
                          title: '더 불러오지 못했어요',
                          onRetry: vm.loadMore,
                        );
                      }
                      if (state.loadingMore) return const _FooterSpinner();
                      return _LoadMoreTrigger(onBuilt: vm.loadMore);
                    },
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

class _FooterSpinner extends StatelessWidget {
  const _FooterSpinner();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppSpacing.s16),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// A footer spinner that asks for the next page once it is built.
class _LoadMoreTrigger extends StatefulWidget {
  const _LoadMoreTrigger({required this.onBuilt});

  final VoidCallback onBuilt;

  @override
  State<_LoadMoreTrigger> createState() => _LoadMoreTriggerState();
}

class _LoadMoreTriggerState extends State<_LoadMoreTrigger> {
  @override
  void initState() {
    super.initState();
    // Not during build: loading changes the state this list is built from.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onBuilt();
    });
  }

  @override
  Widget build(BuildContext context) => const _FooterSpinner();
}
