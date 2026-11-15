import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/feedback/form_analyzer.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/form_fault_clip.dart';

/// The canvas calls of [demo]'s clip, [width] wide, at the start of its loop.
Future<List<(Symbol, List<dynamic>)>> _calls(
  WidgetTester tester,
  FormDemo demo, {
  double width = 250,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: FormFaultClip(demo: demo),
          ),
        ),
      ),
    ),
  );
  final calls = <(Symbol, List<dynamic>)>[];
  expect(
    find
        .descendant(
          of: find.byType(FormFaultClip),
          matching: find.byType(CustomPaint),
        )
        .first,
    paints..everything((method, args) {
      calls.add((method, args));
      return true;
    }),
  );
  return calls;
}

Iterable<Paint> _paints(List<(Symbol, List<dynamic>)> calls) =>
    calls.expand((c) => c.$2.whereType<Paint>());

/// [color] as a number: a painted color reads back as a new object.
int _argb(Color color) => color.toARGB32();

/// The figure's scale in a clip [width] wide and 150 high. A paint keeps
/// widths in single precision, so they are compared to 1e-6.
double _scale(double width) => math.min(width / 150, 150 / 110);

void main() {
  testWidgets('every example is ink on a light floor, amber only at fault, '
      'and nothing pink', (tester) async {
    for (final demo in FormDemo.values) {
      final colors = {
        for (final p in _paints(await _calls(tester, demo))) _argb(p.color),
      };
      expect(
        colors.difference({
          _argb(AppColors.pictogramFloor),
          _argb(AppColors.ink),
          _argb(AppColors.warning),
        }),
        isEmpty,
        reason: '$demo',
      );
      expect(colors, contains(_argb(AppColors.warning)), reason: '$demo');
      expect(
        colors,
        isNot(contains(_argb(AppColors.opponent))),
        reason: '$demo',
      );
    }
  });

  testWidgets('the figure keeps its shape at any width and stands on the '
      'bottom', (tester) async {
    for (final width in [250.0, 120.0]) {
      final calls = await _calls(tester, FormDemo.lockout, width: width);
      final scale = _scale(width);
      final scaled = calls.firstWhere((c) => c.$1 == #scale).$2;
      expect(scaled.first, closeTo(scale, 1e-9), reason: '$width');
      expect(
        scaled.length < 2 || scaled[1] == null || scaled[1] == scaled[0],
        isTrue,
      );
      final moved = calls.firstWhere((c) => c.$1 == #translate).$2;
      expect(moved[0], closeTo((width - 150 * scale) / 2, 1e-9));
      expect(moved[1], closeTo(150 - 110 * scale, 1e-9));
    }
  });

  testWidgets('the floor is a 1.5 px light line 20 px in from each side', (
    tester,
  ) async {
    final calls = await _calls(tester, FormDemo.lockout);
    final floor = calls.firstWhere((c) => c.$1 == #drawLine).$2;
    final y = 104 * _scale(250);
    expect(floor[0], Offset(20, y));
    expect(floor[1], Offset(230, y));
    expect(_argb((floor[2] as Paint).color), _argb(AppColors.pictogramFloor));
    expect((floor[2] as Paint).strokeWidth, 1.5);
  });

  testWidgets('a part at fault is amber at its width inside a 1.5 px ink '
      'edge; the rest is thin ink', (tester) async {
    final calls = await _calls(tester, FormDemo.lockout);
    final px = 1 / _scale(250);
    final limbs = [
      for (final c in calls.skip(1))
        if (c.$1 == #drawLine) (c.$2[0], c.$2[1], c.$2[2] as Paint),
    ];
    final amber = [
      for (final l in limbs)
        if (_argb(l.$3.color) == _argb(AppColors.warning)) l,
    ];
    // Both arm parts are at fault in a lockout.
    expect(amber, hasLength(2));
    for (final (from, to, paint) in amber) {
      expect(paint.strokeWidth, closeTo(6 * px, 1e-6));
      final edge = limbs.firstWhere(
        (l) =>
            l.$1 == from &&
            l.$2 == to &&
            _argb(l.$3.color) == _argb(AppColors.ink),
      );
      expect(edge.$3.strokeWidth, closeTo(9 * px, 1e-6));
      // The edge is drawn first, under the amber.
      expect(limbs.indexOf(edge), lessThan(limbs.indexOf((from, to, paint))));
    }
    final widths = {
      for (final l in limbs)
        if (_argb(l.$3.color) == _argb(AppColors.ink))
          (l.$3.strokeWidth / px).roundToDouble(),
    };
    // Neck and shin 6, the body to the knee 9, and the arms' 9 px edges.
    expect(widths, {6.0, 9.0});
  });

  testWidgets('a head at fault is amber in an ink ring; otherwise plain ink', (
    tester,
  ) async {
    final px = 1 / _scale(250);
    var circles = [
      for (final c in await _calls(tester, FormDemo.shallow))
        if (c.$1 == #drawCircle) (c.$2[1] as double, c.$2[2] as Paint),
    ];
    expect(circles, hasLength(2));
    expect(circles[0].$1, closeTo(8.2 * px, 1e-6));
    expect(_argb(circles[0].$2.color), _argb(AppColors.warning));
    expect(_argb(circles[1].$2.color), _argb(AppColors.ink));
    expect(circles[1].$2.style, PaintingStyle.stroke);
    expect(circles[1].$2.strokeWidth, closeTo(1.5 * px, 1e-6));

    circles = [
      for (final c in await _calls(tester, FormDemo.lockout))
        if (c.$1 == #drawCircle) (c.$2[1] as double, c.$2[2] as Paint),
    ];
    expect(circles, hasLength(1));
    expect(_argb(circles.single.$2.color), _argb(AppColors.ink));
    expect(circles.single.$2.style, PaintingStyle.fill);
  });

  testWidgets('a wall stands behind the standing push-up', (tester) async {
    final calls = await _calls(tester, FormDemo.upright);
    final wall = calls
        .where((c) => c.$1 == #drawLine)
        .map((c) => c.$2)
        .firstWhere((a) => a[0] == const Offset(28, 18));
    expect(wall[1], const Offset(28, 104));
    expect(_argb((wall[2] as Paint).color), _argb(AppColors.pictogramFloor));
    expect((wall[2] as Paint).strokeWidth, closeTo(1.5 / _scale(250), 1e-6));
  });

  testWidgets('a tap pauses and plays the example', (tester) async {
    await _calls(tester, FormDemo.knees);
    expect(find.text('예시 동작 · 누르면 멈춤'), findsOneWidget);
    await tester.tap(find.byType(FormFaultClip));
    await tester.pump();
    expect(find.text('예시 동작 · 누르면 재생'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('예시 동작 · 누르면 재생')).style!.color,
      AppColors.textSecondary,
    );
  });
}
