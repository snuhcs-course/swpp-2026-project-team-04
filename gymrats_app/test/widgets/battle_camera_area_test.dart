import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/setup_hint_short.dart';
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
  SetupHintShort? setupCue,
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
  BattleFxCameraFrame? frame,
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
            setupCue: setupCue,
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
            frame: frame,
          ),
        ),
      ),
      size: size,
    ),
  );
}

SetupStatus _status(
  SetupReason reason, {
  bool ready = false,
  List<BodyPart> parts = const [],
}) => SetupStatus(
  reason: reason,
  isReady: ready,
  readyProgress: 0,
  missingParts: parts,
);

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

/// Every setup cue (A9): every reason the checker gives, ready, a squat
/// outside the silhouette, every one- and two-part cue of both exercises in
/// its order and the whole-body one, and the online setup's own cues.
final _setupCues = <SetupHintShort>{
  for (final reason in SetupReason.values) SetupHintShort.of(_status(reason)),
  SetupHintShort.of(_status(SetupReason.ready, ready: true)),
  SetupHintShort.of(_status(SetupReason.ready), outsideSilhouette: true),
  for (final parts in _checked.values) ...[
    for (final (i, one) in parts.indexed) ...[
      SetupHintShort.of(_status(SetupReason.missingParts, parts: [one])),
      for (final two in parts.skip(i + 1))
        SetupHintShort.of(_status(SetupReason.missingParts, parts: [one, two])),
    ],
    SetupHintShort.of(_status(SetupReason.missingParts, parts: parts)),
  ],
  const SetupHintShort.reconnecting(),
  const SetupHintShort.waitingForOpponent(),
  SetupHintShort.autoReady(3),
};

/// The small hint's lines from the countdown on: the online countdown's.
/// The setup's are cues now (A9), and the squat round has none (spec 6).
final _hints = <String>{'재연결 중 · 준비 상태 확인 중…', '10초 후 함께 시작'};

/// The status frame (A9 spec 3): the 12 wide edge with no fill.
Finder _frame() => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).color == null &&
      (w.decoration as BoxDecoration).border is Border &&
      ((w.decoration as BoxDecoration).border! as Border).top.width ==
          BattleCameraArea.frameWidth,
);

