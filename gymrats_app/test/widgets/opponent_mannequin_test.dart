import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/widgets/opponent_mannequin.dart';

void main() {
  Future<void> show(WidgetTester tester, int moves) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 142,
          height: 128,
          child: OpponentMannequin(moves: moves),
        ),
      ),
    ),
  );

  /// The figure's painter; the stage under it never moves.
  RenderObject figure(WidgetTester tester) => tester.renderObject(
    find
        .descendant(
          of: find.byType(OpponentMannequin),
          matching: find.byType(CustomPaint),
        )
        .last,
  );

  /// The head, 8.4 across in the design's coordinates, centered near (x, y).
  PaintPattern headAt(double x, double y) => paints
    ..something(
      (method, arguments) =>
          method == #drawCircle &&
          arguments[1] == 8.4 &&
          ((arguments[0] as Offset) - Offset(x, y)).distance < 0.01,
    );

  testWidgets('stays at the top until the opponent moves', (tester) async {
    await show(tester, 0);
    expect(tester.hasRunningAnimations, isFalse);
    expect(figure(tester), headAt(24.6, 43.0));

    // The same count again is no new rep.
    await show(tester, 0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('dips to the bottom and back up once per rep', (tester) async {
    await show(tester, 0);
    await show(tester, 1);
    expect(tester.hasRunningAnimations, isTrue);

    // The bottom comes at 45% of the dip.
    await tester.pump(OpponentMannequin.dipDuration * 0.45);
    expect(figure(tester), headAt(18.2, 73.2));

    await tester.pumpAndSettle();
    expect(figure(tester), headAt(24.6, 43.0));

    await show(tester, 2);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(figure(tester), headAt(24.6, 43.0));
  });
}
