import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/grid_background.dart';

void main() {
  testWidgets('draws faint lime lines every 28 px behind its child', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 280,
            height: 140,
            child: GridBackground(child: Text('content')),
          ),
        ),
      ),
    );
    expect(find.text('content'), findsOneWidget);

    final grid = tester.renderObject(
      find
          .descendant(
            of: find.byType(GridBackground),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    final color = AppColors.accent.withValues(alpha: 0.035);
    expect(
      grid,
      paints
        ..line(p1: Offset.zero, p2: const Offset(0, 140), color: color)
        ..line(
          p1: const Offset(28, 0),
          p2: const Offset(28, 140),
          color: color,
        ),
    );
    // 11 vertical lines (x = 0 to 280) and 6 horizontal (y = 0 to 140).
    expect(grid, paintsExactlyCountTimes(#drawLine, 17));
  });
}
