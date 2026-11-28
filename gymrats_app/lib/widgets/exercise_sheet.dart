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

/// Asks which exercise to battle in, under the line [subtitle] when there is
/// one. With [onRankings], a 주간 랭킹 row under the cards opens the weekly
/// rankings over the sheet (P11). Null when the user closes the sheet
/// without choosing.
Future<ExerciseType?> showExerciseSheet(
  BuildContext context, {
  String? subtitle,
  required UserProfile profile,
  VoidCallback? onRankings,
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
  builder: (_) => ExerciseSheet(
    subtitle: subtitle,
    profile: profile,
    onRankings: onRankings,
  ),
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
    this.subtitle,
    required this.profile,
    this.onRankings,
  });

  final String? subtitle;
  final UserProfile profile;

  /// Opens the weekly rankings; null shows no rankings row.
  final VoidCallback? onRankings;

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
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.s4),
              Text(
                subtitle,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
            ] else
              // P11: no line, so the cards come up.
              const SizedBox(height: AppSpacing.s16),
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
            if (widget.onRankings case final open?) ...[
              const SizedBox(height: AppSpacing.s16),
              WeeklyRankingsRow(onTap: open),
            ],
          ],
        ),
      ),
    );
  }
}

/// 주간 랭킹 (P11): a long row under the exercise cards, with the podium.
class WeeklyRankingsRow extends StatelessWidget {
  const WeeklyRankingsRow({super.key, required this.onTap});

  final VoidCallback onTap;

  static const _chip = 48.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '주간 랭킹, 이번 주 전체와 친구 순위',
      onTap: onTap,
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColors.cardHigh,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            child: Row(
              children: [
                const RankingPodiumIcon(size: _chip),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('주간 랭킹', style: text.titleLarge),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        '이번 주 전체·친구 순위 보기',
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.line),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A podium with a star over its top step, on a rounded square.
class RankingPodiumIcon extends StatelessWidget {
  const RankingPodiumIcon({super.key, this.size = 48});

  final double size;

  static const _edge = 1.5;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.fever,
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
      border: Border.all(color: AppColors.ink, width: _edge),
    ),
    child: CustomPaint(painter: _PodiumPainter()),
  );
}

/// Drawn on a 24×24 box: three steps, the middle one highest, and a star
/// over it.
class _PodiumPainter extends CustomPainter {
  _PodiumPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final fill = Paint()..color = AppColors.ink;
    Rect step(double left, double top) =>
        Rect.fromLTRB(left * s, top * s, (left + 5) * s, 19 * s);
    canvas
      ..drawRect(step(4.5, 14), fill)
      ..drawRect(step(9.5, 11), fill)
      ..drawRect(step(14.5, 15.5), fill);
    // A five-point star centred over the middle step.
    final star = Path();
    const points = 5;
    final centre = Offset(12 * s, 7 * s);
    for (var i = 0; i < points * 2; i++) {
      final r = (i.isEven ? 3.2 : 1.4) * s;
      final a = -math.pi / 2 + i * math.pi / points;
      final p = centre + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(star..close(), fill);
  }

  @override
  bool shouldRepaint(_PodiumPainter oldDelegate) => false;
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
        if (goal != null) '미션 있음, ${goal.title}',
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

/// The orange "미션!" sticker over an exercise card's top right corner when
/// the user has a mission (a goal) for that exercise (MISSION-SPEC 2, MsGoal
/// pick, copy "mission", tone "orange", wiggle on): a flag and "미션!" with
/// an ink shadow, turned 6°, giving a short shake every [period]. It holds
/// still with reduced motion, and its ticker stops off screen. It hangs over
/// the card's edge, so it goes over the card in a [GoalStickerFrame]. A
/// picture to a screen reader: the card says "미션 있음, {title}".
class GoalSticker extends StatefulWidget {
  const GoalSticker({super.key, required this.goal});

  final FeedbackGoal goal;

  /// The sticker's words, whatever the mission: its number is in the row
  /// and the summary.
  static const text = '미션!';

