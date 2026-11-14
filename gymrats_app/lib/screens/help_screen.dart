import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../models/tutorial_page.dart';
import '../services/audio/background_music.dart';
import '../theme/app_theme.dart';
import '../viewmodels/tutorial_viewmodel.dart';
import '../widgets/accent_button.dart';
import '../widgets/auth_form.dart';
import '../widgets/grid_background.dart';
import '../widgets/help_pictures.dart';
import '../widgets/help_rules.dart';
import '../widgets/sound_cues.dart';

/// The tutorial: the game rules in pages, every push-up page and then every
/// squat page, turned by swiping, 이전/다음 or the exercise tabs. One
/// picture and one or two lines a page; the words come from [HelpRules].
/// It replaces the three-page rules screen (PM 2026-11-15) and plays the
/// main-menu music (user 2026-11-15).
///
/// Opens once before home for an account that signed up on this phone:
/// then [onStart] is set, there is no back arrow, and 건너뛰기 or the last
/// page's 완료 calls it. Opened from '?' on home (or 규칙 보기, 게임 규칙
/// 다시 보기), [onStart] is null: back or 완료 returns.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, this.onStart});

  final VoidCallback? onStart;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static const _turn = Duration(milliseconds: 300);

  final _tutorial = TutorialViewModel();
  final _pager = PageController();

  @override
  void dispose() {
    _pager.dispose();
    _tutorial.dispose();
    super.dispose();
  }

  /// Turns to [index]; the pager tells the view model when it lands.
  void _turnTo(int index) {
    if (!_pager.hasClients) return;
    _pager.animateToPage(index, duration: _turn, curve: Curves.easeOut);
  }

  void _finish() {
    final onStart = widget.onStart;
    if (onStart != null) {
      onStart();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _next() {
    if (_tutorial.isLast) {
      _finish();
    } else {
      _turnTo(_tutorial.index + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onStart = widget.onStart;
    final text = Theme.of(context).textTheme;
    return SoundCues(
      music: MusicCue.menu,
      child: Scaffold(
        body: GridBackground(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: _tutorial,
              builder: (context, _) {
                final pages = _tutorial.pages;
                final (number, count) = _tutorial.positionOf(_tutorial.index);
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TopBar(
                            title: '게임 규칙',
                            showBack: onStart == null,
                          ),
                        ),
                        if (onStart != null && !_tutorial.isLast)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.s8,
                            ),
                            child: TextButton(
                              onPressed: onStart,
                              child: Text(
                                '건너뛰기',
                                style: text.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s20,
                      ),
                      child: _ExerciseTabs(
                        selected: _tutorial.exercise,
                        onSelected: (exercise) =>
                            _turnTo(_tutorial.firstIndexOf(exercise)),
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pager,
                        onPageChanged: _tutorial.goTo,
                        children: [
                          for (final (index, page) in pages.indexed)
                            _Page(
                              page: page,
                              position: _tutorial.positionOf(index),
                            ),
                        ],
                      ),
                    ),
                    _PageDots(
                      count: count,
                      current: number - 1,
                      exercise: HelpRules.exerciseName(_tutorial.exercise),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s20,
                        0,
                        AppSpacing.s20,
                        AppSpacing.s24,
                      ),
                      child: Row(
                        children: [
                          if (!_tutorial.isFirst) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _turnTo(_tutorial.index - 1),
                                child: const Text('이전'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                          ],
                          Expanded(
                            flex: 2,
                            child: AccentButton(
                              title: _tutorial.isLast ? '완료' : '다음',
                              hint: _tutorial.isLast && onStart != null
                                  ? '홈 화면의 ?로 다시 볼 수 있어요'
                                  : null,
                              onPressed: _next,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 푸시업 | 스쿼트: the exercise whose pages show, and a jump to the other.
class _ExerciseTabs extends StatelessWidget {
  const _ExerciseTabs({required this.selected, required this.onSelected});

  final ExerciseType selected;
  final ValueChanged<ExerciseType> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ExerciseType>(
        showSelectedIcon: false,
        segments: [
          for (final exercise in TutorialViewModel.exercises)
            ButtonSegment(
              value: exercise,
              label: Text(HelpRules.exerciseName(exercise)),
            ),
        ],
        selected: {selected},
        onSelectionChanged: (choice) => onSelected(choice.single),
      ),
    );
  }
}

/// One page: its picture on a card, then "푸시업 3 / 10", the title and its
/// line. Scrolls on a short screen.
class _Page extends StatelessWidget {
  const _Page({required this.page, required this.position});

  final TutorialPage page;
  final (int, int) position;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final words = HelpRules.of(page);
    final (number, count) = position;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s16,
        AppSpacing.s20,
        AppSpacing.s16,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: AspectRatio(
              aspectRatio: HelpPicture.width / HelpPicture.height,
              child: HelpPicture(page: page),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
        Text(
          '${HelpRules.exerciseName(page.exercise)} $number / $count',
          style: text.labelLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(words.title, style: text.headlineLarge),
        const SizedBox(height: AppSpacing.s8),
        Text(
          words.body,
          style: text.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Which page of the exercise is showing: a long lime dot for it, short
/// gray ones for the rest.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.exercise,
  });

  final int count;
  final int current;
  final String exercise;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$exercise $count장 중 ${current + 1}장',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < count; index++) ...[
                if (index > 0) const SizedBox(width: AppSpacing.s4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: index == current ? AppSpacing.s20 : AppSpacing.s8,
                  height: AppSpacing.s8,
                  decoration: ShapeDecoration(
                    color: index == current
                        ? AppColors.accent
                        : AppColors.border,
                    shape: const StadiumBorder(),
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
