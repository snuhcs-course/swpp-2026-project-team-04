import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/square_close_button.dart';

void main() {
  testWidgets('an X in a 46 px card-colored square, with a tooltip', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: SquareCloseButton(tooltip: '닫기', onPressed: () => taps++),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byTooltip('닫기'), findsOneWidget);
    final style = tester.widget<IconButton>(find.byType(IconButton)).style!;
    expect(style.fixedSize!.resolve({}), const Size.square(46));
    expect(style.backgroundColor!.resolve({}), AppColors.card);

    await tester.tap(find.byType(SquareCloseButton));
    expect(taps, 1);
  });
}
