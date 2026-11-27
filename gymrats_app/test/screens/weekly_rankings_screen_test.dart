import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/screens/weekly_rankings_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/rankings/rankings_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/weekly_rankings_viewmodel.dart';

RankingEntry entry(
  int rank,
  String name, {
  int points = 10,
  bool me = false,
  int id = 0,
}) => RankingEntry(
  rank: rank,
  userId: id == 0 ? rank : id,
  nickname: name,
  points: points,
  battles: 3,
  wins: 2,
  koWins: 1,
  isMe: me,
);

WeeklyRanking week(
  RankingScope scope,
  List<RankingEntry> entries, {
  RankingEntry? me,
}) => WeeklyRanking(
  scope: scope,
  // Monday 11.23 00:00 KST to the next Monday.
  weekStart: DateTime.parse('2026-11-23T00:00:00+09:00'),
  weekEnd: DateTime.parse('2026-11-30T00:00:00+09:00'),
  entries: entries,
  me: me,
);

/// Fails each read until [fail] is false.
class _Failing implements RankingsRepository {
  bool fail = true;
  final RankingsRepository then;
  _Failing(this.then);

  @override
  Future<WeeklyRanking> fetchWeekly(RankingScope scope) async {
    if (fail) throw const ApiException(ApiErrorKind.network);
    return then.fetchWeekly(scope);
  }
}

class _Never implements RankingsRepository {
  @override
  Future<WeeklyRanking> fetchWeekly(RankingScope scope) =>
      Completer<WeeklyRanking>().future;
}

