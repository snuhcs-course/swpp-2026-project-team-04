import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/pose_silhouette_squat.dart';

void main() {
  testWidgets('standing guide announces whether the pose is ready', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 400,
          height: 600,
          child: StandingSilhouetteGuide(ready: false),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('스쿼트 준비 자세 안내: 정면을 보고 전신을 실루엣에 맞추세요'),
      findsOneWidget,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 400,
          height: 600,
          child: StandingSilhouetteGuide(ready: true),
        ),
      ),
    );
    expect(find.bySemanticsLabel('스쿼트 준비 자세 확인됨'), findsOneWidget);
    semantics.dispose();
  });

  Future<RenderObject> paintGuide(WidgetTester tester, bool ready) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 290,
          height: 387,
          child: StandingSilhouetteGuide(ready: ready),
        ),
      ),
    );
    return tester.renderObject(
      find.descendant(
        of: find.byType(StandingSilhouetteGuide),
        matching: find.byType(CustomPaint),
      ),
    );
  }

  testWidgets('every outline is twice as wide as before A9: 5 over 10 of '
      'ink, white while not ready', (tester) async {
    final guide = await paintGuide(tester, false);
    var outlines = paints..path(style: PaintingStyle.fill);
    // The body, the two forearms, the hands and the clasp.
    for (var i = 0; i < 4; i++) {
      outlines = outlines
        ..path(
          style: PaintingStyle.stroke,
          strokeWidth: 10,
          color: AppColors.ink,
        )
        ..path(
          style: PaintingStyle.stroke,
          strokeWidth: 5,
          color: AppColors.onInk.withAlpha(220),
        );
    }
    expect(guide, outlines);
  });

  testWidgets('once the pose fits the outlines are status green', (
    tester,
  ) async {
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
          strokeWidth: 5,
          color: AppColors.statusGood.withAlpha(220),
        ),
    );
  });
}
