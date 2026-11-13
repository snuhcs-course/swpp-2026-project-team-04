import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/character_figure.dart';

/// The design's shots (W3 spec 0): 2x, the box's (0, 0) at pixel (60, 24),
/// on this ground.
const _shotsDir = 'test/widgets/character_shots';
const _shotScale = 2.0;
const _shotOrigin = Offset(60, 24);
const _shotGround = Color(0xFFE6E9F0);

/// A pixel counts as different when a channel is off by more than this;
/// edges smoothed a little differently stay under it.
const _pixelTolerance = 64;

/// The share of pixels that may differ: anti-aliased edges only. All 60
/// shots measured 0.018% or less on 2026-11-13; the mouse without one eye
/// shine (the smallest dot) differs by 0.041%.
const _maxDifferentShare = 0.0003;

CharacterFigurePainter _painter(
  String id,
  String pose, {
  BattleSide side = BattleSide.me,
  bool flash = false,
}) {
  final rig = CharacterRig.standard;
  return CharacterFigurePainter(
    rig: rig,
    art: rig.art(id),
    pose: pose,
    teamColor: side == BattleSide.me ? AppColors.accent : AppColors.opponent,
    flash: flash,
  );
}

/// [painter] drawn as the design's shots are, as RGBA bytes.
Future<Uint8List> _render(CharacterFigurePainter painter, int w, int h) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(_shotGround, BlendMode.src);
  canvas.translate(_shotOrigin.dx, _shotOrigin.dy);
  canvas.scale(_shotScale);
  painter.paint(canvas, const Size(140, 160));
  final image = await recorder.endRecording().toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return bytes!.buffer.asUint8List();
}

