import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/widgets/battle_banner.dart';
import 'package:gymrats_app/widgets/battle_camera_area.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';

import 'battle_test_support.dart';

const _camera = Key('camera');

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
  bool readyPressed = false,
  VoidCallback? onSwitchCamera,
  double? setupProgress,
  bool settingUp = false,
  double setupLook = 0,
  bool reconnecting = false,
  double spin = 0,
  List<BattleFxCombo> combos = const [],
  double stageScale = 1,
}) async {
  // The test's screen is the area's, also when it is taller than the
  // default window, as while setting up.
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
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
            readyPressed: readyPressed,
            onSwitchCamera: onSwitchCamera,
            setupProgress: setupProgress,
            settingUp: settingUp,
            setupLook: setupLook,
            reconnecting: reconnecting,
            spin: spin,
            combos: combos,
            stageScale: stageScale,
          ),
        ),
      ),
      size: size,
    ),
  );
}

String _words(SetupReason reason, [List<BodyPart> parts = const []]) =>
    SetupStatus(
      reason: reason,
      isReady: false,
      readyProgress: 0,
      missingParts: parts,
    ).message;

/// The parts the setup checks for each exercise, in the order it names
/// them: the head first, then the exercise's own.
const _checked = {
  ExerciseType.pushUp: [
    BodyPart.head,
    BodyPart.shoulders,
    BodyPart.elbows,
    BodyPart.hands,
  ],
  ExerciseType.squat: [
    BodyPart.head,
    BodyPart.shoulders,
    BodyPart.hips,
    BodyPart.knees,
    BodyPart.ankles,
  ],
};

/// The setup's lines: every reason the checker gives, every one- and
/// two-part line of both exercises in its order and the whole-body line,
/// the online setup's own lines; and the countdown's and the squat round's
/// lines, shown in the small hint.
final _setupHints = <String>{
  for (final reason in SetupReason.values) _words(reason),
  const SetupStatus(
    reason: SetupReason.ready,
    isReady: true,
    readyProgress: 1,
  ).message,
  for (final parts in _checked.values) ...[
    for (final (i, one) in parts.indexed) ...[
      _words(SetupReason.missingParts, [one]),
      for (final two in parts.skip(i + 1))
        _words(SetupReason.missingParts, [one, two]),
    ],
    _words(SetupReason.missingParts, parts),
  ],
  '재연결 중 · 준비 상태 확인 중…',
  '상대 준비를 기다리는 중…',
  '자세 확인! 3초 후 자동으로 준비해요',
};