void main() {
  Future<void> open(
    WidgetTester tester,
    RankingsRepository repository, {
    Size size = const Size(412, 915),
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: WeeklyRankingsScreen(
          createViewModel: () =>
              WeeklyRankingsViewModel(repository: repository),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  final global = week(RankingScope.global, [
    entry(1, '헬창', points: 25),
    entry(2, '쥐돌이', points: 18, me: true),
    entry(2, '근손실', points: 18),
  ], me: entry(2, '쥐돌이', points: 18, me: true));

  final friends = week(RankingScope.friends, [
    entry(1, '쥐돌이', points: 18, me: true),
    entry(2, '단짝', points: 6),
  ], me: entry(1, '쥐돌이', points: 18, me: true));

  testWidgets('shows a spinner while reading', (tester) async {
    await open(tester, _Never(), settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('lists the global week with its dates and no rules line', (
    tester,
  ) async {
    await open(
      tester,
      InMemoryRankingsRepository(rankings: {RankingScope.global: global}),
    );

    expect(find.text('주간 랭킹'), findsOneWidget);
    expect(find.textContaining('KO승'), findsNothing);
    expect(find.text('11.23 (월) – 11.29 (일)'), findsOneWidget);
    expect(find.text('헬창'), findsOneWidget);
    expect(find.text('25점'), findsOneWidget);
    expect(find.text('쥐돌이 (나)'), findsOneWidget);
    // A tie shares the rank.
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('3전 2승 · KO 1'), findsNWidgets(3));
    // Best first.
    expect(
      tester.getTopLeft(find.text('헬창')).dy,
      lessThan(tester.getTopLeft(find.text('쥐돌이 (나)')).dy),
    );
  });

  testWidgets('my row is on the selected fill', (tester) async {
    await open(
      tester,
      InMemoryRankingsRepository(rankings: {RankingScope.global: global}),
    );
    final mine = tester.widget<ColoredBox>(
      find
          .ancestor(of: find.text('쥐돌이 (나)'), matching: find.byType(ColoredBox))
          .first,
    );
    final theirs = tester.widget<ColoredBox>(
      find
          .ancestor(of: find.text('헬창'), matching: find.byType(ColoredBox))
          .first,
    );
    expect(mine.color, AppColors.selectedFill);
    expect(theirs.color, AppColors.card);
  });

  testWidgets('the friends tab shows the same points among friends', (
    tester,
  ) async {
    final repo = InMemoryRankingsRepository(
      rankings: {RankingScope.global: global, RankingScope.friends: friends},
    );
    await open(tester, repo);

    await tester.tap(find.text('친구'));
    await tester.pumpAndSettle();

    expect(find.text('단짝'), findsOneWidget);
    expect(find.text('헬창'), findsNothing);
    expect(repo.reads, {RankingScope.global: 1, RankingScope.friends: 1});

    await tester.tap(find.text('전체'));
    await tester.pumpAndSettle();
    expect(find.text('헬창'), findsOneWidget);
    // Kept, not read again.
    expect(repo.reads[RankingScope.global], 1);
  });

  testWidgets('my row comes under the list when the top stops above it', (
    tester,
  ) async {
    final top = week(RankingScope.global, [
      entry(1, '헬창', points: 25),
    ], me: entry(77, '쥐돌이', points: 1, me: true, id: 9));
    await open(
      tester,
      InMemoryRankingsRepository(rankings: {RankingScope.global: top}),
    );

    expect(find.text('77'), findsOneWidget);
    expect(find.text('쥐돌이 (나)'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(2));
  });

  testWidgets('an empty week says so', (tester) async {
    await open(tester, InMemoryRankingsRepository());
    expect(find.text('이번 주 온라인 대결 기록이 아직 없어요. 첫 승점을 올려 보세요!'), findsOneWidget);
  });

  testWidgets('friends with only me asks to add friends', (tester) async {
    final alone = week(RankingScope.friends, [
      entry(1, '쥐돌이', points: 0, me: true),
    ]);
    await open(
      tester,
      InMemoryRankingsRepository(rankings: {RankingScope.friends: alone}),
    );
    await tester.tap(find.text('친구'));
    await tester.pumpAndSettle();

    expect(find.text('쥐돌이 (나)'), findsOneWidget);
    expect(find.text('친구를 추가하면 친구들과 이번 주 점수를 비교할 수 있어요.'), findsOneWidget);
  });

  testWidgets('a failed read offers to try again', (tester) async {
    final repo = _Failing(
      InMemoryRankingsRepository(rankings: {RankingScope.global: global}),
    );
    await open(tester, repo);

    expect(
      find.text(const ApiException(ApiErrorKind.network).message),
      findsOneWidget,
    );
    repo.fail = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('헬창'), findsOneWidget);
  });

  testWidgets('a row reads as one sentence', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(
      tester,
      InMemoryRankingsRepository(rankings: {RankingScope.global: global}),
    );
    expect(find.bySemanticsLabel('1위, 헬창, 25점, 3전 2승 · KO 1'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('fifty rows and a large text size fit a small phone', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final many = week(RankingScope.global, [
      for (var i = 1; i <= 50; i++) entry(i, '아주긴닉네임열두글자$i', points: 1000 - i),
    ], me: entry(77, '쥐돌이', points: 1, me: true, id: 99));
    await open(
      tester,
      InMemoryRankingsRepository(rankings: {RankingScope.global: many}),
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    // The list shrinks so my row still shows under it.
    expect(find.text('쥐돌이 (나)'), findsOneWidget);
  });

  testWidgets('only the rows scroll: the header, tabs and week stay', (
    tester,
  ) async {
    final many = week(RankingScope.global, [
      for (var i = 1; i <= 50; i++) entry(i, '선수$i', points: 1000 - i),
    ], me: entry(77, '쥐돌이', points: 1, me: true, id: 99));
    await open(
      tester,
      InMemoryRankingsRepository(rankings: {RankingScope.global: many}),
    );
    double top(Finder f) => tester.getTopLeft(f).dy;
    final title = top(find.text('주간 랭킹'));
    final tabs = top(find.text('전체'));
    final weekLine = top(find.text('11.23 (월) – 11.29 (일)'));
    final mine = top(find.text('쥐돌이 (나)'));

    await tester.drag(find.text('선수3'), const Offset(0, -6000));
    await tester.pumpAndSettle();

    expect(top(find.text('주간 랭킹')), title);
    expect(top(find.text('전체')), tabs);
    expect(top(find.text('11.23 (월) – 11.29 (일)')), weekLine);
    // My row stays under the list, and the last rows came up.
    expect(top(find.text('쥐돌이 (나)')), mine);
    expect(find.text('선수50'), findsOneWidget);
    expect(find.text('선수1'), findsNothing);
    // The list ends above my row.
    expect(tester.getBottomLeft(find.text('선수50')).dy, lessThan(mine));
  });

  testWidgets('a short list keeps its own height', (tester) async {
    await open(
      tester,
      InMemoryRankingsRepository(rankings: {RankingScope.friends: friends}),
    );
    await tester.tap(find.text('친구'));
    await tester.pumpAndSettle();
    final card = find.ancestor(
      of: find.text('단짝'),
      matching: find.byType(Card),
    );
    expect(tester.getSize(card).height, lessThan(400));
  });

  test('the week label reads Korean dates whatever the zone given', () {
    final utc = WeeklyRanking(
      scope: RankingScope.global,
      weekStart: DateTime.utc(2026, 11, 22, 15),
      weekEnd: DateTime.utc(2026, 11, 29, 15),
      entries: const [],
      me: null,
    );
    expect(WeeklyRankingsScreen.weekLabel(utc), '11.23 (월) – 11.29 (일)');
  });
}
