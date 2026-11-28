import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/rankings/rankings_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/arcade_parts.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/lobby_parts.dart';
import 'package:gymrats_app/widgets/tutorial_modes.dart';
import 'package:gymrats_app/widgets/tutorial_person.dart';

Future<void> pumpModes(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: const Scaffold(
        body: Align(alignment: Alignment.topLeft, child: TutorialModes()),
      ),
    ),
  );
}

/// How tall a placed person stands: the floor less the top of the head.
double heightOf(TutorialModeIcon icon) {
  final joints = icon.joints;
  final tops = [
    joints.shoulder.dy,
    joints.hip.dy,
    joints.knee.dy,
    joints.wrist.dy,
    joints.head.dy - TutorialBody.headRadius * icon.scale,
  ];
  return TutorialModeIcon.floorY - tops.reduce((a, b) => a < b ? a : b);
}

TutorialModeIcon iconNamed(String name) =>
    TutorialModes.icons.firstWhere((icon) => icon.name == name);

void main() {
  testWidgets('draws the online battle and the arcade on a 316 x 326 board', (
    tester,
  ) async {
    await pumpModes(tester);
    expect(tester.getSize(find.byType(TutorialModes)), const Size(316, 326));
    for (final words in [
      '온라인 대결',
      '다른 사람과 1:1 대결',
      '점수를 모아 주간 랭킹을 올려요',
      '아케이드',
      '혼자서 층마다 보스 깨기',
      'VS',
      '푸시업',
      '스쿼트',
      '플랭크',
      '의자 자세',
    ]) {
      expect(find.text(words), findsOneWidget, reason: words);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the four points are the ranking\'s, KO on lime', (tester) async {
    await pumpModes(tester);
    for (final (name, points) in [
      ('KO승', RankingPoints.koWin),
      ('승리', RankingPoints.win),
      ('무승부', RankingPoints.draw),
      ('패배', RankingPoints.loss),
    ]) {
      expect(find.text(name), findsOneWidget);
      final cell = find.ancestor(
        of: find.text(name),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).border != null,
        ),
      );
      expect(
        find.descendant(of: cell.first, matching: find.text('$points')),
        findsOneWidget,
      );
      final fill =
          (tester.widget<Container>(cell.first).decoration! as BoxDecoration)
              .color;
      expect(fill, name == 'KO승' ? AppColors.accent : AppColors.card);
      expect(tester.getSize(cell.first).height, 22);
    }
    expect(TutorialModes.scores, const [
      ('KO승', RankingPoints.koWin),
      ('승리', RankingPoints.win),
      ('무승부', RankingPoints.draw),
      ('패배', RankingPoints.loss),
    ]);
  });

  test('a screen reader hears the design\'s sentence with the points', () {
    expect(
      TutorialModes.label,
      '온라인 대결: 다른 사람과 1:1 대결, KO승 ${RankingPoints.koWin}점, '
      '승리 ${RankingPoints.win}점, 무승부 ${RankingPoints.draw}점, '
      '패배 ${RankingPoints.loss}점, 점수를 모아 주간 랭킹을 올려요. '
      '아케이드: 혼자서 층마다 보스 깨기, 푸시업, 스쿼트, 하이 플랭크, 의자 자세',
    );
  });

  testWidgets('the cards hold 펭뚱이 against GYM마우스, and the seal owner', (
    tester,
  ) async {
    await pumpModes(tester);
    final figures = tester
        .widgetList<ArcadeFigure>(find.byType(ArcadeFigure))
        .toList();
    expect(
      [for (final f in figures) (f.id, f.side, f.mirror)],
      [('penguin', BattleSide.opponent, true), ('mouse', BattleSide.me, false)],
    );
    final owner = tester.widget<ArcadeOwnerFigure>(
      find.byType(ArcadeOwnerFigure),
    );
    expect((owner.id, owner.mirror), ('seal', true));
    // The cards are 118 x 140 at the design's places.
    Offset cardOf(Finder figure) => tester.getTopLeft(
      find
          .ancestor(of: figure, matching: find.byType(Container))
          .evaluate()
          .map((element) => find.byWidget(element.widget))
          .firstWhere((card) => tester.getSize(card) == const Size(118, 140)),
    );
    expect(cardOf(find.byType(ArcadeOwnerFigure)), const Offset(12, 174));
    expect(cardOf(find.byType(ArcadeFigure).first), const Offset(12, 12));
  });

  testWidgets(
    'VS sits on the online card\'s right middle, clear of the mouse',
    (tester) async {
      await pumpModes(tester);
      final vs = tester.getCenter(find.text('VS'));
      // Inside the 2 edge: (12 + 2 + 94.4, 12 + 2 + 81.2).
      expect(vs.dx, closeTo(108.4, 1));
      expect(vs.dy, closeTo(95.2, 1));
      final mouse = tester.getRect(
        find.byWidgetPredicate((w) => w is ArcadeFigure && w.id == 'mouse'),
      );
      expect(vs.dx, greaterThan(mouse.center.dx));
    },
  );

  testWidgets('the words are drawn at the design\'s sizes', (tester) async {
    await pumpModes(tester);
    Size wordSize(String text) => tester.getSize(
      find.ancestor(
        of: find.text(text),
        matching: find.byType(TutorialModeWord),
      ),
    );
    expect(wordSize('온라인 대결').height, 23);
    expect(wordSize('다른 사람과 1:1 대결').height, 18);
    expect(wordSize('점수를 모아 주간 랭킹을 올려요').height, 16);
    expect(wordSize('의자 자세').height, 13);
    final word = tester.widget<TutorialModeWord>(
      find.ancestor(
        of: find.text('온라인 대결'),
        matching: find.byType(TutorialModeWord),
      ),
    );
    expect(word.size, 23);
    expect(word.scale, 23 / word.style.fontSize!);
    // The name column starts at the design's 142 (the slant leans its
    // top right, about its bottom left, as the design's skewX).
    final name = find.ancestor(
      of: find.text('온라인 대결'),
      matching: find.byType(LobbySkew),
    );
    expect(tester.getTopLeft(name), const Offset(142, 16));
  });

  group('the arcade icons', () {
    test('are the design\'s four calls, clocks on the holds only', () {
      expect(
        [
          for (final icon in TutorialModes.icons)
            (icon.name, icon.pose, icon.k, icon.scale, icon.clock, icon.shift),
        ],
        [
          ('푸시업', TutorialSidePose.push, 0.75, 0.5, false, 0.0),
          ('스쿼트', TutorialSidePose.squat, 0.9, 0.38, false, 0.0),
          ('플랭크', TutorialSidePose.push, 0.0, 0.5, true, 0.0),
          ('의자 자세', TutorialSidePose.squat, 1.08, 0.44, true, -7.0),
        ],
      );
    });

    test('everyone stands on the floor line', () {
      for (final icon in TutorialModes.icons) {
        final joints = icon.joints;
        final lowest = [
          joints.ankle.dy,
          joints.toe.dy,
          joints.heel.dy,
          joints.knee.dy,
          joints.wrist.dy,
        ].reduce((a, b) => a > b ? a : b);
        expect(
          lowest,
          lessThanOrEqualTo(TutorialModeIcon.floorY),
          reason: icon.name,
        );
        expect(
          lowest,
          greaterThan(TutorialModeIcon.floorY - 4),
          reason: icon.name,
        );
      }
    });

    test('the chair pose is about the squat\'s height (within 10%)', () {
      final squat = heightOf(iconNamed('스쿼트'));
      final chair = heightOf(iconNamed('의자 자세'));
      expect((chair - squat).abs() / squat, lessThan(0.1));
    });

    test('the plank and chair people keep off the clock', () {
      const center = TutorialModeIcon.clockCenter;
      const radius = TutorialModeIcon.clockRadius;
      for (final name in ['플랭크', '의자 자세']) {
        final shapes = iconNamed(name).shapes;
        final pieces = [
          ...shapes.farLeg,
          ...shapes.farArm,
          ...shapes.leg,
          ...shapes.torso,
          ...shapes.neck,
          ...shapes.head,
          ...shapes.arm,
        ];
        for (var dx = -radius; dx <= radius; dx += 0.5) {
          for (var dy = -radius; dy <= radius; dy += 0.5) {
            if (dx * dx + dy * dy > radius * radius) continue;
            final point = center + Offset(dx, dy);
            for (final piece in pieces) {
              expect(piece.contains(point), isFalse, reason: '$name at $point');
            }
          }
        }
      }
    });

    testWidgets('each tile draws a floor line and no wall', (tester) async {
      await pumpModes(tester);
      final tiles = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is TutorialModeIconPainter,
      );
      expect(tiles, findsNWidgets(4));
      for (final tile in tiles.evaluate()) {
        final finder = find.byWidget(tile.widget);
        expect(tester.getSize(finder), const Size(37, 29));
        // One rounded rect (the floor), no post or wall rect.
        expect(finder, paintsExactlyCountTimes(#drawRRect, 1));
        expect(finder, paintsExactlyCountTimes(#drawRect, 0));
      }
      // Two clocks: a fill and an edge each.
      var circles = 0;
      for (final tile in tiles.evaluate()) {
        final painter =
            (tile.widget as CustomPaint).painter! as TutorialModeIconPainter;
        if (painter.icon.clock) circles++;
      }
      expect(circles, 2);
      expect(
        find.byWidget(tiles.evaluate().last.widget),
        paints
          ..rrect(color: AppColors.pictogramFloor)
          ..circle(
            x: TutorialModeIcon.clockCenter.dx,
            y: TutorialModeIcon.clockCenter.dy,
            radius: TutorialModeIcon.clockRadius,
            color: AppColors.warning,
          ),
      );
      expect(
        find.byWidget(tiles.evaluate().first.widget),
        isNot(paints..circle(color: AppColors.warning)),
      );
    });

    testWidgets('the tiles sit in a row under the arcade line', (tester) async {
      await pumpModes(tester);
      final tiles = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is TutorialModeIconPainter,
      );
      final lefts = [
        for (final tile in tiles.evaluate())
          tester.getTopLeft(find.byWidget(tile.widget)).dx,
      ];
      // 37 wide, 4 apart, the board 1.5 out of each tile's edge.
      expect(lefts.first, closeTo(142, 0.5));
      for (var i = 1; i < lefts.length; i++) {
        expect(lefts[i] - lefts[i - 1], closeTo(41, 0.01));
      }
      // The names stay inside the picture.
      expect(tester.getRect(find.text('의자 자세')).right, lessThan(316));
    });
  });

  testWidgets('fits its board whatever the system text size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: TutorialModes()),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester
          .getSize(
            find.ancestor(
              of: find.text('온라인 대결'),
              matching: find.byType(TutorialModeWord),
            ),
          )
          .height,
      23,
    );
  });
}
