import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/accent_button.dart';

void main() {
  Future<void> show(WidgetTester tester, AccentButton button) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: Center(child: button)),
        ),
      );

  testWidgets('shows the title, the hint and an arrow, and reports taps', (
    tester,
  ) async {
    var taps = 0;
    await show(
      tester,
      AccentButton(title: 'Title', hint: 'Hint', onPressed: () => taps++),
    );
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    // Dark text on lime, the title in the headline font.
    final title = tester.widget<Text>(find.text('Title')).style!;
    expect(title.fontFamily, AppFonts.headline);
    expect(title.color, AppColors.background);

    await tester.tap(find.text('Title'));
    expect(taps, 1);
  });

  testWidgets('leaves the hint out when there is none', (tester) async {
    await show(tester, AccentButton(title: 'Title', onPressed: () {}));
    final column = tester.widget<Column>(
      find.ancestor(of: find.text('Title'), matching: find.byType(Column)),
    );
    expect(column.children, hasLength(1));
  });
}
