import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/tutorial_page.dart';
import 'package:gymrats_app/services/feedback/coach_script.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/coach_graphics.dart';
import 'package:gymrats_app/widgets/coach_parts.dart';
import 'package:gymrats_app/widgets/tutorial_draft.dart';
import 'package:gymrats_app/widgets/tutorial_figure_painters.dart';
import 'package:gymrats_app/widgets/tutorial_game_shot.dart';
import 'package:gymrats_app/widgets/tutorial_person.dart';

void main() {
  const pushUp = ExerciseType.pushUp;
  const squat = ExerciseType.squat;
  final rules = battleRules;

  Future<void> show(WidgetTester tester, Widget picture) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Center(
          child: SizedBox.fromSize(
            size: TutorialDraft.size,
            child: FittedBox(child: picture),
          ),
        ),
      ),
    );
  }

  test(
    'way a is for the battle, combo, fever and KO; way b for the grades',
    () {
      for (final step in TutorialStep.values) {
        expect(
          TutorialDraft.isWayA(step),
          const {
            TutorialStep.battle,
            TutorialStep.combo,
            TutorialStep.fever,
            TutorialStep.ko,
          }.contains(step),
          reason: '$step',
        );
      }
    },
  );

  group('way a: the game screen on a phone, its marks made large', () {
    Future<void> showA(WidgetTester tester, TutorialStep step) =>
        show(tester, TutorialPhoneZoom(exercise: pushUp, step: step));

    /// How many times [text] shows among the marks at the right, outside
    /// the phone's game screen.
    int marks(WidgetTester tester, String text) => find
        .text(text)
        .evaluate()
        .where(
          (element) => find
              .ancestor(
                of: find.byElementPredicate((e) => e == element),
                matching: find.byType(TutorialGameShot),
              )
              .evaluate()
              .isEmpty,
        )
        .length;

    testWidgets('battle: GOOD and the bar pushed toward the opponent', (
      tester,
    ) async {
      await showA(tester, TutorialStep.battle);
      expect(marks(tester, 'GOOD'), 1);
      expect(find.text('체력 바가 상대 쪽으로'), findsOneWidget);
      final shot = tester.widget<TutorialGameShot>(
        find.byType(TutorialGameShot),
      );
      expect(shot.scene.grade, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('combo: 2 HIT, the rep\'s points and the bonus', (
      tester,
    ) async {
      await showA(tester, TutorialStep.combo);
      expect(marks(tester, '2 HIT'), 1);
      expect(marks(tester, '+${rules.goodPoints}'), 1);
      expect(find.text('콤보 +${rules.comboBonus}'), findsOneWidget);
    });

    testWidgets('fever: the clock at its start, FEVER ×2, an excellent '
        'doubled', (tester) async {
      await showA(tester, TutorialStep.fever);
      expect(
        find.text(
          '0:${rules.feverLength.inSeconds.toString().padLeft(2, '0')}',
        ),
        findsOneWidget,
      );
      expect(marks(tester, BattleFx.feverText(rules.feverMultiplier)), 1);
      expect(
        find.text(
          'EXCELLENT +${rules.excellentPoints * rules.feverMultiplier}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('KO: K.O. and the lead it takes', (tester) async {
      await showA(tester, TutorialStep.ko);
      expect(marks(tester, 'K.O.'), 1);
      expect(find.text('${rules.koLead}점 차'), findsOneWidget);
      // The chip is as wide as its words, not the column.
      final chip = tester.getSize(find.byType(TutorialChip));
      expect(chip.width, lessThan(150));
    });
  });

  group('way b: the person at the grade\'s depth, the game in a bubble', () {
    test('each grade\'s pose and depth, as designed', () {
      expect(TutorialPersonBubble.poseOf(pushUp, TutorialStep.excellent), (
        TutorialSidePose.push,
        0.95,
      ));
      expect(TutorialPersonBubble.poseOf(pushUp, TutorialStep.good), (
        TutorialSidePose.push,
        0.72,
      ));
      expect(TutorialPersonBubble.poseOf(pushUp, TutorialStep.average), (
        TutorialSidePose.push,
        0.3,
      ));
      expect(TutorialPersonBubble.poseOf(pushUp, TutorialStep.fail), (
        TutorialSidePose.kneel,
        0.9,
      ));
      expect(TutorialPersonBubble.poseOf(squat, TutorialStep.excellent), (
        TutorialSidePose.squat,
        1.12,
      ));
      expect(TutorialPersonBubble.poseOf(squat, TutorialStep.good), (
        TutorialSidePose.squat,
        1.0,
      ));
      expect(TutorialPersonBubble.poseOf(squat, TutorialStep.fail), (
        TutorialSidePose.squat,
        0.5,
      ));
      // A fail's bubble looks lower, at the sign over the camera.
      expect(TutorialPersonBubble.windowOf(TutorialStep.fail), 236);
      expect(TutorialPersonBubble.windowOf(TutorialStep.good), 140);
    });

    testWidgets('the person faces the phone at the right; the bubble holds '
        'that grade\'s game screen', (tester) async {
      for (final (exercise, step) in const [
        (pushUp, TutorialStep.excellent),
        (pushUp, TutorialStep.fail),
        (squat, TutorialStep.good),
      ]) {
        await show(
          tester,
          TutorialPersonBubble(exercise: exercise, step: step),
        );
        final person = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((paint) => paint.painter)
            .whereType<TutorialSidePainter>()
            .single;
        expect(person.mirrored, isTrue);
        expect(person.armEdge, 2.6);
        final shot = tester.widget<TutorialGameShot>(
          find.byType(TutorialGameShot),
        );
        expect(shot.scene.squat, exercise == squat);
        expect(
          shot.scene.sign != null,
          step == TutorialStep.fail,
          reason: '$exercise $step',
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('the bubble\'s tail takes no tap: the game screen under it is '
        'what a finger or a finder reaches', (tester) async {
      await show(
        tester,
        const TutorialPersonBubble(
          exercise: pushUp,
          step: TutorialStep.excellent,
        ),
      );
      expect(find.text('EXCELLENT').hitTestable(), findsOneWidget);
    });
  });

  test('the names a screen reader hears, their particles fitted to the '
      'words before them (user 2026-11-28)', () {
    expect(
      TutorialDraftLabel.wayA,
      '왼쪽은 그 순간의 게임 화면 전체, 오른쪽은 그 화면에서 눈여겨볼 표시를 크게 보여 줌',
    );
    expect(
      TutorialDraftLabel.wayB(pushUp),
      '사람이 벽에 기댄 폰 앞에서 푸시업을 하고, 폰 위 말풍선에 그때의 게임 장면',
    );
    expect(
      TutorialDraftLabel.wayB(squat),
      '사람이 벽에 기댄 폰 앞에서 스쿼트를 하고, 폰 위 말풍선에 그때의 게임 장면',
    );
    final report = TutorialCoachTalk.label(
      CoachVoice.of(TutorialCoachTalk.speaker),
    );
    expect(
      report,
      '물렁범이 대화창에서 이번 판을 이야기해 주는 장면. 위에는 5초마다 인정 '
      '횟수 그래프, 아래 대화창에 같은 속도로 하는 게 중요하다범!',
    );
    for (final label in [
      TutorialDraftLabel.wayB(pushUp),
      TutorialDraftLabel.wayB(squat),
      report,
    ]) {
      expect(label, isNot(contains('푸시업를')));
      expect(label, isNot(contains('물렁범가')));
    }
  });

  group('way d: a character talking about the battle', () {
    testWidgets('물렁범 in the coach\'s dialog, mid-talk, the pace card of a '
        'battle that slowed down over them', (tester) async {
      await show(tester, const TutorialCoachTalk());
      final card = tester.widget<CoachGraphicCard>(
        find.byType(CoachGraphicCard),
      );
      final pace = card.graphic as CoachPaceGraphic;
      expect(pace.buckets, [5, 5, 2, 2, 2, 2]);
      expect(pace.sliceSeconds, 5);
      expect(pace.usual, [3, 3, 2.7, 2.7, 2.3, 2.3]);
      expect(pace.mark, CoachPaceMark.late);
      expect(find.text('평소보다 느려졌어요'), findsOneWidget);
      expect(
        tester.widget<CoachNameTag>(find.byType(CoachNameTag)).name,
        '물렁범',
      );
      expect(
        tester
            .widget<CharacterFigure>(find.byType(CharacterFigure))
            .characterId,
        'seal',
      );
      final line = tester.widget<CoachMarkedText>(find.byType(CoachMarkedText));
      expect(line.pieces.where((piece) => piece.marked).single.text, '같은 속도로');
      expect(
        line.pieces.map((piece) => piece.text).join(),
        '멈추지 않고 같은 속도로 하는 게 중요하다범! 처음부터 너무 달리지 말자.',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('where things are, as designed: the card at (146, 10) ×0.49, '
        'the character at (22, 2) ×0.84, the dialog (10, 120) 296×118 with its '
        'line inside the 3 edge, the tag turned about its middle', (
      tester,
    ) async {
      await show(tester, const TutorialCoachTalk());
      final at = tester.getTopLeft(find.byType(TutorialCoachTalk));
      final card = tester.getRect(find.byType(CoachGraphicCard));
      expect(card.topLeft - at, const Offset(146, 10));
      expect(card.width, moreOrLessEquals(328 * 0.49));
      final figure = tester.getRect(find.byType(CharacterFigure));
      expect(figure.topLeft - at, const Offset(22, 2));
      final dialog = tester.getRect(
        find
            .ancestor(
              of: find.byType(CoachMarkedText),
              matching: find.byType(DecoratedBox),
            )
            .last,
      );
      expect(dialog.topLeft - at, const Offset(10, 120));
      expect(dialog.size, const Size(296, 118));
      final line = tester.getRect(find.byType(CoachMarkedText));
      expect(line.topLeft - at, const Offset(10 + 3 + 18, 120 + 3 + 22));
      // The design's 14.5 line from the card's 15: laid out wider, drawn
      // smaller, as wide as the room inside the dialog.
      expect(line.width, moreOrLessEquals(296 - 2 * 3 - 18 - 16));
      final tag = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byType(CoachNameTag),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(tag.alignment, Alignment.center);
    });

    test('the line takes the speaker\'s own ending', () {
      final penguin = TutorialCoachTalk.lineOf(CoachVoice.of('penguin'));
      expect(penguin.map((piece) => piece.text).join(), contains('중요하다펭!'));
    });
  });

  group('where things are, as designed', () {
    Offset origin(WidgetTester tester, Type picture) =>
        tester.getTopLeft(find.byType(picture));

    testWidgets('way a: the phone 108×234 at (16, 7); its game screen inside '
        'the 3 ink edge, 0.2833 of 360×780', (tester) async {
      await show(
        tester,
        const TutorialPhoneZoom(exercise: pushUp, step: TutorialStep.combo),
      );
      final at = origin(tester, TutorialPhoneZoom);
      final phone = tester.getRect(
        find
            .ancestor(
              of: find.byType(TutorialGameShot),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(phone.topLeft - at, const Offset(16, 7));
      expect(phone.size, const Size(108, 234));
      final shot = tester.getRect(find.byType(TutorialGameShot));
      expect(shot.left - at.dx, moreOrLessEquals(19, epsilon: 0.01));
      expect(shot.top - at.dy, moreOrLessEquals(10, epsilon: 0.01));
      expect(shot.width, moreOrLessEquals(360 * 0.2833, epsilon: 0.01));
      expect(shot.height, moreOrLessEquals(780 * 0.2833, epsilon: 0.01));
    });

    testWidgets('way b: the bubble 157×148 at (146, 8); its game screen inside '
        'the 2.5 edge, 0.4222 of it, from 140 down (236 on a fail)', (
      tester,
    ) async {
      for (final (step, window) in const [
        (TutorialStep.good, 140.0),
        (TutorialStep.fail, 236.0),
      ]) {
        await show(tester, TutorialPersonBubble(exercise: pushUp, step: step));
        final at = origin(tester, TutorialPersonBubble);
        final bubble = tester.getRect(
          find
              .ancestor(
                of: find.byType(TutorialGameShot),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(bubble.topLeft - at, const Offset(146, 8));
        expect(bubble.size, const Size(157, 148));
        final shot = tester.getRect(find.byType(TutorialGameShot));
        expect(shot.left - at.dx, moreOrLessEquals(148.5, epsilon: 0.01));
        expect(
          shot.top - at.dy,
          moreOrLessEquals(10.5 - window * 0.4222, epsilon: 0.01),
          reason: '$step',
        );
        expect(shot.width, moreOrLessEquals(360 * 0.4222, epsilon: 0.01));
      }
    });

    testWidgets('way b: the person stands on the floor at 217, its middle at '
        '104, turned about it', (tester) async {
      await show(
        tester,
        const TutorialPersonBubble(exercise: squat, step: TutorialStep.good),
      );
      final person = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<TutorialSidePainter>()
          .single;
      expect(person.mirrorAxis, 104);
      final feet = person.shapes.leg
          .map((piece) => piece.getBounds().bottom)
          .reduce((a, b) => a > b ? a : b);
      expect(feet, moreOrLessEquals(217, epsilon: 3));
      // The middle of the pose's width (in body units) goes to 104.
      final raw = TutorialSide.joints(TutorialSidePose.squat, 1);
      final placed = TutorialSide.place(
        raw,
        scale: 1.45,
        centerX: 104,
        floorY: 217,
      );
      expect(
        placed.hip.dx,
        moreOrLessEquals(
          104 + (raw.hip.dx - TutorialSide.middleOf(raw)) * 1.45,
        ),
      );
    });
  });
}
