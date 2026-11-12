import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/player_avatar.dart';

void main() {
  Future<void> show(WidgetTester tester, PlayerAvatar avatar) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: Center(child: avatar)),
        ),
      );

  testWidgets('shows the first letter of the name in an ink ring', (
    tester,
  ) async {
    await show(
      tester,
      const PlayerAvatar(color: AppColors.accent, name: '우현', size: 100),
    );
    expect(find.text('우'), findsOneWidget);
    expect(tester.getSize(find.byType(PlayerAvatar)), const Size.square(100));
    final ring = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(PlayerAvatar),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration as BoxDecoration)
        .singleWhere((decoration) => decoration.border != null);
    expect((ring.border! as Border).top.color, AppColors.ink);
  });

  testWidgets('the halo is lime at 0.4 for me, pink at 0.3 for the '
      'opponent (palette B)', (tester) async {
    Color halo() =>
        (tester
                    .widgetList<DecoratedBox>(
                      find.descendant(
                        of: find.byType(PlayerAvatar),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .first
                    .decoration
                as BoxDecoration)
            .color!;
    await show(tester, const PlayerAvatar(color: AppColors.accent, name: '우현'));
    expect(halo(), AppColors.accent.withValues(alpha: 0.4));
    await show(
      tester,
      const PlayerAvatar(color: AppColors.opponent, name: 'RepBot'),
    );
    expect(halo(), AppColors.opponent.withValues(alpha: 0.3));
  });

  testWidgets('a bot shows a robot instead of a letter', (tester) async {
    await show(
      tester,
      const PlayerAvatar(color: AppColors.opponent, name: 'RepBot', isBot: true),
    );
    expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.smart_toy_rounded)).color,
      AppColors.ink,
    );
    expect(find.text('R'), findsNothing);
  });

  testWidgets('an unknown or empty name shows a person icon', (tester) async {
    await show(tester, const PlayerAvatar(color: AppColors.accent));
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    await show(tester, const PlayerAvatar(color: AppColors.accent, name: ''));
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
  });
}
