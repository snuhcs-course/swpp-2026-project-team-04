import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/bot_difficulty.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/matchup.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/exercise_sheet.dart';
import '../widgets/lobby_parts.dart';

/// AI 1v1, from 게임 시작: the exercise and RepBot's level, then 대결 시작.
/// The choice is kept in home's view model.
class AiSetupScreen extends StatelessWidget {
  const AiSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final setup = vm.state.botSetup;
    final level = vm.state.botLevel;
    final profile = vm.state.profile!;
    final text = Theme.of(context).textTheme;
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
        const SizedBox(height: AppSpacing.s24),
        const _SectionLabel('종목', 'EXERCISE'),
        const SizedBox(height: AppSpacing.s8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, exercise) in ExerciseType.values.indexed) ...[
                if (index > 0) const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: _ExerciseOption(
                    exercise,
                    best: profile.bestOf(exercise),
                    selected: exercise == setup.exercise,
                    onTap: () => vm.chooseBotExercise(exercise),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        const _SectionLabel('난이도', 'LEVEL'),
        const SizedBox(height: AppSpacing.s8),
        for (final (index, option) in BotDifficulty.values.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.s8),
          _LevelOption(
            option,
            selected: option == level,
            onTap: () => vm.chooseBotLevel(option),
          ),
        ],
        const Spacer(),
        const SizedBox(height: AppSpacing.s24),
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
        const SizedBox(height: AppSpacing.s8),
        Text(
          '${setup.exercise.koreanName} · RepBot ${level.label} · '
          '${battleDuration.inSeconds}초 대결',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
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
  });

  final ExerciseType exercise;
  final PersonalBest? best;
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
    return _Option(
      label: '${exercise.koreanName}, $_best',
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
                      child: Text(
                        exercise.koreanName,
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
  }
}

/// A level: its name, one line about it, and one to three pink bars.
class _LevelOption extends StatelessWidget {
  const _LevelOption(this.level, {required this.selected, required this.onTap});

  final BotDifficulty level;
  final bool selected;
  final VoidCallback onTap;

  static const _height = 64.0;
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
