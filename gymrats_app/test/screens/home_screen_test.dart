import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/home_viewmodel.dart';
import 'package:gymrats_app/widgets/grid_background.dart';

import '../support/fakes.dart';

const _lastMatch = MatchRecord(
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: 24,
  opponentReps: 19,
);

/// The push-up drawing in the exercise card.
final _drawing = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.size == const Size(126, 70),
);

void main() {
  late FakeUserRepository repository;

  setUp(() {
    repository = FakeUserRepository()
      ..profile = const UserProfile(
        name: '우현',
        bestReps: 32,
        lastMatch: _lastMatch,
      );
  });

  /// Opens HomeScreen on a phone-sized screen, with a stub matching route
  /// that shows its argument.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomeScreen(
          createViewModel: () => HomeViewModel(repository: repository),
        ),
        routes: {
          GymRatsApp.matchingRoute: (context) => Scaffold(
            body: Text('matching ${ModalRoute.of(context)!.settings.arguments}'),
          ),
        },
      ),
    );
    // The first frame shows loading; this one shows what the load returned.
    await tester.pump();
  }

  testWidgets('shows the greeting, exercise card and start button', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(GridBackground), findsOneWidget);
    expect(find.text('안녕하세요, 우현님'), findsOneWidget);
    expect(find.text('오늘도 한 판,\n붙어볼까요?'), findsOneWidget);
    expect(find.text('종목 선택'), findsOneWidget);
    expect(find.text('60초 · 1v1'), findsOneWidget);
    expect(find.text('푸쉬업'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('개인 최고 32회'), findsOneWidget);
    expect(find.text('AI와 1v1 대결'), findsOneWidget);
    expect(find.text('60초 안에 더 많이 하면 승리'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byIcon(Icons.arrow_forward_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('exercise card: drawing on the left, text centered beside it', (
    tester,
  ) async {
    await open(tester);
    final card = tester.getRect(
      find.ancestor(of: find.text('푸쉬업'), matching: find.byType(Card)),
    );
    final drawing = tester.getRect(_drawing);
    final title = tester.getRect(find.text('푸쉬업'));
    final best = tester.getRect(find.text('개인 최고 32회'));
    final check = tester.getRect(find.byIcon(Icons.check_rounded));

    expect(drawing.size, const Size(126, 70));
    expect(title.left, greaterThan(drawing.right));
    expect(best.left, title.left);
    expect(best.top, greaterThan(title.bottom));
    // The name and the record together are centered on the drawing.
    expect(
      (title.top + best.bottom) / 2,
      moreOrLessEquals(drawing.center.dy, epsilon: 0.5),
    );
    // The check stays in the top right corner.
    expect(check.topRight, card.topRight + const Offset(-18, 18));
  });

  testWidgets('exercise card text: name 36, record 18, number 22', (
    tester,
  ) async {
    await open(tester);
    final name = tester.widget<Text>(find.text('푸쉬업')).style!;
    expect(name.fontFamily, AppFonts.headline);
    expect(name.fontSize, 36);

    final record =
        tester.widget<Text>(find.text('개인 최고 32회')).textSpan! as TextSpan;
    expect(record.style!.fontSize, 18);
    final number = record.children![1] as TextSpan;
    expect(number.text, '32');
    expect(number.style!.fontFamily, AppFonts.number);
    expect(number.style!.fontWeight, FontWeight.w700);
    expect(number.style!.fontSize, 22);
    expect(number.style!.color, AppColors.textPrimary);
  });

  testWidgets('push-up drawing scales its points but not its line widths', (
    tester,
  ) async {
    await open(tester);
    // The 72×40 design times 1.75; line widths stay 1.5 and 3.
    expect(
      tester.renderObject(_drawing),
      paints
        ..line(
          p1: const Offset(7, 63),
          p2: const Offset(122.5, 63),
          strokeWidth: 1.5,
        )
        ..circle(x: 17.5, y: 26.25, radius: 7.875, strokeWidth: 3)
        ..line(
          p1: const Offset(28, 31.5),
          p2: const Offset(112, 52.5),
          strokeWidth: 3,
        )
        ..line(
          p1: const Offset(31.5, 31.5),
          p2: const Offset(31.5, 59.5),
          strokeWidth: 3,
        )
        ..line(
          p1: const Offset(112, 52.5),
          p2: const Offset(115.5, 59.5),
          strokeWidth: 3,
        ),
    );
  });

  testWidgets('shows the latest match in one row, about 72 tall', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('최근 경기'), findsOneWidget);
    final card = find.ancestor(
      of: find.text('푸쉬업 · vs RepBot'),
      matching: find.byType(Card),
    );
    for (final text in ['승', '24', ':', '19', '나', '상대']) {
      expect(
        find.descendant(of: card, matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(tester.getSize(card).height, moreOrLessEquals(72, epsilon: 1));

    // Badge, names, my score, ':' and their score from left to right.
    final badge = tester.getRect(find.text('승'));
    final names = tester.getRect(find.text('푸쉬업 · vs RepBot'));
    final mine = tester.getRect(find.text('24'));
    final colon = tester.getRect(find.text(':'));
    final theirs = tester.getRect(find.text('19'));
    expect(badge.right, lessThan(names.left));
    expect(names.right, lessThan(mine.left));
    expect(mine.right, lessThan(colon.left));
    expect(colon.right, lessThan(theirs.left));

    // Each label sits centered under its number.
    final me = tester.getRect(find.text('나'));
    final them = tester.getRect(find.text('상대'));
    expect(me.top, greaterThanOrEqualTo(mine.bottom));
    expect(me.center.dx, moreOrLessEquals(mine.center.dx, epsilon: 0.5));
    expect(them.top, greaterThanOrEqualTo(theirs.bottom));
    expect(them.center.dx, moreOrLessEquals(theirs.center.dx, epsilon: 0.5));
  });

  testWidgets(
    'recent match: my score is big and white, theirs small and gray',
    (tester) async {
      await open(tester);
      final mine = tester.widget<Text>(find.text('24')).style!;
      expect(mine.fontFamily, AppFonts.number);
      expect(mine.fontWeight, FontWeight.w700);
      expect(mine.fontSize, 26);
      expect(mine.color, AppColors.textPrimary);
      final theirs = tester.widget<Text>(find.text('19')).style!;
      expect(theirs.fontFamily, AppFonts.number);
      expect(theirs.fontWeight, FontWeight.w700);
      expect(theirs.fontSize, 22);
      expect(theirs.color, AppColors.textSecondary);
      final colon = tester.widget<Text>(find.text(':')).style!;
      expect(colon.fontSize, lessThan(22));
      expect(colon.color, AppColors.textMuted);

      // 나 is dark text on a lime pill; 상대 is small gray text.
      final pill = tester.widget<DecoratedBox>(
        find
            .ancestor(of: find.text('나'), matching: find.byType(DecoratedBox))
            .first,
      );
      expect((pill.decoration as ShapeDecoration).color, AppColors.accent);
      final me = tester.widget<Text>(find.text('나')).style!;
      expect(me.fontSize, 11);
      expect(me.color, AppColors.background);
      final them = tester.widget<Text>(find.text('상대')).style!;
      expect(them.fontSize, 11);
      expect(them.color, AppColors.textSecondary);
    },
  );

  testWidgets('my score stays highlighted when I lose', (tester) async {
    repository.profile = const UserProfile(
      name: '우현',
      lastMatch: MatchRecord(
        exercise: ExerciseType.pushUp,
        opponentName: 'RepBot',
        myReps: 19,
        opponentReps: 24,
      ),
    );
    await open(tester);
    expect(find.text('패'), findsOneWidget);
    final mine = tester.widget<Text>(find.text('19')).style!;
    expect(mine.fontSize, 26);
    expect(mine.color, AppColors.textPrimary);
    final theirs = tester.widget<Text>(find.text('24')).style!;
    expect(theirs.fontSize, 22);
    expect(theirs.color, AppColors.textSecondary);
    // 나 stays under my score.
    expect(
      tester.getRect(find.text('나')).center.dx,
      moreOrLessEquals(tester.getRect(find.text('19')).center.dx, epsilon: 0.5),
    );
  });

  testWidgets('hides the recent match when there is none', (tester) async {
    repository.profile = const UserProfile(name: '우현');
    await open(tester);
    expect(find.text('최근 경기'), findsNothing);
    // No best record yet either.
    expect(find.text('개인 최고 —'), findsOneWidget);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    repository.gate = Completer();
    await open(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('AI와 1v1 대결'), findsNothing);
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('AI와 1v1 대결'), findsOneWidget);
  });

  testWidgets('a failed load shows a retry button that loads again', (
    tester,
  ) async {
    repository.error = Exception('offline');
    await open(tester);
    expect(find.text('정보를 불러오지 못했어요'), findsOneWidget);
    repository.error = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('안녕하세요, 우현님'), findsOneWidget);
    expect(repository.fetchCount, 2);
  });

  testWidgets('the start button opens matching for push-ups', (tester) async {
    await open(tester);
    await tester.tap(find.text('AI와 1v1 대결'));
    await tester.pumpAndSettle();
    expect(find.text('matching ${ExerciseType.pushUp}'), findsOneWidget);
  });

  testWidgets('fits a small phone without overflow', (tester) async {
    repository.profile = const UserProfile(
      name: '우현',
      bestReps: 999,
      lastMatch: MatchRecord(
        exercise: ExerciseType.pushUp,
        opponentName: 'RepBot with a very long name',
        myReps: 100,
        opponentReps: 99,
      ),
    );
    await open(tester, size: const Size(360, 640));
    // The row was laid out, so an overflow in it would have been reported.
    expect(find.text('99', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
