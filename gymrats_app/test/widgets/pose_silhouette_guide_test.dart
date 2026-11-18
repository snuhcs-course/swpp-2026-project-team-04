import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/pose_silhouette_guide.dart';

void main() {
  testWidgets('guide describes framing and does not block camera controls', (
    tester,
  ) async {
    var tapped = false;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              TextButton(
                onPressed: () => tapped = true,
                child: const Text('camera control'),
              ),
              const PoseSilhouetteGuide(ready: false),
            ],
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('푸시업 준비 자세 안내: 경계선 안에 몸을 맞추세요'),
      findsOneWidget,
    );
    await tester.tap(find.text('camera control'));
    expect(tapped, isTrue);
    semantics.dispose();
  });

  Future<RenderObject> paintGuide(WidgetTester tester, bool ready) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 290,
          height: 387,
          child: PoseSilhouetteGuide(ready: ready),
        ),
      ),
    );
    return tester.renderObject(
      find.descendant(
        of: find.byType(PoseSilhouetteGuide),
        matching: find.byType(CustomPaint),
      ),
    );
  }

  testWidgets('the outline is twice as wide as before A9: 4 over 10 of ink, '
      'white while not ready', (tester) async {
    expect(
      await paintGuide(tester, false),
      paints
        ..path(style: PaintingStyle.fill)
        ..path(
          style: PaintingStyle.stroke,
          strokeWidth: 10,
          color: AppColors.ink,
        )
        ..path(
          style: PaintingStyle.stroke,
          strokeWidth: 4,
          color: Colors.white.withAlpha(220),
        ),
    );
  });

  testWidgets('once the pose fits the outline is status green', (tester) async {
    expect(
      await paintGuide(tester, true),
      paints
        ..path(style: PaintingStyle.fill)
        ..path(
          style: PaintingStyle.stroke,
          strokeWidth: 10,
          color: AppColors.ink,
        )
        ..path(
          style: PaintingStyle.stroke,
          strokeWidth: 4,
          color: AppColors.statusGood.withAlpha(220),
        ),
    );
  });
}
