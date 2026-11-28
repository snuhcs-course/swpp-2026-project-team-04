import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/screens/weekly_rankings_screen.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/rankings/rankings_repository.dart';
import 'package:gymrats_app/services/user/character_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/character_viewmodel.dart';
import 'package:gymrats_app/viewmodels/weekly_rankings_viewmodel.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/weekly_rankings_banner.dart';
import 'package:gymrats_app/widgets/weekly_rankings_empty_card.dart';
import 'package:gymrats_app/widgets/weekly_rankings_my_card.dart';
import 'package:gymrats_app/widgets/weekly_rankings_row.dart';
import 'package:gymrats_app/widgets/weekly_rankings_rules_sheet.dart';
import 'package:gymrats_app/widgets/weekly_rankings_tabs.dart';
import 'package:provider/provider.dart';

import '../support/auth_fakes.dart';

RankingEntry entry(
  int rank,
  String name, {
  int points = 10,
  bool me = false,
  int id = 0,
  int battles = 3,
}) => RankingEntry(
  rank: rank,
  userId: id == 0 ? rank : id,
  nickname: name,
  points: points,
  battles: battles,
  wins: battles == 0 ? 0 : 2,
  koWins: battles == 0 ? 0 : 1,
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
  Future<WeeklyRanking> fetchWeekly(
    RankingScope scope,
    ExerciseType exercise,
  ) async {
    if (fail) throw const ApiException(ApiErrorKind.network);
    return then.fetchWeekly(scope, exercise);
  }
}

class _Never implements RankingsRepository {
  @override
  Future<WeeklyRanking> fetchWeekly(
    RankingScope scope,
    ExerciseType exercise,
  ) => Completer<WeeklyRanking>().future;
}

