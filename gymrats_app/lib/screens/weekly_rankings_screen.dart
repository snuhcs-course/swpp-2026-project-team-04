import 'dart:async';

import 'package:flutter/material.dart';

import '../services/rankings/rankings_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/weekly_rankings_viewmodel.dart';
import '../widgets/lobby_parts.dart';

/// 주간 랭킹 (P11), from the online battle's exercise sheet: this week's
/// points of online battles, everyone's or among me and my friends. Friend
/// battles never score; the friends tab ranks the same points.
class WeeklyRankingsScreen extends StatefulWidget {
  const WeeklyRankingsScreen({super.key, required this.createViewModel});

  final WeeklyRankingsViewModel Function() createViewModel;

  /// "11.23 (월) – 11.29 (일)" of a week that starts on Monday in Korea.
  static String weekLabel(WeeklyRanking ranking) {
    // The server's times are Korea's; the app reads them as UTC.
    const korea = Duration(hours: 9);
    final first = ranking.weekStart.toUtc().add(korea);
    final last = ranking.weekEnd
        .toUtc()
        .add(korea)
        .subtract(const Duration(days: 1));
    String day(DateTime d, String weekday) => '${d.month}.${d.day} ($weekday)';
    return '${day(first, '월')} – ${day(last, '일')}';
  }

  @override
  State<WeeklyRankingsScreen> createState() => _WeeklyRankingsScreenState();
}

class _WeeklyRankingsScreenState extends State<WeeklyRankingsScreen> {
  late final WeeklyRankingsViewModel _vm = widget.createViewModel();

  @override
  void initState() {
    super.initState();
    _vm.addListener(_changed);
    unawaited(_vm.load());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ranking = _vm.ranking;
    final secondary = text.bodyMedium?.copyWith(color: AppColors.textSecondary);
    // The header, the tabs and the week stay; only the rows scroll.
    return Scaffold(
      body: Stack(
        children: [
          const LobbyWatermark('RANK', left: 150),
          SafeArea(
            child: Padding(
              padding: _padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LobbyPageHeader(
                    tag: '01 / PLAY · RANKING',
                    title: '주간 랭킹',
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  _ScopeTabs(
                    selected: _vm.scope,
                    onSelected: (scope) => unawaited(_vm.select(scope)),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  if (_vm.error case final error?)
                    _Notice(error, onRetry: () => unawaited(_vm.retry()))
                  else if (ranking == null)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    Text(
                      WeeklyRankingsScreen.weekLabel(ranking),
                      style: secondary,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    if (ranking.entries.isEmpty)
                      const _Empty(
                        '이번 주 온라인 대결 기록이 아직 없어요. 첫 승점을 올려 보세요!',
                      )
                    else
                      // As tall as its rows, scrolling when they do not fit.
                      Flexible(child: _Board(entries: ranking.entries)),
                    // The friends tab always holds me.
                    if (ranking.scope == RankingScope.friends &&
                        ranking.entries.length < 2) ...[
                      const SizedBox(height: AppSpacing.s12),
                      const _Empty('친구를 추가하면 친구들과 이번 주 점수를 비교할 수 있어요.'),
                    ],
                    if (_myRowApart(ranking) case final me?) ...[
                      const SizedBox(height: AppSpacing.s12),
                      _Board(entries: [me]),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// As a lobby page's.
  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.s20,
    AppSpacing.s4,
    AppSpacing.s20,
    AppSpacing.s24,
  );

  /// My row under the list, when the global top stops above it.
  static RankingEntry? _myRowApart(WeeklyRanking ranking) {
    final me = ranking.me;
    if (me == null || ranking.entries.any((e) => e.isMe)) return null;
    return me;
  }
}

class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs({required this.selected, required this.onSelected});

  final RankingScope selected;
  final ValueChanged<RankingScope> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: SegmentedButton<RankingScope>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: RankingScope.global, label: Text('전체')),
        ButtonSegment(value: RankingScope.friends, label: Text('친구')),
      ],
      selected: {selected},
      onSelectionChanged: (choice) => onSelected(choice.single),
    ),
  );
}

/// Rows of a ranking on one card; they scroll inside it when the card is
/// given less height than they need.
class _Board extends StatelessWidget {
  const _Board({required this.entries});

  final List<RankingEntry> entries;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, index) => _Row(entries[index]),
    ),
  );
}

/// "1  쥐돌이 (나)  ·  3전 2승 · KO 1  ·  25점", mine on the selected fill.
class _Row extends StatelessWidget {
  const _Row(this.entry);

  final RankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = entry.isMe ? '${entry.nickname} (나)' : entry.nickname;
    final line = '${entry.battles}전 ${entry.wins}승 · KO ${entry.koWins}';
    return Semantics(
      container: true,
      label: '${entry.rank}위, $name, ${entry.points}점, $line',
      excludeSemantics: true,
      child: ColoredBox(
        color: entry.isMe ? AppColors.selectedFill : AppColors.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          child: Row(
            children: [
              SizedBox(
                width: _rankWidth,
                child: Text('${entry.rank}', style: text.titleLarge),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: text.lobbyRowTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      line,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text('${entry.points}점', style: text.titleMedium),
            ],
          ),
        ),
      ),
    );
  }

  /// Room for a three-digit rank.
  static const _rankWidth = 44.0;
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: AppHighlight.band(AppColors.warning),
    child: Padding(
      padding: AppHighlight.bandPadding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.ink),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: AppColors.ink),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    ),
  );
}
