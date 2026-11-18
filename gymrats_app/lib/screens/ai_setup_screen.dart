import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/bot_difficulty.dart';
import '../models/character_rig.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/feedback_goal.dart';
import '../models/matchup.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../utils/korean_josa.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/character_figure.dart';
import '../widgets/exercise_sheet.dart';
import '../widgets/lobby_parts.dart';

/// AI 1v1, from 게임 시작: the exercise and RepBot's level, then 대결 시작.
/// The choice is kept in home's view model.
///
/// The user's goals (A11 spec 3) show as a sticker on each exercise with
/// one, and the chosen exercise's goal as a row under the cards. The
/// screen reads them once and never changes them (task.md W11 decision
/// 6); what they move stays hidden for the moment the read takes, so
/// nothing jumps when they come.
class AiSetupScreen extends StatefulWidget {
  const AiSetupScreen({super.key});

  @override
  State<AiSetupScreen> createState() => _AiSetupScreenState();

  /// The end of the line under the start button for [goal] (spec 3), e.g.
  /// " · 목표 20회" or " · 목표 콤보 5"; empty without one.
  @visibleForTesting
  static String summaryGoal(FeedbackGoal? goal) {
    if (goal == null) return '';
    final sticker = GoalSticker.textOf(goal);
    // The reps sticker already starts with 목표.
    return goal.kind == GoalKind.reps ? ' · $sticker' : ' · 목표 $sticker';
  }
}

