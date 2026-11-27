import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../models/tutorial_page.dart';
import '../theme/app_theme.dart';
import 'help_rules.dart';
import 'tutorial_draft.dart';
import 'tutorial_rep_bot.dart';
import 'tutorial_setup_scenes.dart';

/// The picture of one tutorial page: RepBot doing the exercise, or a small
/// copy of the battle screen with the stage's characters. Drawn on a
/// [width] x [height] board and scaled to the room it gets.
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
  /// `aria-label` where the page has its new picture, else the title.
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
      _ => HelpRules.of(page).title,
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
      TutorialStep.welcome => Stack(
        clipBehavior: Clip.none,
        children: _welcome(),
      ),
      TutorialStep.report => Stack(
        clipBehavior: Clip.none,
        children: _report(context, squat),
      ),
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

  /// The whole game: RepBot squatting and doing a push-up toward the phone
  /// between them.
  List<Widget> _welcome() => [
    const Positioned(left: 0, right: 0, top: 204, child: _Floor()),
    const Positioned(
      left: 16,
      top: 34,
      width: 100,
      height: 172,
      child: TutorialRepBot(figure: RepBotFigure.squatFront, depth: 0.5),
    ),
    const Positioned(left: 128, top: 140, child: _Phone()),
    const Positioned(
      left: 150,
      top: 82,
      width: 150,
      height: 124,
      child: TutorialRepBot(figure: RepBotFigure.pushUpSide, depth: 0.5),
    ),
    const Positioned(
      left: 0,
      right: 0,
      top: 12,
      child: Center(
        child: _Pill(
          label: '1:1 대결',
          color: AppColors.ink,
          textColor: AppColors.onInk,
        ),
      ),
    ),
  ];

  /// A result card in small, with the way to the form feedback.
  List<Widget> _report(BuildContext context, bool squat) {
    final text = Theme.of(context).textTheme;
    final name = HelpRules.sectionName(page.exercise);
    final tiles = squat
        ? const [('5', 'Excellent'), ('8', 'Good'), ('3', '무효')]
        : const [('6', 'Excellent'), ('9', 'Good'), ('2', 'Average')];
    return [
      Positioned(
        left: 30,
        right: 30,
        top: 4,
        bottom: 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.cardHigh,
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadius.card),
            ),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Column(
              children: [
                Text('승리!', style: text.headlineSmall),
                Text(
                  squat ? '$name · 13회 · 155점' : '$name · 15회 · 190점',
                  style: text.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Row(
                  children: [
                    for (final (index, (count, grade)) in tiles.indexed) ...[
                      if (index > 0) const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.all(
                              Radius.circular(AppRadius.small),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.s4,
                            ),
                            child: Column(
                              children: [
                                Text(count, style: text.titleMedium),
                                Text(
                                  grade,
                                  style: text.labelSmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                const _Pill(
                  label: '자세 피드백 보기',
                  color: AppColors.accent,
                  textColor: AppColors.ink,
                  wide: true,
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

/// A short label on a round box.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.textColor,
    this.wide = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: wide ? AppSpacing.s48 : AppSpacing.s12,
          vertical: AppSpacing.s4,
        ),
        child: Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: textColor, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

/// A phone standing on the floor, camera at the top.
class _Phone extends StatelessWidget {
  const _Phone();

  static const _size = Size(34, 64);

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: _size,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.mark)),
        ),
        child: Align(
          alignment: Alignment(0, -0.7),
          child: SizedBox.square(
            dimension: AppSpacing.s8,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: AppColors.fever,
                shape: CircleBorder(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The floor line under the characters.
class _Floor extends StatelessWidget {
  const _Floor();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: AppSpacing.s8),
    child: SizedBox(
      height: AppSpacing.s4,
      child: ColoredBox(color: AppColors.pictogramFloor),
    ),
  );
}
