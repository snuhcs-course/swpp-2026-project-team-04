import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/widgets/gym_background.dart';
import 'package:gymrats_app/widgets/gym_background_art.dart';

final _art = GymArt.standard;

Widget _host(Widget child, {double width = 360}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: child),
  ),
);

GymArtPainter _painterIn(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(GymBackground),
      matching: find.byType(CustomPaint),
    ),
  );
  return paint.painter! as GymArtPainter;
}

void main() {
  testWidgets('takes the width it is given and 390/360 of it as height', (
    tester,
  ) async {
    for (final width in [360.0, 412.0, 180.0]) {
      await tester.pumpWidget(
        _host(const GymBackground(floor: 2), width: width),
      );
      expect(
        tester.getSize(find.byType(GymBackground)),
        Size(width, width * 390 / 360),
      );
    }
  });

  testWidgets('draws its floor, cut to the 360 x 390 picture', (tester) async {
    for (final floor in [1, 2, 3, 4, 5]) {
      await tester.pumpWidget(_host(GymBackground(floor: floor)));
      final painter = _painterIn(tester);
      expect(identical(painter.shapes, _art.floors[floor]), isTrue);
      expect(painter.window, const Size(360, 390));
      expect(painter.clip, isTrue);
    }
  });

  testWidgets('an unknown floor draws 1F', (tester) async {
    for (final floor in [0, 6, -1, 42]) {
      await tester.pumpWidget(_host(GymBackground(floor: floor)));
      expect(
        identical(_painterIn(tester).shapes, _art.floors[1]),
        isTrue,
        reason: '$floor',
      );
      expect(GymBackground.floorShown(floor), 1);
    }
    expect(GymBackground.floorShown(4), 4);
  });

  testWidgets('is decoration: screen readers skip it', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const GymBackground(floor: 3)));
    final exclude = tester.widget<ExcludeSemantics>(
      find.descendant(
        of: find.byType(GymBackground),
        matching: find.byType(ExcludeSemantics),
      ),
    );
    expect(exclude.excluding, isTrue);
    expect(
      find.descendant(
        of: find.byType(GymBackground),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
    handle.dispose();
  });

  test('publishes the picture size and the floor line of the art data', () {
    expect(gymBackgroundSize, _art.backgroundSize);
    expect(gymBackgroundFloorLineY, _art.floorLineY);
    expect(gymBackgroundFloorLineY, 296);
  });
}
