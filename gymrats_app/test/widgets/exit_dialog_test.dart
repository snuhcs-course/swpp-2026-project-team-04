import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';

const _dialog = ExitDialog(
  title: 'title',
  message: 'message',
  leaveLabel: 'leave',
);

void main() {
  bool? answer;

  /// A page whose 'ask' button shows [dialog] and keeps the answer.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(412, 915),
    ExitDialog dialog = _dialog,
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
                  answer = await confirmExit(context, dialog),
              child: const Text('ask'),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the dialog, answers it with [reply], and returns the answer.
  Future<bool?> ask(WidgetTester tester, Future<void> Function() reply) async {
    answer = null;
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    expect(find.byType(ExitDialog), findsOneWidget);
    await reply();
    await tester.pumpAndSettle();
    expect(find.byType(ExitDialog), findsNothing);
    return answer;
  }

  testWidgets('shows the words it is given and 계속하기 under a pink exit '
      'icon', (tester) async {
    await open(tester);
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    for (final words in ['title', 'message', 'leave', '계속하기']) {
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

  testWidgets('계속하기 is a big lime button, leave pink words under it', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    final stay = find.ancestor(
      of: find.text('계속하기'),
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
    expect(await ask(tester, () => tester.tap(find.text('계속하기'))), isFalse);
    // Outside the dialog, on the barrier.
    expect(await ask(tester, () => tester.tapAt(const Offset(5, 5))), isFalse);
    expect(await ask(tester, () => tester.binding.handlePopRoute()), isFalse);
  });

  testWidgets('the game and matching words', (tester) async {
    Future<void> show(ExitDialog dialog) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: dialog),
      ),
    );

    await show(ExitDialog.game(opponentName: 'RepBot'));
    expect(find.text('게임에서 나갈까요?'), findsOneWidget);
    expect(find.text('RepBot 님과의 대결이 취소되고\n홈으로 돌아가요.'), findsOneWidget);
    expect(find.text('계속하기'), findsOneWidget);
    expect(find.text('게임 나가기'), findsOneWidget);

    await show(const ExitDialog.matching());
    expect(find.text('매칭을 취소할까요?'), findsOneWidget);
    expect(find.text('상대 찾기를 멈추고\n홈으로 돌아가요.'), findsOneWidget);
    expect(find.text('계속하기'), findsOneWidget);
    expect(find.text('매칭 취소'), findsOneWidget);
  });

  group('the game message writes the name with', () {
    String message(String name) =>
        ExitDialog.game(opponentName: name).message.split('의 대결').first;

    test('the rest of the sentence after it', () {
      expect(
        ExitDialog.game(opponentName: 'Mike').message,
        'Mike 님과의 대결이 취소되고\n홈으로 돌아가요.',
      );
      expect(
        ExitDialog.game(opponentName: '진영').message,
        '진영과의 대결이 취소되고\n홈으로 돌아가요.',
      );
    });

    test('the same words for a screen that builds its own dialog', () {
      for (final name in const ['진영', '초보', 'Mike', '']) {
        expect(
          ExitDialog.gameMessage(name),
          ExitDialog.game(opponentName: name).message,
        );
      }
    });

    test('와 after a Hangul syllable with no final letter', () {
      expect(message('AI 봇 · 초보'), 'AI 봇 · 초보와');
      expect(message('AI 봇 · 중수'), 'AI 봇 · 중수와');
      expect(message('AI 봇 · 고수'), 'AI 봇 · 고수와');
      // The first and the last plain syllables in Unicode.
      expect(message('가'), '가와');
      expect(message('하'), '하와');
    });

    test('과 after a Hangul syllable with a final letter', () {
      expect(message('진영'), '진영과');
      expect(message('우현'), '우현과');
      // The first and the last syllables with a final letter.
      expect(message('각'), '각과');
      expect(message('힣'), '힣과');
    });

    test('" 님과" after anything that is not a Hangul syllable', () {
      expect(message('RepBot'), 'RepBot 님과');
      expect(message('Mike'), 'Mike 님과');
      expect(message('rat7'), 'rat7 님과');
      expect(message('rat!'), 'rat! 님과');
      expect(message('rat🐀'), 'rat🐀 님과');
      // A Hangul letter alone is not a syllable.
      expect(message('ㅋ'), 'ㅋ 님과');
      // Below the syllables, where the count would read as no final letter.
      expect(message('David'), 'David 님과');
      expect(message('Fred'), 'Fred 님과');
      // Right past the last syllable, where it would read the same.
      expect(message('\u{D7A4}'), '\u{D7A4} 님과');
    });

    test('상대와 for no name', () {
      expect(message(''), '상대와');
    });
  });

  for (final size in const [Size(360, 640), Size(640, 360)]) {
    testWidgets('a 12-letter English name fits without overflow '
        '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      await open(
        tester,
        size: size,
        dialog: ExitDialog.game(opponentName: 'NightRunner7'),
      );
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('NightRunner7 님과의 대결이 취소되고\n홈으로 돌아가요.'), findsOneWidget);
      // Still reachable on the short landscape screen.
      await tester.ensureVisible(find.text('게임 나가기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('게임 나가기'));
      await tester.pumpAndSettle();
      expect(answer, isTrue);
    });
  }

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
