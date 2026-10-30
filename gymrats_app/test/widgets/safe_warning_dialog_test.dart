import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/safe_warning_dialog.dart';

/// Width and height from a PNG file's IHDR chunk.
(int, int) _pngSize(String path) {
  final bytes = File(path).readAsBytesSync();
  int at(int offset) =>
      bytes[offset] << 24 |
      bytes[offset + 1] << 16 |
      bytes[offset + 2] << 8 |
      bytes[offset + 3];
  return (at(16), at(20));
}

void main() {
  bool? seen;

  /// A page whose 'ask' button shows the warning and keeps its answer.
  Future<void> open(
    WidgetTester tester, {
    Duration? autoClose,
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    seen = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  seen = await showSafeWarning(context, autoClose: autoClose),
              child: const Text('ask'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    expect(find.byType(SafeWarningDialog), findsOneWidget);
  }

  final button = find.descendant(
    of: find.byType(SafeWarningDialog),
    matching: find.byType(FilledButton),
  );

  testWidgets('the picture on a lighter box, then 무리하지 마세요, the message '
      'and a lime 확인', (tester) async {
    await open(tester);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, SafeWarningDialog.picture);
    expect(image.semanticLabel, SafeWarningDialog.pictureLabel);
    final box = tester.widget<DecoratedBox>(
      find.ancestor(
        of: find.byType(Image),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((box.decoration as BoxDecoration).color, AppColors.cardHigh);
    expect(
      tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
      AppColors.card,
    );

    final theme = Theme.of(tester.element(find.byType(SafeWarningDialog)));
    expect(
      tester.widget<Text>(find.text('무리하지 마세요')).style,
      theme.textTheme.headlineSmall,
    );
    final message = find.text('무리해서 운동하면 몸을 다칠 수 있어요.\n몸 상태를 살피며 플레이해 주세요.');
    expect(tester.widget<Text>(message).style!.color, AppColors.textSecondary);
    expect(find.text('확인'), findsOneWidget);
    expect(find.text('확인을 누르면 자세 세팅을 시작할 수 있어요'), findsOneWidget);
    // FilledButton paints with the theme's primary, the lime accent.
    expect(theme.colorScheme.primary, AppColors.accent);

    // Top to bottom: picture, title, message, button, note.
    final order = [
      find.byType(Image),
      find.text('무리하지 마세요'),
      message,
      button,
      find.text('확인을 누르면 자세 세팅을 시작할 수 있어요'),
    ].map((f) => tester.getRect(f).top).toList();
    expect(order, orderedEquals([...order]..sort()));
  });

  testWidgets('확인 closes it and answers true', (tester) async {
    await open(tester);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(SafeWarningDialog), findsNothing);
    expect(seen, isTrue);
  });

  testWidgets('back closes it and answers false', (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SafeWarningDialog), findsNothing);
    expect(seen, isFalse);
  });

  testWidgets('removed some other way it answers null', (tester) async {
    await open(tester, autoClose: const Duration(seconds: 5));
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    expect(find.byType(SafeWarningDialog), findsNothing);
    expect(seen, isNull);
    // Its countdown went with it.
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('ask'), findsOneWidget);
  });

  testWidgets('a tap outside keeps it open', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(SafeWarningDialog), findsOneWidget);
    expect(seen, isNull);
    await tester.tap(button);
    await tester.pumpAndSettle();
  });

  testWidgets('with autoClose it counts down each second and closes itself '
      'with true', (tester) async {
    await open(tester, autoClose: const Duration(seconds: 3));
    expect(find.text('확인 (3)'), findsOneWidget);
    expect(find.text('3초 뒤 자동으로 닫혀요'), findsOneWidget);
    expect(find.text('확인을 누르면 자세 세팅을 시작할 수 있어요'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('확인 (2)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('확인 (1)'), findsOneWidget);
    expect(find.text('1초 뒤 자동으로 닫혀요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(SafeWarningDialog), findsNothing);
    expect(seen, isTrue);
  });

  testWidgets('확인 during the countdown answers once and stops it', (
    tester,
  ) async {
    await open(tester, autoClose: const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(seen, isTrue);
    // Had the countdown kept going, it would pop the page under it.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('ask'), findsOneWidget);
  });

  testWidgets('back during the countdown answers false and stops it', (
    tester,
  ) async {
    await open(tester, autoClose: const Duration(seconds: 5));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(seen, isFalse);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('ask'), findsOneWidget);
  });

  for (final size in [const Size(360, 640), const Size(640, 360)]) {
    testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} without '
        'overflow', (tester) async {
      await open(tester, size: size);
      expect(tester.takeException(), isNull);
      // The card, not the Dialog widget, which spans the whole screen.
      final card = tester.getRect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(card.width, lessThanOrEqualTo(360));
      // On a short screen it scrolls; 확인 is reachable at the bottom.
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(seen, isTrue);
    });
  }

  test('the picture ships at 1x, 2x and 3x, and pubspec lists its folder', () {
    expect(_pngSize('assets/images/safe_warning.png'), (240, 150));
    expect(_pngSize('assets/images/2.0x/safe_warning.png'), (480, 300));
    expect(_pngSize('assets/images/3.0x/safe_warning.png'), (720, 450));
    expect(SafeWarningDialog.picture, 'assets/images/safe_warning.png');
    // Line by line: a Windows checkout has CRLF line ends.
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    expect(pubspec.map((line) => line.trim()), contains('- assets/images/'));
  });
}
