import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/widgets/battle_art_path.dart';

/// The length of everything [path] draws.
double _length(Path path) =>
    path.computeMetrics().fold(0, (sum, metric) => sum + metric.length);

void main() {
  group('battleArtPath', () {
    test('reads absolute moves and lines', () {
      final path = battleArtPath('M36 70L16 60L20 78Z');
      expect(path.getBounds(), const Rect.fromLTRB(16, 60, 36, 78));
      expect(path.contains(const Offset(24, 69)), isTrue);
    });

    test('more pairs after a move are lines', () {
      final path = battleArtPath('M0 0 10 0 10 10');
      expect(_length(path), 20);
      expect(path.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
    });

    test('reads horizontal and vertical lines, absolute and relative', () {
      expect(
        battleArtPath('M6 84H90').getBounds(),
        const Rect.fromLTRB(6, 84, 90, 84),
      );
      expect(
        battleArtPath('M68 16V5').getBounds(),
        const Rect.fromLTRB(68, 5, 68, 16),
      );
      final relative = battleArtPath('M10 10h5v-4');
      expect(relative.getBounds(), const Rect.fromLTRB(10, 6, 15, 10));
      expect(_length(relative), 9);
    });

    test('reads relative lines whose numbers run together', () {
      // The small star of the knocked-out pose.
      final star = battleArtPath(
        'M24 60l3.5 8 8 3.5-8 3.5-3.5 8-3.5-8-8-3.5 8-3.5z',
      );
      expect(star.getBounds(), const Rect.fromLTRB(12.5, 60, 35.5, 83));
      expect(star.contains(const Offset(24, 71.5)), isTrue);
    });

    test('a relative move starts from where the last part ended', () {
      final path = battleArtPath('M4 12l7 7m10 0l-7 7');
      expect(path.computeMetrics(), hasLength(2));
      expect(path.getBounds(), const Rect.fromLTRB(4, 12, 21, 26));
    });

    test('reads quadratic curves, absolute and relative', () {
      final absolute = battleArtPath('M36 68Q68 80 100 66');
      expect(absolute.getBounds().left, 36);
      expect(absolute.getBounds().right, 100);
      expect(absolute.getBounds().bottom, greaterThan(70));
      // The two happy eyes of the win pose.
      final eyes = battleArtPath('M62 100q7.5-12 15 0M83 100q7-12 14 0');
      expect(eyes.computeMetrics(), hasLength(2));
      expect(eyes.getBounds().left, 62);
      expect(eyes.getBounds().right, 97);
      expect(eyes.getBounds().bottom, 100);
      expect(eyes.getBounds().top, lessThan(96));
    });

    test('closing goes back to where the part started', () {
      final path = battleArtPath('M0 0L10 0L10 10ZL0 5');
      // Three sides, the closing diagonal, and a line on from the start.
      expect(_length(path), closeTo(10 + 10 + 14.142 + 5, 0.01));
    });

    test('commas and line breaks may separate the numbers', () {
      expect(
        battleArtPath('M 1,2 L 3,4\n L 5,6').getBounds(),
        const Rect.fromLTRB(1, 2, 5, 6),
      );
    });

    test('refuses what the design\'s drawings do not use', () {
      expect(() => battleArtPath('M0 0C1 1 2 2 3 3'), throwsArgumentError);
      expect(() => battleArtPath('M0 0A5 5 0 0 1 9 9'), throwsArgumentError);
      expect(() => battleArtPath('M0 0L1 x'), throwsArgumentError);
    });

    test('refuses a command with a number missing, or numbers with none', () {
      expect(() => battleArtPath('M0 0L5'), throwsArgumentError);
      expect(() => battleArtPath('5 5L1 1'), throwsArgumentError);
      expect(() => battleArtPath('M0 0L1 1Z5 5'), throwsArgumentError);
    });
  });
}
