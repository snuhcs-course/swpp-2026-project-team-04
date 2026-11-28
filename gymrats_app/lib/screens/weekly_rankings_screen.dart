import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/rankings/rankings_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/character_viewmodel.dart';
import '../viewmodels/weekly_rankings_viewmodel.dart';
import '../widgets/lobby_parts.dart';
import '../widgets/weekly_rankings_banner.dart';
import '../widgets/weekly_rankings_empty_card.dart';
import '../widgets/weekly_rankings_my_card.dart';
import '../widgets/weekly_rankings_row.dart';
import '../widgets/weekly_rankings_rules_sheet.dart';
import '../widgets/weekly_rankings_tabs.dart';

/// 주간 랭킹 (P11, redrawn in A13 as design `RankD1`), from the online
/// battle's exercise sheet: this week's points of online battles,
/// everyone's or among me and my friends, of push-ups or of squats. Friend
/// battles never score; the friends tab ranks the same points.
///
/// Top to bottom: the header with '?' for the points rules, the week's ink
/// banner, the scope and exercise tabs, my card, then the list (or a card
/// in its place). Only the list scrolls, unless the screen is too short
/// for the rest.
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

class _WeeklyRankingsScreenState extends State<WeeklyRankingsScreen>
    with WidgetsBindingObserver {
  late final WeeklyRankingsViewModel _vm = widget.createViewModel();

  /// Redraws the time left on the banner every minute.
  late final Timer _minute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vm.addListener(_changed);
    unawaited(_vm.load());
    _minute = Timer.periodic(const Duration(minutes: 1), (_) => _changed());
  }

  /// Back from the background, perhaps in a new week.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_vm.refreshIfWeekEnded());
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _minute.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _vm
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  /// As a lobby page's.
  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.s20,
    AppSpacing.s4,
    AppSpacing.s20,
    AppSpacing.s24,
  );

  /// Under the title, the banner (design 14).
  static const _bannerGap = 14.0;

  /// Around the tabs: the design's 12 less the 4 each side of the 40-high
  /// pills inside their 48-high tap area.
  static const _tabsGap = AppSpacing.s8;

  /// Under the list's name (design 6), and between rows (design 5).
  static const _headingGap = 6.0;
  static const _rowGap = 5.0;

  /// The least height the list gets before the page itself scrolls: three
  /// rows.
  static const _listMinHeight = 3 * WeeklyRankingsListRow.height + 2 * _rowGap;

  @override
  Widget build(BuildContext context) {
    final ranking = _vm.ranking;
    final characterId = context.watch<CharacterViewModel>().characterId;
    // My name before my first battle, when the global ranking has no row of
    // mine; the app always has an account here, a lone test may not.
    final account = context.watch<AuthViewModel?>()?.account;
    final standing = _vm.standing;
    final listed =
        ranking != null && ranking.entries.isNotEmpty && !_vm.noFriends;
    return Scaffold(
      body: Stack(
        children: [
          const LobbyWatermark('RANK', left: 150),
          SafeArea(
            // Pulling past either end stops there: Android's stretch would
            // draw the rows taller.
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(overscroll: false),
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: _padding,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (box.maxHeight - _padding.vertical).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: LobbyFillColumn(
                      above: [
                        const _Header(),
                        const SizedBox(height: _bannerGap),
                        WeeklyRankingsBanner(
                          weekName: _vm.weekName,
                          dates: ranking == null
                              ? null
                              : WeeklyRankingsScreen.weekLabel(ranking),
                          timeLeft: _vm.timeLeft,
                          progress: _vm.weekProgress,
                        ),
                        const SizedBox(height: _tabsGap),
                        WeeklyRankingsTabs(
                          scope: _vm.scope,
                          exercise: _vm.exercise,
                          onScope: (scope) => unawaited(_vm.select(scope)),
                          onExercise: (exercise) =>
                              unawaited(_vm.selectExercise(exercise)),
                        ),
                        const SizedBox(height: _tabsGap),
                        if (standing != null) ...[
                          WeeklyRankingsMyCard(
                            standing: standing,
                            name: _vm.myName(account?.nickname),
                            record: _vm.myRecord,
                            characterId: characterId,
                          ),
                          const SizedBox(height: AppSpacing.s12),
                        ],
                        if (listed) ...[
                          WeeklyRankingsListHeading(
                            title: _vm.listTitle!,
                            note: _vm.listNote!,
                          ),
                          const SizedBox(height: _headingGap),
                        ],
                      ],
                      fill: _list(ranking),
                      fillMinHeight: _listMinHeight,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// What takes the room under my card: the rows, a card in their place,
  /// the error with 다시 시도, or the spinner.
  Widget _list(WeeklyRanking? ranking) {
    if (_vm.error case final error?) {
      return Align(
        alignment: Alignment.topCenter,
        child: _Notice(error, onRetry: () => unawaited(_vm.retry())),
      );
    }
    if (ranking == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final Widget? card = _vm.noFriends
        ? WeeklyRankingsEmptyCard.noFriends(
            onAddFriends: () =>
                Navigator.pushNamed(context, GymRatsApp.friendsRoute),
          )
        : ranking.entries.isEmpty
        ? const WeeklyRankingsEmptyCard.emptyWeek()
        : null;
    if (card != null) {
      return ListView(padding: EdgeInsets.zero, children: [card]);
    }
    final entries = ranking.entries;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: _rowGap),
      itemBuilder: (_, index) {
        final entry = entries[index];
        return WeeklyRankingsListRow(
          rank: entry.rank,
          nickname: entry.nickname,
          points: entry.points,
          battles: entry.battles,
          wins: entry.wins,
          koWins: entry.koWins,
          isMe: entry.isMe,
        );
      },
    );
  }
}

/// The lobby page header (`LobbyPageHeader`'s parts) with '?' for the
/// points rules at the right of its top line (A13 spec 3.1).
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LobbySquareButton(
              icon: Icons.chevron_left_rounded,
              tooltip: '뒤로',
              onPressed: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: AppSpacing.s12),
            const Expanded(
              child: LobbyTag(
                '01 / PLAY · RANKING',
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            LobbySquareButton(
              icon: Icons.help_outline_rounded,
              tooltip: '점수 규칙',
              onPressed: () => showWeeklyRankingsRules(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s20),
        Semantics(
          header: true,
          child: LobbySkew(
            degrees: 10,
            child: Text(
              '주간 랭킹',
              style: Theme.of(context).textTheme.lobbyPageTitle,
            ),
          ),
        ),
      ],
    );
  }
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
