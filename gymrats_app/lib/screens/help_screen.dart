import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exercise_type.dart';
import '../models/tutorial_page.dart';
import '../services/audio/background_music.dart';
import '../services/telemetry/telemetry_service.dart';
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
/// picture, a title and one line a page; the words come from [HelpRules].
/// It replaces the three-page rules screen (PM 2026-11-15) and plays the
/// main-menu music (user 2026-11-15). Laid out as the A12 design (`TutX`,
/// 360 x 780): the tabs, the picture filling its card, the words under it,
/// the page dots and the two buttons.
///
/// Opens once before home for an account that signed up on this phone:
/// then [onStart] is set, there is no back arrow, and 건너뛰기 or the last
/// page's 완료 calls it. Opened from '?' on home (or 게임 규칙 다시 보기 in
/// the settings), [onStart] is null: back or 완료 returns.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, this.onStart});

  final VoidCallback? onStart;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static const _turn = Duration(milliseconds: 300);

  /// From the top bar to the tabs, and from the page dots to the buttons.
  static const _tabsGap = 10.0;
  static const _dotsGap = 18.0;

  late final TutorialViewModel _tutorial;
  final _pager = PageController();

  @override
  void initState() {
    super.initState();
    Telemetry? telemetry;
    try {
      telemetry = context.read<Telemetry>();
    } on ProviderNotFoundException {
      telemetry = null;
    }
    // P17 measures the onboarding: the tutorial before the first home, not
    // the help opened again later.
    _tutorial = TutorialViewModel(
      telemetry: widget.onStart == null ? null : telemetry,
    )..open();
  }

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
      _tutorial.complete();
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
                final hint = _tutorial.isLast && onStart != null;
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
                              onPressed: () {
                                _tutorial.skip();
                                onStart();
                              },
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
                    const SizedBox(height: _tabsGap),
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
                      label:
                          '${HelpRules.sectionName(_tutorial.exercise)} '
                          '$count장 중 $number장',
                    ),
                    if (hint) ...[
                      const SizedBox(height: AppSpacing.s12),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s20,
                        ),
                        child: _OneLine(
                          '홈 화면의 ?로 다시 볼 수 있어요',
                          center: true,
                          style: _Page.labelStyle(text),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                    ] else
                      const SizedBox(height: _dotsGap),
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
                            _BackButton(
                              onPressed: () => _turnTo(_tutorial.index - 1),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                          ],
                          Expanded(
                            child: AccentButton(
                              title: _tutorial.isLast ? '완료' : '다음',
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

/// 이전: a white box with an ink edge beside 다음 (A12 design: 104 x 58,
/// Do Hyeon 22).
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  static const _size = Size(104, 58);
  static const _edge = 2.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        fixedSize: _size,
        padding: EdgeInsets.zero,
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.ink, width: _edge),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
        textStyle: text.cameraSetupButton,
      ),
      child: const Text('이전'),
    );
  }
}

/// 푸시업 | 스쿼트: the exercise whose pages show, and a jump to the other.
/// Drawn as the A12 design's pill (46 high, an ink edge, the chosen half
/// lime and bold); a screen reader hears a tab bar of two tabs and which
/// one is chosen. Each tab takes taps over the full [_tapHeight], a little
/// more than the pill.
class _ExerciseTabs extends StatelessWidget {
  const _ExerciseTabs({required this.selected, required this.onSelected});

  /// Null on the page about the game: neither tab is chosen.
  final ExerciseType? selected;
  final ValueChanged<ExerciseType> onSelected;

  static const _height = 46.0;
  static const _tapHeight = kMinInteractiveDimension;
  static const _edge = 2.0;

  /// Each half's own edge where they meet, side by side as in the design.
  static const _split = 1.0;

  /// What a screen reader adds after a tab's name, e.g. "탭 2개 중 1번째".
  static String tabPosition(int index, int count) =>
      '탭 $count개 중 ${index + 1}번째';

