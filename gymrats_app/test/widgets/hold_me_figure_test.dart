import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/hold_me_figure.dart';
import 'package:gymrats_app/widgets/hold_me_rig.dart';
import 'package:gymrats_app/widgets/hold_me_scene.dart';
import 'package:gymrats_app/widgets/victory_motion.dart';

final _rig = HoldMeRig.standard;
const _ids = ['mouse', 'kangaroo', 'bear', 'penguin', 'seal'];

/// What [painter] calls on a canvas of [size].
List<RecordedInvocation> _record(CustomPainter painter, Size size) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, size);
  return canvas.invocations;
}

Iterable<RecordedInvocation> _named(
  List<RecordedInvocation> calls,
  String name,
) => calls.where((c) => c.invocation.memberName == Symbol(name));

/// The numbers [call] was given, without the optional ones left out.
List<double> _args(RecordedInvocation call) =>
    call.invocation.positionalArguments.whereType<double>().toList();

HoldMeFrame _frame(String id, HoldPose pose, HoldMeMoment moment) =>
    HoldMeScene.frameAt(_rig.placeOf(id, pose), moment);

Size _boxOf(HoldMeFrame frame) => _rig.box * frame.place.scale;

/// The drawPath calls a rig frame's character alone makes.
int _rigPaths(HoldMeFrame frame) {
  final w3 = CharacterRig.standard;
  final w5 = VictoryRig.standard;
  final id = frame.place.characterId;
  return _named(
    _record(
      CharacterFigurePainter(
        rig: w3,
        art: w3.art(id),
        teamColor: AppColors.accent,
        values: frame.pose,
        tags: w5.tagsOf(frame.expression, id),
        patches: w5.characterOf(id).drawPatch,
        flags: frame.place.flags,
        effects: w5.effects,
      ),
      Size(w3.boxWidth, w3.boxHeight),
    ),
    'drawPath',
  ).length;
}

/// The drawPath calls a drawing's shapes make with [tags].
int _drawingPaths(HoldMePlace place, Set<String> tags) => [
  for (final s in place.drawing!)
    if (s.shownWith(tags)) ...[if (s.fill != null) s, if (s.stroke != null) s],
].length;