  /// One shake and the rest before it (MsGoal `msWiggle 2.5s`).
  static const period = Duration(milliseconds: 2500);

  /// The design's keyframes (MsGoal `@keyframes msWiggle`): when, as a
  /// share of [period], and the turn in degrees and the size there. Each
  /// step eases in and out, as the design's `ease-in-out`.
  static const keyframes = <(double, double, double)>[
    (0, 6, 1),
    (0.76, 6, 1),
    (0.80, -6, 1.1),
    (0.84, 12, 1.1),
    (0.88, 0, 1.05),
    (0.92, 9, 1),
    (1, 6, 1),
  ];

  /// The turn and the size at [t], from 0 to 1 through one [period].
  static ({double degrees, double scale}) poseAt(double t) {
    final at = t.clamp(0.0, 1.0);
    for (var i = 1; i < keyframes.length; i++) {
      final (end, degrees, scale) = keyframes[i];
      if (at > end && i < keyframes.length - 1) continue;
      final (start, fromDegrees, fromScale) = keyframes[i - 1];
      final span = end - start;
      final eased = Curves.easeInOut.transform(
        span <= 0 ? 1 : ((at - start) / span).clamp(0.0, 1.0),
      );
      return (
        degrees: fromDegrees + (degrees - fromDegrees) * eased,
        scale: fromScale + (scale - fromScale) * eased,
      );
    }
    return (degrees: 6, scale: 1);
  }

  /// The mission's short words for the summary line, e.g. "20회",
  /// "콤보 6".
  static String textOf(FeedbackGoal goal) =>
      GoalProgress.shortText(goal.kind, goal.target);

  @override
  State<GoalSticker> createState() => _GoalStickerState();
}

class _GoalStickerState extends State<GoalSticker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: GoalSticker.period,
  );

  static const _height = 32.0;
  static const _edge = 2.0;
  static const _corner = 10.0;
  static const _icon = 16.0;
  static const _iconStroke = 2.8;
  static const _iconGap = 5.0;

  /// Inside the edge: 8 before the flag, 11 after the words, as designed.
  static const _padStart = 8.0;
  static const _padEnd = 11.0;

  /// The ink shadow: 2 right, 3 down, no blur.
  static const _shadow = Offset(2, 3);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shake
        ..stop()
        ..value = 0;
    } else if (!_shake.isAnimating) {
      _shake.repeat();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sticker = Container(
      height: _height,
      padding: const EdgeInsets.fromLTRB(_padStart, 0, _padEnd, 0),
      decoration: const BoxDecoration(
        color: AppColors.warning,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.ink, width: _edge),
        ),
        borderRadius: BorderRadius.all(Radius.circular(_corner)),
        boxShadow: [BoxShadow(color: AppColors.ink, offset: _shadow)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoachFlagIcon(size: _icon, stroke: _iconStroke),
          const SizedBox(width: _iconGap),
          // At the design's size whatever the text size: the sticker is
          // 32 high, and its card says the mission to a screen reader.
          Text(
            GoalSticker.text,
            maxLines: 1,
            softWrap: false,
            textScaler: TextScaler.noScaling,
            style: Theme.of(context).textTheme.goalMissionSticker,
          ),
        ],
      ),
    );
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _shake,
        child: sticker,
        builder: (context, child) {
          final pose = GoalSticker.poseAt(_shake.value);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationZ(pose.degrees * math.pi / 180)
              ..scaleByDouble(pose.scale, pose.scale, 1, 1),
            child: child,
          );
        },
      ),
    );
  }
}

/// An exercise card ([child]) with the [GoalSticker] of [goal] over its top
/// right corner, 8 past its right edge and 20 above it (above the card's
/// check), as designed; just the card without a goal.
class GoalStickerFrame extends StatelessWidget {
  const GoalStickerFrame({super.key, required this.goal, required this.child});

  final FeedbackGoal? goal;
  final Widget child;

  static const _right = -8.0;
  static const _top = -20.0;

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