  void _choose(ExerciseType exercise) {
    // The tab already chosen stays where it is.
    if (exercise != selected) onSelected(exercise);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const exercises = TutorialViewModel.exercises;
    const split = BorderSide(color: AppColors.ink, width: _split);
    return Semantics(
      role: SemanticsRole.tabBar,
      container: true,
      explicitChildNodes: true,
      child: SizedBox(
        height: _tapHeight,
        child: Stack(
          children: [
            // The drawn pill; the tabs over it below are what a screen
            // reader hears.
            ExcludeSemantics(
              child: Center(
                // The ink edge over the halves, which are clipped inside it,
                // as the rankings' tabs: a clip of the bordered pill alone
                // let the halves' square corners cover the edge's round ends.
                child: Container(
                  height: _height,
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
                        for (final (index, exercise) in exercises.indexed)
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: exercise == selected
                                    ? AppColors.accent
                                    : AppColors.card,
                                border: Border(
                                  left: index > 0 ? split : BorderSide.none,
                                  right: index < exercises.length - 1
                                      ? split
                                      : BorderSide.none,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  HelpRules.exerciseName(exercise),
                                  maxLines: 1,
                                  // The design's 17: medium, bold when
                                  // chosen.
                                  style: text.authField.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: exercise == selected
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
                for (final (index, exercise) in exercises.indexed)
                  Expanded(
                    child: Semantics(
                      role: SemanticsRole.tab,
                      // Android reads no tab role (Flutter 3.47): a button,
                      // as the segments before were, with where it is
                      // among the tabs, as TabBar adds to its labels.
                      button: true,
                      selected: exercise == selected,
                      label: HelpRules.exerciseName(exercise),
                      value: tabPosition(index, exercises.length),
                      onTap: () => _choose(exercise),
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _choose(exercise),
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

/// One page: its picture filling a card, then "푸시업 3 / 11", the title and
/// its line (none for a page told by its title alone). Scrolls on a short
/// screen.
class _Page extends StatelessWidget {
  const _Page({required this.page, required this.position});

  final TutorialPage page;
  final (int, int) position;

  static const _cardEdge = 2.0;
  static const _cardCorner = 22.0;

  /// Between the counter, the title and the body.
  static const _lineGap = 6.0;

  /// "푸시업 3 / 11" and the last page's hint: the design's 15, medium,
  /// gray.
  static TextStyle labelStyle(TextTheme text) => text.statsStrong.copyWith(
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final words = HelpRules.of(page);
    final (number, count) = position;
    final picture = HelpPicture.sizeOf(page);
    const corner = BorderRadius.all(Radius.circular(_cardCorner));
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s16,
        AppSpacing.s20,
        AppSpacing.s16,
      ),
      children: [
        // The picture fills the card up to its ink edge, drawn over it.
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.ink, width: _cardEdge),
            borderRadius: corner,
          ),
          child: ClipRRect(
            borderRadius: corner,
            child: ColoredBox(
              color: AppColors.card,
              child: Padding(
                padding: const EdgeInsets.all(_cardEdge),
                child: AspectRatio(
                  aspectRatio: picture.width / picture.height,
                  child: HelpPicture(page: page),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
        Text(
          page.exercise == null
              ? HelpRules.sectionName(null)
              : '${HelpRules.sectionName(page.exercise)} $number / $count',
          style: labelStyle(text),
        ),
        const SizedBox(height: _lineGap),
        _OneLine(
          words.title,
          // Black Han Sans 28, as designed.
          style: text.headlineMedium,
        ),
        if (words.hasBody) ...[
          const SizedBox(height: _lineGap),
          _OneLine(
            words.body,
            style: text.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// [text] on one line (user 2026-11-15): shrunk to fit a narrow screen or
/// a large text size instead of wrapping.
class _OneLine extends StatelessWidget {
  const _OneLine(this.text, {this.style, this.center = false});

  final String text;
  final TextStyle? style;

  /// In the middle of its line, as the last page's hint; at the start
  /// otherwise.
  final bool center;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: center ? Alignment.center : Alignment.centerLeft,
      child: Text(text, maxLines: 1, softWrap: false, style: style),
    );
  }
}

/// Which page of the exercise is showing: a long lime dot with an ink edge
/// for it, short gray ones for the rest.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.label,
  });

  final int count;
  final int current;

  /// What a screen reader says, e.g. "푸시업 11장 중 3장".
  final String label;

  static const _dot = 10.0;
  static const _currentWidth = 26.0;
  static const _gap = 6.0;
  static const _edge = 2.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < count; index++) ...[
              if (index > 0) const SizedBox(width: _gap),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: index == current ? _currentWidth : _dot,
                height: _dot,
                decoration: ShapeDecoration(
                  color: index == current ? AppColors.accent : AppColors.border,
                  shape: StadiumBorder(
                    side: index == current
                        ? const BorderSide(color: AppColors.ink, width: _edge)
                        : BorderSide.none,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