void main() {
  group('who draws each character (A8 spec 9.1)', () {
    for (final id in _ids) {
      for (final pose in HoldPose.values) {
        test('$id ${pose.name}', () {
          final frame = _frame(id, pose, const HoldMeMoment.hold());
          final calls = _record(HoldMePainter(frame), _boxOf(frame));
          // The shadow first, under the feet.
          final shadow = _named(calls, 'drawOval').first;
          final rect = shadow.invocation.positionalArguments.first as Rect;
          expect(rect.center, Offset(frame.shadowX, 152));
          expect(rect.width, frame.shadowRx * 2);
          final paths = _named(calls, 'drawPath').length;
          if (frame.place.drawing == null) {
            expect(paths, _rigPaths(frame));
          } else {
            expect(paths, _drawingPaths(frame.place, {'atk'}));
          }
        });
      }
    }
  });

  group('faces (A8 spec 4; grit is W5\'s atk with the teeth)', () {
    test('the rig shows the gritted teeth but 물렁범, who has none', () {
      for (final id in _ids) {
        final hold = _frame(id, HoldPose.chair, const HoldMeMoment.hold());
        final strain = _frame(id, HoldPose.chair, const HoldMeMoment.strain());
        final more = _rigPaths(strain) - _rigPaths(hold);
        expect(more, id == 'seal' ? 0 : greaterThan(0), reason: id);
      }
    });

    test('a lying drawing adds its teeth to the atk face', () {
      for (final id in ['penguin', 'seal']) {
        final place = _rig.placeOf(id, HoldPose.plank);
        final strain = HoldMeScene.frameAt(place, const HoldMeMoment.strain());
        final calls = _record(HoldMePainter(strain), _boxOf(strain));
        expect(
          _named(calls, 'drawPath').length,
          // The shapes, the drops (fill and outline), the shake lines.
          _drawingPaths(place, {'atk', 'teeth'}) + strain.sweat.length * 2 + 1,
        );
        expect(
          _drawingPaths(place, {'atk', 'teeth'}),
          greaterThan(_drawingPaths(place, {'atk'})),
        );
      }
    });

    test('each face draws only its own shapes', () {
      final place = _rig.placeOf('bear', HoldPose.plank);
      for (final (moment, tag) in [
        (const HoldMeMoment.go(), 'idle'),
        (const HoldMeMoment.warn(500), 'hit'),
        (const HoldMeMoment.star(1, 1300), 'win'),
      ]) {
        final frame = HoldMeScene.frameAt(place, moment);
        final calls = _record(HoldMePainter(frame), _boxOf(frame));
        final fx = frame.sweat.length * 2; // A warning's drops.
        expect(
          _named(calls, 'drawPath').length,
          _drawingPaths(place, {tag}) + fx,
          reason: tag,
        );
      }
    });

    test('the team lime fills the drawings\' gloves and vests', () {
      final frame = _frame('penguin', HoldPose.plank, const HoldMeMoment.go());
      final colors = [
        for (final call in _named(
          _record(HoldMePainter(frame), _boxOf(frame)),
          'drawPath',
        ))
          (call.invocation.positionalArguments[1] as Paint).color.toARGB32(),
      ];
      // Paint keeps 32-bit colors: compare them as such.
      expect(colors, contains(AppColors.accent.toARGB32()));
    });
  });

  group('moves', () {
    test('the box moves about the feet: across, up and squashed', () {
      final frame = _frame(
        'mouse',
        HoldPose.plank,
        const HoldMeMoment.star(1, 460),
      );
      final calls = _record(HoldMePainter(frame), _boxOf(frame));
      final translates = [
        for (final c in _named(calls, 'translate'))
          c.invocation.positionalArguments,
      ];
      expect(translates.first, [frame.jx, -frame.hop]);
      expect(translates[1], [70.0, 150.0]);
      expect(
        _named(calls, 'scale').map(_args),
        containsAllInOrder([
          [1.12],
          [frame.sx, frame.sy],
        ]),
      );
    });

    test('a drawing\'s near arm and head turn at a star\'s hop', () {
      final frame = _frame(
        'seal',
        HoldPose.plank,
        const HoldMeMoment.star(1, 460),
      );
      expect(frame.nearArmDeg, closeTo(-55, 1e-9));
      final turns = [
        for (final c in _named(
          _record(HoldMePainter(frame), _boxOf(frame)),
          'rotate',
        ))
          c.invocation.positionalArguments.first as double,
      ];
      expect(turns, contains(closeTo(-55 * math.pi / 180, 1e-9)));
      expect(turns, contains(closeTo(-6 * math.pi / 180, 1e-9)));
    });

    test('a warning tips 곰탱이 about its toes and flattens the lying ones', () {
      final bear = _frame('bear', HoldPose.plank, const HoldMeMoment.warn(500));
      expect(
        _named(
          _record(HoldMePainter(bear), _boxOf(bear)),
          'rotate',
        ).map((c) => c.invocation.positionalArguments.first),
        contains(closeTo(4 * math.pi / 180, 1e-9)),
      );
      final penguin = _frame(
        'penguin',
        HoldPose.plank,
        const HoldMeMoment.warn(500),
      );
      expect(
        _named(
          _record(HoldMePainter(penguin), _boxOf(penguin)),
          'scale',
        ).map(_args),
        contains(equals([1.05, 0.9])),
      );
    });
  });

  group('effects', () {
    test('the strain: three drops in layers of their opacity and the shake '
        'lines', () {
      final frame = _frame(
        'kangaroo',
        HoldPose.plank,
        const HoldMeMoment.strain(),
      );
      final calls = _record(HoldMePainter(frame), _boxOf(frame));
      final layers = _named(calls, 'saveLayer').toList();
      expect(layers, hasLength(3));
      for (final (i, layer) in layers.indexed) {
        final paint = layer.invocation.positionalArguments[1] as Paint;
        expect(paint.color.a, closeTo(frame.sweat[i].opacity, 1e-3));
      }
      final shake = _named(calls, 'drawPath').last;
      final paint = shake.invocation.positionalArguments[1] as Paint;
      expect(paint.strokeWidth, closeTo(2.4, 1e-6));
      expect(paint.style, PaintingStyle.stroke);
    });

    test('a star: its rays, then the landing\'s dust', () {
      final rays = _frame(
        'bear',
        HoldPose.chair,
        const HoldMeMoment.star(1, 300),
      );
      final rayCalls = _record(HoldMePainter(rays), _boxOf(rays));
      expect(_named(rayCalls, 'saveLayer'), hasLength(1));
      expect(
        _named(rayCalls, 'translate').map(_args),
        contains(equals([70.0, 92.0])),
      );
      final dust = _frame(
        'bear',
        HoldPose.chair,
        const HoldMeMoment.star(1, 900),
      );
      final dustCalls = _record(HoldMePainter(dust), _boxOf(dust));
      expect(
        _named(dustCalls, 'scale').map(_args),
        contains(equals([dust.dust!.scaleX, 1.0])),
      );
    });

    test(
      'a group at full opacity needs no layer; none at all shows nothing',
      () {
        final frame = _frame(
          'mouse',
          HoldPose.plank,
          const HoldMeMoment.star(1, 140),
        );
        expect(frame.spark!.opacity, 1);
        final calls = _record(HoldMePainter(frame), _boxOf(frame));
        expect(_named(calls, 'saveLayer'), isEmpty);
        final faded = _frame(
          'mouse',
          HoldPose.plank,
          const HoldMeMoment.star(1, 1149.99999),
        );
        expect(faded.dust!.opacity, lessThan(1e-4));
      },
    );
  });

  group('the flying star (A8 spec 4)', () {
    final place = _rig.placeOf('mouse', HoldPose.plank);
    final flight = HoldMeScene.flightAt(
      place,
      place.topOn(_rig),
      560,
      const Offset(180, 107),
    )!;

    test('its trail, then the star turned and scaled at its place', () {
      final calls = _record(HoldMeFlightPainter(flight), const Size(360, 390));
      final paths = _named(calls, 'drawPath').toList();
      expect(paths, hasLength(3));
      final trail = paths.first.invocation.positionalArguments[1] as Paint;
      expect(trail.strokeWidth, 5);
      expect(trail.color.a, closeTo(0.7, 1e-3));
      expect(_named(calls, 'translate').map(_args), [
        [flight.at.dx, flight.at.dy],
      ]);
      // The star's own move from the mockup: translate(-12 -12).
      final matrix =
          _named(
                calls,
                'transform',
              ).single.invocation.positionalArguments.single
              as List<double>;
      expect([matrix[12], matrix[13]], [-12, -12]);
      expect(
        _named(calls, 'rotate').single.invocation.positionalArguments.single,
        closeTo(flight.rotDeg * math.pi / 180, 1e-9),
      );
    });

    test('repaints when it moves', () {
      final painter = HoldMeFlightPainter(flight);
      expect(painter.shouldRepaint(HoldMeFlightPainter(flight)), isFalse);
      final next = HoldMeScene.flightAt(
        place,
        place.topOn(_rig),
        600,
        const Offset(180, 107),
      )!;
      expect(painter.shouldRepaint(HoldMeFlightPainter(next)), isTrue);
    });
  });

  test('every character in every moment paints on a real canvas', () {
    for (final id in _ids) {
      for (final pose in HoldPose.values) {
        final place = _rig.placeOf(id, pose);
        for (final moment in [
          const HoldMeMoment.go(),
          const HoldMeMoment.hold(sinceResumeMs: 60),
          const HoldMeMoment.strain(),
          for (final t in [0.0, 200.0, 460.0, 860.0, 1200.0])
            HoldMeMoment.star(1, t),
          const HoldMeMoment.warn(100),
        ]) {
          final frame = HoldMeScene.frameAt(place, moment, liveMs: 777);
          final recorder = ui.PictureRecorder();
          HoldMePainter(frame).paint(Canvas(recorder), _boxOf(frame));
          recorder.endRecording().dispose();
        }
      }
    }
  });

  testWidgets('the figure: its box at its scale, and nothing for a screen '
      'reader', (tester) async {
    final handle = tester.ensureSemantics();
    final frame = _frame('penguin', HoldPose.plank, const HoldMeMoment.hold());
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: HoldMeFigure(frame: frame)),
      ),
    );
    expect(
      tester.getSize(find.byType(HoldMeFigure)),
      const Size(140 * 1.28, 160 * 1.28),
    );
    expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(HoldMeFigure),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as HoldMePainter;
    expect(painter.shouldRepaint(HoldMePainter(frame)), isFalse);
    expect(
      painter.shouldRepaint(
        HoldMePainter(
          _frame('penguin', HoldPose.plank, const HoldMeMoment.hold()),
        ),
      ),
      isTrue,
    );
    handle.dispose();
  });
}
