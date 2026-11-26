import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hold_record.dart';
import '../services/feedback/feedback_stats.dart';
import '../services/feedback/form_report_store.dart';
import '../services/feedback/hold_record_store.dart';
import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/history_viewmodel.dart';
import '../widgets/archive_cards.dart';
import '../widgets/archive_match_row.dart';
import '../widgets/auth_form.dart';
import 'hold_report_screen.dart';
import 'result_screen.dart';

/// 운동일지 (P13, draft C), opened from home's 03 / ARCHIVE (named 기록보관소
/// there): two tabs.
///
/// - **전체:** a period (이번 주, 이번 달, 전체 기간) and an exercise; the
///   battles, counted reps per battle and best score; the battles' scores or
///   reps in time; the bests of every exercise; the most frequent reject
///   reasons; and the holds (P13).
/// - **경기:** chips for 전체, an exercise, 온라인 or 아케이드, and the battles
///   by day, loaded page by page as the list scrolls. A row opens its
///   battle's report.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.createViewModel, this.now});

  /// Builds the view model; replaces the default one in tests.
  final HistoryViewModel Function()? createViewModel;

  /// Today, for "오늘" and "어제" and the periods; the clock by default.
  final DateTime Function()? now;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryViewModel _viewModel;

  /// The statistics' battles; null without a source, and then the 전체 tab
  /// says the periods are not available.
  late final FeedbackStatsSource? _statsSource;

  @override
  void initState() {
    super.initState();
    _statsSource = switch (context.read<UserRepository>()) {
      final FeedbackStatsSource source => source,
      _ => null,
    };
    _viewModel =
        widget.createViewModel?.call() ??
        HistoryViewModel(
          repository: context.read<UserRepository>(),
          holdRecords: _holdRecords(),
          formReports: _formReports(),
          // One clock for the periods and the rows' words.
          now: widget.now,
        );
    _viewModel.load();
  }

  /// The battles' form reports kept on the phone, for 운동량 (P13).
  FormReportStore? _formReports() {
    try {
      return context.read<FormReportStore>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// The app's kept holds (P13); none without one, as in tests.
  HoldRecordStore? _holdRecords() {
    try {
      return context.read<HoldRecordStore>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HistoryViewModel>.value(
      value: _viewModel,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Consumer<HistoryViewModel>(
              builder: (context, vm, _) {
                final state = vm.state;
                final source = _statsSource;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Top(),
                    Expanded(
                      child: switch (state.phase) {
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
                        HistoryPhase.ready => TabBarView(
                          children: [
                            _OverviewTab(hasSource: source != null),
                            _MatchesTab(now: _now),
                          ],
                        ),
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The back button and "운동일지" on white, then the 전체 | 경기 tabs with an
/// ink line under the chosen one.
class _Top extends StatelessWidget {
  const _Top();

  static const _indicator = 3.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s8,
              AppSpacing.s4,
              AppSpacing.s20,
              0,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: '뒤로',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: AppColors.ink,
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('운동일지', style: text.lobbyCardTitle),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            labelStyle: text.reportCardTitle,
            unselectedLabelStyle: text.feedbackMeta,
            labelColor: AppColors.ink,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.ink,
            indicatorWeight: _indicator,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: AppColors.card,
            tabs: const [
              Tab(text: '전체'),
              Tab(text: '경기'),
            ],
          ),
        ],
      ),
    );
  }
}

const _gap = SizedBox(height: AppSpacing.s8);

/// The 전체 tab: the period and the scope (전체, 푸쉬업, 스쿼트, 버티기), then
/// what they hold. 전체 sums every exercise and the holds; an exercise shows
/// its battles; 버티기 only what fits a hold (no score, reps or lifted
/// weight).
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.hasSource});

  final bool hasSource;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistoryViewModel>();
    final state = vm.state;
    final text = Theme.of(context).textTheme;
    final hold = state.scope == ArchiveScope.hold;
    return ListView(
      padding: const EdgeInsets.only(
        top: AppSpacing.s8,
        bottom: AppSpacing.s24,
      ),
      children: [
        ArchiveSection(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ArchivePeriodPicker(value: state.period, onChanged: vm.setPeriod),
              const SizedBox(height: AppSpacing.s12),
              ArchiveScopeChips(selected: state.scope, onSelected: vm.setScope),
            ],
          ),
        ),
        _gap,
        ...hold ? _holds(vm, text) : _battles(vm, text),
      ],
    );
  }

  /// 버티기: the holds' summary, bests and trend, their calories and their
  /// warnings.
  List<Widget> _holds(HistoryViewModel vm, TextTheme text) {
    final holds = vm.holdSummary;
    if (holds == null) {
      return [
        ArchiveSection(
          child: Text(
            '버티기 기록이 아직 없어요. 아케이드의 버티기 스테이지를 하면 여기에 모여요.',
            style: text.feedbackMeta,
          ),
        ),
      ];
    }
    final period = vm.state.period;
    // The same order as an exercise's: the summary, the volume, each play
    // in time, the bests and what went wrong most (user, 2026-11-26).
    return [
      ArchiveSection(child: ArchiveHoldFigures(holds: holds)),
      if (vm.volume case final volume?) ...[
        _gap,
        ArchiveSection(
          child: ArchiveVolumeSection(
            volume: volume,
            period: period,
            holdsOnly: true,
          ),
        ),
      ],
      _gap,
      ArchiveSection(child: ArchiveHoldChart(holds: holds.points)),
      _gap,
      ArchiveSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ArchiveSectionTitle('개인 최고'),
            const SizedBox(height: AppSpacing.s12),
            ArchiveBests(holds: holds.bests),
          ],
        ),
      ),
      _gap,
      ArchiveSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ArchiveSectionTitle('자주 받은 경고'),
            const SizedBox(height: AppSpacing.s12),
            ArchiveHoldWarnings(warnings: holds.warnings),
          ],
        ),
      ),
    ];
  }

  /// 전체 or one exercise: the summary, the volume, the scores in time, the
  /// bests and the reject reasons.
  List<Widget> _battles(HistoryViewModel vm, TextTheme text) {
    final state = vm.state;
    final growth = vm.growth;
    if (growth == null) {
      return [
        if (state.statsFailed)
          ArchiveStatsRetry(onRetry: vm.load)
        else if (!hasSource)
          ArchiveSection(
            child: Text(
              '기간별 기록은 서버에 연결되어 있을 때 볼 수 있어요.',
              style: text.feedbackMeta,
            ),
          )
        else
          const ArchiveSection(
            child: Center(child: CircularProgressIndicator()),
          ),
      ];
    }
    final every = state.scope == ArchiveScope.all;
    final holds = vm.holdSummary;
    return [
      ArchiveSection(
        child: ArchiveSummary(
          growth: growth,
          holds: every ? holds?.count ?? 0 : 0,
        ),
      ),
      _gap,
      if (vm.volume case final volume?) ...[
        ArchiveSection(
          child: ArchiveVolumeSection(volume: volume, period: state.period),
        ),
        _gap,
      ],
      ArchiveSection(child: ArchiveScoreChart(points: growth.points)),
      _gap,
      ArchiveSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ArchiveSectionTitle('개인 최고'),
            const SizedBox(height: AppSpacing.s12),
            // One exercise shows its own best; 전체 every exercise's and
            // every pose's (user, 2026-11-26).
            ArchiveBests(
              bests: [
                for (final b in growth.bests)
                  if (every || b.exercise == state.exercise) b,
              ],
              holds: every ? holds?.bests ?? const [] : const [],
            ),
          ],
        ),
      ),
      _gap,
      ArchiveSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ArchiveSectionTitle('자주 나온 자세 문제'),
            const SizedBox(height: AppSpacing.s12),
            ArchiveIssues(issues: growth.issues),
          ],
        ),
      ),
    ];
  }
}

