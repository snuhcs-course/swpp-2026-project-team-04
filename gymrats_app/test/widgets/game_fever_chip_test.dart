import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/game_fever_chip.dart';

void main() {
  testWidgets('says the multiplier in dark letters on cyan', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: GameFeverChip(multiplier: 3)),
      ),
    );
    expect(find.text('FEVER ×3'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('FEVER ×3')).style!.color,
      AppColors.background,
    );
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    expect((box.decoration as ShapeDecoration).color, AppColors.fever);
  });
}
