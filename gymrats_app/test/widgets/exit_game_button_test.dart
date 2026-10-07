import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/exit_game_button.dart';

void main() {
  testWidgets('게임 나가기 with an exit icon on a card-colored pill', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(child: ExitGameButton(onPressed: () => taps++)),
        ),
      ),
    );
    expect(find.text('게임 나가기'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

    final button = find.bySubtype<OutlinedButton>();
    final style = tester.widget<OutlinedButton>(button).style!;
    expect(style.backgroundColor!.resolve({}), AppColors.card);
    expect(style.foregroundColor!.resolve({}), AppColors.textPrimary);
    expect(style.side!.resolve({})!.color, AppColors.border);
    expect(style.shape!.resolve({}), isA<StadiumBorder>());
    // With its tap target, as tall as SetupScreen's round buttons.
    expect(tester.getSize(button).height, 48);

    await tester.tap(find.byType(ExitGameButton));
    expect(taps, 1);
  });
}