/// The 경기 tab: the chips, then the battles by day, then a footer that
/// loads the next page as soon as the list builds it.
class _MatchesTab extends StatelessWidget {
  const _MatchesTab({required this.now});

  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistoryViewModel>();
    final state = vm.state;
    final days = state.days;
    final showFooter =
        state.hasMore || state.loadingMore || state.loadMoreFailed;
    final today = now();
    final text = Theme.of(context).textTheme;
    // The chips, the days (or a note when the chip leaves none), the footer.
    final count =
        1 +
        (days.isEmpty && !showFooter ? 1 : days.length) +
        (showFooter ? 1 : 0);
    return ListView.builder(
      padding: const EdgeInsets.only(
        top: AppSpacing.s8,
        bottom: AppSpacing.s24,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: ArchiveSection(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: ArchiveChips<ArchiveFilter>(
                values: ArchiveFilter.values,
                labelOf: (f) => f.label,
                selected: state.filter,
                onSelected: vm.setFilter,
              ),
            ),
          );
        }
        final at = index - 1;
        if (days.isEmpty && !showFooter && at == 0) {
          return ArchiveSection(
            child: Text('이 조건에 맞는 기록이 없어요.', style: text.feedbackMeta),
          );
        }
        if (at < days.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: _Day(day: days[at], now: today, state: state),
          );
        }
        if (state.loadMoreFailed) {
          return CenteredMessage(title: '더 불러오지 못했어요', onRetry: vm.loadMore);
        }
        if (state.loadingMore) return const _FooterSpinner();
        return _LoadMoreTrigger(onBuilt: vm.loadMore);
      },
    );
  }
}

/// One day on white: its head, then its battles with a line between them.
class _Day extends StatelessWidget {
  const _Day({required this.day, required this.now, required this.state});

  final ArchiveDay day;
  final DateTime now;
  final HistoryState state;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArchiveDayHeader(
            date: day.date,
            count: day.entries.length,
            now: now,
            unit: day.holds.isEmpty ? '경기' : '기록',
          ),
          for (final (index, entry) in day.entries.indexed) ...[
            if (index > 0)
              const Divider(
                height: 1,
                indent: AppSpacing.s20,
                endIndent: AppSpacing.s20,
                color: AppColors.facetLight,
              ),
            switch (entry) {
              ArchiveMatchEntry(:final match) => ArchiveMatchRow(
                match: match,
                bestGain: state.bestGainOf(match),
                onTap: reportTap(context, match),
              ),
              ArchiveHoldEntry(:final hold) => ArchiveHoldRow(
                hold: hold,
                onTap: () => _openHold(context, hold),
              ),
            },
          ],
        ],
      ),
    );
  }
}

/// A played hold's report on top (P13).
void _openHold(BuildContext context, HoldRecord hold) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) => HoldReportScreen(
      record: hold,
      store: context.read<HistoryViewModel>().holdRecords,
    ),
  ),
);

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