void main() {
  late CharacterViewModel characters;

  setUp(() => characters = CharacterViewModel(store: MemoryCharacterStore()));

  /// The screen as the app shows it: my character from the app's
  /// [CharacterViewModel], and [auth] when given.
  Widget app(
    WeeklyRankingsViewModel Function() createViewModel, {
    AuthViewModel? auth,
  }) => MultiProvider(
    providers: [
      ChangeNotifierProvider<CharacterViewModel>.value(value: characters),
      if (auth != null)
        ChangeNotifierProvider<AuthViewModel>.value(value: auth),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      routes: {GymRatsApp.friendsRoute: (_) => const Text('friends page')},
      home: WeeklyRankingsScreen(createViewModel: createViewModel),
    ),
  );

  Future<void> open(
    WidgetTester tester,
    RankingsRepository repository, {
    Size size = const Size(412, 915),
    bool settle = true,
    AuthViewModel? auth,
    DateTime Function()? now,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        // Wednesday of the week of week(), whatever today is.
        () => WeeklyRankingsViewModel(
          repository: repository,
          now: now ?? () => DateTime.utc(2026, 11, 25),
        ),
        auth: auth,
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  /// A tab by its name (my card also names the scope).
  Finder tab(String name) => find.descendant(
    of: find.byType(WeeklyRankingsTabs),
    matching: find.text(name),
  );

  Future<void> tapTab(WidgetTester tester, String name) async {
    await tester.tap(tab(name));
    await tester.pumpAndSettle();
  }

  /// The list row of [name].
  WeeklyRankingsListRow rowOf(WidgetTester tester, String name) =>
      tester.widget<WeeklyRankingsListRow>(
        find.ancestor(
          of: find.text(name),
          matching: find.byType(WeeklyRankingsListRow),
        ),
      );

  Finder inCard(String text) => find.descendant(
    of: find.byType(WeeklyRankingsMyCard),
    matching: find.text(text),
  );

  final global = week(RankingScope.global, [
    entry(1, '헬창', points: 25),
    entry(2, '쥐돌이', points: 18, me: true),
    entry(2, '근손실', points: 18),
  ], me: entry(2, '쥐돌이', points: 18, me: true));

  final friends = week(RankingScope.friends, [
    entry(1, '쥐돌이', points: 18, me: true),
    entry(2, '단짝', points: 6),
  ], me: entry(1, '쥐돌이', points: 18, me: true));

  InMemoryRankingsRepository globalOnly() => InMemoryRankingsRepository(
    rankings: {(RankingScope.global, ExerciseType.pushUp): global},
  );

  testWidgets('shows a spinner while reading, under the banner, tabs and ?', (
    tester,
  ) async {
    await open(tester, _Never(), settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(WeeklyRankingsBanner), findsOneWidget);
    expect(find.byType(WeeklyRankingsTabs), findsOneWidget);
    expect(find.byTooltip('점수 규칙'), findsOneWidget);
    expect(find.byType(WeeklyRankingsMyCard), findsNothing);
    // No week computed on the phone before the server's answer.
    final banner = tester.widget<WeeklyRankingsBanner>(
      find.byType(WeeklyRankingsBanner),
    );
    expect(
      (banner.weekName, banner.dates, banner.timeLeft),
      (null, null, null),
    );
  });

  testWidgets('the banner names the week, its dates, the time left and how '
      'far it has gone', (tester) async {
    await open(tester, globalOnly());
    expect(find.text('주간 랭킹'), findsOneWidget);
    expect(find.text('11월 4주차'), findsOneWidget);
    expect(find.text('11.23 (월) – 11.29 (일)'), findsOneWidget);
    // Wednesday 09:00 KST to Monday 00:00 KST.
    expect(find.text('4일 15시간 남음'), findsOneWidget);
    final banner = tester.widget<WeeklyRankingsBanner>(
      find.byType(WeeklyRankingsBanner),
    );
    expect(banner.progress, closeTo(57 / 168, 1e-9));
  });

  testWidgets('the time left is drawn again every minute', (tester) async {
    var now = DateTime.utc(2026, 11, 29, 14, 57, 30);
    await open(tester, globalOnly(), now: () => now);
    expect(find.text('2분 남음'), findsOneWidget);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('1분 남음'), findsOneWidget);
  });

  testWidgets('? opens the points rules; 확인 closes them', (tester) async {
    await open(tester, globalOnly());
    await tester.tap(find.byTooltip('점수 규칙'));
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyRankingsRulesSheet), findsOneWidget);
    for (final name in ['KO승', '승리', '무승부', '패배', '중간에 나감']) {
      expect(find.text(name), findsOneWidget);
    }
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyRankingsRulesSheet), findsNothing);
  });

  testWidgets('lists the global week under TOP 50, best first, a tie '
      'sharing its rank; no rules over the list', (tester) async {
    await open(tester, globalOnly());

    expect(find.textContaining('KO승'), findsNothing);
    expect(find.text('TOP 50'), findsOneWidget);
    expect(find.text('같은 점수는 같은 등수'), findsOneWidget);
    expect(find.byType(WeeklyRankingsListRow), findsNWidgets(3));
    expect(find.text('헬창'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.byType(WeeklyRankingsMeMark), findsOneWidget);
    // A tie shares the rank.
    expect(rowOf(tester, '근손실').rank, 2);
    expect(find.text('3전 2승 · KO 1'), findsNWidgets(4));
    // Best first.
    expect(
      tester.getTopLeft(find.text('헬창')).dy,
      lessThan(tester.getTopLeft(find.text('근손실')).dy),
    );
  });

  testWidgets('my row is lime with its rank on ink; the first is orange', (
    tester,
  ) async {
    await open(tester, globalOnly());
    final mine = tester.widget<WeeklyRankingsListRow>(
      find.byWidgetPredicate((w) => w is WeeklyRankingsListRow && w.isMe),
    );
    expect(mine.rankFill, AppColors.ink);
    expect(rowOf(tester, '헬창').rankFill, AppColors.warning);
    expect(rowOf(tester, '근손실').rankFill, AppColors.card);
  });

  testWidgets('my card: my character, the scope, my rank, points and the '
      'goal toward the row above', (tester) async {
    await open(tester, globalOnly());
    final figure = tester.widget<CharacterFigure>(
      find.descendant(
        of: find.byType(WeeklyRankingsMyCard),
        matching: find.byType(CharacterFigure),
      ),
    );
    expect(figure.characterId, characters.characterId);
    expect(inCard('전체'), findsOneWidget);
    expect(inCard('2'), findsOneWidget);
    expect(inCard('쥐돌이'), findsOneWidget);
    expect(inCard('18'), findsOneWidget);
    expect(inCard('3전 2승 · KO 1'), findsOneWidget);
    expect(find.text('1위까지 7점'), findsOneWidget);
    expect(find.byType(WeeklyRankingsGoalBar), findsOneWidget);
  });

  testWidgets('the friends tab shows the same points among friends', (
    tester,
  ) async {
    final repo = InMemoryRankingsRepository(
      rankings: {
        (RankingScope.global, ExerciseType.pushUp): global,
        (RankingScope.friends, ExerciseType.pushUp): friends,
      },
    );
    await open(tester, repo);

    await tapTab(tester, '친구');

    expect(find.text('단짝'), findsOneWidget);
    expect(find.text('헬창'), findsNothing);
    expect(find.text('나와 친구 1명'), findsOneWidget);
    expect(inCard('친구'), findsOneWidget);
    expect(find.text('2위보다 12점 앞섬'), findsOneWidget);
    expect(repo.reads, {
      (RankingScope.global, ExerciseType.pushUp): 1,
      (RankingScope.friends, ExerciseType.pushUp): 1,
    });

    await tapTab(tester, '전체');
    expect(find.text('헬창'), findsOneWidget);
    // Kept, not read again.
    expect(repo.reads[(RankingScope.global, ExerciseType.pushUp)], 1);
  });

  testWidgets('outside the top: my rank in my card, the goal at the last '
      'row, and the note says how to get listed', (tester) async {
    final top = week(RankingScope.global, [
      entry(1, '헬창', points: 25),
    ], me: entry(77, '쥐돌이', points: 1, me: true, id: 9));
    await open(
      tester,
      InMemoryRankingsRepository(
        rankings: {(RankingScope.global, ExerciseType.pushUp): top},
      ),
    );

    expect(inCard('77'), findsOneWidget);
    expect(find.text('1위까지 24점'), findsOneWidget);
    expect(find.text('50위 안에 들면 목록에 나와요'), findsOneWidget);
    // Not a second row under the list.
    expect(find.byType(WeeklyRankingsListRow), findsOneWidget);
    expect(find.byType(WeeklyRankingsMeMark), findsNothing);
  });

  testWidgets('before my first battle: – in my card under my account '
      'name, no note by TOP 50', (tester) async {
    final repository = ScriptedAuthRepository();
    await repository.logIn(loginId: 'woohyun', password: 'pw');
    final unranked = week(RankingScope.global, [entry(1, '헬창', points: 25)]);
    await open(
      tester,
      InMemoryRankingsRepository(
        rankings: {(RankingScope.global, ExerciseType.pushUp): unranked},
      ),
      auth: AuthViewModel(repository: repository),
    );
    expect(inCard('–'), findsOneWidget);
    expect(inCard('우현'), findsOneWidget);
    expect(inCard('이번 주 기록 없음'), findsOneWidget);
    expect(find.text('대결하면 순위에 올라요'), findsOneWidget);
    expect(find.text('TOP 50'), findsOneWidget);
    expect(find.text('같은 점수는 같은 등수'), findsNothing);
  });

  testWidgets('without an account in reach my card says 나', (tester) async {
    await open(
      tester,
      InMemoryRankingsRepository(
        rankings: {
          (RankingScope.global, ExerciseType.pushUp): week(
            RankingScope.global,
            [entry(1, '헬창', points: 25)],
          ),
        },
      ),
    );
    expect(inCard('나'), findsOneWidget);
  });

  testWidgets('an empty week says so in a card, without a list name', (
    tester,
  ) async {
    await open(tester, InMemoryRankingsRepository());
    expect(find.byType(WeeklyRankingsEmptyCard), findsOneWidget);
    expect(find.text('이번 주 온라인 대결 기록이 아직 없어요.'), findsOneWidget);
    expect(find.text('첫 승점을 올려 보세요!'), findsOneWidget);
    expect(find.text('친구 추가하러 가기'), findsNothing);
    expect(find.text('TOP 50'), findsNothing);
  });

  testWidgets('friends with only me: no goal, and a card that opens the '
      'friends page', (tester) async {
    final alone = week(RankingScope.friends, [
      entry(1, '쥐돌이', points: 19, me: true),
    ]);
    await open(
      tester,
      InMemoryRankingsRepository(
        rankings: {(RankingScope.friends, ExerciseType.pushUp): alone},
      ),
    );
    await tapTab(tester, '친구');

    expect(inCard('쥐돌이'), findsOneWidget);
    expect(inCard('1'), findsOneWidget);
    expect(find.byType(WeeklyRankingsGoalBar), findsNothing);
    expect(find.text('아직 비교할 친구가 없어요'), findsOneWidget);
    expect(find.byType(WeeklyRankingsListRow), findsNothing);
    await tester.tap(find.text('친구 추가하러 가기'));
    await tester.pumpAndSettle();
    expect(find.text('friends page'), findsOneWidget);
  });

  testWidgets('friends without a battle this week: – rows and the note', (
    tester,
  ) async {
    final quiet = week(RankingScope.friends, [
      entry(1, '근육곰', points: 0, battles: 0),
      entry(1, '쥐돌이', points: 0, battles: 0, me: true),
    ]);
    await open(
      tester,
      InMemoryRankingsRepository(
        rankings: {(RankingScope.friends, ExerciseType.pushUp): quiet},
      ),
    );
    await tapTab(tester, '친구');
    expect(find.text('나와 친구 1명'), findsOneWidget);
    expect(find.text('이번 주 아직 아무도 대결하지 않았어요'), findsOneWidget);
    expect(rowOf(tester, '근육곰').rankFill, AppColors.cardHigh);
    expect(
      find.descendant(
        of: find.byType(WeeklyRankingsListRow),
        matching: find.text('이번 주 기록 없음'),
      ),
      findsNWidgets(2),
    );
    expect(find.text('대결하면 점수가 쌓여요'), findsOneWidget);
  });

  testWidgets('a failed read offers to try again; the banner and tabs stay', (
    tester,
  ) async {
    final repo = _Failing(globalOnly());
    await open(tester, repo);

    expect(
      find.text(const ApiException(ApiErrorKind.network).message),
      findsOneWidget,
    );
    expect(find.byType(WeeklyRankingsBanner), findsOneWidget);
    expect(find.byType(WeeklyRankingsTabs), findsOneWidget);
    expect(find.byType(WeeklyRankingsMyCard), findsNothing);
    repo.fail = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('헬창'), findsOneWidget);
  });

  testWidgets('a row reads as one sentence', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester, globalOnly());
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
      InMemoryRankingsRepository(
        rankings: {(RankingScope.global, ExerciseType.pushUp): many},
      ),
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    // My standing still shows in my card.
    expect(inCard('77'), findsOneWidget);
  });

  testWidgets('only the rows scroll: the header, banner, tabs and my card '
      'stay', (tester) async {
    final many = week(RankingScope.global, [
      for (var i = 1; i <= 50; i++) entry(i, '선수$i', points: 1000 - i),
    ], me: entry(77, '쥐돌이', points: 1, me: true, id: 99));
    await open(
      tester,
      InMemoryRankingsRepository(
        rankings: {(RankingScope.global, ExerciseType.pushUp): many},
      ),
    );
    double top(Finder f) => tester.getTopLeft(f).dy;
    final title = top(find.text('주간 랭킹'));
    final tabs = top(tab('전체'));
    final weekLine = top(find.text('11.23 (월) – 11.29 (일)'));
    final card = top(find.byType(WeeklyRankingsMyCard));
    // The list's scrolling area, under its name.
    Rect list() => tester.getRect(
      find
          .ancestor(
            of: find.byType(WeeklyRankingsListRow).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final area = list();
    expect(area.top, greaterThan(tester.getBottomLeft(find.text('TOP 50')).dy));

    await tester.drag(find.text('선수3'), const Offset(0, -6000));
    await tester.pumpAndSettle();

    expect(top(find.text('주간 랭킹')), title);
    expect(top(tab('전체')), tabs);
    expect(top(find.text('11.23 (월) – 11.29 (일)')), weekLine);
    expect(top(find.byType(WeeklyRankingsMyCard)), card);
    // The last rows came up, under my card.
    expect(find.text('선수50'), findsOneWidget);
    expect(find.text('선수1'), findsNothing);
    // The list scrolled inside its own area, which stayed put.
    expect(list(), area);
  });

  testWidgets('pulling past the end does not stretch the rows', (tester) async {
    final many = week(RankingScope.global, [
      for (var i = 1; i <= 50; i++) entry(i, '선수$i', points: 1000 - i),
    ]);
    await open(
      tester,
      InMemoryRankingsRepository(
        rankings: {(RankingScope.global, ExerciseType.pushUp): many},
      ),
    );
    final row = find.text('선수3');

    // Pull down at the top, held, as a finger past the end would.
    final gesture = await tester.startGesture(tester.getCenter(row));
    await gesture.moveBy(const Offset(0, 300));
    await tester.pump();

    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a short list keeps its rows 46 high, 5 apart', (tester) async {
    await open(
      tester,
      InMemoryRankingsRepository(
        rankings: {(RankingScope.friends, ExerciseType.pushUp): friends},
      ),
    );
    await tapTab(tester, '친구');
    final rows = find.byType(WeeklyRankingsListRow);
    expect(rows, findsNWidgets(2));
    expect(tester.getSize(rows.at(0)).height, WeeklyRankingsListRow.height);
    expect(tester.getSize(rows.at(1)).height, WeeklyRankingsListRow.height);
    expect(
      tester.getTopLeft(rows.at(1)).dy - tester.getBottomLeft(rows.at(0)).dy,
      5,
    );
  });

  testWidgets('the tabs share one line, scope first, push-ups chosen', (
    tester,
  ) async {
    await open(tester, InMemoryRankingsRepository());
    expect(find.byType(SegmentedButton<ExerciseType>), findsNothing);
    expect(
      tester.getTopLeft(tab('전체')).dx,
      lessThan(tester.getTopLeft(tab('푸쉬업')).dx),
    );
    expect(
      tester.getCenter(tab('전체')).dy,
      closeTo(tester.getCenter(tab('푸쉬업')).dy, 1),
    );
    expect(tester.getCenter(tab('푸쉬업')).dy, tester.getCenter(tab('스쿼트')).dy);
    final tabs = tester.widget<WeeklyRankingsTabs>(
      find.byType(WeeklyRankingsTabs),
    );
    expect(
      (tabs.scope, tabs.exercise),
      (RankingScope.global, ExerciseType.pushUp),
    );
  });

  testWidgets('squats show their own ranking in each scope', (tester) async {
    final squats = week(RankingScope.global, [entry(1, '스쿼트왕', points: 40)]);
    final squatFriends = week(RankingScope.friends, [
      entry(1, '단짝', points: 9),
      entry(2, '쥐돌이', points: 3, me: true),
    ]);
    final repo = InMemoryRankingsRepository(
      rankings: {
        (RankingScope.global, ExerciseType.pushUp): global,
        (RankingScope.global, ExerciseType.squat): squats,
        (RankingScope.friends, ExerciseType.squat): squatFriends,
      },
    );
    await open(tester, repo);

    await tapTab(tester, '스쿼트');
    expect(find.text('스쿼트왕'), findsOneWidget);
    expect(find.text('헬창'), findsNothing);

    // The exercise stays when the scope changes.
    await tapTab(tester, '친구');
    expect(find.text('단짝'), findsOneWidget);
    expect(find.text('1위까지 6점'), findsOneWidget);
    expect(find.text('스쿼트왕'), findsNothing);

    await tester.tap(tab('전체'));
    await tapTab(tester, '푸쉬업');
    expect(find.text('헬창'), findsOneWidget);
    expect(repo.reads, {
      (RankingScope.global, ExerciseType.pushUp): 1,
      (RankingScope.global, ExerciseType.squat): 1,
      (RankingScope.friends, ExerciseType.squat): 1,
    });
  });

  testWidgets('back from the background in a new week, it reads again', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 25);
    final repo = globalOnly();
    await tester.pumpWidget(
      app(() => WeeklyRankingsViewModel(repository: repo, now: () => now)),
    );
    await tester.pumpAndSettle();
    final key = (RankingScope.global, ExerciseType.pushUp);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.reads[key], 1);

    // Monday after the week of week().
    now = DateTime.utc(2026, 11, 30, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.reads[key], 2);
    expect(find.text('헬창'), findsOneWidget);
  });

  group('no state overflows', () {
    final states = <String, (RankingScope, WeeklyRanking?)>{
      'my rank in the list': (RankingScope.global, global),
      'outside the top': (
        RankingScope.global,
        week(RankingScope.global, [
          for (var i = 1; i <= 50; i++)
            entry(i, '아주긴닉네임열두글자$i', points: 1000 - i),
        ], me: entry(63, '아주긴닉네임열두글자', points: 4, me: true, id: 99)),
      ),
      'before my first battle': (
        RankingScope.global,
        week(RankingScope.global, [entry(1, '헬창', points: 25)]),
      ),
      'friends': (RankingScope.friends, friends),
      'no friends': (
        RankingScope.friends,
        week(RankingScope.friends, [entry(1, '쥐돌이', points: 19, me: true)]),
      ),
      'an empty week': (RankingScope.global, null),
    };
    for (final (size, scale) in const [
      (Size(360, 780), 1.3),
      (Size(320, 640), 1.0),
    ]) {
      for (final MapEntry(key: name, value: (scope, ranking))
          in states.entries) {
        testWidgets('$name at ${size.width.toInt()}×${size.height.toInt()} '
            'text ×$scale', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await open(
            tester,
            InMemoryRankingsRepository(
              rankings: {(scope, ExerciseType.pushUp): ?ranking},
            ),
            size: size,
          );
          if (scope == RankingScope.friends) await tapTab(tester, '친구');
          expect(tester.takeException(), isNull);
          expect(find.byType(WeeklyRankingsMyCard), findsOneWidget);
        });
      }
    }
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
