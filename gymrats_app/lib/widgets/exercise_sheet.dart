import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/feedback_goal.dart';
import '../models/user_profile.dart';
import '../services/feedback/goal_progress.dart';
import '../services/feedback/goal_store.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'coach_parts.dart';

/// Asks which exercise to battle in, under the line [subtitle]. Null when the
/// user closes the sheet without choosing.
Future<ExerciseType?> showExerciseSheet(
  BuildContext context, {
  required String subtitle,
  required UserProfile profile,
}) => showModalBottomSheet<ExerciseType>(
  context: context,
  backgroundColor: AppColors.card,
  showDragHandle: true,
  // Taller than the default limit with a large system text size.
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    side: BorderSide(color: AppColors.border),
  ),
  builder: (_) => ExerciseSheet(subtitle: subtitle, profile: profile),
);

/// One card per exercise, side by side. Tapping a card closes the sheet with it.
///
/// A card of an exercise the user has a goal for wears its sticker (A11
/// spec 3; the sheet has no chosen card, so no goal row: task.md W11
/// decision 1). The cards show once the goals are read, so no sticker
/// comes in late.
class ExerciseSheet extends StatefulWidget {
  const ExerciseSheet({
    super.key,
    required this.subtitle,
    required this.profile,
  });

  final String subtitle;
  final UserProfile profile;

  @override
  State<ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends State<ExerciseSheet>
    with GoalsOnce<ExerciseSheet> {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final goals = this.goals;
    final subtitle = widget.subtitle;
    final profile = widget.profile;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          0,
          AppSpacing.s20,
          AppSpacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OneLine(
              '어떤 종목으로 붙을까요?',
              alignment: Alignment.centerLeft,
              style: text.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              subtitle,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s24),
            // Hidden for the moment the goals take to read: the stickers
            // come with the cards.
            Opacity(
              opacity: goals == null ? 0 : 1,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, exercise)
                        in ExerciseType.values.indexed) ...[
                      if (index > 0) const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: _ExerciseCard(
                          exercise,
                          best: profile.bestOf(exercise),
                          goal: goals?[exercise],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The exercise's drawing, its name and the user's best in it.
class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard(this.exercise, {required this.best, this.goal});

  final ExerciseType exercise;
  final PersonalBest? best;

  /// The user's goal for [exercise], worn as a sticker; null for none.
  final FeedbackGoal? goal;

  /// The best's number and unit: points, or reps with none above 0, or a dash
  /// with nothing to show, as before the first battle.
  (String, String) get _best => switch (best) {
    null => ('—', ''),
    final best when best.readsInPoints => ('${best.score}', '점'),
    final best => ('${best.reps}', '회'),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (value, unit) = _best;
    final number = text.titleLarge!.copyWith(color: AppColors.textPrimary);
    void choose() => Navigator.pop(context, exercise);
    final goal = this.goal;
    // One sentence for a screen reader, which also loses the InkWell's tap.
    final card = Semantics(
      button: true,
      label: [
        '${exercise.koreanName}, 개인 최고 $value$unit',
        if (goal != null) '이번 판 목표 ${goal.title}',
      ].join(', '),
      onTap: choose,
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColors.cardHigh,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: choose,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExercisePictogram(exercise),
                const SizedBox(height: AppSpacing.s8),
                _OneLine(exercise.koreanName, style: text.headlineSmall),
                const SizedBox(height: AppSpacing.s4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '개인 최고 '),
                        TextSpan(text: value, style: number),
                        TextSpan(text: unit),
                      ],
                    ),
                    maxLines: 1,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    // The number's height whatever fits on the line, so the
                    // row's measured height holds with a large text size.
                    strutStyle: StrutStyle.fromTextStyle(
                      number,
                      forceStrutHeight: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return GoalStickerFrame(goal: goal, child: card);
  }
}

class _OneLine extends StatelessWidget {
  const _OneLine(this.text, {this.style, this.alignment = Alignment.center});

  final String text;
  final TextStyle? style;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: alignment,
    child: Text(text, maxLines: 1, style: style),
  );
}

/// An exercise as a line drawing on a floor line, in [color].
class ExercisePictogram extends StatelessWidget {
  const ExercisePictogram(
    this.exercise, {
    super.key,
    this.color = AppColors.textPrimary,
    this.size = defaultSize,
  });

  final ExerciseType exercise;
  final Color color;
  final Size size;

  /// 1.5 times the 72×40 design.
  static const defaultSize = Size(108, 60);

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: size, painter: _ExercisePainter(exercise, color));
}

/// Designed on a 72×40 box and stretched to the canvas. Only the points scale;
/// line widths stay the same.
class _ExercisePainter extends CustomPainter {
  const _ExercisePainter(this.exercise, this.color);

