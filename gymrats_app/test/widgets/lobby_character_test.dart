import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/widgets/character_motion.dart';
import 'package:gymrats_app/widgets/lobby_character.dart';

/// The design's home shots (W4 bundle `shots/home_three_<id>.png`, reduced
/// motion, 2x) cut to the character's room: x 20 to 340, y 154 to 424 of a
/// 360 x 780 phone with a three-button bar.
const _shotsDir = 'test/widgets/character_home_shots';
const _room = Size(320, 270);

/// A channel off by more than this counts as different (as the W3 shots).
const _pixelTolerance = 64;

/// The three flat tones of the lobby's backdrop in the shots, and the
/// smoothed edges between them: every channel in these ranges.
const _backdropLow = [218, 222, 230];
const _backdropHigh = [240, 242, 247];

const _ids = ['mouse', 'kangaroo', 'bear', 'penguin', 'seal'];

Future<void> _pump(
  WidgetTester tester, {
  String id = 'kangaroo',
  VoidCallback? onTap,
  bool still = false,
  Size size = _room,
}) => tester.pumpWidget(
  MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox.fromSize(
          size: size,
          child: LobbyCharacter(characterId: id, onTap: onTap ?? () {}),
        ),
      ),
    ),
  ),
);

/// The painter, also on a page another one covers.
LobbyCharacterPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(LobbyCharacter, skipOffstage: false),
                matching: find.byType(CustomPaint, skipOffstage: false),
              ),
            )
            .painter!
        as LobbyCharacterPainter;

double _clock(WidgetTester tester) => _painter(tester).clock.value;

