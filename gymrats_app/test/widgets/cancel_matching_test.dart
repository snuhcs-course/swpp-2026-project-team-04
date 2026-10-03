import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/cancel_matching.dart';

void main() {
  testWidgets('only 매칭 취소 answers true', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  answer = await confirmCancelMatching(context),
              child: const Text('ask'),
            ),
          ),
        ),
      ),
    );

    /// Opens the dialog, answers it with [reply], and returns the answer.
    Future<bool?> ask(Future<void> Function() reply) async {
      answer = null;
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      expect(find.text('매칭을 취소할까요?'), findsOneWidget);
      await reply();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      return answer;
    }

    expect(await ask(() => tester.tap(find.text('매칭 취소'))), isTrue);
    expect(await ask(() => tester.tap(find.text('계속하기'))), isFalse);
    // Outside the dialog, on the barrier.
    expect(await ask(() => tester.tapAt(const Offset(5, 5))), isFalse);
    expect(await ask(() => tester.binding.handlePopRoute()), isFalse);
  });

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