  final ExerciseType exercise;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 72;
    final sy = size.height / 40;
    Offset at(double x, double y) => Offset(x * sx, y * sy);
    final floor = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    final figure = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(at(4, 36), at(70, 36), floor);
    switch (exercise) {
      case ExerciseType.pushUp:
        canvas
          ..drawCircle(at(10, 15), 4.5 * sx, figure) // head
          ..drawLine(at(16, 18), at(64, 30), figure) // body
          ..drawLine(at(18, 18), at(18, 34), figure) // arm
          ..drawLine(at(64, 30), at(66, 34), figure); // feet
      case ExerciseType.squat:
        canvas
          ..drawCircle(at(36, 5), 4.5 * sx, figure) // head
          ..drawLine(at(47, 23), at(40.5, 11), figure) // body
          ..drawLine(at(40, 12), at(24, 13), figure) // arms
          ..drawPath(
            // Hip to knee, knee to ankle, ankle to toe.
            Path()
              ..moveTo(at(47, 23).dx, at(47, 23).dy)
              ..lineTo(at(30, 22).dx, at(30, 22).dy)
              ..lineTo(at(37, 34).dx, at(37, 34).dy)
              ..lineTo(at(30, 34).dx, at(30, 34).dy),
            figure,
          );
    }
  }

  @override
  bool shouldRepaint(_ExercisePainter oldDelegate) =>
      oldDelegate.exercise != exercise || oldDelegate.color != color;
}

/// The lime sticker over an exercise card's top right corner when the user
/// has a goal for that exercise (A11 spec 3, UxGoal pick): a target and the
/// goal's short words, e.g. "목표 20회", turned 6°. It hangs over the card's
/// edge, so it goes over the card in a [GoalStickerFrame]. A picture to a
/// screen reader: the card says the goal.
class GoalSticker extends StatelessWidget {
  const GoalSticker({super.key, required this.goal});

  final FeedbackGoal goal;

  static const _turn = 6 * math.pi / 180;
  static const _edge = 2.0;
  static const _corner = 10.0;
  static const _icon = 14.0;
  static const _iconGap = 4.0;

  /// Inside the edge: 6 before the target, 9 after the words, 3 above and
  /// below, as designed.
  static const _padStart = 6.0;
  static const _padEnd = 9.0;
  static const _padY = 3.0;

  /// The sticker's words for [goal].
  static String textOf(FeedbackGoal goal) =>
      GoalProgress.stickerText(goal.kind, goal.target);

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: _turn,
        child: Container(
          padding: const EdgeInsets.fromLTRB(_padStart, _padY, _padEnd, _padY),
          decoration: BoxDecoration(
            color: AppColors.accent,
            border: Border.all(color: AppColors.ink, width: _edge),
            borderRadius: const BorderRadius.all(Radius.circular(_corner)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoachTargetIcon(size: _icon),
              const SizedBox(width: _iconGap),
              Text(
                textOf(goal),
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.goalSticker,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An exercise card ([child]) with the [GoalSticker] of [goal] over its top
/// right corner, 8 past its right edge and 12 above it; just the card
/// without a goal.
class GoalStickerFrame extends StatelessWidget {
  const GoalStickerFrame({super.key, required this.goal, required this.child});

  final FeedbackGoal? goal;
  final Widget child;

  static const _right = -8.0;
  static const _top = -12.0;

  @override
  Widget build(BuildContext context) {
    final goal = this.goal;
    if (goal == null) return child;
    // The card keeps the room it is given; a tap on the sticker is the
    // card's.
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned(
          right: _right,
          top: _top,
          child: IgnorePointer(child: GoalSticker(goal: goal)),
        ),
      ],
    );
  }
}

/// Reads the user's saved goal of each exercise once, for a game choice or
/// the match-found screen (A11 spec 3 and 4): from the app's [GoalStore],
/// for the signed-in account. It only reads (task.md W11 decision 6). Null
/// while reading; empty without a store or an account, which needs no
/// reading.
///
/// A screen hides what the goals move while they are read, so it waits at
/// most [readLimit] (a read takes a few milliseconds): a slower read (the
/// phone's key store stuck) shows the screen without goals, and a goal that
/// comes after that is not shown there, so nothing jumps.
mixin GoalsOnce<T extends StatefulWidget> on State<T> {
  /// The longest a screen waits for its goals.
  static const readLimit = Duration(milliseconds: 300);

  /// The goals by exercise; null until read.
  Map<ExerciseType, FeedbackGoal>? goals;

  bool _asked = false;
  Timer? _limit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    final store = Provider.of<GoalStore?>(context, listen: false);
    final account = Provider.of<AuthViewModel?>(
      context,
      listen: false,
    )?.account;
    if (store == null || account == null) {
      goals = const {};
      return;
    }
    _limit = Timer(readLimit, () => _settle(const {}));
    unawaited(readGoals(store, account.id).then(_settle));
  }

  /// The first of the read and the end of the wait decides the goals.
  void _settle(Map<ExerciseType, FeedbackGoal> read) {
    _limit?.cancel();
    if (!mounted || goals != null) return;
    setState(() => goals = read);
  }

  @override
  void dispose() {
    _limit?.cancel();
    super.dispose();
  }
}
