import 'package:flutter/material.dart';

import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/tutorial_page.dart';
import '../theme/app_theme.dart';
import 'battle_fx_motion.dart';
import 'battle_stage_model.dart';
import 'character_figure.dart';
import 'help_rules.dart';
import 'pose_silhouette_guide.dart';
import 'tutorial_rep_bot.dart';

/// The picture of one tutorial page: RepBot doing the exercise, or a small
/// copy of the battle screen with the stage's characters. Drawn on a
/// [width] x [height] board and scaled to the room it gets.
class HelpPicture extends StatelessWidget {
  const HelpPicture({super.key, required this.page});

  final TutorialPage page;

  static const width = 300.0;
  static const height = 220.0;

  /// How deep RepBot is on each grade page (0 top, 1 bottom).
  static const gradeDepth = {
    TutorialStep.excellent: 1.0,
    TutorialStep.good: 0.75,
    TutorialStep.average: 0.35,
    TutorialStep.fail: 0.15,
  };

  /// The squat's pass line, at the good page's depth.
  static const squatPassDepth = 0.75;

  /// The stage's characters for the battle pages: (mine, the opponent's).
  static (String, String) charactersOf(ExerciseType exercise) =>
      switch (exercise) {
        ExerciseType.pushUp => ('mouse', 'seal'),
        ExerciseType.squat => ('penguin', 'kangaroo'),
      };

  @override
  Widget build(BuildContext context) {
    final squat = page.exercise == ExerciseType.squat;
    final children = switch (page.step) {
      TutorialStep.intro => _intro(context, squat),
      TutorialStep.setup =>
        squat ? _squatSetup(context) : _pushUpSetup(context),
      TutorialStep.battle => _battle(context, fever: false),
      TutorialStep.excellent ||
      TutorialStep.good ||
      TutorialStep.average ||
      TutorialStep.fail => _grade(context, squat),
      TutorialStep.fever => _battle(context, fever: true),
      TutorialStep.ko => _ko(context),
      TutorialStep.report => _report(context, squat),
    };
    return Semantics(
      image: true,
      label: HelpRules.of(page).title,
      child: ExcludeSemantics(
        child: FittedBox(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(clipBehavior: Clip.none, children: children),
          ),
        ),
      ),
    );
  }

  List<Widget> _intro(BuildContext context, bool squat) => [
    Positioned(
      left: 0,
      right: 0,
      top: squat ? 202 : 198,
      child: const _Floor(),
    ),
    Positioned(
      left: squat ? 36 : 24,
      top: squat ? 108 : 132,
      child: Transform.rotate(angle: squat ? 0 : -0.25, child: const _Phone()),
    ),
    if (squat)
      const Positioned(
        left: 168,
        top: 36,
        width: 100,
        height: 166,
        child: TutorialRepBot(figure: RepBotFigure.squatFront),
      )
    else
      const Positioned(
        left: 86,
        top: 40,
        width: 204,
        height: 168,
        child: TutorialRepBot(figure: RepBotFigure.pushUpSide, depth: 0.5),
      ),
    Positioned(
      right: 12,
      top: 12,
      child: _Pill(
        label: '1:1 · ${HelpRules.totalSeconds}초',
        color: AppColors.ink,
        textColor: AppColors.onInk,
      ),
    ),
  ];

  /// Two camera panels with the app's guide: outside the line it waits,
  /// inside the green line it is ready.
  List<Widget> _pushUpSetup(BuildContext context) {
    final caption = Theme.of(context).textTheme.labelSmall;
    return [
      const Positioned(
        left: 0,
        top: 0,
        width: 144,
        height: 192,
        child: _GuidePanel(ready: false),
      ),
      const Positioned(
        left: 156,
        top: 0,
        width: 144,
        height: 192,
        child: _GuidePanel(ready: true),
      ),
      Positioned(
        left: 134,
        top: 80,
        child: DecoratedBox(
          decoration: const ShapeDecoration(
            color: AppColors.accent,
            shape: CircleBorder(side: BorderSide(color: AppColors.ink)),
          ),
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.s4),
            child: Icon(Icons.arrow_forward, color: AppColors.ink),
          ),
        ),
      ),
      Positioned(
        left: 0,
        width: 144,
        top: 198,
        child: Text(
          '선 밖이면 대기',
          textAlign: TextAlign.center,
          style: caption?.copyWith(color: AppColors.textSecondary),
        ),
      ),
      Positioned(
        left: 156,
        width: 144,
        top: 198,
        child: Text(
          '선 안 = 준비 완료',
          textAlign: TextAlign.center,
          style: caption?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ];
  }

  List<Widget> _squatSetup(BuildContext context) => [
    Positioned(
      left: 40,
      top: 10,
      width: 220,
      height: 200,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
          border: Border.all(color: AppColors.accent, width: AppSpacing.s4),
        ),
      ),
    ),
    const Positioned(
      left: 110,
      top: 50,
      width: 80,
      height: 133,
      child: TutorialRepBot(figure: RepBotFigure.squatFront),
    ),
    const Positioned(
      left: 0,
      right: 0,
      top: 22,
      child: Center(
        child: _Pill(
          label: '인식 완료',
          color: AppColors.accent,
          textColor: AppColors.ink,
        ),
      ),
    ),
    Positioned(
      left: 0,
      right: 0,
      top: 184,
      child: Center(
        child: Text(
          '상대를 기다리는 중…',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.onInk),
        ),
      ),
    ),
  ];

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
      const Positioned(
        left: 16,
        right: 16,
        top: 8,
        child: _Hud(mine: 245, theirs: 145, time: '0:12', fever: false),
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
    final name = HelpRules.exerciseName(page.exercise);
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

/// A camera panel with the push-up setup guide: RepBot fills the outline
/// when [ready], and stands off to the side, dimmed, when not.
class _GuidePanel extends StatelessWidget {
  const _GuidePanel({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.textSecondary),
        child: FittedBox(
          child: SizedBox.fromSize(
            size: RepBotFigure.pushUpFront.viewBox.size,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Transform.translate(
                    offset: ready ? Offset.zero : const Offset(70, 40),
                    child: Transform.scale(
                      scale: ready ? 1 : 0.8,
                      child: const TutorialRepBot(
                        figure: RepBotFigure.pushUpFront,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(child: PoseSilhouetteGuide(ready: ready)),
              ],
            ),
          ),
        ),
      ),
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
