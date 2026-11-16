import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/victory_motion.dart';
import 'package:gymrats_app/widgets/victory_overlay.dart';
import 'package:gymrats_app/widgets/victory_scene.dart';

import 'battle_test_support.dart';
import 'victory_test_support.dart';

/// The test's stand-in for the report: a ground, a button at the bottom
/// left, and the overlay over all of it, on a 360 x 780 screen.
class _Backdrop extends StatelessWidget {
  const _Backdrop({
    required this.result,
    this.characterId = 'mouse',
    this.play = true,
    this.reduceMotion = false,
    this.onButton,
    this.pictureKey,
    this.onEnd,
  });

  final VictoryResult result;
  final String characterId;
  final bool play;
  final bool reduceMotion;
  final VoidCallback? onButton;
  final Key? pictureKey;
  final VoidCallback? onEnd;

  static const buttonText = '홈으로';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: RepaintBoundary(
            key: pictureKey,
            child: ColoredBox(
              color: AppColors.background,
              child: Stack(
                children: [
                  Positioned(
                    left: 20,
                    bottom: 20,
                    child: OutlinedButton(
                      onPressed: onButton,
                      child: const Text(buttonText),
                    ),
                  ),
                  Positioned.fill(
                    child: VictoryOverlay(
                      result: result,
                      characterId: characterId,
                      seat: designSeat,
                      play: play,
                      onEnd: onEnd,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _show(WidgetTester tester, _Backdrop backdrop) async {
  tester.view
    ..physicalSize = designSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(backdrop);
  // The clock's first tick: 0 ms.
  await tester.pump();
}

VictoryPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(VictoryOverlay),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as VictoryPainter;

VictoryFrame _frame(WidgetTester tester) =>
    _painter(tester).frameIn(tester.getSize(find.byType(VictoryOverlay)));

/// Whether [frame] is the end look: the stand and the still end pose, open
/// and whole, nothing else.
bool _isEnd(VictoryFrame frame) =>
    frame.panel == null &&
    frame.band == null &&
    frame.confetti.isEmpty &&
    frame.stand?.scaleX == 1 &&
    frame.stand?.opacity == 1 &&
    (frame.figure?.still ?? false) &&
    frame.figure?.foot == const Offset(286, 168) &&
    frame.figure?.opacity == 1;

Finder _skip(String label) => find.bySemanticsLabel(label);

Future<ui.Image> _picture(WidgetTester tester, GlobalKey key) async {
  late ui.Image image;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    image = await boundary.toImage();
  });
  return image;
}

Future<Color> Function(double x, double y) _reader(
  WidgetTester tester,
  ui.Image image,
) {
  ByteData? bytes;
  return (x, y) async {
    await tester.runAsync(() async {
      bytes ??= await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    final i = (y.round() * image.width + x.round()) * 4;
    return Color.fromARGB(
      bytes!.getUint8(i + 3),
      bytes!.getUint8(i),
      bytes!.getUint8(i + 1),
      bytes!.getUint8(i + 2),
    );
  };
}

bool _near(Color a, Color b, {int by = 3}) =>
    ((a.r - b.r) * 255).abs() <= by &&
    ((a.g - b.g) * 255).abs() <= by &&
    ((a.b - b.b) * 255).abs() <= by;

/// Whether [c] is the panel: lime, a white stripe on lime, or between.
bool _isPanel(Color c) {
  final stripe = Color.alphaBlend(
    AppColors.card.withValues(alpha: 0.4),
    AppColors.accent,
  );
  bool between(double v, double a, double b) =>
      v * 255 >= (a < b ? a : b) * 255 - 2 &&
      v * 255 <= (a < b ? b : a) * 255 + 2;
  return between(c.r, AppColors.accent.r, stripe.r) &&
      between(c.g, AppColors.accent.g, stripe.g) &&
      between(c.b, AppColors.accent.b, stripe.b);
}

void main() {
  setUpAll(loadBattleFonts);

  group('a win (spec 3 and 4)', () {
    testWidgets('plays the cut-in, then sits the character on its seat at '
        '2100 ms', (tester) async {
      final semantics = tester.ensureSemantics();
      await _show(tester, const _Backdrop(result: VictoryResult.koWin));
      expect(_frame(tester).panel, isA<VictoryWipe>());
      expect(_skip(VictoryOverlay.skipWinLabel), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 900));
      final big = _frame(tester);
      expect(big.band!.text, 'KO 승리');
      expect(big.figure!.scale, closeTo(2.2, 1e-9));
      expect(big.figure!.timeMs, 380);
      expect(big.confetti, hasLength(22));
      // The painted band says nothing to a screen reader: the report says
      // the result.
      expect(find.bySemanticsLabel('KO 승리'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1199));
      expect(_frame(tester).panel, isA<VictoryShrink>());
      expect(_skip(VictoryOverlay.skipWinLabel), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      expect(_isEnd(_frame(tester)), isTrue);
      expect(_skip(VictoryOverlay.skipWinLabel), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      semantics.dispose();
    });

    for (final (result, words) in [
      (VictoryResult.koWin, 'KO 승리'),
      (VictoryResult.timeWin, '판정승'),
      (VictoryResult.leftWin, '기권승'),
    ]) {
      testWidgets('${result.name}: the band reads "$words"', (tester) async {
        await _show(tester, _Backdrop(result: result));
        await tester.pump(const Duration(milliseconds: 600));
        expect(_frame(tester).band!.text, words);
      });
    }

    testWidgets('paints the panel, the band and the character, then only '
        'the stand and the character on the seat', (tester) async {
      final key = GlobalKey();
      await _show(
        tester,
        _Backdrop(result: VictoryResult.koWin, pictureKey: key),
      );
      await tester.pump(const Duration(milliseconds: 900));
      var color = _reader(tester, await _picture(tester, key));
      // The panel over the report, the band's white and ink in its middle.
      expect(_isPanel(await color(20, 700)), isTrue);
      expect(_isPanel(await color(340, 60)), isTrue);
      var white = 0;
      var ink = 0;
      for (var x = 110.0; x <= 250; x += 4) {
        final c = await color(x, 207);
        if (_near(c, AppColors.card)) white++;
        if (_near(c, AppColors.ink, by: 30)) ink++;
      }
      expect(white, greaterThan(5));
      expect(ink, greaterThan(2));

      await tester.pump(const Duration(milliseconds: 1300));
      color = _reader(tester, await _picture(tester, key));
      // The report shows again; the lime stand under the character.
      expect(await color(20, 700), AppColors.background);
      expect(await color(340, 60), AppColors.background);
      expect(_near(await color(250, 171), AppColors.accent), isTrue);
      // Its ink edge, 2.5 wide inside its left side (x 244).
      expect(_near(await color(245, 171), AppColors.ink), isTrue);
      // The character inside the seat: ink outlines and its team lime.
      var inkInSeat = 0;
      for (var y = 70.0; y < 160; y += 3) {
        for (var x = 236.0; x < 340; x += 3) {
          if (_near(await color(x, y), AppColors.ink, by: 30)) inkInSeat++;
        }
      }
      expect(inkInSeat, greaterThan(20));
    });
  });

  group('a loss or a draw (spec 6)', () {
    testWidgets('frustrates once on a white stand, over the report, and '
        'stops at 760 ms', (tester) async {
      final semantics = tester.ensureSemantics();
      final key = GlobalKey();
      await _show(
        tester,
        _Backdrop(result: VictoryResult.lose, pictureKey: key),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final frame = _frame(tester);
      expect(frame.panel, isNull);
      expect(frame.band, isNull);
      expect(frame.confetti, isEmpty);
      expect(frame.figure!.timeMs, 300);
      expect(frame.figure!.foot, const Offset(286, 168));
      expect(_skip(VictoryOverlay.skipLabel), findsOneWidget);
      final color = _reader(tester, await _picture(tester, key));
      expect(await color(20, 700), AppColors.background);
      expect(_near(await color(250, 171), AppColors.card), isTrue);

      await tester.pump(const Duration(milliseconds: 459));
      expect(_skip(VictoryOverlay.skipLabel), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_isEnd(_frame(tester)), isTrue);
      expect(_skip(VictoryOverlay.skipLabel), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      semantics.dispose();
    });

    testWidgets('물렁범 stops at 820 ms; a draw is a loss\'s scene', (
      tester,
    ) async {
      await _show(
        tester,
        const _Backdrop(result: VictoryResult.draw, characterId: 'seal'),
      );
      await tester.pump(const Duration(milliseconds: 819));
      expect(_isEnd(_frame(tester)), isFalse);
      expect(_frame(tester).stand!.color, AppColors.card);
      await tester.pump(const Duration(milliseconds: 1));
      expect(_isEnd(_frame(tester)), isTrue);
      expect(_frame(tester).figure!.frame.expression, 'tongue');
    });
  });

  group('skipping, reduced motion and a past report (spec 8, 11.1)', () {
    testWidgets('a tap anywhere jumps to the end look, not to the report\'s '
        'button', (tester) async {
      final semantics = tester.ensureSemantics();
      var pressed = 0;
      await _show(
        tester,
        _Backdrop(result: VictoryResult.timeWin, onButton: () => pressed++),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(_Backdrop.buttonText), warnIfMissed: false);
      await tester.pump();
      expect(pressed, 0);
      expect(_isEnd(_frame(tester)), isTrue);
      expect(_skip(VictoryOverlay.skipWinLabel), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Now the report takes the tap.
      await tester.tap(find.text(_Backdrop.buttonText));
      expect(pressed, 1);
      semantics.dispose();
    });

    testWidgets('a screen reader skips with the button\'s action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _show(
        tester,
        const _Backdrop(result: VictoryResult.lose, characterId: 'bear'),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.getSemantics(_skip(VictoryOverlay.skipLabel)),
        matchesSemantics(
          label: VictoryOverlay.skipLabel,
          isButton: true,
          hasTapAction: true,
        ),
      );
      tester.semantics.tap(find.semantics.byLabel(VictoryOverlay.skipLabel));
      await tester.pump();
      expect(_isEnd(_frame(tester)), isTrue);
      semantics.dispose();
    });

    testWidgets('reduced motion turned on while it plays jumps to the end', (
      tester,
    ) async {
      await _show(tester, const _Backdrop(result: VictoryResult.koWin));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_isEnd(_frame(tester)), isFalse);
      await tester.pumpWidget(
        const _Backdrop(result: VictoryResult.koWin, reduceMotion: true),
      );
      expect(_isEnd(_frame(tester)), isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_isEnd(_frame(tester)), isTrue);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    for (final result in [VictoryResult.koWin, VictoryResult.draw]) {
      testWidgets('${result.name}: with reduced motion only the end look '
          'shows, from the start', (tester) async {
        final semantics = tester.ensureSemantics();
        await _show(tester, _Backdrop(result: result, reduceMotion: true));
        final frame = _frame(tester);
        expect(_isEnd(frame), isTrue);
        expect(
          frame.stand!.color,
          result.isWin ? AppColors.accent : AppColors.card,
        );
        expect(_skip(VictoryOverlay.skipWinLabel), findsNothing);
        expect(_skip(VictoryOverlay.skipLabel), findsNothing);
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.pump(const Duration(seconds: 3));
        expect(_isEnd(_frame(tester)), isTrue);
        semantics.dispose();
      });
    }

    testWidgets('a past report (play: false) shows only the end look and '
        'its button works at once', (tester) async {
      var pressed = 0;
      await _show(
        tester,
        _Backdrop(
          result: VictoryResult.koWin,
          characterId: 'penguin',
          play: false,
          onButton: () => pressed++,
        ),
      );
      expect(_isEnd(_frame(tester)), isTrue);
      expect(_frame(tester).figure!.frame.expression, 'win');
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tap(find.text(_Backdrop.buttonText));
      expect(pressed, 1);
    });

    testWidgets('it plays once: a rebuild after the end does not play it '
        'again', (tester) async {
      // The same callback throughout, so the button itself never animates.
      void tap() {}
      await _show(
        tester,
        _Backdrop(result: VictoryResult.koWin, onButton: tap),
      );
      await tester.pump(const Duration(milliseconds: 2100));
      expect(_isEnd(_frame(tester)), isTrue);
      // A new widget (not the same const one), so the overlay updates; then
      // reduced motion on and off again, so its dependencies change too.
      for (final reduceMotion in [false, true, false]) {
        await tester.pumpWidget(
          _Backdrop(
            result: VictoryResult.koWin,
            reduceMotion: reduceMotion,
            onButton: tap,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(_isEnd(_frame(tester)), isTrue, reason: '$reduceMotion');
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
    });

    testWidgets('turning play off while it plays jumps to the end', (
      tester,
    ) async {
      await _show(tester, const _Backdrop(result: VictoryResult.koWin));
      await tester.pump(const Duration(milliseconds: 700));
      expect(_isEnd(_frame(tester)), isFalse);
      await tester.pumpWidget(
        const _Backdrop(result: VictoryResult.koWin, play: false),
      );
      expect(_isEnd(_frame(tester)), isTrue);
      // The frame the clock asked for before it stopped, then none.
      await tester.pump(const Duration(milliseconds: 100));
      expect(_isEnd(_frame(tester)), isTrue);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    group('onEnd (the result screen takes the overlay away then)', () {
      testWidgets('is called once when the scene plays out', (tester) async {
        var ended = 0;
        await _show(
          tester,
          _Backdrop(result: VictoryResult.koWin, onEnd: () => ended++),
        );
        await tester.pump(const Duration(milliseconds: 2099));
        expect(ended, 0);
        await tester.pump(const Duration(milliseconds: 1));
        expect(ended, 1);
        await tester.pump(const Duration(seconds: 1));
        expect(ended, 1);
      });

      testWidgets('is called once when a tap skips it; a second tap does '
          'not call it again', (tester) async {
        var ended = 0;
        await _show(
          tester,
          _Backdrop(result: VictoryResult.lose, onEnd: () => ended++),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tapAt(const Offset(180, 400));
        expect(ended, 1);
        await tester.pump();
        await tester.tapAt(const Offset(180, 400));
        await tester.pump(const Duration(seconds: 1));
        expect(ended, 1);
      });

      testWidgets('is not called when it never plays, nor when reduced '
          'motion or play turned off stops it', (tester) async {
        var ended = 0;
        void onEnd() => ended++;
        for (final still in [
          _Backdrop(result: VictoryResult.koWin, play: false, onEnd: onEnd),
          _Backdrop(
            result: VictoryResult.koWin,
            reduceMotion: true,
            onEnd: onEnd,
          ),
        ]) {
          await _show(tester, still);
          await tester.pump(const Duration(seconds: 3));
        }
        expect(ended, 0);
        for (final stopped in [
          _Backdrop(result: VictoryResult.draw, play: false, onEnd: onEnd),
          _Backdrop(
            result: VictoryResult.draw,
            reduceMotion: true,
            onEnd: onEnd,
          ),
        ]) {
          // A fresh overlay plays, then is stopped.
          await tester.pumpWidget(const SizedBox.shrink());
          await _show(
            tester,
            _Backdrop(result: VictoryResult.draw, onEnd: onEnd),
          );
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pumpWidget(stopped);
          await tester.pump(const Duration(seconds: 1));
        }
        expect(ended, 0);
      });
    });

    testWidgets('RepBot\'s or an unknown id draws the default character', (
      tester,
    ) async {
      await _show(
        tester,
        const _Backdrop(result: VictoryResult.lose, characterId: 'bot'),
      );
      expect(_painter(tester).character.id, 'mouse');
      await tester.pumpWidget(
        const _Backdrop(result: VictoryResult.lose, characterId: 'nobody'),
      );
      expect(_painter(tester).character.id, 'mouse');
    });
  });

  group('the painter', () {
    test('repaints when what it shows changes', () {
      final clock = ValueNotifier<double>(0);
      addTearDown(clock.dispose);
      VictoryPainter painter({
        VictoryResult result = VictoryResult.koWin,
        String id = 'mouse',
        Offset seat = designSeat,
        bool over = false,
      }) {
        final rig = VictoryRig.standard;
        return VictoryPainter(
          rig: rig,
          character: rig.characterOf(id),
          result: result,
          seat: seat,
          clock: clock,
          over: over,
          bandStyle: const TextStyle(),
        );
      }

      final base = painter();
      expect(base.shouldRepaint(painter()), isFalse);
      expect(base.shouldRepaint(painter(result: VictoryResult.lose)), isTrue);
      expect(base.shouldRepaint(painter(id: 'seal')), isTrue);
      expect(base.shouldRepaint(painter(seat: Offset.zero)), isTrue);
      expect(base.shouldRepaint(painter(over: true)), isTrue);
    });

    testWidgets('paints every result at every golden time without an error, '
        'on the design\'s screen and on another', (tester) async {
      for (final size in [designSize, const Size(412, 915), Size.zero]) {
        for (final id in victoryIds) {
          for (final result in VictoryResult.values) {
            final clock = ValueNotifier<double>(0);
            final rig = VictoryRig.standard;
            final painter = VictoryPainter(
              rig: rig,
              character: rig.characterOf(id),
              result: result,
              seat: designSeat,
              clock: clock,
              over: false,
              bandStyle: const TextStyle(fontSize: 62),
            );
            for (final t in [0, 150, 300, 700, 1250, 1650, 1900, 2099]) {
              clock.value = t.toDouble();
              final recorder = ui.PictureRecorder();
              painter.paint(Canvas(recorder), size);
              recorder.endRecording().dispose();
            }
            clock.dispose();
          }
        }
      }
    });
  });
}
