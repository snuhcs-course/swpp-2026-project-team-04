import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/widgets/gym_background_art.dart';
import 'package:gymrats_app/widgets/gym_owner_figure.dart';

final _art = GymArt.standard;

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  ),
);

GymArtPainter _painterIn(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(GymOwnerFigure),
      matching: find.byType(CustomPaint),
    ),
  );
  return paint.painter! as GymArtPainter;
}

/// The breathing's transform, or null when the owner stands still.
Transform? _breath(WidgetTester tester) {
  final found = find.descendant(
    of: find.byType(GymOwnerFigure),
    matching: find.byType(Transform),
  );
  return found.evaluate().isEmpty ? null : tester.widget<Transform>(found);
}

/// The (across, up) scale of [transform].
(double, double) _scaleOf(Transform transform) =>
    (transform.transform.storage[0], transform.transform.storage[5]);

void main() {
  testWidgets('is the 140 x 160 box times its scale', (tester) async {
    for (final scale in [1.0, 0.5, 1.5]) {
      await tester.pumpWidget(
        _host(GymOwnerFigure(ownerId: 'bear', scale: scale)),
      );
      expect(
        tester.getSize(find.byType(GymOwnerFigure)),
        Size(140 * scale, 160 * scale),
      );
    }
  });

  testWidgets('draws the owner and face asked for, unclipped, in its box', (
    tester,
  ) async {
    for (final owner in _art.owners.values) {
      for (final face in GymOwnerFace.values) {
        await tester.pumpWidget(
          _host(GymOwnerFigure(ownerId: owner.id, face: face)),
        );
        final painter = _painterIn(tester);
        expect(
          identical(painter.shapes, owner.faces[face.name]),
          isTrue,
          reason: '${owner.id} ${face.name}',
        );
        expect(painter.window, const Size(140, 160));
        expect(painter.clip, isFalse);
      }
    }
  });

  testWidgets('watches by default', (tester) async {
    await tester.pumpWidget(_host(const GymOwnerFigure(ownerId: 'penguin')));
    expect(
      identical(
        _painterIn(tester).shapes,
        _art.owners['penguin']!.faces['watch'],
      ),
      isTrue,
    );
  });

  testWidgets('an unknown owner draws the seal', (tester) async {
    for (final id in ['mouse', 'bot', '', 'Seal']) {
      await tester.pumpWidget(
        _host(GymOwnerFigure(ownerId: id, face: GymOwnerFace.blow)),
      );
      expect(
        identical(
          _painterIn(tester).shapes,
          _art.owners['seal']!.faces['blow'],
        ),
        isTrue,
        reason: id,
      );
    }
    expect(GymOwnerFigure.artOf('mouse').id, 'seal');
    expect(GymOwnerFigure.artOf('kangaroo').id, 'kangaroo');
  });

  testWidgets('screen readers hear "체육관 관장" and the name, not the face', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final names = {
      'seal': '물렁범',
      'penguin': '펭뚱이',
      'kangaroo': '그루',
      'bear': '곰탱이',
      'unknown': '물렁범',
    };
    for (final MapEntry(key: id, value: name) in names.entries) {
      for (final face in GymOwnerFace.values) {
        await tester.pumpWidget(
          _host(GymOwnerFigure(ownerId: id, face: face, idle: true)),
        );
        expect(
          tester.getSemantics(find.byType(GymOwnerFigure)),
          matchesSemantics(label: '체육관 관장 $name', isImage: true),
        );
      }
    }
    handle.dispose();
  });

  testWidgets('stands still unless asked to breathe', (tester) async {
    await tester.pumpWidget(_host(const GymOwnerFigure(ownerId: 'seal')));
    expect(_breath(tester), isNull);
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });

  testWidgets('breathes about its feet: 1.2% narrower and 2% taller a '
      'quarter into its 2.2 s cycle, back at the half', (tester) async {
    await tester.pumpWidget(
      _host(const GymOwnerFigure(ownerId: 'kangaroo', scale: 2, idle: true)),
    );
    final start = _breath(tester)!;
    expect(start.origin, const Offset(140, 300));
    expect(_scaleOf(start), (1.0, 1.0));

    // The ticker's clock starts on the first frame after this one.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    var (across, up) = _scaleOf(_breath(tester)!);
    expect(across, closeTo(0.988, 1e-9));
    expect(up, closeTo(1.02, 1e-9));

    await tester.pump(const Duration(milliseconds: 550));
    (across, up) = _scaleOf(_breath(tester)!);
    expect(across, closeTo(1, 1e-9));
    expect(up, closeTo(1, 1e-9));

    await tester.pump(const Duration(milliseconds: 550));
    (across, up) = _scaleOf(_breath(tester)!);
    expect(across, closeTo(1.012, 1e-9));
    expect(up, closeTo(0.98, 1e-9));

    // Any moment follows the sine.
    await tester.pump(const Duration(milliseconds: 333));
    final s = math.sin(2 * math.pi * (550 * 3 + 333) / 2200);
    (across, up) = _scaleOf(_breath(tester)!);
    expect(across, closeTo(1 - 0.012 * s, 1e-9));
    expect(up, closeTo(1 + 0.02 * s, 1e-9));
  });

  testWidgets('does not breathe when the device asks for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const GymOwnerFigure(ownerId: 'bear', idle: true),
        reduceMotion: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 550));
    expect(_scaleOf(_breath(tester)!), (1.0, 1.0));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });

  testWidgets('stops and settles when reduced motion is turned on, and '
      'starts again when it is turned off', (tester) async {
    const owner = GymOwnerFigure(ownerId: 'seal', idle: true);
    await tester.pumpWidget(_host(owner));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(_scaleOf(_breath(tester)!), isNot((1.0, 1.0)));

    await tester.pumpWidget(_host(owner, reduceMotion: true));
    expect(_scaleOf(_breath(tester)!), (1.0, 1.0));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);

    await tester.pumpWidget(_host(owner));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(_scaleOf(_breath(tester)!).$2, closeTo(1.02, 1e-9));
  });

  testWidgets('stops its clock when it leaves the screen', (tester) async {
    await tester.pumpWidget(
      _host(const GymOwnerFigure(ownerId: 'seal', idle: true)),
    );
    expect(SchedulerBinding.instance.transientCallbackCount, 1);
    await tester.pumpWidget(_host(const SizedBox()));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });

  test('publishes each owner face centre in its box (spec 3)', () {
    expect(gymOwnerFaceCenters, {
      'seal': const Offset(70, 66),
      'penguin': const Offset(70, 66),
      'kangaroo': const Offset(76, 50),
      'bear': const Offset(72, 62),
    });
    expect(gymOwnerFaceCenters.keys, _art.owners.keys);
  });

  test('the faces are the art data faces, watching first', () {
    expect([for (final f in GymOwnerFace.values) f.name], _art.faces);
  });
}
