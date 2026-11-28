import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../services/rankings/rankings_repository.dart';
import '../theme/app_theme.dart';

/// The rankings' two tabs on one line (A13 design `RankD1`): the scope
/// (전체 · 친구, lime when chosen) filling the room, then the exercise
/// (푸시업 · 스쿼트, ink when chosen) 136 wide. Each pill is drawn 40 high
/// in a 48-high tap area.
class WeeklyRankingsTabs extends StatelessWidget {
  const WeeklyRankingsTabs({
    super.key,
    required this.scope,
    required this.exercise,
    required this.onScope,
    required this.onExercise,
  });

  final RankingScope scope;
  final ExerciseType exercise;
  final ValueChanged<RankingScope> onScope;
  final ValueChanged<ExerciseType> onExercise;

  /// The tap areas' height; the pills are [pillHeight] in their middle.
  static const height = kMinInteractiveDimension;
  static const pillHeight = 40.0;
  static const exerciseWidth = 136.0;

  /// The scope names, as the tabs and my card write them.
  static String scopeName(RankingScope scope) => switch (scope) {
    RankingScope.global => '전체',
    RankingScope.friends => '친구',
  };

  /// The exercise names as the design writes them ('푸시업', as the
  /// tutorial; the app's `koreanName` says '푸쉬업').
  static String exerciseName(ExerciseType exercise) => switch (exercise) {
    ExerciseType.pushUp => '푸시업',
    ExerciseType.squat => '스쿼트',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: _Pill(
              names: [for (final s in RankingScope.values) scopeName(s)],
              selected: RankingScope.values.indexOf(scope),
              onSelected: (index) => onScope(RankingScope.values[index]),
              style: text.rankingScopeTab,
              selectedFill: AppColors.accent,
              selectedInk: AppColors.ink,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          SizedBox(
            width: exerciseWidth,
            child: _Pill(
              names: [for (final e in ExerciseType.values) exerciseName(e)],
              selected: ExerciseType.values.indexOf(exercise),
              onSelected: (index) => onExercise(ExerciseType.values[index]),
              style: text.rankingExerciseTab,
              selectedFill: AppColors.ink,
              selectedInk: AppColors.onInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// A white pill with a 2 ink edge cut in two by an ink line: the chosen
/// half on [selectedFill] in bold [selectedInk], the other medium gray.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.names,
    required this.selected,
    required this.onSelected,
    required this.style,
    required this.selectedFill,
    required this.selectedInk,
  });

  final List<String> names;
  final int selected;
  final ValueChanged<int> onSelected;
  final TextStyle style;
  final Color selectedFill;
  final Color selectedInk;

  static const _edge = 2.0;

  /// What a screen reader adds after a tab's name, e.g. "탭 2개 중 1번째"
  /// (as the tutorial's tabs).
  static String tabPosition(int index, int count) =>
      '탭 $count개 중 ${index + 1}번째';

  /// The tab already chosen stays where it is.
  void _choose(int index) {
    if (index != selected) onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    const split = BorderSide(color: AppColors.ink, width: _edge);
    return Semantics(
      role: SemanticsRole.tabBar,
      container: true,
      explicitChildNodes: true,
      child: Stack(
        children: [
          // The drawn pill; the tabs over it are what a screen reader hears.
          ExcludeSemantics(
            child: Center(
              // The ink edge over the halves, which are clipped inside
              // it (the design's `overflow: hidden` keeps the edge whole).
              child: Container(
                height: WeeklyRankingsTabs.pillHeight,
                padding: const EdgeInsets.all(_edge),
                decoration: const ShapeDecoration(
                  color: AppColors.card,
                  shape: StadiumBorder(),
                ),
                foregroundDecoration: const ShapeDecoration(
                  shape: StadiumBorder(
                    side: BorderSide(color: AppColors.ink, width: _edge),
                  ),
                ),
                child: ClipPath(
                  clipper: const ShapeBorderClipper(shape: StadiumBorder()),
                  child: Row(
                    children: [
                      for (final (index, name) in names.indexed)
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: index == selected
                                  ? selectedFill
                                  : AppColors.card,
                              border: Border(
                                right: index < names.length - 1
                                    ? split
                                    : BorderSide.none,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                name,
                                maxLines: 1,
                                style: style.copyWith(
                                  color: index == selected
                                      ? selectedInk
                                      : AppColors.textSecondary,
                                  fontWeight: index == selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (index, name) in names.indexed)
                Expanded(
                  child: Semantics(
                    role: SemanticsRole.tab,
                    // Android reads no tab role (Flutter 3.47): a button,
                    // with where it is among the tabs.
                    button: true,
                    selected: index == selected,
                    label: name,
                    value: tabPosition(index, names.length),
                    onTap: () => _choose(index),
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // The tab already chosen stays where it is.
                      onTap: () => _choose(index),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
