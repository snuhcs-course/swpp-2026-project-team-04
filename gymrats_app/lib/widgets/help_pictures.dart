import 'package:flutter/material.dart';

import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/tutorial_page.dart';
import '../theme/app_theme.dart';
import 'battle_fx_motion.dart';
import 'battle_stage_model.dart';
import 'character_figure.dart';
import 'help_rules.dart';
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

  /// How deep RepBot is on each grade page (0 top, 1 bottom).
  static const gradeDepth = {
    TutorialStep.excellent: 1.0,
    TutorialStep.good: 0.75,
    TutorialStep.average: 0.35,
    TutorialStep.fail: 0.15,
  };

  /// The opponent's score on the KO page; mine is [HelpRules.koLead] more,
  /// so the scores, the label and the full bar agree with the rules.
  static const koLoserScore = 145;

  /// The squat's pass line, at the good page's depth.
  static const squatPassDepth = 0.75;

  /// The stage's characters for the battle pages: (mine, the opponent's).
  static (String, String) charactersOf(ExerciseType? exercise) =>
      switch (exercise) {
        ExerciseType.squat => ('penguin', 'kangaroo'),
        _ => ('mouse', 'seal'),
      };

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
      _ => HelpRules.of(page).title,
    };
  }

  @override
  Widget build(BuildContext context) {
    final squat = page.exercise == ExerciseType.squat;
    final Widget picture = switch (page.step) {
      TutorialStep.intro => TutorialWallScene(squat: squat),
      TutorialStep.setup => TutorialSetupCameras(squat: squat),
      _ => Stack(
        clipBehavior: Clip.none,
        children: switch (page.step) {
          TutorialStep.welcome => _welcome(),
          TutorialStep.battle => _battle(context, fever: false),
          TutorialStep.excellent ||
          TutorialStep.good ||
          TutorialStep.average ||
          TutorialStep.fail => _grade(context, squat),
          TutorialStep.combo => _combo(context),
          TutorialStep.fever => _battle(context, fever: true),
          TutorialStep.ko => _ko(context),
          _ => _report(context, squat),
        },
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

  /// A good rep and the next one close behind it, which adds the bonus.
  List<Widget> _combo(BuildContext context) {
    final (mine, theirs) = charactersOf(page.exercise);
    return [
      const Positioned(
        left: 16,
        right: 16,
        top: 8,
        child: _Hud(mine: 120, theirs: 85, time: '0:15', fever: false),
      ),
      const Positioned(left: 0, right: 0, top: 200, child: _Floor()),
      Positioned(
        left: 16,
        top: 100,
        child: CharacterFigure(
          characterId: mine,
          pose: BattlePose.attack,
          scale: 0.65,
        ),
      ),
      Positioned(
        right: 16,
        top: 100,
        child: Transform.flip(
          flipX: true,
          child: CharacterFigure(
            characterId: theirs,
            side: BattleSide.opponent,
            scale: 0.65,
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 92,
        child: Center(
          child: _Pill(
            label: '+${HelpRules.good}',
            color: AppColors.accent,
            textColor: AppColors.ink,
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 124,
        child: Center(
          child: _Pill(
            label: 'COMBO +${HelpRules.comboBonus}',
            color: AppColors.warning,
            textColor: AppColors.ink,
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 206,
        child: Center(
          child: Text(
            '${HelpRules.comboSeconds}초 안에 다음 동작',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
    ];
  }

  List<Widget> _grade(BuildContext context, bool squat) {
    final (label, color, textColor) = switch (page.step) {
      TutorialStep.excellent => (
        'EXCELLENT +${HelpRules.excellent}',
        AppColors.accent,
        AppColors.ink,
      ),
      TutorialStep.good => (
        'GOOD +${HelpRules.good}',
        AppColors.ink,
        AppColors.onInk,
      ),
      TutorialStep.average => (
        'AVERAGE +${HelpRules.average}',
        AppColors.warning,
        AppColors.ink,
      ),
      _ => ('FAIL 0점', AppColors.danger, AppColors.ink),
    };
    final depth = gradeDepth[page.step]!;
    return [
      Positioned(left: 0, right: 0, top: 206, child: const _Floor()),
      if (squat)
        Positioned(
          left: 60,
          right: 0,
          top: 50,
          height: 160,
          child: TutorialRepBot(
            figure: RepBotFigure.squatFront,
            depth: depth,
            passDepth: squatPassDepth,
          ),
        )
      else
        Positioned(
          left: 48,
          top: 50,
          width: 204,
          height: 168,
          child: TutorialRepBot(figure: RepBotFigure.pushUpSide, depth: depth),
        ),
      Positioned(
        left: 0,
        right: 0,
        top: 8,
        child: Center(
          child: _Pill(label: label, color: color, textColor: textColor),
        ),
      ),
      if (page.step == TutorialStep.fail)
        const Positioned(
          right: 24,
          top: 80,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: AppColors.danger,
              shape: CircleBorder(),
            ),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.s4),
              child: Icon(Icons.close, color: AppColors.onInk),
            ),
          ),
        ),
    ];
  }

  /// The battle screen in small; in [fever] the last seconds' look.
  List<Widget> _battle(BuildContext context, {required bool fever}) {
    final (mine, theirs) = charactersOf(page.exercise);
    return [
      if (fever)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.card),
              ),
              border: Border.all(color: AppColors.fever, width: AppSpacing.s4),
            ),
          ),
        ),
      Positioned(
        left: 16,
        right: 16,
        top: 8,
        child: _Hud(
          mine: fever ? 190 : 120,
          theirs: fever ? 150 : 85,
          time: fever ? '0:08' : '0:18',
          fever: fever,
        ),
      ),
      if (fever)
        Positioned(
          left: 0,
          right: 0,
          top: 82,
          child: Center(
            child: _Pill(
              label: 'FEVER TIME ×${HelpRules.feverMultiplier}',
              color: AppColors.fever,
              textColor: AppColors.ink,
            ),
          ),
        ),
      Positioned(left: 0, right: 0, top: 204, child: const _Floor()),
      Positioned(
        left: 16,
        top: 100,
        child: CharacterFigure(
          characterId: mine,
          pose: BattlePose.attack,
          scale: 0.65,
        ),
      ),
      Positioned(
        right: 16,
        top: 100,
        child: Transform.flip(
          flipX: true,
          child: CharacterFigure(
            characterId: theirs,
            pose: fever ? BattlePose.hit : BattlePose.idle,
            side: BattleSide.opponent,
            scale: 0.65,
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 118,
        child: Center(
          child: _Pill(
            label: fever
                ? '+${HelpRules.feverExcellent}'
                : '+${HelpRules.good}',
            color: fever ? AppColors.fever : AppColors.accent,
            textColor: AppColors.ink,
          ),
        ),
      ),
    ];
  }

  List<Widget> _ko(BuildContext context) {
    final (mine, theirs) = charactersOf(page.exercise);
    return [
      Positioned(
        left: 16,
        right: 16,
        top: 8,
        child: _Hud(
          mine: koLoserScore + HelpRules.koLead,
          theirs: koLoserScore,
          time: '0:12',
          fever: false,
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 80,
        child: Center(
          child: _Pill(
            label: '${HelpRules.koLead}점 차',
            color: AppColors.ink,
            textColor: AppColors.onInk,
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 112,
        child: Center(
          child: Text('K.O.!', style: Theme.of(context).textTheme.displaySmall),
        ),
      ),
      Positioned(left: 0, right: 0, top: 204, child: const _Floor()),
      Positioned(
        left: 4,
        top: 110,
        child: CharacterFigure(
          characterId: mine,
          pose: BattlePose.win,
          scale: 0.58,
        ),
      ),
      Positioned(
        right: 4,
        top: 110,
        child: Transform.flip(
          flipX: true,
          child: CharacterFigure(
            characterId: theirs,
            pose: BattlePose.knockedOut,
            side: BattleSide.opponent,
            scale: 0.58,
          ),
        ),
      ),
    ];
  }

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

/// The score line of the battle screen: both scores, the time and the bar.
class _Hud extends StatelessWidget {
  const _Hud({
    required this.mine,
    required this.theirs,
    required this.time,
    required this.fever,
  });

  final int mine;
  final int theirs;
  final String time;

  final bool fever;

  /// My part of the bar, 0 to 1, as the game draws it for these scores.
  double get share => battleRules.barShare(mine - theirs);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final side = text.labelSmall?.copyWith(color: AppColors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('나', style: side),
                Text('$mine', style: text.titleLarge),
              ],
            ),
            const Spacer(),
            _Pill(
              label: time,
              color: fever ? AppColors.fever : AppColors.ink,
              textColor: fever ? AppColors.ink : AppColors.onInk,
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('상대', style: side),
                Text('$theirs', style: text.titleLarge),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.mark)),
          child: SizedBox(
            height: AppSpacing.s12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: (share * 100).round(),
                  child: const ColoredBox(color: AppColors.accent),
                ),
                Expanded(
                  flex: 100 - (share * 100).round(),
                  child: const ColoredBox(color: AppColors.opponent),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
