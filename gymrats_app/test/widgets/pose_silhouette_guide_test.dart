import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