/// The status frame's color, or null when there is none.
Color? _frameColor(WidgetTester tester) {
  if (_frame().evaluate().isEmpty) return null;
  final decoration =
      tester.widget<DecoratedBox>(_frame()).decoration as BoxDecoration;
  return (decoration.border! as Border).top.color;
}

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

  group('every countdown and round line fits its two lines at 1.3x text on '
      'a 360-wide phone', () {
    test('the list holds the online countdown\'s lines; the squat round '
        'has no line any more (A9 spec 6)', () {
      expect(_hints, contains('10초 후 함께 시작'));
      expect(_hints, isNot(contains('일어선 상태 · 무릎 가까이 앉아 주세요')));
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
        for (final hint in _hints) {
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

  group('the setup\'s large look (W2b 3-B, A9 spec 2)', () {
    // The camera's box while setting up on an S22, with the line on top.
    const setupSize = Size(360, 624);
    final tooClose = SetupHintShort.of(_status(SetupReason.tooClose));
    final noPerson = SetupHintShort.of(_status(SetupReason.noPerson));
    final held = SetupHintShort.of(_status(SetupReason.ready));

    /// The cue's band: the white box with the 3 ink edge around its lines.
    Finder band(String line) => find
        .ancestor(
          of: find.text(line),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == AppColors.card &&
                (w.decoration as BoxDecoration).border ==
                    Border.all(color: AppColors.ink, width: 3),
          ),
        )
        .first;

    /// The large ready button's pill.
    Finder pill(String label) => find
        .ancestor(of: find.text(label), matching: find.byType(Material))
        .first;

    /// The icon box: the 68 square in the cue's color.
    Finder iconBox() => find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == 68 && w.height == 68,
    );

    Color iconFill(WidgetTester tester) =>
        (tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: iconBox(),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration)
            .color!;

    double sizeOf(WidgetTester tester, String line) =>
        tester.widget<Text>(find.text(line)).style!.fontSize!;

    /// Clears the band, so the next cue shows at once, not after the hold.
    Future<void> clear(WidgetTester tester, {double textScale = 1}) => _pump(
      tester,
      size: setupSize,
      textScale: textScale,
      settingUp: true,
      setupLook: 1,
    );

    testWidgets('the bar on top, the cue\'s band 18 under the line with its '
        'icon box and two lines, the camera switch bottom right level with '
        'the leave button; no small hint', (tester) async {
      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        onLeave: () {},
        setupCue: noPerson,
        onSwitchCamera: () {},
        setupProgress: 0.4,
      );
      // Inside the box under the 3 wide line: the band from 18, 12 from the
      // sides; two lines of 76 on a 0.98 line, 14 above and below them
      // inside its 3 edge: about 183 tall.
      final rect = tester.getRect(band('카메라'));
      expect(rect.left, 12);
      expect(rect.top, 3 + 18);
      expect(rect.width, 336);
      // (Each line laid out to whole points: 74 of 74.48.)
      expect(rect.height, closeTo(3 + 14 + 2 * 0.98 * 76 + 14 + 3, 1.5));
      final look =
          tester.widget<DecoratedBox>(band('카메라')).decoration as BoxDecoration;
      expect(look.borderRadius, const BorderRadius.all(Radius.circular(22)));
      // The icon box: 68 square, 14 + 3 in from the band's left.
      expect(tester.getRect(iconBox()).left, 12 + 3 + 14);
      expect(tester.getSize(iconBox()), const Size(68, 68));
      expect(iconFill(tester), AppColors.danger);
      // The two short lines, 14 after the icon box, in Do Hyeon 76.
      for (final line in ['카메라', '앞으로']) {
        final text = tester.widget<Text>(find.text(line));
        expect(text.style!.fontFamily, AppFonts.display, reason: line);
        expect(text.style!.fontSize, 76, reason: line);
        expect(text.maxLines, 1, reason: line);
        expect(
          tester.getRect(find.text(line)).left,
          12 + 3 + 14 + 68 + 14,
          reason: line,
        );
      }
      // The long sentence is not on screen; there is no small hint.
      expect(find.text(noPerson.message), findsNothing);
      expect(
        tester.getRect(_circle(Icons.cameraswitch_outlined)),
        const Rect.fromLTWH(360 - 12 - 44, 624 - 14 - 44, 44, 44),
      );
      expect(
        tester.getRect(_circle(Icons.logout_rounded)),
        const Rect.fromLTWH(12, 624 - 14 - 44, 44, 44),
      );
      expect(find.byIcon(Icons.cameraswitch_outlined), findsOneWidget);
      expect(find.bySemanticsLabel('자세 세팅 진행'), findsOneWidget);
    });

    testWidgets('the hold bar only while the pose is held: 18 tall under the '
        'lines, filling with status green as the setup says', (tester) async {
      Finder holdFill(String line) => find.descendant(
        of: band(line),
        matching: find.byWidgetPredicate(
          (w) => w is FractionallySizedBox && w.widthFactor == 0.6,
        ),
      );
      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        setupCue: held,
        setupProgress: 0.6,
      );
      expect(holdFill('그대로'), findsOneWidget);
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(
                of: holdFill('그대로'),
                matching: find.byType(ColoredBox),
              ),
            )
            .color,
        AppColors.statusGood,
      );
      final bar = find
          .ancestor(of: holdFill('그대로'), matching: find.byType(SizedBox))
          .first;
      expect(tester.getSize(bar).height, 18);
      expect(
        tester.getRect(bar).top,
        greaterThan(tester.getRect(find.text('멈춰요')).bottom),
      );
      // About 213 tall with it.
      expect(
        tester.getSize(band('그대로')).height,
        closeTo(3 + 14 + 2 * 0.98 * 76 + 12 + 18 + 14 + 3, 1.5),
      );
      expect(iconFill(tester), AppColors.statusGood);

      // Not for a cue that is not held; the top bar alone shows the 0.6.
      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        setupCue: SetupHintShort.of(_status(SetupReason.ready, ready: true)),
        setupProgress: 0.6,
      );
      expect(find.text('완료!'), findsOneWidget);
      expect(holdFill('준비'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is FractionallySizedBox && w.widthFactor == 0.6,
        ),
        findsOneWidget,
      );
    });

    testWidgets('a notice is amber, with the connection icon', (tester) async {
      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        setupCue: const SetupHintShort.reconnecting(),
      );
      expect(iconFill(tester), AppColors.warning);
      expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);
    });

    testWidgets('each icon: the hand and the connection from Material, the '
        'others drawn in ink lines', (tester) async {
      final cues = {
        SetupCueIcon.check: held,
        SetupCueIcon.person: noPerson,
        SetupCueIcon.stepBack: tooClose,
        SetupCueIcon.stepCloser: SetupHintShort.of(_status(SetupReason.tooFar)),
        SetupCueIcon.phone: SetupHintShort.of(_status(SetupReason.phoneShaky)),
      };
      for (final MapEntry(key: icon, value: cue) in cues.entries) {
        await clear(tester);
        await _pump(
          tester,
          size: setupSize,
          settingUp: true,
          setupLook: 1,
          setupCue: cue,
        );
        final painter =
            tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: iconBox(),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as SetupCueIconPainter;
        expect(painter.icon, icon);
        expect(
          tester.getSize(
            find.descendant(of: iconBox(), matching: find.byType(CustomPaint)),
          ),
          const Size.square(44),
        );
        expect(
          find.descendant(of: iconBox(), matching: find.byType(CustomPaint)),
          paints..path(color: AppColors.ink, style: PaintingStyle.stroke),
        );
      }
      await clear(tester);
      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        setupCue: SetupHintShort.of(
          _status(SetupReason.missingParts, parts: [BodyPart.hands]),
        ),
      );
      expect(find.byIcon(Icons.back_hand_outlined), findsOneWidget);
      expect(
        const SetupCueIconPainter(SetupCueIcon.check)
            .shouldRepaint(const SetupCueIconPainter(SetupCueIcon.check)),
        isFalse,
      );
      expect(
        const SetupCueIconPainter(SetupCueIcon.check)
            .shouldRepaint(const SetupCueIconPainter(SetupCueIcon.phone)),
        isTrue,
      );
    });

    testWidgets('a screen reader hears the cue\'s whole sentence, in a live '
        'region, not its two short lines', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        setupCue: tooClose,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('조금 뒤로 물러나 주세요.')),
        matchesSemantics(label: '조금 뒤로 물러나 주세요.', isLiveRegion: true),
      );
      expect(find.bySemanticsLabel('한 걸음'), findsNothing);
      handle.dispose();
    });

    testWidgets('with no cue there is no band, and no frame', (tester) async {
      await _pump(tester, size: setupSize, settingUp: true, setupLook: 1);
      expect(iconBox(), findsNothing);
      expect(_frame(), findsNothing);
    });

    group('a cue keeps to its two lines on a 360-wide phone', () {
      test('as large as fits, up to 76: the size from the widest line', () {
        expect(
          BattleCameraArea.cueTextSize(widestAtMax: 200, room: 218),
          BattleCameraArea.cueMaxSize,
        );
        expect(BattleCameraArea.cueTextSize(widestAtMax: 218, room: 218), 76);
        // 76 x 218 / 256.3: cut to a tenth.
        expect(
          BattleCameraArea.cueTextSize(widestAtMax: 256.3, room: 218),
          64.6,
        );
        expect(BattleCameraArea.cueTextSize(widestAtMax: 0, room: 218), 76);
        expect(BattleCameraArea.cueMinSize, 56);
      });

      for (final textScale in [1.0, 1.3, 2.0]) {
        testWidgets('every cue at ${textScale}x text: one line each, the two '
            'alike, inside the band, at least 56 but for two missing parts '
            '(task.md W9 decision 7), nothing overflows', (tester) async {
          for (final cue in _setupCues) {
            await clear(tester, textScale: textScale);
            await _pump(
              tester,
              size: setupSize,
              textScale: textScale,
              settingUp: true,
              setupLook: 1,
              onLeave: () {},
              setupCue: cue,
              onSwitchCamera: () {},
              setupProgress: 0.3,
            );
            expect(tester.takeException(), isNull, reason: '$cue');
            final room = tester.getRect(band(cue.first)).deflate(3);
            for (final line in [cue.first, cue.second]) {
              final paragraph = tester.renderObject<RenderParagraph>(
                find.text(line),
              );
              expect(paragraph.maxLines, 1, reason: line);
              expect(paragraph.didExceedMaxLines, isFalse, reason: line);
              final drawn = tester.getRect(find.text(line));
              // The text's own width, all of it inside the band's edge.
              expect(
                paragraph.getMaxIntrinsicWidth(double.infinity),
                lessThanOrEqualTo(drawn.width + 0.01),
                reason: line,
              );
              expect(drawn.left, greaterThanOrEqualTo(room.left), reason: line);
              expect(
                drawn.left + paragraph.getMaxIntrinsicWidth(double.infinity),
                lessThanOrEqualTo(room.right - 16 + 0.01),
                reason: line,
              );
            }
            final size = sizeOf(tester, cue.first);
            expect(sizeOf(tester, cue.second), size, reason: '$cue');
            final twoParts = cue.first.contains('·');
            if (!twoParts) {
              expect(size, greaterThanOrEqualTo(56), reason: '$cue');
            }
            expect(size, lessThanOrEqualTo(76), reason: '$cue');
          }
        });
      }

      testWidgets('with the real Do Hyeon: short lines stay 76, 몸 전체가 / '
          '보이게 shrinks to about 64.6, 어깨·팔꿈치가 / 안 보여요 to about 44', (
        tester,
      ) async {
        Future<double> sized(SetupHintShort cue) async {
          await clear(tester);
          await _pump(
            tester,
            size: setupSize,
            settingUp: true,
            setupLook: 1,
            setupCue: cue,
          );
          return sizeOf(tester, cue.first);
        }

        expect(await sized(tooClose), 76);
        expect(
          await sized(
            SetupHintShort.of(
              _status(
                SetupReason.missingParts,
                parts: [BodyPart.shoulders, BodyPart.hips, BodyPart.knees],
              ),
            ),
          ),
          closeTo(64.6, 0.3),
        );
        expect(
          await sized(
            SetupHintShort.of(
              _status(SetupReason.missingParts, parts: [BodyPart.hips]),
            ),
          ),
          greaterThanOrEqualTo(56),
        );
        expect(
          await sized(
            SetupHintShort.of(
              _status(
                SetupReason.missingParts,
                parts: [BodyPart.shoulders, BodyPart.elbows],
              ),
            ),
          ),
          closeTo(44.1, 0.3),
        );
      });
    });

    group('a new cue waits until the one shown has been up for 600 ms '
        '(task.md W9 decision 1)', () {
      Future<void> show(WidgetTester tester, SetupHintShort cue) => _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        setupCue: cue,
        setupProgress: 0.5,
      );

      testWidgets('another cue that is not right shows only once the hold is '
          'over', (tester) async {
        await show(tester, tooClose);
        await tester.pump(const Duration(milliseconds: 100));
        await show(tester, noPerson);
        expect(find.text('한 걸음'), findsOneWidget);
        expect(find.text('카메라'), findsNothing);
        expect(_frameColor(tester), AppColors.danger);
        await tester.pump(const Duration(milliseconds: 499));
        expect(find.text('한 걸음'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.text('카메라'), findsOneWidget);
        expect(find.text('한 걸음'), findsNothing);
        expect(BattleCameraArea.cueHold, const Duration(milliseconds: 600));
      });

      testWidgets('the hold over, a new cue shows at once', (tester) async {
        await show(tester, tooClose);
        await tester.pump(const Duration(milliseconds: 700));
        await show(tester, noPerson);
        expect(find.text('카메라'), findsOneWidget);
      });

      testWidgets('a cue that says the setup is right shows at once, its '
          'frame green', (tester) async {
        await show(tester, tooClose);
        await tester.pump(const Duration(milliseconds: 100));
        await show(tester, held);
        expect(find.text('그대로'), findsOneWidget);
        expect(_frameColor(tester), AppColors.statusGood);
        // And it is held in turn: losing the pose 100 ms later waits.
        await tester.pump(const Duration(milliseconds: 100));
        await show(tester, tooClose);
        expect(find.text('그대로'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('한 걸음'), findsOneWidget);
        expect(_frameColor(tester), AppColors.danger);
      });

      testWidgets('a cue that came and went during the hold is never shown', (
        tester,
      ) async {
        await show(tester, tooClose);
        await tester.pump(const Duration(milliseconds: 100));
        await show(tester, noPerson);
        await tester.pump(const Duration(milliseconds: 100));
        await show(tester, tooClose);
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('한 걸음'), findsOneWidget);
        expect(find.text('카메라'), findsNothing);
      });

      testWidgets('the same cue with a new sentence takes it at once: the '
          'count to the auto ready', (tester) async {
        final handle = tester.ensureSemantics();
        await show(tester, SetupHintShort.autoReady(3));
        await tester.pump(const Duration(milliseconds: 100));
        await show(tester, SetupHintShort.autoReady(2));
        expect(find.bySemanticsLabel('자세 확인! 2초 후 자동으로 준비해요'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('no cue clears the band at once', (tester) async {
        await show(tester, tooClose);
        await _pump(tester, size: setupSize, settingUp: true, setupLook: 1);
        expect(find.text('한 걸음'), findsNothing);
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      });
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

    testWidgets('with a ready button (none since A6) the camera switch stands '
        'over it, and both can be pressed', (tester) async {
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
      expect(
        tester.getRect(pill('준비')),
        const Rect.fromLTRB(216, 624 - 14 - 52, 348, 624 - 14),
      );
      expect(
        tester.getRect(_circle(Icons.cameraswitch_outlined)).bottom,
        lessThan(tester.getRect(pill('준비')).top),
      );
      expect(tester.getRect(_circle(Icons.cameraswitch_outlined)).right, 348);
      await tester.tap(find.text('준비'));
      await tester.tap(find.byIcon(Icons.cameraswitch_outlined));
      expect((ready, switched), (1, 1));
    });

    testWidgets('as the countdown begins the large things keep the setup\'s '
        'look while they fade, take no taps and are not read; the '
        'countdown\'s own come in, small', (tester) async {
      var started = 0;
      var switched = 0;
      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        onLeave: () {},
        setupCue: held,
        onSwitchCamera: () => switched++,
        setupProgress: 0.9,
      );
      final bigSwitch = tester.getCenter(
        find.byIcon(Icons.cameraswitch_outlined),
      );
      // The countdown: other words, the bot's pressable 시작.
      await _pump(
        tester,
        size: setupSize,
        setupLook: 0.5,
        onLeave: () {},
        setupCue: noPerson,
        hint: '10초 후 함께 시작',
        readyLabel: '시작',
        onReady: () => started++,
        frame: BattleFxCameraFrame.good,
      );
      // The setup's band, bar and switch as the setup left them.
      expect(find.text('그대로'), findsOneWidget);
      expect(find.text('카메라'), findsNothing);
      expect(find.byIcon(Icons.cameraswitch_outlined), findsOneWidget);
      // The bar is drawn as the setup left it (0.9 filled), half faded, and
      // read by no one.
      final bar = find.byWidgetPredicate(
        (w) => w is FractionallySizedBox && w.widthFactor == 0.9,
      );
      expect(bar, findsNWidgets(2), reason: 'the top bar and the hold bar');
      Opacity around(Finder finder) => tester
          .widgetList<Opacity>(
            find.ancestor(of: finder, matching: find.byType(Opacity)),
          )
          .first;
      expect(around(bar.first).opacity, 0.5);
      expect(around(find.text('그대로')).opacity, 0.5);
      expect(find.bySemanticsLabel('자세 세팅 진행'), findsNothing);
      // The countdown's small hint and button, coming in, and the round's
      // frame: green while counting down.
      expect(find.text('10초 후 함께 시작'), findsOneWidget);
      expect(around(find.text('10초 후 함께 시작')).opacity, 0.5);
      expect(around(find.text('시작')).opacity, 0.5);
      expect(_frameColor(tester), AppColors.statusGood);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(held.message), findsNothing);
      handle.dispose();
      // Where the big switch was, the countdown's own button takes the tap.
      await tester.tapAt(bigSwitch);
      expect((switched, started), (0, 1));
      // Gone once faded.
      await _pump(
        tester,
        size: setupSize,
        onLeave: () {},
        hint: '10초 후 함께 시작',
        readyLabel: '시작',
        onReady: () => started++,
      );
      expect(find.text('그대로'), findsNothing);
      expect(find.byIcon(Icons.cameraswitch_outlined), findsNothing);
      expect(_frame(), findsNothing);
    });

    testWidgets('back to the setup they come in with its cue, and take '
        'taps once all there', (tester) async {
      var switched = 0;
      Future<void> setup(double look) => _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: look,
        setupCue: noPerson,
        onSwitchCamera: () => switched++,
      );
      await setup(0.5);
      expect(find.text('카메라'), findsOneWidget);
      await tester.tap(
        find.byIcon(Icons.cameraswitch_outlined),
        warnIfMissed: false,
      );
      expect(switched, 0);
      await setup(1);
      await tester.tap(find.byIcon(Icons.cameraswitch_outlined));
      expect(switched, 1);
    });

    testWidgets('the large ready button and the camera switch stand above '
        'the system\'s bottom bar', (tester) async {
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
      await _pump(
        tester,
        size: setupSize,
        bottomInset: 24,
        settingUp: true,
        setupLook: 1,
        onSwitchCamera: () {},
      );
      expect(
        tester.getRect(_circle(Icons.cameraswitch_outlined)).bottom,
        624 - 24 - 14,
      );
    });
  });

  group('the status frame (A9 spec 3)', () {
    const setupSize = Size(360, 624);

    testWidgets('while setting up it is the shown cue\'s: green when right, '
        'red when not, none for a notice; 12 wide inside the camera area', (
      tester,
    ) async {
      for (final (cue, color) in [
        (SetupHintShort.of(_status(SetupReason.ready)), AppColors.statusGood),
        (const SetupHintShort.waitingForOpponent(), AppColors.statusGood),
        (SetupHintShort.of(_status(SetupReason.tooFar)), AppColors.danger),
        (const SetupHintShort.reconnecting(), null),
      ]) {
        await _pump(
          tester,
          size: setupSize,
          settingUp: true,
          setupLook: 1,
          setupCue: cue,
          // The round's value is not used while setting up.
          frame: BattleFxCameraFrame.rejected,
        );
        expect(_frameColor(tester), color, reason: '$cue');
        await tester.pump(const Duration(milliseconds: 700));
      }
      await _pump(
        tester,
        size: setupSize,
        settingUp: true,
        setupLook: 1,
        setupCue: SetupHintShort.of(_status(SetupReason.noPerson)),
      );
      // Under the line, the whole camera area.
      expect(tester.getRect(_frame()), const Rect.fromLTWH(0, 3, 360, 621));
      final border =
          (tester.widget<DecoratedBox>(_frame()).decoration as BoxDecoration)
                  .border!
              as Border;
      expect(border.top.width, BattleCameraArea.frameWidth);
      expect(BattleCameraArea.frameWidth, 12);
    });

    testWidgets('from the countdown on it is the round\'s: green, amber, red '
        'or none', (tester) async {
      for (final (frame, color) in [
        (BattleFxCameraFrame.good, AppColors.statusGood),
        (BattleFxCameraFrame.average, AppColors.warning),
        (BattleFxCameraFrame.rejected, AppColors.danger),
        (null, null),
      ]) {
        await _pump(tester, onLeave: () {}, frame: frame);
        expect(_frameColor(tester), color, reason: '$frame');
      }
    });

    testWidgets('it lies over the camera, under the buttons, and takes no '
        'taps', (tester) async {
      var left = 0;
      await _pump(
        tester,
        onLeave: () => left++,
        frame: BattleFxCameraFrame.rejected,
      );
      final stack = tester.widget<Stack>(
        find
            .ancestor(of: find.byKey(_camera), matching: find.byType(Stack))
            .first,
      );
      final order = stack.children;
      final frameAt = order.indexWhere(
        (w) =>
            w is Positioned &&
            w.child is IgnorePointer &&
            (w.child as IgnorePointer).child is DecoratedBox,
      );
      expect(frameAt, 1, reason: 'right after the camera');
      expect(
        find.ancestor(of: _frame(), matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
      await tester.tap(find.byIcon(Icons.logout_rounded));
      expect(left, 1);
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
