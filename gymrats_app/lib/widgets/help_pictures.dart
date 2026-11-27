import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../models/tutorial_page.dart';
import '../services/feedback/coach_script.dart';
import 'tutorial_draft.dart';
import 'tutorial_setup_scenes.dart';
import 'tutorial_welcome.dart';

/// The picture of one tutorial page (A12 design): the game page's two
/// screenshots, the person in front of the phone (page 1), the setup's
/// camera (page 2), the game screen on a phone with its marks made large
/// (way a), the person with the game screen in a bubble (way b), and a
/// character talking about the battle (way d). Drawn on its board
/// ([sizeOf]) and scaled to the room it gets.
class HelpPicture extends StatelessWidget {
  const HelpPicture({super.key, required this.page});

  final TutorialPage page;

  /// The board of a page's picture (A12 design `TutDraft`, 316 x 248); the
  /// page about the game is taller ([welcomeHeight], `TutX` g0).
  static const width = 316.0;
  static const height = 248.0;
  static const welcomeHeight = 326.0;

  /// The board [page]'s picture is drawn on.
  static Size sizeOf(TutorialPage page) =>
      Size(width, page.step == TutorialStep.welcome ? welcomeHeight : height);

  /// What a screen reader hears for [page]'s picture: the A12 design's
  /// `aria-label`, its two misspelled particles fitted (user 2026-11-28).
  static String labelOf(TutorialPage page) {
    final squat = page.exercise == ExerciseType.squat;
    return switch (page.step) {
      TutorialStep.intro =>
        squat
            ? '벽에 기대어 세운 폰 앞에서 두 손을 모으고 스쿼트를 하는 그림'
            : '벽에 기대어 세운 폰 앞에서 푸시업을 하는 그림',
      TutorialStep.setup =>
        squat
            ? '왼쪽은 몸이 선 밖이라 흰 선, 오른쪽은 두 손을 가슴 앞에 모으고 '
                  '선 안에 들어와 초록 선이 된 카메라 화면'
            : '왼쪽은 몸이 선 밖이라 흰 선, 오른쪽은 몸이 선 안에 들어와 '
                  '초록 선이 된 카메라 화면',
      TutorialStep.battle ||
      TutorialStep.combo ||
      TutorialStep.fever ||
      TutorialStep.ko => TutorialDraftLabel.wayA,
      TutorialStep.excellent ||
      TutorialStep.good ||
      TutorialStep.average ||
      TutorialStep.fail => TutorialDraftLabel.wayB(page.exercise!),
      TutorialStep.welcome => TutorialWelcome.label,
      TutorialStep.report => TutorialCoachTalk.label(
        CoachVoice.of(TutorialCoachTalk.speaker),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final squat = page.exercise == ExerciseType.squat;
    final exercise = page.exercise ?? ExerciseType.pushUp;
    final Widget picture = switch (page.step) {
      TutorialStep.intro => TutorialWallScene(squat: squat),
      TutorialStep.setup => TutorialSetupCameras(squat: squat),
      TutorialStep.battle ||
      TutorialStep.combo ||
      TutorialStep.fever ||
      TutorialStep.ko => TutorialPhoneZoom(exercise: exercise, step: page.step),
      TutorialStep.excellent ||
      TutorialStep.good ||
      TutorialStep.average ||
      TutorialStep.fail => TutorialPersonBubble(
        exercise: exercise,
        step: page.step,
      ),
      TutorialStep.welcome => const TutorialWelcome(),
      TutorialStep.report => const TutorialCoachTalk(),
    };
    // A drawing scaled as a whole: its words keep the drawing's size
    // whatever the system text size (the page's own words follow it).
    return Semantics(
      image: true,
      label: labelOf(page),
      child: ExcludeSemantics(
        child: MediaQuery.withNoTextScaling(
          child: FittedBox(
            child: SizedBox.fromSize(size: sizeOf(page), child: picture),
          ),
        ),
      ),
    );
  }
}
