import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
