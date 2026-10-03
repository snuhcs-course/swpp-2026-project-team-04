import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';

const _dialog = ExitDialog(
  title: 'title',
  message: 'message',
  leaveLabel: 'leave',
  stayLabel: 'stay',
);

void main() {
  bool? answer;

  /// A page whose 'ask' button shows [_dialog] and keeps the answer.
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
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  answer = await confirmExit(context, _dialog),
              child: const Text('ask'),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the dialog, answers it with [reply], and returns the answer.
  Future<bool?> ask(
    WidgetTester tester,
    Future<void> Function() reply,
  ) async {
    answer = null;
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    expect(find.byType(ExitDialog), findsOneWidget);
    await reply();
    await tester.pumpAndSettle();
    expect(find.byType(ExitDialog), findsNothing);
    return answer;
  }

  testWidgets('shows the words it is given under a pink exit icon', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    for (final words in ['title', 'message', 'leave', 'stay']) {
      expect(find.text(words), findsOneWidget, reason: words);
    }
    final icon = tester.widget<Icon>(find.byIcon(Icons.logout_rounded));
    expect(icon.color, AppColors.opponent);
    expect(
      tester.widget<Text>(find.text('title')).style!.fontFamily,
      AppFonts.headline,
    );
    expect(
      tester.widget<Text>(find.text('message')).style!.color,
      AppColors.textSecondary,
    );
    expect(
      tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
      AppColors.card,
    );
  });

  testWidgets('stay is a big lime button, leave pink words under it', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    final stay = find.ancestor(
      of: find.text('stay'),
      matching: find.byType(FilledButton),
    );
    final lime = tester.widget<Material>(
      find.descendant(of: stay, matching: find.byType(Material)),
    );
    expect(lime.color, AppColors.accent);
    final leave = tester.widget<TextButton>(
      find.ancestor(of: find.text('leave'), matching: find.byType(TextButton)),
    );
    expect(leave.style!.foregroundColor!.resolve({}), AppColors.opponent);
    expect(
      tester.getRect(stay).bottom,
      lessThan(tester.getRect(find.text('leave')).top),
    );
  });

  testWidgets('only the leave button answers true', (tester) async {
    await open(tester);
    expect(await ask(tester, () => tester.tap(find.text('leave'))), isTrue);
    expect(await ask(tester, () => tester.tap(find.text('stay'))), isFalse);
    // Outside the dialog, on the barrier.
    expect(
      await ask(tester, () => tester.tapAt(const Offset(5, 5))),
      isFalse,
    );
    expect(
      await ask(tester, () => tester.binding.handlePopRoute()),
      isFalse,
    );
  });

  testWidgets('the game and matching words', (tester) async {
    Future<void> show(ExitDialog dialog) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: dialog),
      ),
    );

    await show(const ExitDialog.game(opponentName: 'RepBot'));
    expect(find.text('게임에서 나갈까요?'), findsOneWidget);
    expect(find.text('RepBot과의 대결이 취소되고\n홈으로 돌아가요.'), findsOneWidget);
    expect(find.text('계속하기'), findsOneWidget);
    expect(find.text('게임 나가기'), findsOneWidget);

    await show(const ExitDialog.matching());
    expect(find.text('매칭을 취소할까요?'), findsOneWidget);
    expect(find.text('상대 찾기를 멈추고\n홈으로 돌아가요.'), findsOneWidget);
    expect(find.text('계속하기'), findsOneWidget);
    expect(find.text('매칭 취소'), findsOneWidget);
  });

  for (final size in const [Size(360, 640), Size(640, 360)]) {
    testWidgets('fits without overflow '
        '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      await open(tester, size: size);
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The Dialog widget spans the screen; its first Material is the card.
      final card = find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first;
      expect(
        tester.getSize(card).width,
        lessThanOrEqualTo(size.width - 2 * 32),
      );
      expect(tester.getSize(card).width, lessThanOrEqualTo(360));
      // Still reachable on the short landscape screen.
      await tester.ensureVisible(find.text('leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();
      expect(answer, isTrue);
    });
  }

  testWidgets('popToHome closes every screen above home, even one that '
      'blocks back', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('home'))),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('a'))),
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const PopScope(canPop: false, child: Scaffold(body: Text('b'))),
      ),
    );
    await tester.pumpAndSettle();

    popToHome(tester.element(find.text('b')));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('a'), findsNothing);
    expect(find.text('b'), findsNothing);
  });
}