/// What [painter] draws in the room, 2x, on a clear ground, as RGBA. The
/// design's canvas put the feet on a whole point (GYM마우스 at 180 for
/// 179.52), so the picture moves by that rounding; the app keeps the exact
/// place (the placement tests check it).
Future<Uint8List> _render(LobbyCharacterPainter painter) async {
  final foot = painter.placementIn(_room).foot.dx;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..scale(2)
    ..translate(foot.roundToDouble() - foot, 0);
  painter.paint(canvas, _room);
  final image = await recorder.endRecording().toImage(
    (_room.width * 2).toInt(),
    (_room.height * 2).toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return bytes!.buffer.asUint8List();
}

Future<Uint8List> _decode(File file) async {
  final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
  final image = (await codec.getNextFrame()).image;
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return bytes!.buffer.asUint8List();
}

/// How the app's rest picture of [id] differs from the design's shot:
/// [painted] pixels the app covers whole whose color is off, and [missed]
/// pixels the shot shows apart from the backdrop that the app leaves
/// empty, both as a share of the room.
Future<({double painted, double missed})> _against(
  String id,
  LobbyCharacterPainter painter,
) async {
  final shot = await _decode(File('$_shotsDir/$id.png'));
  final app = await _render(painter);
  var painted = 0;
  var missed = 0;
  for (var i = 0; i < shot.length; i += 4) {
    final backdrop = [
      for (var c = 0; c < 3; c++)
        shot[i + c] >= _backdropLow[c] && shot[i + c] <= _backdropHigh[c],
    ].every((inRange) => inRange);
    final alpha = app[i + 3];
    if (alpha == 255) {
      for (var c = 0; c < 3; c++) {
        if ((shot[i + c] - app[i + c]).abs() > _pixelTolerance) {
          painted++;
          break;
        }
      }
    } else if (alpha == 0 && !backdrop) {
      missed++;
    }
  }
  final pixels = shot.length / 4;
  return (painted: painted / pixels, missed: missed / pixels);
}

LobbyCharacterPainter _stillPainter(String id) => LobbyCharacterPainter(
  rig: CharacterRig.standard,
  art: CharacterRig.standard.art(id),
  motion: CharacterMotionRig.standard,
  clock: ValueNotifier(0),
  still: true,
);

void main() {
  testWidgets('the whole room is one button that opens 캐릭터 선택, named '
      'for the character (W4 spec 6)', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await _pump(tester, onTap: () => taps++);
    expect(
      tester.getSemantics(find.byType(LobbyCharacter)),
      matchesSemantics(
        label: '캐릭터 바꾸기, 지금 캐릭터 그루',
        isButton: true,
        hasTapAction: true,
      ),
    );
    // A corner far from the drawing is still the button.
    final room = tester.getRect(find.byType(LobbyCharacter));
    for (final point in [
      room.topLeft + const Offset(2, 2),
      room.center,
      room.bottomRight - const Offset(2, 2),
    ]) {
      await tester.tapAt(point);
    }
    expect(taps, 3);
    semantics.dispose();
  });

  testWidgets('each character is named by its W3 name', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final id in _ids) {
      await _pump(tester, id: id);
      expect(
        tester.getSemantics(find.byType(LobbyCharacter)).label,
        '캐릭터 바꾸기, 지금 캐릭터 ${CharacterRig.standard.art(id).name}',
      );
    }
    // An unknown id and RepBot's (no home motion) draw and name the
    // default mouse.
    for (final id in ['rabbit', 'bot']) {
      await _pump(tester, id: id);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: id);
      expect(_painter(tester).art.id, 'mouse', reason: id);
      expect(
        tester.getSemantics(find.byType(LobbyCharacter)).label,
        '캐릭터 바꾸기, 지금 캐릭터 GYM마우스',
        reason: id,
      );
    }
    semantics.dispose();
  });

  testWidgets('it does its exercise on its own clock, repainting alone', (
    tester,
  ) async {
    await _pump(tester);
    expect(_painter(tester).still, isFalse);
    final first = _painter(tester).frame;
    await tester.pump(const Duration(milliseconds: 400));
    expect(_clock(tester), closeTo(400, 1));
    final later = _painter(tester).frame;
    expect(later.pose, isNot(same(first.pose)));
    expect(tester.binding.hasScheduledFrame, isTrue);
    expect(
      find.descendant(
        of: find.byType(LobbyCharacter),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
  });

  testWidgets('with less motion it shows the rest picture and stays still', (
    tester,
  ) async {
    await _pump(tester, still: true);
    final rest = CharacterMotionRig.standard.characters['kangaroo']!.rest;
    expect(_painter(tester).frame, same(rest));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(_painter(tester).frame, same(rest));
    expect(_clock(tester), 0);
    // And moves again once it may.
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_painter(tester).still, isFalse);
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('a new character starts its motion from 0', (tester) async {
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(_clock(tester), closeTo(700, 1));
    await _pump(tester, id: 'bear');
    expect(_painter(tester).art.id, 'bear');
    expect(_clock(tester), 0);
    // Counted from the frame the character changed in.
    await tester.pump(const Duration(milliseconds: 50));
    expect(_clock(tester), closeTo(50, 1));
    // The same character again does not restart it.
    await _pump(tester, id: 'bear');
    await tester.pump(const Duration(milliseconds: 50));
    expect(_clock(tester), closeTo(100, 1));
  });

  /// Home with the character [id] holds, and a navigator to cover it.
  Future<GlobalKey<NavigatorState>> pumpCoverable(
    WidgetTester tester,
    ValueNotifier<String> id,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: id,
            builder: (_, value, _) =>
                LobbyCharacter(characterId: value, onTap: () {}),
          ),
        ),
      ),
    );
    return navigator;
  }

  testWidgets('a page over it stops its clock; shown again it runs from 0', (
    tester,
  ) async {
    final id = ValueNotifier('seal');
    addTearDown(id.dispose);
    final navigator = await pumpCoverable(tester, id);
    await tester.pump(const Duration(milliseconds: 100));
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('over')),
    );
    // Settles: the covered page asks for no more frames.
    await tester.pumpAndSettle();
    final covered = _clock(tester);
    expect(covered, greaterThan(0));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(_clock(tester), covered);
    navigator.currentState!.pop();
    // From the first frame the page starts to leave.
    await tester.pump();
    expect(_clock(tester), 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_clock(tester), closeTo(100, 1));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('over'), findsNothing);
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('a character chosen while a page covers home starts from 0 '
      'when home shows again (환경설정 -> 캐릭터 -> back)', (tester) async {
    final id = ValueNotifier('seal');
    addTearDown(id.dispose);
    final navigator = await pumpCoverable(tester, id);
    await tester.pump(const Duration(milliseconds: 100));
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('over')),
    );
    await tester.pumpAndSettle();
    id.value = 'bear';
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_painter(tester).art.id, 'bear');
    expect(_clock(tester), closeTo(16, 1));
  });

  testWidgets('an app in the background asks for no frames', (tester) async {
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    expect(tester.binding.framesEnabled, isFalse);
    // The frame already asked for; the clock asks for no next one.
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(tester.binding.hasScheduledFrame, isTrue);
    final resumed = _clock(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_clock(tester), greaterThan(resumed));
  });

  testWidgets('it stands by the W4 rule in whatever room it gets', (
    tester,
  ) async {
    await _pump(tester);
    final painter = _painter(tester);
    expect(
      painter.placementIn(_room),
      CharacterMotionRig.standard.characters['kangaroo']!.placeIn(
        _room,
        const Offset(70, 150),
      ),
    );
    expect(painter.placementIn(_room).scale, 1.6);
    // A room with no space draws nothing and does not fail.
    await _pump(tester, size: const Size(320, 10));
    expect(tester.takeException(), isNull);
    expect(_painter(tester).placementIn(const Size(320, 10)).scale, 0);
  });

  test('repaints when what it draws changes', () {
    final clock = ValueNotifier<double>(0);
    LobbyCharacterPainter painter({String id = 'mouse', bool still = false}) =>
        LobbyCharacterPainter(
          rig: CharacterRig.standard,
          art: CharacterRig.standard.art(id),
          motion: CharacterMotionRig.standard,
          clock: clock,
          still: still,
        );
    expect(painter().shouldRepaint(painter()), isFalse);
    expect(painter().shouldRepaint(painter(id: 'seal')), isTrue);
    expect(painter().shouldRepaint(painter(still: true)), isTrue);
  });

  group('against the design\'s home shots (W4 spec 8, "화면 대조")', () {
    test('the comparison catches a wrong picture (another character, the '
        'other key pose)', () async {
      final wrong = await _against('mouse', _stillPainter('kangaroo'));
      expect(wrong.painted + wrong.missed, greaterThan(0.01));
      final moving = LobbyCharacterPainter(
        rig: CharacterRig.standard,
        art: CharacterRig.standard.art('mouse'),
        motion: CharacterMotionRig.standard,
        clock: ValueNotifier(512),
        still: false,
      );
      final down = await _against('mouse', moving);
      expect(down.painted + down.missed, greaterThan(0.01));
    });

    for (final id in _ids) {
      test('$id\'s rest picture matches the design but for edges', () async {
        final result = await _against(id, _stillPainter(id));
        expect(
          result.painted,
          lessThan(0.0005),
          reason: '$id: ${(result.painted * 100).toStringAsFixed(3)}% off',
        );
        expect(
          result.missed,
          lessThan(0.0005),
          reason: '$id: ${(result.missed * 100).toStringAsFixed(3)}% missed',
        );
      });
    }
  });
}
