import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/widgets/battle_banner.dart';
import 'package:gymrats_app/widgets/battle_camera_area.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';

import 'battle_test_support.dart';

const _camera = Key('camera');

/// 결과 보기 fully up.
const _up = BattleFxResultButton(opacity: 1, scale: 1, scrim: 0.62);

/// The lower half of a phone: 360 x 390 unless [size] says otherwise.
Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(360, 390),
  double textScale = 1,
  double bottomInset = 0,
  VoidCallback? onLeave,
  String? hint,
  String? readyLabel,
  VoidCallback? onReady,
  VoidCallback? onSwitchCamera,
  double? setupProgress,
  bool reconnecting = false,
  double spin = 0,
  BattleFxResultButton? resultButton,
  VoidCallback? onShowResult,
  List<BattleFxCombo> combos = const [],
  double stageScale = 1,
}) => tester.pumpWidget(
  battleTestApp(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
        padding: EdgeInsets.only(bottom: bottomInset),
      ),
      child: Material(
        child: BattleCameraArea(
          camera: const AspectRatio(
            aspectRatio: 3 / 4,
            child: ColoredBox(key: _camera, color: AppColors.textMuted),
          ),
          onLeave: onLeave,
          hint: hint,
          readyLabel: readyLabel,
          onReady: onReady,
          onSwitchCamera: onSwitchCamera,
          setupProgress: setupProgress,
          reconnecting: reconnecting,
          spin: spin,
          resultButton: resultButton,
          onShowResult: onShowResult,
          combos: combos,
          stageScale: stageScale,
        ),
      ),
    ),
    size: size,
  ),
);

/// The white circle of a round button, by its icon.
Finder _circle(IconData icon) => find.ancestor(
  of: find.byIcon(icon),
  matching: find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle,
  ),
);

const _band = '재연결 중 · 경기 시간은 계속 진행됩니다.';

/// The size of the combo mark that says [text], before it is turned.
Size _mark(WidgetTester tester, String text) => tester.getSize(
  find.ancestor(of: find.text(text), matching: find.byType(BattleBand)),
);