class _AiSetupScreenState extends State<AiSetupScreen>
    with GoalsOnce<AiSetupScreen> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final setup = vm.state.botSetup;
    final level = vm.state.botLevel;
    final profile = vm.state.profile!;
    final text = Theme.of(context).textTheme;
    final goals = this.goals;
    final goal = goals?[setup.exercise];
    // Under the subtitle everything waits unseen for the goals, at most
    // [GoalsOnce.readLimit].
    Widget shown(Widget child) =>
        goals == null ? Opacity(opacity: 0, child: child) : child;
    return LobbyPage(
      behind: const LobbyWatermark('BOT', left: 168),
      children: [
        const LobbyPageHeader(
          tag: 'PLAY / AI 1V1',
          title: 'AI 1v1',
          tagColor: AppColors.textPrimary,
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          'RepBot과 겨룰 종목과 난이도를 골라요',
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        // 20 over each section and 16 at least over 대결 시작, so the goal
        // row fits a 360 x 780 phone (task.md W11 decision 9).
        const SizedBox(height: AppSpacing.s20),
        shown(const _SectionLabel('종목', 'EXERCISE')),
        const SizedBox(height: AppSpacing.s8),
        shown(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, exercise)
                    in ExerciseType.values.indexed) ...[
                  if (index > 0) const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: _ExerciseOption(
                      exercise,
                      best: profile.bestOf(exercise),
                      goal: goals?[exercise],
                      selected: exercise == setup.exercise,
                      onTap: () => vm.chooseBotExercise(exercise),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (goal != null) ...[
          const SizedBox(height: AppSpacing.s12),
          _GoalRow(goal),
        ],
        const SizedBox(height: AppSpacing.s20),
        shown(const _SectionLabel('난이도', 'LEVEL')),
        const SizedBox(height: AppSpacing.s8),
        for (final (index, option) in BotDifficulty.values.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.s8),
          shown(
            _LevelOption(
              option,
              selected: option == level,
              onTap: () => vm.chooseBotLevel(option),
            ),
          ),
        ],
        const Spacer(),
        const SizedBox(height: AppSpacing.s16),
        shown(
          _StartButton(
            onPressed: () => Navigator.pushNamed(
              context,
              GymRatsApp.matchingRoute,
              arguments: BotMatchRequest(
                exercise: setup.exercise,
                difficulty: level,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        shown(
          Text(
            '${setup.exercise.koreanName} · RepBot ${level.label} · '
            '${battleDuration.inSeconds}초 대결${AiSetupScreen.summaryGoal(goal)}',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// The design's dark start button: "대결 시작" in white with a lime arrow
/// (a dark fill takes light text, the exception in palette B).
class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  static const _height = 58.0;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.onInk,
        minimumSize: const Size.fromHeight(_height),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: LobbySkew(
              degrees: 10,
              alignment: Alignment.center,
              child: Text(
                '대결 시작',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.lobbyButton
                    .copyWith(color: AppColors.onInk),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          const Icon(Icons.arrow_forward_rounded, color: AppColors.accent),
        ],
      ),
    );
  }
}

/// A bold Korean name with its English tag beside it.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.name, this.tag);

  final String name;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(name, style: text.lobbyRowTitle),
          const SizedBox(width: AppSpacing.s8),
          ExcludeSemantics(
            child: Text(
              tag,
              style: text.lobbyMiniTag.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A choice on this page: a card with a thick edge, ink on a light lime
/// fill when chosen, as designed.
class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  /// What a screen reader says for it.
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  static const _edge = 2.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.selectedFill : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
          side: BorderSide(
            color: selected ? AppColors.ink : AppColors.border,
            width: _edge,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

/// An exercise with its drawing, its name and the user's best in it.
class _ExerciseOption extends StatelessWidget {
  const _ExerciseOption(
    this.exercise, {
    required this.best,
    required this.selected,
    required this.onTap,
    this.goal,
  });

  final ExerciseType exercise;
  final PersonalBest? best;

  /// The user's goal for [exercise], worn as a sticker; null for none.
  final FeedbackGoal? goal;
  final bool selected;
  final VoidCallback onTap;

  static const _pictureSize = Size(50, 28);
  static const _checkSize = 22.0;

  String get _best => switch (best) {
    null => '기록 없음',
    final best when best.readsInPoints => '최고 ${best.score}점',
    final best => '최고 ${best.reps}회',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final goal = this.goal;
    final option = _Option(
      label: [
        '${exercise.koreanName}, $_best',
        if (goal != null) '이번 판 목표 ${goal.title}',
      ].join(', '),
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ExercisePictogram(
                  exercise,
                  size: _pictureSize,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
                if (selected)
                  const LobbyArrowChip(
                    size: _checkSize,
                    icon: Icons.check_rounded,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: LobbySkew(
                      degrees: 10,
                      // One line: the row's height is measured on it too,
                      // and two would leave the card 32 taller than drawn.
                      child: Text(
                        exercise.koreanName,
                        maxLines: 1,
                        softWrap: false,
                        style: text.lobbyCardTitle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                // Shrinks, as the name does, with a large text size.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _best,
                      maxLines: 1,
                      softWrap: false,
                      style: text.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return GoalStickerFrame(goal: goal, child: option);
  }
}

/// A level: its name, one line about it, and one to three pink bars.
class _LevelOption extends StatelessWidget {
  const _LevelOption(this.level, {required this.selected, required this.onTap});

  final BotDifficulty level;
  final bool selected;
  final VoidCallback onTap;

  /// The goal scene's height (UxGoal pick; was 64), so the goal row fits.
  static const _height = 56.0;
  static const _barSize = Size(10, 20);
  static const _barEdge = 1.5;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final strength = level.index + 1;
    return _Option(
      label: '${level.label}, ${level.summary}',
      selected: selected,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _height),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: Row(
            children: [
              LobbySkew(
                degrees: 10,
                child: Text(level.label, style: text.lobbyCardTitle),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  level.summary,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              for (var bar = 1; bar <= BotDifficulty.values.length; bar++) ...[
                const SizedBox(width: AppSpacing.s4),
                // Pink with an ink edge when lit, an empty gray outline when
                // not: the count reads without the color.
                LobbySkew(
                  degrees: 14,
                  alignment: Alignment.center,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: bar <= strength
                          ? AppColors.opponent
                          : AppColors.card,
                      border: Border.all(
                        color: bar <= strength ? AppColors.ink : AppColors.line,
                        width: _barEdge,
                      ),
                    ),
                    child: SizedBox.fromSize(size: _barSize),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The goal row under the exercise cards (A11 spec 3, UxGoal pick): the face
/// of the character the goal was set with (not the one chosen now: spec 1.3),
/// "이번 판 목표 · 물렁범과 정함" over the goal's title, and the value it was
/// set against, "지난 18".
class _GoalRow extends StatelessWidget {
  const _GoalRow(this.goal);

  final FeedbackGoal goal;

  static const _edge = 2.0;
  static const _face = 46.0;
  static const _faceInner = _face - 2 * _edge;
  static const _faceScale = 0.62;
  static const _lineGap = 1.0;

  /// Inside the edge: 12 above and below, 14 beside, as designed.
  static const _padSide = 14.0;

  /// Where each character's face is in its 140 x 160 rig box, idle: the
  /// design's centers for the face circle (UxGoal `hx`, `hy`).
  static const _faceCenters = {
    'mouse': Offset(72, 55),
    'kangaroo': Offset(76, 50),
    'bear': Offset(72, 62),
    'penguin': Offset(70, 66),
    'seal': Offset(70, 66),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rig = CharacterRig.standard;
    final id = rig.selectableOrDefault(goal.characterId);
    final name = rig.art(id).name;
    final center = _faceCenters[id] ?? _faceCenters[CharacterRig.defaultId]!;
    final setWith = '${Josa.gwaWa.after(name)} 정함';
    return Semantics(
      container: true,
      label: '이번 판 목표 ${goal.title}, $setWith, 지난 판 ${goal.baseline}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.s12,
            horizontal: _padSide,
          ),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.ink, width: _edge),
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadius.card),
            ),
          ),
          child: Row(
            children: [
              SizedBox.square(
                key: const ValueKey('goal-row-face'),
                dimension: _face,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: const ShapeDecoration(
                    shape: CircleBorder(
                      side: BorderSide(color: AppColors.ink, width: _edge),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(_edge),
                    child: ClipOval(
                      child: ColoredBox(
                        color: AppColors.accent,
                        child: Stack(
                          children: [
                            Positioned(
                              left: _faceInner / 2 - center.dx * _faceScale,
                              top: _faceInner / 2 - center.dy * _faceScale,
                              child: CharacterFigure(
                                characterId: id,
                                scale: _faceScale,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이번 판 목표 · $setWith',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.goalRowLabel,
                    ),
                    const SizedBox(height: _lineGap),
                    Text(goal.title, maxLines: 2, style: text.goalRowTitle),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Text('지난 ${goal.baseline}', style: text.goalRowBaseline),
            ],
          ),
        ),
      ),
    );
  }
}
