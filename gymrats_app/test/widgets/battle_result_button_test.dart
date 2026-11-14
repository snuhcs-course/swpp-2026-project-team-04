import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_result_button.dart';

import 'battle_test_support.dart';

/// 결과 보기 fully up.
const _up = BattleFxResultButton(opacity: 1, scale: 1);

/// The button in the middle of a box of [size], 12 from its sides, as the
/// battle screen puts it.
Future<void> _pump(
  WidgetTester tester, {
  BattleFxResultButton look = _up,
  VoidCallback? onPressed,
  Size size = const Size(360, 390),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    battleTestApp(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Material(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
              child: BattleResultButton(look: look, onPressed: onPressed),
            ),
          ),
        ),
      ),
      size: size,
    ),
  );
}

Finder get _button => find
    .ancestor(of: find.text('결과 보기'), matching: find.byType(Material))
    .first;

void main() {
  setUpAll(loadBattleFonts);

  testWidgets('lime with an ink edge, the words on the left and the arrow '
      'on the right, and it opens the result', (tester) async {
    var opened = 0;
    final handle = tester.ensureSemantics();
    await _pump(tester, onPressed: () => opened++);
    final material = tester.widget<Material>(_button);
    expect(material.color, AppColors.accent);
    expect(
      material.shape,
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: AppColors.ink, width: 2),
      ),
    );
    final rect = tester.getRect(_button);
    expect(rect.size, BattleResultButton.size);
    expect(rect.size, const Size(240, 58));
    final label = tester.widget<Text>(find.text('결과 보기'));
    expect(label.style!.fontFamily, AppFonts.display);
    expect(label.style!.color, AppColors.ink);
    final arrow = tester.getRect(find.byIcon(Icons.arrow_forward_rounded));
    expect(tester.getRect(find.text('결과 보기')).left, lessThan(arrow.left));
    expect(rect.right - arrow.right, 24);
    expect(
      tester.getSemantics(find.bySemanticsLabel('결과 보기')),
      matchesSemantics(label: '결과 보기', isButton: true, hasTapAction: true),
    );
    await tester.tap(find.text('결과 보기'));
    expect(opened, 1);
    handle.dispose();
  });

  testWidgets('it comes up as the effect says: faded and smaller', (
    tester,
  ) async {
    await _pump(
      tester,
      look: const BattleFxResultButton(opacity: 0.5, scale: 0.8),
      onPressed: () {},
    );
    expect(tester.getRect(_button).width, closeTo(240 * 0.8, 0.01));
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: _button, matching: find.byType(Opacity)).first,
          )
          .opacity,
      0.5,
    );
  });

  for (final scale in [1.3, 2.0]) {
    // The lower half of a 360 x 780 phone and of a small 320 x 640 one.
    for (final size in [const Size(360, 390), const Size(320, 320)]) {
      final width = size.width;
      testWidgets('it follows the system text size and fits the '
          '${width.toInt()} x ${size.height.toInt()} lower half at $scale', (
        tester,
      ) async {
        await _pump(tester, size: size, textScale: scale, onPressed: () {});
        expect(tester.takeException(), isNull);
        final button = tester.getRect(_button);
        expect(button.left, greaterThanOrEqualTo(12));
        expect(button.right, lessThanOrEqualTo(width - 12));
        expect(button.top, greaterThanOrEqualTo(0));
        expect(button.bottom, lessThanOrEqualTo(size.height));
        // At 1.3 the larger words still fit its least height.
        expect(button.height, scale < 2 ? 58 : greaterThan(58));
        final words = tester.getRect(find.text('결과 보기'));
        expect(words.left, greaterThanOrEqualTo(button.left));
        expect(
          words.right,
          lessThanOrEqualTo(
            tester.getRect(find.byIcon(Icons.arrow_forward_rounded)).left,
          ),
        );
      });
    }
  }
}