void main() {
  setUpAll(loadBattleFonts);

  group('BattleCameraArea', () {
    testWidgets('shows the camera whole, in the middle, under a 3 wide ink '
        'line', (tester) async {
      await _pump(tester);
      final area = tester.getRect(find.byType(BattleCameraArea));
      final camera = tester.getRect(find.byKey(_camera));
      // 3:4 in the 387 left under the line.
      expect(camera.height, 387);
      expect(camera.width, closeTo(387 * 3 / 4, 0.01));
      expect(camera.center.dx, closeTo(area.center.dx, 0.01));
      expect(camera.top, 3);
      final box =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(BattleCameraArea),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(box.color, AppColors.border);
      expect(
        box.border,
        const Border(top: BorderSide(color: AppColors.ink, width: 3)),
      );
    });

    testWidgets('with nothing to say it shows only the camera', (tester) async {
      await _pump(tester);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('the leave button: a 44 white circle with an ink edge at the '
        'bottom left, with room for a finger, that asks to leave', (
      tester,
    ) async {
      var asked = 0;
      final handle = tester.ensureSemantics();
      await _pump(tester, onLeave: () => asked++);
      final circle = tester.getRect(_circle(Icons.logout_rounded));
      expect(circle.size, const Size.square(44));
      expect(circle.left, 12);
      expect(390 - circle.bottom, 14);
      final look =
          tester.widget<DecoratedBox>(_circle(Icons.logout_rounded)).decoration
              as BoxDecoration;
      expect(look.color, AppColors.card);
      expect(look.border, Border.all(color: AppColors.ink, width: 1.5));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.logout_rounded)).color,
        AppColors.ink,
      );
      final button = find.bySemanticsLabel('게임 나가기');
      expect(tester.getSize(button), const Size.square(48));
      expect(
        tester.getSemantics(button),
        matchesSemantics(label: '게임 나가기', isButton: true, hasTapAction: true),
      );
      await tester.tap(button);
      expect(asked, 1);
      handle.dispose();
    });

    testWidgets('the leave button is gone once the battle has ended', (
      tester,
    ) async {
      await _pump(tester, resultButton: _up, onShowResult: () {});
      expect(find.byIcon(Icons.logout_rounded), findsNothing);
    });

    testWidgets('the hint: one line of ink on white with an ink edge, in the '
        'middle of the bottom, announced when it changes', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, onLeave: () {}, hint: '폰을 더 세워 주세요.');
      final hint = find.text('폰을 더 세워 주세요.');
      final box = find
          .ancestor(of: hint, matching: find.byType(DecoratedBox))
          .first;
      final look = tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
      expect(look.color, AppColors.card);
      expect(look.border, Border.all(color: AppColors.ink, width: 1.5));
      expect(look.borderRadius, const BorderRadius.all(Radius.circular(12)));
      final rect = tester.getRect(box);
      expect(rect.height, greaterThanOrEqualTo(44));
      expect(rect.center.dx, closeTo(180, 0.01));
      expect(
        rect.left,
        greaterThan(tester.getRect(_circle(Icons.logout_rounded)).right),
      );
      final text = tester.widget<Text>(hint);
      expect(text.maxLines, 2);
      expect(text.style!.color, AppColors.ink);
      expect(text.style!.fontWeight, FontWeight.w500);
      expect(
        tester.getSemantics(hint),
        matchesSemantics(label: '폰을 더 세워 주세요.', isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('the ready button: ink edged and pressable, or gray and not', (
      tester,
    ) async {
      var pressed = 0;
      await _pump(tester, readyLabel: '준비', onReady: () => pressed++);
      Material button() => tester.widget<Material>(
        find
            .ancestor(of: find.text('준비'), matching: find.byType(Material))
            .first,
      );
      expect(
        (button().shape! as StadiumBorder).side,
        const BorderSide(color: AppColors.ink, width: 2),
      );
      expect(tester.widget<Text>(find.text('준비')).style!.color, AppColors.ink);
      await tester.tap(find.text('준비'));
      expect(pressed, 1);
      final rect = tester.getRect(
        find
            .ancestor(of: find.text('준비'), matching: find.byType(Material))
            .first,
      );
      expect(360 - rect.right, 12);
      expect(rect.height, greaterThanOrEqualTo(44));

      await _pump(tester, readyLabel: '준비');
      expect(
        (button().shape! as StadiumBorder).side,
        const BorderSide(color: AppColors.border, width: 2),
      );
      expect(
        tester.widget<Text>(find.text('준비')).style!.color,
        AppColors.textMuted,
      );
      await tester.tap(find.text('준비'));
      expect(pressed, 1);
    });

    testWidgets('a screen reader hears whether the ready button can be '
        'pressed', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, readyLabel: '준비');
      expect(
        tester.getSemantics(find.bySemanticsLabel('준비')),
        matchesSemantics(label: '준비', isButton: true, hasEnabledState: true),
      );
      await _pump(tester, readyLabel: '준비 취소', onReady: () {});
      expect(
        tester.getSemantics(find.bySemanticsLabel('준비 취소')),
        matchesSemantics(
          label: '준비 취소',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('the camera switch sits at the top right, clear of the top '
        'band, only before the start', (tester) async {
      var switched = 0;
      await _pump(tester, onSwitchCamera: () => switched++);
      final circle = tester.getRect(_circle(Icons.cameraswitch_outlined));
      expect(circle.size, const Size.square(44));
      expect(360 - circle.right, 12);
      expect(circle.top, 3 + 44);
      await tester.tap(find.byIcon(Icons.cameraswitch_outlined));
      expect(switched, 1);
      await _pump(tester);
      expect(find.byIcon(Icons.cameraswitch_outlined), findsNothing);
    });

    testWidgets('the setup bar fills with lime under the line', (tester) async {
      await _pump(tester, setupProgress: 0.6);
      final fill = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.accent,
        ),
      );
      expect(fill.top, 3);
      expect(fill.height, 6);
      expect(fill.width, closeTo(360 * 0.6, 0.01));
      await _pump(tester, setupProgress: 1.4);
      expect(
        tester
            .getRect(
              find.byWidgetPredicate(
                (w) => w is ColoredBox && w.color == AppColors.accent,
              ),
            )
            .width,
        360,
      );
      await _pump(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.accent,
        ),
        findsNothing,
      );
    });

    testWidgets('the reconnect band: amber under the line, ink words that '
        'say the clock keeps running, a turning arc', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, reconnecting: true, spin: 90);
      final band = find
          .ancestor(of: find.text(_band), matching: find.byType(DecoratedBox))
          .first;
      final look =
          tester.widget<DecoratedBox>(band).decoration as BoxDecoration;
      expect(look.color, AppColors.warning);
      final rect = tester.getRect(band);
      expect(rect.top, 3);
      expect(rect.width, 360);
      expect(rect.height, greaterThanOrEqualTo(34));
      expect(tester.widget<Text>(find.text(_band)).style!.color, AppColors.ink);
      final arc = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byWidgetPredicate(
                (w) =>
                    w is CustomPaint && w.painter is BattleReconnectArcPainter,
              ),
              matching: find.byType(Transform),
            )
            .first,
      );
      // A quarter turn.
      expect(arc.transform.entry(0, 1), closeTo(-1, 1e-9));
      // The arena says it aloud when it begins; the band itself does not.
      expect(
        tester.getSemantics(find.text(_band)),
        matchesSemantics(label: _band),
      );
      handle.dispose();
    });

    testWidgets('the reconnect band takes the place of the setup bar', (
      tester,
    ) async {
      await _pump(tester, reconnecting: true, setupProgress: 0.5);
      expect(find.text(_band), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == AppColors.accent,
        ),
        findsNothing,
      );
    });

    testWidgets('결과 보기: lime with an ink edge in the middle of a dimmed '
        'camera, and it opens the result', (tester) async {
      var opened = 0;
      final handle = tester.ensureSemantics();
      await _pump(tester, resultButton: _up, onShowResult: () => opened++);
      final button = find
          .ancestor(of: find.text('결과 보기'), matching: find.byType(Material))
          .first;
      final material = tester.widget<Material>(button);
      expect(material.color, AppColors.accent);
      expect(
        material.shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: AppColors.ink, width: 2),
        ),
      );
      final rect = tester.getRect(button);
      expect(rect.size, const Size(240, 58));
      expect(rect.center.dx, closeTo(180, 0.01));
      expect(rect.center.dy, closeTo(3 + 387 / 2, 0.01));
      final label = tester.widget<Text>(find.text('결과 보기'));
      expect(label.style!.fontFamily, AppFonts.display);
      expect(label.style!.color, AppColors.ink);
      // The words on the left, the arrow on the right.
      expect(
        tester.getRect(find.text('결과 보기')).left,
        lessThan(tester.getRect(find.byIcon(Icons.arrow_forward_rounded)).left),
      );
      expect(
        rect.right -
            tester.getRect(find.byIcon(Icons.arrow_forward_rounded)).right,
        24,
      );
      // The camera behind it is covered with the background color.
      final scrim = tester.widget<ColoredBox>(
        find.byWidgetPredicate(
          (w) =>
              w is ColoredBox &&
              w.color == AppColors.background.withValues(alpha: 0.62),
        ),
      );
      expect(scrim, isNotNull);
      expect(
        tester.getSemantics(find.bySemanticsLabel('결과 보기')),
        matchesSemantics(label: '결과 보기', isButton: true, hasTapAction: true),
      );
      await tester.tap(find.text('결과 보기'));
      expect(opened, 1);
      handle.dispose();
    });

    testWidgets('결과 보기 comes up as the effect says, and is not there '
        'before', (tester) async {
      await _pump(tester, onShowResult: () {});
      expect(find.text('결과 보기'), findsNothing);
      await _pump(
        tester,
        resultButton: const BattleFxResultButton(
          opacity: 0.5,
          scale: 0.8,
          scrim: 0.2,
        ),
        onShowResult: () {},
      );
      final button = find
          .ancestor(of: find.text('결과 보기'), matching: find.byType(Material))
          .first;
      expect(tester.getRect(button).width, closeTo(240 * 0.8, 0.01));
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(of: button, matching: find.byType(Opacity)).first,
            )
            .opacity,
        0.5,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is ColoredBox &&
              w.color == AppColors.background.withValues(alpha: 0.2),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the buttons stand above the system\'s bottom bar', (
      tester,
    ) async {
      await _pump(tester, onLeave: () {}, bottomInset: 0);
      final plain = tester.getRect(_circle(Icons.logout_rounded));
      await _pump(tester, onLeave: () {}, bottomInset: 34);
      expect(
        tester.getRect(_circle(Icons.logout_rounded)).bottom,
        plain.bottom - 34,
      );
    });
  });

  group('BattleCameraArea follows the system text size', () {
    const longHint = '일어선 상태 · 무릎 가까이 앉아 주세요';

    testWidgets('its texts grow with it', (tester) async {
      await _pump(
        tester,
        onLeave: () {},
        hint: '폰을 더 세워 주세요.',
        readyLabel: '준비',
        onReady: () {},
      );
      final hint = tester.getSize(find.text('폰을 더 세워 주세요.'));
      final ready = tester.getSize(find.text('준비'));
      await _pump(
        tester,
        textScale: 2,
        onLeave: () {},
        hint: '폰을 더 세워 주세요.',
        readyLabel: '준비',
        onReady: () {},
      );
      expect(
        tester.getSize(find.text('폰을 더 세워 주세요.')).height,
        greaterThan(hint.height * 1.5),
      );
      expect(
        tester.getSize(find.text('준비')).width,
        closeTo(ready.width * 2, 1),
      );
    });

    for (final scale in [1.3, 2.0]) {
      for (final size in [const Size(360, 390), const Size(320, 320)]) {
        final where =
            '${size.width.toInt()} x ${size.height.toInt()} at $scale';

        testWidgets('before the start nothing overflows or overlaps ($where)', (
          tester,
        ) async {
          await _pump(
            tester,
            size: size,
            textScale: scale,
            onLeave: () {},
            hint: longHint,
            readyLabel: '준비 취소',
            onReady: () {},
            onSwitchCamera: () {},
            setupProgress: 0.6,
          );
          expect(tester.takeException(), isNull);
          final area = tester.getRect(find.byType(BattleCameraArea));
          final leave = tester.getRect(find.byIcon(Icons.logout_rounded));
          final hint = tester.getRect(
            find
                .ancestor(
                  of: find.text(longHint),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          final ready = tester.getRect(
            find
                .ancestor(
                  of: find.text('준비 취소'),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(leave.right, lessThanOrEqualTo(hint.left));
          expect(hint.right, lessThanOrEqualTo(ready.left));
          expect(hint.width, greaterThan(40));
          for (final rect in [leave, hint, ready]) {
            expect(rect.left, greaterThanOrEqualTo(area.left));
            expect(rect.right, lessThanOrEqualTo(area.right));
            expect(rect.bottom, lessThanOrEqualTo(area.bottom));
            expect(rect.top, greaterThanOrEqualTo(area.top));
          }
          // The whole label of the button shows.
          expect(
            tester.getRect(find.text('준비 취소')).width,
            lessThanOrEqualTo(ready.width),
          );
        });

        testWidgets('the reconnect band and 결과 보기 fit ($where)', (
          tester,
        ) async {
          await _pump(
            tester,
            size: size,
            textScale: scale,
            onLeave: () {},
            reconnecting: true,
            hint: longHint,
          );
          expect(tester.takeException(), isNull);
          final area = tester.getRect(find.byType(BattleCameraArea));
          final band = tester.getRect(
            find
                .ancestor(
                  of: find.text(_band),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          expect(band.width, area.width);
          expect(
            tester.getRect(find.text(_band)).height,
            lessThanOrEqualTo(band.height),
          );
          expect(
            band.bottom,
            lessThan(tester.getRect(find.byIcon(Icons.logout_rounded)).top),
          );

          await _pump(
            tester,
            size: size,
            textScale: scale,
            resultButton: _up,
            onShowResult: () {},
          );
          expect(tester.takeException(), isNull);
          final button = tester.getRect(
            find
                .ancestor(
                  of: find.text('결과 보기'),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(button.left, greaterThanOrEqualTo(area.left + 12));
          expect(button.right, lessThanOrEqualTo(area.right - 12));
          expect(button.top, greaterThanOrEqualTo(area.top));
          expect(button.bottom, lessThanOrEqualTo(area.bottom));
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
  });

  group('the combo marks (spec v2.2)', () {
    /// The combo marks of real reps once they have popped in: mine of
    /// [mine] in a row, the opponent's of [theirs].
    List<BattleFxCombo> marks({int? mine, int? theirs}) {
      final fx = BattleFxTimeline();
      BattleStageEvent good(BattleSide side, int combo) => BattleStageEvent(
        side: side,
        grade: GameGrade.good,
        points: 15,
        combo: combo,
      );
      if (mine != null) fx.rep(good(BattleSide.me, mine), 0);
      if (theirs != null) fx.rep(good(BattleSide.opponent, theirs), 0);
      return fx.frame(500).combos;
    }

    /// The slanted fill of the mark that says [text], as drawn.
    Rect fillOf(WidgetTester tester, String text) {
      final fill = find.descendant(
        of: find.ancestor(
          of: find.text(text),
          matching: find.byType(BattleBand),
        ),
        matching: find.byType(DecoratedBox),
      );
      final corners = [
        tester.getTopLeft(fill),
        tester.getTopRight(fill),
        tester.getBottomLeft(fill),
        tester.getBottomRight(fill),
      ];
      return Rect.fromPoints(
        Offset(
          corners.map((c) => c.dx).reduce((a, b) => a < b ? a : b),
          corners.map((c) => c.dy).reduce((a, b) => a < b ? a : b),
        ),
        Offset(
          corners.map((c) => c.dx).reduce((a, b) => a > b ? a : b),
          corners.map((c) => c.dy).reduce((a, b) => a > b ? a : b),
        ),
      );
    }

    // The area starts at the line, which the design has at y 390.
    const line = 390.0;

    testWidgets('sit in the top corners where the design puts them: "2 HIT" '
        'x 5 to 95, y 395 to 447', (tester) async {
      await _pump(tester, combos: marks(mine: 2, theirs: 2));
      expect(find.text('2 HIT'), findsNWidgets(2));
      await _pump(tester, combos: marks(mine: 2));
      final mine = fillOf(tester, '2 HIT');
      expect(mine.left, closeTo(5, 1.5));
      expect(mine.right, closeTo(95, 1.5));
      expect(mine.top, closeTo(395 - line, 1.5));
      expect(mine.bottom, closeTo(447 - line, 1.5));

      final band = find.byType(BattleBand);
      final myCorners = [
        tester.getTopLeft(band),
        tester.getTopRight(band),
        tester.getBottomLeft(band),
        tester.getBottomRight(band),
      ];
      await _pump(tester, combos: marks(theirs: 2));
      // The opponent's band is mine mirrored; only the slant leans the same
      // way on both, as in the design.
      final theirCorners = [
        tester.getTopRight(band),
        tester.getTopLeft(band),
        tester.getBottomRight(band),
        tester.getBottomLeft(band),
      ];
      for (var i = 0; i < 4; i++) {
        expect(theirCorners[i].dx, closeTo(360 - myCorners[i].dx, 0.01));
        expect(theirCorners[i].dy, closeTo(myCorners[i].dy, 0.01));
      }
      // With the slant its outer corner reaches further out than mine (the
      // design's own CSS does the same), still on the screen.
      final theirs = fillOf(tester, '2 HIT');
      expect(theirs.right, lessThan(360));
      expect(theirs.right, greaterThan(360 - 6));
      expect(theirs.top, closeTo(395 - line, 1.5));
      expect(theirs.bottom, closeTo(447 - line, 1.5));
    });

    testWidgets('"10 HIT" x 5 to 113, y 393 to 447, clear of the reject '
        'sign\'s tile from x 116', (tester) async {
      await _pump(tester, combos: marks(mine: 10));
      final mine = fillOf(tester, '10 HIT');
      expect(mine.left, closeTo(5, 1.5));
      expect(mine.right, closeTo(113, 1.5));
      expect(mine.right, lessThan(116));
      expect(mine.top, closeTo(393 - line, 1.5));
      expect(mine.bottom, closeTo(447 - line, 1.5));
    });

    testWidgets('go under the reconnect band: 34 lower at the design\'s text '
        'size', (tester) async {
      final level = [
        const BattleFxCombo(
          side: BattleSide.me,
          count: 2,
          opacity: 1,
          rotation: 0,
          scaleX: 1,
          scaleY: 1,
        ),
      ];
      await _pump(tester, combos: level);
      final top = tester.getTopLeft(find.byType(BattleBand)).dy;
      expect(top, closeTo(BattleFx.comboBelowLine, 0.01));
      await _pump(tester, combos: level, reconnecting: true);
      expect(
        tester.getTopLeft(find.byType(BattleBand)).dy,
        closeTo(top + BattleFx.reconnectBandHeight, 0.01),
      );
      expect(find.text(_band), findsOneWidget);
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('stay under the reconnect band when the system text size '
          'grows it ($scale x)', (tester) async {
        await _pump(
          tester,
          textScale: scale,
          reconnecting: true,
          combos: marks(mine: 3, theirs: 4),
        );
        expect(tester.takeException(), isNull);
        final band = tester.getRect(
          find.ancestor(of: find.text(_band), matching: find.byType(Row)),
        );
        for (final text in ['3 HIT', '4 HIT']) {
          expect(
            fillOf(tester, text).top,
            greaterThan(band.bottom),
            reason: text,
          );
        }
        // The marks themselves do not grow with the text.
        expect(_mark(tester, '3 HIT').height, BattleFx.bandBox(44).height);
      });
    }

    testWidgets('are sized with the stage: further from the line and the '
        'side on a larger stage', (tester) async {
      final level = [
        const BattleFxCombo(
          side: BattleSide.me,
          count: 2,
          opacity: 1,
          rotation: 0,
          scaleX: 1,
          scaleY: 1,
        ),
      ];
      await _pump(tester, combos: level, stageScale: 1.2);
      final band = tester.getRect(find.byType(BattleBand));
      expect(band.top, closeTo(14 * 1.2, 0.01));
      expect(band.left, closeTo(6 * 1.2, 0.01));
      expect(band.height, closeTo(BattleFx.bandBox(44).height * 1.2, 0.01));
    });

    testWidgets('none when there is no combo', (tester) async {
      await _pump(tester, reconnecting: true);
      expect(find.byType(BattleComboMark), findsNothing);
      expect(find.text(_band), findsOneWidget);
    });
  });

  group('BattleReconnectArcPainter', () {
    test('every number of the reviewed drawing is kept', () {
      expectReviewedDrawing(
        'reconnect arc',
        paintedOps(const BattleReconnectArcPainter(), const Size.square(16)),
      );
    });

    testWidgets('is three quarters of a circle, open at the top right', (
      tester,
    ) async {
      final picture = await paintPicture(
        tester,
        const CustomPaint(
          size: Size.square(64),
          painter: BattleReconnectArcPainter(),
        ),
        size: const Size.square(64),
      );
      // The arc has radius 24 around (32, 32) here.
      expect(picture.at(56, 32), AppColors.ink, reason: 'right');
      expect(picture.at(32, 56), AppColors.ink, reason: 'bottom');
      expect(picture.at(8, 32), AppColors.ink, reason: 'left');
      expect(picture.at(32, 8), AppColors.ink, reason: 'top');
      expect(picture.at(49, 15), AppColors.card, reason: 'the open quarter');
      expect(picture.at(32, 32), AppColors.card);
    });
  });
}
