import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/history_viewmodel.dart';
import '../widgets/auth_form.dart';
import '../widgets/grid_background.dart';
import '../widgets/match_record_card.dart';

/// Every battle the user finished, newest first, loaded page by page as
/// the list scrolls. Opened from home's "최근 경기".
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.createViewModel});

  /// Builds the view model; replaces the default one in tests.
  final HistoryViewModel Function()? createViewModel;

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
        HistoryViewModel(repository: context.read<UserRepository>());
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HistoryViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        body: GridBackground(
          child: SafeArea(
            child: Column(
              children: [
                const TopBar(title: '경기 기록'),
                Expanded(
                  child: Consumer<HistoryViewModel>(
                    builder: (context, vm, _) {
                      final state = vm.state;
                      return switch (state.phase) {
                        HistoryPhase.loading => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        HistoryPhase.failed => CenteredMessage(
                          title: '기록을 불러오지 못했어요',
                          detail: state.errorMessage,
                          onRetry: vm.load,
                        ),
                        HistoryPhase.empty => const CenteredMessage(
                          title: '아직 경기 기록이 없어요',
                          detail: '첫 대결을 마치면 여기에 기록돼요.',
                        ),
                        HistoryPhase.ready => _HistoryList(
                          state: state,
                          onLoadMore: vm.loadMore,
                        ),
                      };
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The battles, and under them a footer while older ones are left: the
/// footer loads the next page as soon as the list builds it, which is when
/// the end comes near (or right away when one page does not fill the
/// screen).
class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.state, required this.onLoadMore});

  final HistoryState state;

  /// Loads the next page, or retries it after it failed.
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final matches = state.matches;
    final showFooter =
        state.hasMore || state.loadingMore || state.loadMoreFailed;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s8,
        AppSpacing.s20,
        AppSpacing.s24,
      ),
      itemCount: matches.length + (showFooter ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s12),
      itemBuilder: (context, index) {
        if (index < matches.length) {
          return MatchRecordCard(match: matches[index], showDate: true);
        }
        if (state.loadMoreFailed) {
          return CenteredMessage(title: '더 불러오지 못했어요', onRetry: onLoadMore);
        }
        if (state.loadingMore) return const _FooterSpinner();
        return _LoadMoreTrigger(onBuilt: onLoadMore);
      },
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