final _hints = <String>{
  ..._setupHints,
  // The online countdown's line and the squat round's.
  '10초 후 함께 시작',
  '일어선 상태 · 무릎 가까이 앉아 주세요',
  '앉은 상태 · 이제 일어서세요',
  '정면에서 전신이 보이도록 서 주세요',
};

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
      // The arena gives no way to leave then.
      await _pump(tester);
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

        testWidgets('the reconnect band fits ($where)', (tester) async {
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
        });
      }
    }
  });

  group('every setup hint fits its two lines at 1.3x text on a 360-wide '
      'phone', () {
    final hints = _hints;

    test('the list holds every named line the checker can give', () {
      expect(hints, contains('어깨, 팔꿈치가 화면에 안 보여요.'));
      expect(hints, contains('어깨, 엉덩이가 화면에 안 보여요.'));
      expect(hints, contains('몸 전체가 화면에 보이게 해 주세요.'));
      // 4 + 5 single parts, 6 + 10 pairs, the whole-body line, 11 more
      // reasons (ready twice) and 7 other lines.
      expect(hints.length, greaterThanOrEqualTo(40));
    });

    // The online round's lines (`OnlineBattleScreen._roundHint`): there is
    // no ready button then, so the hint has the row's whole width.
    const serverCodes = [
      'ALREADY_IN_MATCH',
      'ALREADY_QUEUED',
      'FORBIDDEN',
      'INVALID_AVATAR',
      'INVALID_PAYLOAD',
      'INVALID_STATE',
      'MATCH_NOT_FOUND',
      'QUEUE_NOT_FOUND',
      'RATE_LIMITED',
      'REP_CONFLICT',
      'REP_OUT_OF_ORDER',
      'REQUEST_ID_REUSED',
      'UNKNOWN_TYPE',
      'UNSUPPORTED_VERSION',
    ];
    // The session's other errors end the battle (phase failed): they show
    // whole on the ended page, never in this line.
    final roundHints = [
      '서버의 최종 결과를 기다리는 중…',
      '잘못된 서버 데이터를 무시했어요.',
      for (final code in serverCodes) '온라인 요청 오류: $code',
    ];

    testWidgets("the online round's lines, with no ready button", (
      tester,
    ) async {
      for (final hint in roundHints) {
        await _pump(tester, textScale: 1.3, onLeave: () {}, hint: hint);
        expect(tester.takeException(), isNull, reason: hint);
        final paragraph = tester.renderObject<RenderParagraph>(find.text(hint));
        expect(paragraph.didExceedMaxLines, isFalse, reason: hint);
      }
    });

    for (final readyLabel in ['시작', '준비', '준비 취소']) {
      testWidgets('beside "$readyLabel"', (tester) async {
        for (final hint in hints) {
          await _pump(
            tester,
            textScale: 1.3,
            onLeave: () {},
            hint: hint,
            readyLabel: readyLabel,
            onReady: () {},
            onSwitchCamera: () {},
            setupProgress: 0.3,
          );
          expect(tester.takeException(), isNull, reason: hint);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(hint),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: hint);
        }
      });
    }
  });

  group('the setup\'s large look (W2b 3-B)', () {
    // The camera's box while setting up on an S22, with the line on top.
    const setupSize = Size(360, 624);

    /// The large hint's band, and the large ready button's pill.
    Finder band(String hint) => find
        .ancestor(of: find.text(hint), matching: find.byType(SizedBox))
        .first;
    Finder pill(String label) => find
        .ancestor(of: find.text(label), matching: find.byType(Material))
        .first;

    testWidgets('the bar on top, the guidance in a large band under it, the '
        'camera switch under the band, the large ready button bottom right, '
        'the leave button as before; no small hint or ready button', (
      tester,
    ) async {
      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        onLeave: () {},
        hint: '카메라 앞에 서 주세요.',
        readyLabel: '준비',
        onReady: () {},
        onSwitchCamera: () {},
        setupProgress: 0.4,
      );
      // Inside the box under the 3 wide line: the bar 0 to 6, the band 14
      // to 68, 12 from the sides.
      expect(
        tester.getRect(band('카메라 앞에 서 주세요.')),
        const Rect.fromLTWH(12, 3 + 14, 336, 54),
      );
      final look =
          tester
                  .widget<DecoratedBox>(
                    find
                        .ancestor(
                          of: find.text('카메라 앞에 서 주세요.'),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(look.color, AppColors.card);
      expect(look.border, Border.all(color: AppColors.ink, width: 2));
      expect(
        tester.widget<Text>(find.text('카메라 앞에 서 주세요.')).style!.fontFamily,
        AppFonts.display,
      );
      expect(
        tester.widget<Text>(find.text('카메라 앞에 서 주세요.')).style!.fontSize,
        26,
      );
      expect(
        tester.getRect(_circle(Icons.cameraswitch_outlined)),
        const Rect.fromLTWH(304, 3 + 78, 44, 44),
      );
      expect(
        tester.getRect(pill('준비')),
        const Rect.fromLTRB(216, 624 - 14 - 52, 348, 624 - 14),
      );
      expect(tester.widget<Text>(find.text('준비')).style!.fontSize, 22);
      expect(
        tester.getRect(_circle(Icons.logout_rounded)),
        const Rect.fromLTWH(12, 624 - 14 - 44, 44, 44),
      );
      // Only one of each.
      expect(find.text('카메라 앞에 서 주세요.'), findsOneWidget);
      expect(find.text('준비'), findsOneWidget);
      expect(find.byIcon(Icons.cameraswitch_outlined), findsOneWidget);
      expect(find.bySemanticsLabel('자세 세팅 진행'), findsOneWidget);
    });

    testWidgets('the large ready button: lime to press, white to take the '
        'ready back, gray when it cannot be pressed', (tester) async {
      ShapeBorder shape(String label) =>
          tester.widget<Material>(pill(label)).shape!;
      Color fill(String label) => tester.widget<Material>(pill(label)).color!;
      Color words(String label) =>
          tester.widget<Text>(find.text(label)).style!.color!;

      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        readyLabel: '준비',
        onReady: () {},
      );
      expect(fill('준비'), AppColors.accent);
      expect(
        shape('준비'),
        const StadiumBorder(side: BorderSide(color: AppColors.ink, width: 2)),
      );
      expect(words('준비'), AppColors.ink);

      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        readyLabel: '준비 취소',
        onReady: () {},
        readyPressed: true,
      );
      expect(fill('준비 취소'), AppColors.card);
      expect(words('준비 취소'), AppColors.ink);

      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        readyLabel: '시작',
      );
      expect(fill('시작'), AppColors.card);
      expect(
        shape('시작'),
        const StadiumBorder(
          side: BorderSide(color: AppColors.border, width: 2),
        ),
      );
      expect(words('시작'), AppColors.textMuted);
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('시작')),
        matchesSemantics(
          label: '시작',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('pressing them while setting up', (tester) async {
      var ready = 0;
      var switched = 0;
      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        readyLabel: '준비',
        onReady: () => ready++,
        onSwitchCamera: () => switched++,
      );
      await tester.tap(find.text('준비'));
      await tester.tap(find.byIcon(Icons.cameraswitch_outlined));
      expect((ready, switched), (1, 1));
    });

    testWidgets('with nothing to say there is no band', (tester) async {
      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        readyLabel: '시작',
      );
      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.height == 54),
        findsNothing,
      );
    });

    testWidgets('a screen reader hears the large guidance whole when it '
        'changes', (tester) async {
      const longest = '팔을 펴고 푸시업 자세를 잡아 주세요.';
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        hint: longest,
      );
      expect(
        tester.getSemantics(find.text(longest)),
        matchesSemantics(label: longest, isLiveRegion: true),
      );
      handle.dispose();
    });

    // W2B-SPEC 4.2: in DoHyeon 26 four lines are wider than the band's 316
    // inside, and are shrunk to it on their one line; the rest fit as they
    // are.
    const tooWide = {
      '팔을 펴고 푸시업 자세를 잡아 주세요.': 343.7,
      '자세 확인! 3초 후 자동으로 준비해요': 339.5,
      '카메라에 조금 더 가까이 와 주세요.': 323.8,
      '몸 전체가 화면에 보이게 해 주세요.': 323.8,
    };

    testWidgets('the four wide lines measure as the design says and are '
        'shrunk to the band; the longest to about 23.9', (tester) async {
      for (final MapEntry(key: hint, value: width) in tooWide.entries) {
        await _pump(
          tester,
          size: setupSize,
          settingUp: true,
          setupLook: 1,
          hint: hint,
        );
        final natural = tester.getSize(find.text(hint)).width;
        expect(natural, closeTo(width, 1.5), reason: hint);
        final drawn = tester.getRect(find.text(hint));
        expect(drawn.width, closeTo(316, 0.01), reason: hint);
      }
      const longest = '팔을 펴고 푸시업 자세를 잡아 주세요.';
      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        hint: longest,
      );
      final scale =
          tester.getRect(find.text(longest)).width /
          tester.getSize(find.text(longest)).width;
      expect(26 * scale, closeTo(23.9, 0.15));
    });

    for (final textScale in [1.0, 1.3, 2.0]) {
      testWidgets('every setup line keeps to one line inside the band at '
          '${textScale}x text, and nothing overflows', (tester) async {
        final bandRect = Rect.fromLTWH(12 + 2, 3 + 14 + 2, 336 - 4, 54 - 4);
        for (final hint in _setupHints) {
          await _pump(
            tester,
            size: setupSize,
            textScale: textScale,
            settingUp: true,
            setupLook: 1,
            onLeave: () {},
            hint: hint,
            readyLabel: '준비 취소',
            onReady: () {},
            readyPressed: true,
            onSwitchCamera: () {},
            setupProgress: 0.3,
          );
          expect(tester.takeException(), isNull, reason: hint);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(hint),
          );
          // One line, and all of it: shrunk, never cut.
          expect(paragraph.maxLines, 1, reason: hint);
          expect(paragraph.didExceedMaxLines, isFalse, reason: hint);
          final drawn = tester.getRect(find.text(hint));
          expect(
            bandRect.inflate(0.01).contains(drawn.topLeft) &&
                bandRect.inflate(0.01).contains(drawn.bottomRight),
            isTrue,
            reason: '$hint at $textScale: $drawn',
          );
          if (textScale == 1 && !tooWide.containsKey(hint)) {
            expect(
              drawn.width,
              closeTo(tester.getSize(find.text(hint)).width, 0.01),
              reason: '$hint is not shrunk',
            );
          }
          // The large ready button grows with the text, from 132 x 52.
          final button = tester.getSize(pill('준비 취소'));
          expect(button.width, greaterThanOrEqualTo(132), reason: hint);
          expect(button.height, greaterThanOrEqualTo(52), reason: hint);
        }
      });
    }

    testWidgets('as the countdown begins the large things keep the setup\'s '
        'look while they fade, take no taps and are not read; the '
        'countdown\'s own come in, small', (tester) async {
      var ready = 0;
      var started = 0;
      var switched = 0;
      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        onLeave: () {},
        hint: '그대로 잠시 유지하세요.',
        readyLabel: '준비',
        onReady: () => ready++,
        onSwitchCamera: () => switched++,
        setupProgress: 0.9,
      );
      final bigReady = tester.getCenter(find.text('준비'));
      final bigSwitch = tester.getCenter(
        find.byIcon(Icons.cameraswitch_outlined),
      );
      // The countdown: other words, the bot's pressable 시작.
      await _pump(
        tester,
        size: setupSize,
        setupLook: 0.5,
        onLeave: () {},
        hint: '10초 후 함께 시작',
        readyLabel: '시작',
        onReady: () => started++,
      );
      // The setup's band, bar, switch and button as the setup left them.
      expect(find.text('그대로 잠시 유지하세요.'), findsOneWidget);
      expect(find.text('준비'), findsOneWidget);
      expect(find.byIcon(Icons.cameraswitch_outlined), findsOneWidget);
      // The bar is drawn as the setup left it (0.9 filled), half faded, and
      // read by no one.
      final bar = find.byWidgetPredicate(
        (w) => w is FractionallySizedBox && w.widthFactor == 0.9,
      );
      expect(bar, findsOneWidget);
      expect(
        tester
            .widgetList<Opacity>(
              find.ancestor(of: bar, matching: find.byType(Opacity)),
            )
            .first
            .opacity,
        0.5,
      );
      expect(find.bySemanticsLabel('자세 세팅 진행'), findsNothing);
      expect(
        tester.widget<Material>(pill('준비')).color,
        AppColors.accent,
        reason: 'the look it had',
      );
      Opacity around(Finder finder) => tester
          .widgetList<Opacity>(
            find.ancestor(of: finder, matching: find.byType(Opacity)),
          )
          .first;
      expect(around(find.text('준비')).opacity, 0.5);
      // The countdown's small hint and button, coming in.
      expect(find.text('10초 후 함께 시작'), findsOneWidget);
      expect(around(find.text('10초 후 함께 시작')).opacity, 0.5);
      expect(around(find.text('시작')).opacity, 0.5);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('준비'), findsNothing);
      expect(find.bySemanticsLabel('그대로 잠시 유지하세요.'), findsNothing);
      handle.dispose();
      await tester.tapAt(bigReady);
      await tester.tapAt(bigSwitch);
      expect((ready, switched), (0, 0));
      await tester.tap(find.text('시작'));
      expect(started, 1);
      // Gone once faded.
      await _pump(
        tester,
        size: setupSize,
        onLeave: () {},
        hint: '10초 후 함께 시작',
        readyLabel: '시작',
        onReady: () => started++,
      );
      expect(find.text('그대로 잠시 유지하세요.'), findsNothing);
      expect(find.text('준비'), findsNothing);
      expect(find.byIcon(Icons.cameraswitch_outlined), findsNothing);
    });

    testWidgets('back to the setup they come in with its words, and take '
        'taps once all there', (tester) async {
      var ready = 0;
      Future<void> setup(double look) => _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: look,
        hint: '카메라 앞에 서 주세요.',
        readyLabel: '준비',
        onReady: () => ready++,
      );
      await setup(0.5);
      expect(find.text('카메라 앞에 서 주세요.'), findsOneWidget);
      await tester.tap(find.text('준비'), warnIfMissed: false);
      expect(ready, 0);
      await setup(1);
      await tester.tap(find.text('준비'));
      expect(ready, 1);
    });

    testWidgets('the large ready button stands above the system\'s bottom '
        'bar', (tester) async {
      await _pump(
        tester,
        size: setupSize,
        bottomInset: 24,
        settingUp: true,
        setupLook: 1,
        readyLabel: '준비',
        onReady: () {},
      );
      expect(tester.getRect(pill('준비')).bottom, 624 - 24 - 14);
    });
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