Future<ui.Image> _decode(File file) async {
  final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

void main() {
  final rig = CharacterRig.standard;

  group('CharacterFigure', () {
    testWidgets('is the rig box times its scale, in the given pose and team', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Center(
          child: CharacterFigure(
            characterId: 'bear',
            pose: BattlePose.win,
            side: BattleSide.opponent,
            flash: true,
            scale: 1.5,
          ),
        ),
      );
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(CharacterFigure),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(paint.size, const Size(210, 240));
      final painter = paint.painter! as CharacterFigurePainter;
      expect(painter.art.id, 'bear');
      expect(painter.pose, 'win');
      expect(painter.teamColor, AppColors.opponent);
      expect(painter.flash, isTrue);
    });

    testWidgets('is the 140 x 160 box, idle, in my color by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Center(child: CharacterFigure(characterId: 'seal')),
      );
      expect(
        tester.getSize(find.byType(CharacterFigure)),
        const Size(140, 160),
      );
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(CharacterFigure),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as CharacterFigurePainter;
      expect(painter.pose, 'idle');
      expect(painter.teamColor, AppColors.accent);
      expect(painter.flash, isFalse);
    });

    testWidgets('an unknown character draws the default mouse', (tester) async {
      await tester.pumpWidget(
        const Center(child: CharacterFigure(characterId: 'rabbit')),
      );
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(CharacterFigure),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as CharacterFigurePainter;
      expect(painter.art.id, 'mouse');
    });
  });

  group('CharacterIdleFigure', () {
    Future<void> pump(
      WidgetTester tester,
      Widget figure, {
      bool still = false,
    }) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: figure),
        ),
      ),
    );

    Matrix4 transform(WidgetTester tester) => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(CharacterIdleFigure),
            matching: find.byType(Transform),
          ),
        )
        .transform;

    testWidgets('moves as its character idles, about its feet, at its scale', (
      tester,
    ) async {
      await pump(
        tester,
        const CharacterIdleFigure(characterId: 'kangaroo', scale: 1.5),
      );
      expect(
        tester.getSize(find.byType(CharacterFigure)),
        const Size(210, 240),
      );
      await tester.pump(const Duration(milliseconds: 230));
      // The top of the hop: 6 px times the scale, straight up.
      final hop = transform(tester).getTranslation();
      expect(hop.y, closeTo(-6 * 1.5, 1e-6));
      expect(hop.x, closeTo(0, 1e-6));
      final paint = tester.widget<Transform>(
        find.descendant(
          of: find.byType(CharacterIdleFigure),
          matching: find.byType(Transform),
        ),
      );
      expect(paint.origin, const Offset(70 * 1.5, 150 * 1.5));
      await tester.pump(const Duration(milliseconds: 230));
      expect(transform(tester).getTranslation().y, closeTo(0, 1e-6));
    });

    testWidgets('rocks and stretches as the rig says', (tester) async {
      await pump(tester, const CharacterIdleFigure(characterId: 'seal'));
      await tester.pump(const Duration(milliseconds: 275));
      // A quarter of the seal's 1100 ms: tallest and narrowest.
      final m = transform(tester);
      expect(m.entry(0, 0), closeTo(0.97, 1e-6));
      expect(m.entry(1, 1), closeTo(1.03, 1e-6));
      // A new figure, on its own clock.
      await pump(
        tester,
        const CharacterIdleFigure(
          key: ValueKey('penguin'),
          characterId: 'penguin',
        ),
      );
      await tester.pump(const Duration(milliseconds: 325));
      // A quarter of the penguin's 1300 ms: leaning the full 4 degrees.
      final lean = transform(tester);
      expect(
        math.atan2(lean.entry(1, 0), lean.entry(0, 0)) * 180 / math.pi,
        closeTo(4, 0.05),
      );
    });

    testWidgets('holds still when the device asks for less motion', (
      tester,
    ) async {
      await pump(
        tester,
        const CharacterIdleFigure(characterId: 'kangaroo'),
        still: true,
      );
      await tester.pump(const Duration(milliseconds: 230));
      expect(transform(tester), Matrix4.identity());
      // And moves again once it may.
      await pump(tester, const CharacterIdleFigure(characterId: 'kangaroo'));
      await tester.pump(const Duration(milliseconds: 230));
      expect(transform(tester).getTranslation().y, lessThan(0));
    });

    testWidgets('wears the side\'s color and draws the character asked for', (
      tester,
    ) async {
      await pump(
        tester,
        const CharacterIdleFigure(
          characterId: 'bot',
          side: BattleSide.opponent,
        ),
      );
      final figure = tester.widget<CharacterFigure>(
        find.byType(CharacterFigure),
      );
      expect(
        (figure.characterId, figure.side, figure.pose),
        ('bot', BattleSide.opponent, BattlePose.idle),
      );
    });
  });

  group('BattleCharacters', () {
    test('gives each side its character', () {
      const characters = BattleCharacters(me: 'seal', opponent: 'bot');
      expect(characters.of(BattleSide.me), 'seal');
      expect(characters.of(BattleSide.opponent), 'bot');
    });

    test('brings the rig\'s idle motions, the opponent\'s 230 ms, and the '
        'star where blows land', () {
      final cast = const BattleCharacters(me: 'penguin', opponent: 'bear').cast;
      expect(cast.meIdle, same(rig.art('penguin').idleMotion));
      expect(cast.opponentIdle, same(rig.art('bear').idleMotion));
      expect(cast.opponentIdleOffsetMs, 230);
      expect((cast.hitStarDx, cast.hitStarUp), (48, 58));
    });

    test('an unknown id idles as the default mouse', () {
      final cast = const BattleCharacters(me: 'rabbit', opponent: '').cast;
      expect(cast.meIdle, same(rig.art('mouse').idleMotion));
      expect(cast.opponentIdle, same(rig.art('mouse').idleMotion));
    });

    test('two with the same characters are equal', () {
      const a = BattleCharacters(me: 'mouse', opponent: 'bot');
      expect(a, const BattleCharacters(me: 'mouse', opponent: 'bot'));
      expect(
        a.hashCode,
        const BattleCharacters(me: 'mouse', opponent: 'bot').hashCode,
      );
      expect(a, isNot(const BattleCharacters(me: 'bot', opponent: 'mouse')));
    });
  });

  test('the stage poses map to the rig pose keys', () {
    expect(
      {for (final pose in BattlePose.values) pose: characterPoseKey(pose)},
      {
        BattlePose.idle: 'idle',
        BattlePose.attack: 'atk',
        BattlePose.hit: 'hit',
        BattlePose.knockedOut: 'ko',
        BattlePose.win: 'win',
      },
    );
    expect(rig.poses, BattlePose.values.map(characterPoseKey).toList());
  });

  test('the theme colors are the rig colors (ink, lime for me, pink for the '
      'opponent)', () {
    expect(AppColors.ink.toARGB32(), rig.ink);
    expect(AppColors.accent.toARGB32(), rig.teamMe);
    expect(AppColors.opponent.toARGB32(), rig.teamOpponent);
    // The flash is white (spec 6), whatever the card surface becomes.
    expect(AppColors.card.toARGB32(), 0xFFFFFFFF);
  });

  test('a parent of another shape gets the character scaled the same both '
      'ways and centred, not stretched', () async {
    Future<Uint8List> at(Size size) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(_shotGround, BlendMode.src);
      _painter('kangaroo', 'win').paint(canvas, size);
      final image = await recorder.endRecording().toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return bytes!.buffer.asUint8List();
    }

    // Twice the box, and the same height in a box 120 wider.
    final box = await at(const Size(280, 320));
    final wide = await at(const Size(400, 320));
    var different = 0;
    for (var y = 0; y < 320; y++) {
      for (var x = 0; x < 280; x++) {
        final i = (y * 280 + x) * 4;
        final j = (y * 400 + x + 60) * 4;
        for (var c = 0; c < 3; c++) {
          if ((box[i + c] - wide[j + c]).abs() > _pixelTolerance) {
            different++;
            break;
          }
        }
      }
    }
    expect(different / (280 * 320), lessThan(_maxDifferentShare));
    // The strips beside it stay empty (the win pose reaches x -2 to 135.5
    // of its box: 56 to 331 here).
    for (var y = 0; y < 320; y += 7) {
      for (final x in [0, 30, 50, 340, 370, 399]) {
        final j = (y * 400 + x) * 4;
        expect(
          [wide[j], wide[j + 1], wide[j + 2]],
          [0xE6, 0xE9, 0xF0],
          reason: '($x, $y)',
        );
      }
    }
  });

  test('every character paints in every pose, both teams, with and without '
      'the flash', () {
    var drawn = 0;
    for (final id in rig.order) {
      for (final pose in rig.poses) {
        for (final side in BattleSide.values) {
          for (final flash in [false, true]) {
            final recorder = ui.PictureRecorder();
            _painter(
              id,
              pose,
              side: side,
              flash: flash,
            ).paint(Canvas(recorder), const Size(140, 160));
            recorder.endRecording().dispose();
            drawn++;
          }
        }
      }
    }
    expect(drawn, 6 * 5 * 2 * 2);
  });

  test('an unknown pose is an error, not a blank picture', () {
    final recorder = ui.PictureRecorder();
    expect(
      () => _painter(
        'mouse',
        'dance',
      ).paint(Canvas(recorder), const Size(140, 160)),
      throwsArgumentError,
    );
    recorder.endRecording().dispose();
  });

  group('colors', () {
    test('switching the team changes only the shapes the rig marks "team"', () {
      for (final id in rig.order) {
        final me = _painter(id, 'idle');
        final opponent = _painter(id, 'idle', side: BattleSide.opponent);
        for (final op in rig.art(id).ops) {
          for (final (paint, outline) in [
            (op.prim.fill, false),
            (op.prim.stroke, true),
          ]) {
            if (paint == null) continue;
            final mine = me.colorOf(paint, outline: outline);
            final theirs = opponent.colorOf(paint, outline: outline);
            if (paint.team) {
              expect(mine, AppColors.accent, reason: id);
              expect(theirs, AppColors.opponent, reason: id);
            } else {
              expect(mine, Color(paint.argb), reason: id);
              expect(theirs, mine, reason: id);
            }
          }
        }
      }
    });

    test(
      'the flash turns every fill white and every outline but ink white',
      () {
        var inkOutlines = 0;
        var otherOutlines = 0;
        for (final id in rig.order) {
          final painter = _painter(id, 'hit', flash: true);
          for (final op in rig.art(id).ops) {
            final fill = op.prim.fill;
            if (fill != null) {
              expect(painter.colorOf(fill), AppColors.card, reason: id);
            }
            final stroke = op.prim.stroke;
            if (stroke == null) continue;
            final isInk = !stroke.team && stroke.argb == rig.ink;
            isInk ? inkOutlines++ : otherOutlines++;
            expect(
              painter.colorOf(stroke, outline: true),
              isInk ? AppColors.ink : AppColors.card,
              reason: id,
            );
          }
        }
        // Both kinds occur, so both branches were checked.
        expect(inkOutlines, greaterThan(0));
        expect(otherOutlines, greaterThan(0));
      },
    );

    test('an ink fill turns white in the flash too (RepBot\'s screen)', () {
      final screen = rig
          .art('bot')
          .ops
          .map((op) => op.prim.fill)
          .whereType<RigPaint>()
          .firstWhere((paint) => !paint.team && paint.argb == rig.ink);
      expect(_painter('bot', 'idle').colorOf(screen), AppColors.ink);
      expect(
        _painter('bot', 'idle', flash: true).colorOf(screen),
        AppColors.card,
      );
    });
  });

  test('repaints only when what it draws changes', () {
    final base = _painter('mouse', 'idle');
    expect(base.shouldRepaint(_painter('mouse', 'idle')), isFalse);
    expect(base.shouldRepaint(_painter('bear', 'idle')), isTrue);
    expect(base.shouldRepaint(_painter('mouse', 'atk')), isTrue);
    expect(
      base.shouldRepaint(_painter('mouse', 'idle', side: BattleSide.opponent)),
      isTrue,
    );
    expect(base.shouldRepaint(_painter('mouse', 'idle', flash: true)), isTrue);
    final otherRig = CharacterFigurePainter(
      rig: CharacterRig.parse(_rigSource()),
      art: rig.art('mouse'),
      pose: 'idle',
      teamColor: AppColors.accent,
    );
    expect(base.shouldRepaint(otherRig), isTrue);
  });

  group('against the design shots (test/widgets/character_shots)', () {
    final shots =
        Directory(_shotsDir)
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.png'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    test('there are shots of every character and every pose in both teams', () {
      final names = shots.map((f) => f.uri.pathSegments.last).toList();
      for (final id in rig.order) {
        expect(names.where((n) => n.startsWith('${id}_')), isNotEmpty);
      }
      for (final pose in rig.poses) {
        expect(names.where((n) => n.contains('_${pose}_')), isNotEmpty);
      }
      expect(names.where((n) => n.endsWith('_me.png')), isNotEmpty);
      expect(names.where((n) => n.endsWith('_op.png')), isNotEmpty);
    });

    test('the comparison catches a wrong picture (the other team, a missing '
        'eye shine)', () async {
      final shot = File('$_shotsDir/mouse_idle_me.png');
      expect(
        await _differentShare(
          shot,
          _painter('mouse', 'idle', side: BattleSide.opponent),
        ),
        greaterThan(_maxDifferentShare),
      );
      final source = jsonDecode(_rigSource()) as Map<String, dynamic>;
      final ops = source['characters']['mouse']['ops'] as List;
      // The first white dot drawn in the idle pose: an eye's shine.
      ops.remove(
        ops.firstWhere(
          (op) =>
              op['prim']['type'] == 'circle' &&
              op['prim']['fill'] == '#FFFFFF' &&
              (op['show'] == null || (op['show'] as List).contains('idle')),
        ),
      );
      final noShine = CharacterRig.parse(jsonEncode(source));
      expect(
        await _differentShare(
          shot,
          CharacterFigurePainter(
            rig: noShine,
            art: noShine.art('mouse'),
            pose: 'idle',
            teamColor: AppColors.accent,
          ),
        ),
        greaterThan(_maxDifferentShare),
      );
    });

    for (final file in shots) {
      final name = file.uri.pathSegments.last.replaceAll('.png', '');
      final [id, pose, team] = name.split('_');
      test('$name matches the design pixel for pixel but for edges', () async {
        final share = await _differentShare(
          file,
          _painter(
            id,
            pose,
            side: team == 'op' ? BattleSide.opponent : BattleSide.me,
          ),
        );
        expect(
          share,
          lessThan(_maxDifferentShare),
          reason:
              '$name: ${(share * 100).toStringAsFixed(3)}% of pixels differ',
        );
      });
    }
  });
}

/// The share of pixels of [shot] that [painter] draws differently.
Future<double> _differentShare(
  File shot,
  CharacterFigurePainter painter,
) async {
  final image = await _decode(shot);
  final expected = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
      .buffer
      .asUint8List();
  final actual = await _render(painter, image.width, image.height);
  var different = 0;
  for (var i = 0; i < expected.length; i += 4) {
    for (var c = 0; c < 3; c++) {
      if ((expected[i + c] - actual[i + c]).abs() > _pixelTolerance) {
        different++;
        break;
      }
    }
  }
  return different / (image.width * image.height);
}

String _rigSource() => File('assets/characters/w3_rig.json').readAsStringSync();
