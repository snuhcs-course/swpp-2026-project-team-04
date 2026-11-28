import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/ranking_ladder.dart';
import '../theme/app_theme.dart';
import '../viewmodels/ranking_ladder_viewmodel.dart';
import 'character_motion.dart' show MotionEase;
import 'victory_scene.dart';

/// The rank ladder over the victory scene (A15, the design `SpScene.dc.html`
/// `v="E"`): while the scene holds its big moment ([VictoryTimes.holdMs]),
/// up to four rows of this week's global ranking come in from the right, my
/// row rolls its points and climbs past the players it passed (they step
/// down one by one), the ranks turn to the server's after the battle, and
/// at the way out the other rows leave to the right while mine shrinks into
/// the rank chip on the seat ([VictoryRankChip]), which the report keeps.
///
/// The values are the design's `renderVals()` as they are, in its 360 x 780
/// points and in ms from the moment the report opens. The rows go on other
/// screens as the big scene does (the design's screen scaled to fit,
/// [VictoryLayout.fromDesign]); the chip follows the seat
/// ([VictoryLayout.nearSeat]).
abstract final class VictoryLadder {
  /// A row: [rowWidth] by [rowHeight] at x [rowLeft], slot k's top at
  /// [firstTop] + k [slotGap].
  static const rowLeft = 22.0;
  static const rowWidth = 316.0;
  static const rowHeight = 42.0;
  static const firstTop = 118.0;
  static const slotGap = 48.0;

  /// Row k comes in from [entranceSlide] to the right from [entranceFromMs]
  /// + k [entranceStepMs] over [entranceMs], showing over [fadeInMs].
  static const entranceFromMs = 960.0;
  static const entranceStepMs = 70.0;
  static const entranceMs = 260.0;
  static const entranceSlide = 380.0;
  static const fadeInMs = 120.0;

  /// The climb: from [moveFromMs] over [moveMs] the rows move to their end
  /// slots and my points roll; the ranks turn at [flipAt] of it and a turned
  /// rank pops [rankPop] larger, settling over [popMs]. My row lifts
  /// [meLift] larger and its shadow drops [shadowBase] + [shadowLift] at the
  /// top of the climb; its '+N' shows over [tagMs] from [moveFromMs].
  static const moveFromMs = 1300.0;
  static const moveMs = 600.0;
  static const flipAt = 0.55;
  static const rankPop = 0.3;
  static const popMs = 220.0;
  static const meLift = 0.05;
  static const shadowBase = 2.0;
  static const shadowLift = 6.0;
  static const tagMs = 200.0;

  /// The way out, from the scene's [VictoryScene.outFromMs]: my row goes to
  /// the chip's middle ([chipCenter] on the design's screen, about the
  /// seat) over [exitMs] on an arc [exitArc] high, shrinking to [exitScale],
  /// fading over the last of it from [exitFadeFrom]; the other rows leave
  /// [entranceSlide] to the right, row k from [othersExitStepMs] k later,
  /// over [othersExitMs].
  static const exitMs = 480.0;
  static const exitArc = 40.0;
  static const exitScale = 0.43;
  static const exitFadeFrom = 0.7;
  static const othersExitStepMs = 50.0;
  static const othersExitMs = 240.0;

  /// The dots between the list's last row and mine when I stay outside it:
  /// [dotsSize] at y [dotsTop], showing [dotsFadeDelayMs] after the first
  /// row comes in, over [dotsFadeMs]; three ink dots of [dotRadius] at
  /// [dotYs].
  static const dotsTop = 164.0;
  static const dotsSize = Size(8, 22);
  static const dotsFadeDelayMs = 60.0;
  static const dotsFadeMs = 160.0;
  static const dotRadius = 2.6;
  static const dotYs = [3.0, 11.0, 19.0];

  /// The rank chip on the seat: its middle at [chipCenter] (on the design's
  /// screen, the seat at (200, 36)), shown [chipFromMs] after the way out
  /// starts over [chipMs], growing from [chipFromScale].
  static const chipCenter = Offset(272, 53);
  static const chipFromMs = 380.0;
  static const chipMs = 140.0;
  static const chipFromScale = 0.8;

  /// The chip's top on the seat: [chipTop] below its top, [chipHeight]
  /// high and at most [chipMaxWidth] wide (smaller to fit beyond that).
  static const chipTop = 4.0;
  static const chipHeight = 26.0;
  static const chipMaxWidth = 140.0;

  /// A rank chip confirmed after the scene ended shows [lateDelayMs] after
  /// the seat shows it (the design's 300 ms after the end), over the
  /// chip's [lateMs].
  static const lateDelayMs = 300.0;
  static const lateMs = 220.0;

  // A row's look (the design's markup).

  static const edge = 1.5;
  static const rowRadius = 9.0;
  static const rankSkewDeg = -12.0;
  static const namePad = 10.0;
  static const nameGap = 5.0;
  static const badgeHeight = 16.0;
  static const badgePad = 4.0;
  static const badgeEdge = 1.2;
  static const badgeRadius = 4.0;
  static const tagHeight = 22.0;
  static const tagPad = 6.0;
  static const tagRadius = 6.0;
  static const scoreLeft = 8.0;
  static const scoreRight = 12.0;
  static const unitGap = 1.0;

  // The chip's look.

  static const chipRadius = 7.0;
  static const chipRankPad = 6.0;
  static const chipRankSkewDeg = -10.0;
  static const chipScoreLeft = 7.0;
  static const chipScoreRight = 5.0;
  static const chipTagRight = 4.0;
  static const chipTagHeight = 16.0;
  static const chipTagPad = 4.0;
  static const chipTagRadius = 4.0;

  /// The words.
  static const meWord = '나';
  static const rankWord = '위';
  static const pointsWord = '점';

  /// The chip as a screen reader says it (SPEC 6): "주간 랭킹 2위, 이번 주
  /// 29점, 이번 판 10점".
  static String chipLabel(RankChipValues chip) =>
      '주간 랭킹 ${RankingLadder.rankText(chip.rank)}위, '
      '이번 주 ${RankingLadder.rankText(chip.points)}점, '
      '이번 판 ${chip.gained}점';

  /// '+N' of [gained] points.
  static String gainText(int gained) => '+$gained';
}

/// One ladder row at a time, on the screen: its middle [center] and its
/// [scale], the rank and points it shows, its rank's pop ([rankScale]),
/// my '+N' ([tagOpacity], [tagScale]) and my shadow's drop ([lift]).
class VictoryLadderRowFrame {
  const VictoryLadderRowFrame({
    required this.row,
    required this.center,
    required this.scale,
    required this.opacity,
    required this.rank,
    required this.rankScale,
    required this.points,
    required this.tagOpacity,
    required this.tagScale,
    required this.lift,
  });

  final LadderRow row;
  final Offset center;
  final double scale;
  final double opacity;
  final String rank;
  final double rankScale;
  final String points;
  final double tagOpacity;
  final double tagScale;
  final double lift;

  bool get isMe => row.isMe;

  /// Whether its rank cell is the first place's (orange): another
  /// player's row showing rank 1.
  bool get first => !isMe && rank == '1';
}

/// The rank chip in the scene: its middle [center] on the screen, [scale]
/// and [opacity].
class VictoryChipFrame {
  const VictoryChipFrame({
    required this.center,
    required this.scale,
    required this.opacity,
  });

  final Offset center;
  final double scale;
  final double opacity;
}

/// What the ladder shows at one time: [rows] in drawing order (mine last),
/// the [dotsCenter] at [dotsOpacity] when I stay outside the list, and the
/// [chip] once it shows.
class VictoryLadderFrame {
  const VictoryLadderFrame({
    this.rows = const [],
    this.dotsCenter,
    this.dotsOpacity = 0,
    this.chip,
  });

  final List<VictoryLadderRowFrame> rows;
  final Offset? dotsCenter;
  final double dotsOpacity;
  final VictoryChipFrame? chip;
}

/// The ladder of [ladder] over [scene] (a scene with its hold): what it
/// shows at a time (the design's `rowAt`), and its end look, the chip alone.
class VictoryLadderScene {
  VictoryLadderScene({required this.ladder, required this.scene});

  final RankingLadder ladder;
  final VictoryScene scene;

  VictoryLayout get _layout => scene.layout;

  /// The chip's middle on this screen.
  Offset get chipCenter => _layout.nearSeat(VictoryLadder.chipCenter);

  /// The end look: the chip on the seat.
  VictoryLadderFrame get end => VictoryLadderFrame(
    chip: VictoryChipFrame(center: chipCenter, scale: 1, opacity: 1),
  );

  /// The ladder [t] ms after the report opened; its end look from the
  /// scene's end on.
  VictoryLadderFrame at(double t) {
    if (t >= scene.endMs) return end;
    final out = scene.outFromMs;
    final move = _eio((t - VictoryLadder.moveFromMs) / VictoryLadder.moveMs);
    final roll = _eo((t - VictoryLadder.moveFromMs) / VictoryLadder.moveMs);
    const flipMs =
        VictoryLadder.moveFromMs + VictoryLadder.flipAt * VictoryLadder.moveMs;
    final flipped = t >= flipMs;
    final pop = flipped ? 1 - _clamp((t - flipMs) / VictoryLadder.popMs) : 0.0;
    final exit = t >= out ? _eio((t - out) / VictoryLadder.exitMs) : 0.0;
    final tag = _clamp((t - VictoryLadder.moveFromMs) / VictoryLadder.tagMs);
    final scale = _layout.designScale;
    double slotTop(double slot) =>
        VictoryLadder.firstTop + slot * VictoryLadder.slotGap;
    // The row's middle on the design's screen for a top-left x of
    // rowLeft + dx.
    Offset middle(double dx, double top) => Offset(
      VictoryLadder.rowLeft + VictoryLadder.rowWidth / 2 + dx,
      top + VictoryLadder.rowHeight / 2,
    );

    final rows = <VictoryLadderRowFrame>[];
    for (final row in ladder.rows) {
      final enterAt =
          VictoryLadder.entranceFromMs +
          row.order * VictoryLadder.entranceStepMs;
      final slid =
          VictoryLadder.entranceSlide *
          (1 - _eo((t - enterAt) / VictoryLadder.entranceMs));
      final top = slotTop(_lerp(row.fromSlot, row.toSlot, move));
      var opacity = t < enterAt
          ? 0.0
          : _clamp((t - enterAt) / VictoryLadder.fadeInMs);
      final lift = row.isMe ? math.sin(math.pi * move) : 0.0;
      Offset center;
      double size;
      if (t < out) {
        center = _layout.fromDesign(middle(slid, top));
        size = scale * (1 + VictoryLadder.meLift * lift);
      } else if (row.isMe) {
        center =
            Offset.lerp(_layout.fromDesign(middle(0, top)), chipCenter, exit)! -
            Offset(0, VictoryLadder.exitArc * math.sin(math.pi * exit) * scale);
        size = _lerp(scale, VictoryLadder.exitScale, exit);
        opacity *=
            1 -
            _clamp(
              (exit - VictoryLadder.exitFadeFrom) /
                  (1 - VictoryLadder.exitFadeFrom),
            );
      } else {
        final leave = _ei(
          (t - out - row.order * VictoryLadder.othersExitStepMs) /
              VictoryLadder.othersExitMs,
        );
        center = _layout.fromDesign(
          middle(slid + VictoryLadder.entranceSlide * leave, top),
        );
        size = scale;
        opacity *= 1 - leave;
      }
      final points = row.isMe
          ? (ladder.pointsBefore + (row.points - ladder.pointsBefore) * roll)
                .round()
          : row.points;
      rows.add(
        VictoryLadderRowFrame(
          row: row,
          center: center,
          scale: size,
          opacity: opacity,
          rank: flipped ? row.rankAfterText : row.rankBeforeText,
          rankScale: 1 + VictoryLadder.rankPop * (row.rankChanged ? pop : 0),
          points: RankingLadder.rankText(points),
          tagOpacity: _clamp(tag * 3),
          tagScale: 1.6 - 0.6 * _back(tag),
          lift: row.isMe
              ? VictoryLadder.shadowBase + VictoryLadder.shadowLift * lift
              : 0,
        ),
      );
    }

    Offset? dotsCenter;
    var dotsOpacity = 0.0;
    if (ladder.outside) {
      final leave = t >= out
          ? _ei((t - out) / VictoryLadder.othersExitMs)
          : 0.0;
      const shownAt =
          VictoryLadder.entranceFromMs + VictoryLadder.dotsFadeDelayMs;
      dotsOpacity = t < shownAt
          ? 0
          : _clamp((t - shownAt) / VictoryLadder.dotsFadeMs) * (1 - leave);
      final dx =
          VictoryLadder.entranceSlide *
              (1 -
                  _eo(
                    (t - VictoryLadder.entranceFromMs) /
                        VictoryLadder.entranceMs,
                  )) +
          VictoryLadder.entranceSlide * leave;
      dotsCenter = _layout.fromDesign(
        Offset(
          scene.layout.values.screen.width / 2 + dx,
          VictoryLadder.dotsTop + VictoryLadder.dotsSize.height / 2,
        ),
      );
    }

    VictoryChipFrame? chip;
    if (t >= out + VictoryLadder.chipFromMs) {
      final u = _clamp(
        (t - out - VictoryLadder.chipFromMs) / VictoryLadder.chipMs,
      );
      chip = VictoryChipFrame(
        center: chipCenter,
        scale: chipScaleAt(u),
        opacity: u,
      );
    }
    return VictoryLadderFrame(
      rows: rows,
      dotsCenter: dotsCenter,
      dotsOpacity: dotsOpacity,
      chip: chip,
    );
  }

  /// The chip's size [u] of the way in: from 0.8 with a little overshoot.
  static double chipScaleAt(double u) =>
      VictoryLadder.chipFromScale +
      (1 - VictoryLadder.chipFromScale) * _back(u);
}

/// The ladder layer of the victory overlay while the scene plays: draws
/// [scene]'s ladder from [viewModel] at the time [clock] holds, once the
/// scene chose to play it. It is decoration: screen readers skip it.
class VictoryLadderLayer extends StatelessWidget {
  const VictoryLadderLayer({
    super.key,
    required this.viewModel,
    required this.sceneIn,
    required this.clock,
  });

  final RankingLadderViewModel viewModel;

  /// The held scene on a screen of a size.
  final VictoryScene Function(Size size) sceneIn;
  final ValueListenable<double> clock;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: MediaQuery.withNoTextScaling(
        child: LayoutBuilder(
          builder: (context, constraints) => ValueListenableBuilder<double>(
            valueListenable: clock,
            builder: (context, t, _) {
              final ladder = viewModel.ladder;
              if (ladder == null) return const SizedBox.shrink();
              final scene = sceneIn(constraints.biggest);
              final frame = VictoryLadderScene(
                ladder: ladder,
                scene: scene,
              ).at(t);
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (frame.dotsCenter case final dots?)
                    if (frame.dotsOpacity > 0)
                      _placed(
                        center: dots,
                        size: VictoryLadder.dotsSize,
                        scale: scene.layout.designScale,
                        opacity: frame.dotsOpacity,
                        child: const CustomPaint(painter: _DotsPainter()),
                      ),
                  for (final row in frame.rows)
                    if (row.opacity > 0)
                      _placed(
                        center: row.center,
                        size: const Size(
                          VictoryLadder.rowWidth,
                          VictoryLadder.rowHeight,
                        ),
                        scale: row.scale,
                        opacity: row.opacity,
                        child: VictoryLadderRow(frame: row, ladder: ladder),
                      ),
                  if (frame.chip case final chip?)
                    if (viewModel.chip case final values?)
                      _placed(
                        center: chip.center,
                        size: const Size(
                          VictoryLadder.chipMaxWidth,
                          VictoryLadder.chipHeight,
                        ),
                        scale: chip.scale,
                        opacity: chip.opacity,
                        child: Center(child: VictoryRankChip(values: values)),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  static Widget _placed({
    required Offset center,
    required Size size,
    required double scale,
    required double opacity,
    required Widget child,
  }) => Positioned(
    left: center.dx - size.width / 2,
    top: center.dy - size.height / 2,
    width: size.width,
    height: size.height,
    child: Transform.scale(
      scale: scale,
      child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
    ),
  );
}

/// One ladder row (the design's markup): the rank cell (ink with lime
/// digits for mine, orange for the first place, else white), the name (with
/// '나' for mine), my '+N', and the week's points.
class VictoryLadderRow extends StatelessWidget {
  const VictoryLadderRow({
    super.key,
    required this.frame,
    required this.ladder,
  });

  final VictoryLadderRowFrame frame;
  final RankingLadder ladder;

  @override
  Widget build(BuildContext context) {
    final me = frame.isMe;
    const edge = BorderSide(color: AppColors.ink, width: VictoryLadder.edge);
    final radius = BorderRadius.circular(VictoryLadder.rowRadius);
    return Container(
      width: VictoryLadder.rowWidth,
      height: VictoryLadder.rowHeight,
      padding: const EdgeInsets.all(VictoryLadder.edge),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: me ? AppColors.accent : AppColors.card,
        borderRadius: radius,
        boxShadow: [
          if (me)
            BoxShadow(color: AppColors.ink, offset: Offset(0, frame.lift)),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.fromBorderSide(edge),
        borderRadius: radius,
      ),
      child: Row(
        children: [
          Container(
            // The design's cell is its width plus its right edge.
            width: ladder.rankCellWidth + VictoryLadder.edge,
            decoration: BoxDecoration(
              color: me
                  ? AppColors.ink
                  : frame.first
                  ? AppColors.warning
                  : AppColors.card,
              border: const Border(right: edge),
            ),
            alignment: Alignment.center,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(
                VictoryLadder.rankSkewDeg * math.pi / 180,
              )..scaleByDouble(frame.rankScale, frame.rankScale, 1, 1),
              child: Text(
                frame.rank,
                maxLines: 1,
                softWrap: false,
                style: _rankStyle(
                  Theme.of(context).textTheme,
                  ladder.rankChars,
                ).copyWith(color: me ? AppColors.accent : AppColors.ink),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: VictoryLadder.namePad,
              ),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      frame.row.nickname,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: Theme.of(context).textTheme.rankingName,
                    ),
                  ),
                  if (me) ...[
                    const SizedBox(width: VictoryLadder.nameGap),
                    Container(
                      height: VictoryLadder.badgeHeight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: VictoryLadder.badgePad,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        border: Border.all(
                          color: AppColors.ink,
                          width: VictoryLadder.badgeEdge,
                        ),
                        borderRadius: BorderRadius.circular(
                          VictoryLadder.badgeRadius,
                        ),
                      ),
                      child: Text(
                        VictoryLadder.meWord,
                        style: Theme.of(context).textTheme.rankingMeMark,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (me)
            Opacity(
              opacity: frame.tagOpacity,
              child: Transform.scale(
                scale: frame.tagScale,
                child: Container(
                  height: VictoryLadder.tagHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: VictoryLadder.tagPad,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(
                      VictoryLadder.tagRadius,
                    ),
                  ),
                  child: Text(
                    VictoryLadder.gainText(ladder.gained),
                    style: Theme.of(context).textTheme.ladderGain
                        .copyWith(color: AppColors.accent),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(
              left: VictoryLadder.scoreLeft,
              right: VictoryLadder.scoreRight,
            ),
            child: Row(
              children: [
                Text(
                  frame.points,
                  style: Theme.of(context).textTheme.ladderNumber,
                ),
                const SizedBox(width: VictoryLadder.unitGap),
                Text(
                  VictoryLadder.pointsWord,
                  style: Theme.of(context).textTheme.rankingSmall
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The rank chip the report keeps on the seat (SPEC 6): my rank on ink
/// with '위', the week's points on lime with '점', and the battle's '+N' on
/// ink at its right end. It is at most [VictoryLadder.chipMaxWidth] wide,
/// made smaller to fit beyond that, and keeps its size whatever the text
/// size, as the seat does.
class VictoryRankChip extends StatelessWidget {
  const VictoryRankChip({super.key, required this.values});

  final RankChipValues values;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(VictoryLadder.chipRadius);
    final chip = Container(
      height: VictoryLadder.chipHeight,
      padding: const EdgeInsets.all(VictoryLadder.edge),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.accent, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: AppColors.ink, width: VictoryLadder.edge),
        borderRadius: radius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.ink,
            padding: const EdgeInsets.symmetric(
              horizontal: VictoryLadder.chipRankPad,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.skewX(
                    VictoryLadder.chipRankSkewDeg * math.pi / 180,
                  ),
                  child: Text(
                    RankingLadder.rankText(values.rank),
                    style: text.rankChipNumber.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: VictoryLadder.unitGap),
                Text(
                  VictoryLadder.rankWord,
                  style: text.rankingMeMark.copyWith(color: AppColors.onInk),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: VictoryLadder.chipScoreLeft,
              right: VictoryLadder.chipScoreRight,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  RankingLadder.rankText(values.points),
                  style: text.rankChipNumber,
                ),
                const SizedBox(width: VictoryLadder.unitGap),
                Text(VictoryLadder.pointsWord, style: text.rankChipUnit),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: VictoryLadder.chipTagRight),
            child: Center(
              child: Container(
                height: VictoryLadder.chipTagHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: VictoryLadder.chipTagPad,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(
                    VictoryLadder.chipTagRadius,
                  ),
                ),
                child: Text(
                  VictoryLadder.gainText(values.gained),
                  style: text.rankChipGain.copyWith(color: AppColors.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return MediaQuery.withNoTextScaling(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: VictoryLadder.chipMaxWidth,
          maxHeight: VictoryLadder.chipHeight,
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: chip),
      ),
    );
  }
}

/// The rank chip on the report's seat, from [viewModel]: there when its
/// ranking is confirmed, and one sentence for screen readers. The seat
/// shows the scene's end, so it chooses the scene's path if the scene did
/// not (reduced motion). A chip confirmed only after the scene chose its
/// path without the ladder (late) comes in as the design's late chip,
/// [VictoryLadder.lateDelayMs] after the seat shows if it was already
/// there, at once if it comes later; with reduced motion it just shows.
class VictorySeatChip extends StatefulWidget {
  const VictorySeatChip({super.key, required this.viewModel});

  final RankingLadderViewModel viewModel;

  @override
  State<VictorySeatChip> createState() => _VictorySeatChipState();
}

class _VictorySeatChipState extends State<VictorySeatChip>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);

  /// How long the chip waits before coming in, once it comes in.
  double _delayMs = 0;

  /// Whether the chip comes in (late) rather than just shows.
  bool _comesIn = false;

  RankingLadderViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    final path = _viewModel.decide();
    if (path == LadderPath.late) {
      if (_viewModel.chip != null) {
        _comeIn(delayMs: VictoryLadder.lateDelayMs);
      } else {
        _viewModel.addListener(_onChange);
      }
    }
  }

  void _onChange() {
    if (_viewModel.chip == null || _comesIn) return;
    _viewModel.removeListener(_onChange);
    setState(() => _comeIn(delayMs: 0));
  }

  void _comeIn({required double delayMs}) {
    _comesIn = true;
    _delayMs = delayMs;
    _controller
      ..duration = Duration(
        milliseconds: (delayMs + VictoryLadder.lateMs).round(),
      )
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = _viewModel.chip;
    if (values == null) return const SizedBox.shrink();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final chip = Semantics(
      label: VictoryLadder.chipLabel(values),
      container: true,
      excludeSemantics: true,
      child: VictoryRankChip(values: values),
    );
    if (!_comesIn || still) return chip;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final total = _delayMs + VictoryLadder.lateMs;
        final u = _clamp(
          (_controller.value * total - _delayMs) / VictoryLadder.lateMs,
        );
        return Opacity(
          opacity: u,
          child: Transform.scale(
            scale: VictoryLadderScene.chipScaleAt(u),
            child: child,
          ),
        );
      },
      child: chip,
    );
  }
}

/// The three dots between the list's last row and mine.
class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.ink;
    for (final y in VictoryLadder.dotYs) {
      canvas.drawCircle(
        Offset(size.width / 2, y),
        VictoryLadder.dotRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}

/// The rank cell's digits for ranks of [chars] characters (SPEC 5): 19 for
/// one, 17 for two, 15 for more ([RankingLadder.rankCellText]).
TextStyle _rankStyle(TextTheme text, int chars) => switch (chars) {
  <= 1 => text.ladderNumber,
  2 => text.rankingRowRankWide,
  _ => text.ladderRankNarrow,
};

double _clamp(double x) => x.clamp(0.0, 1.0);

double _lerp(double a, double b, double u) => a + (b - a) * u;

double _eo(double x) => MotionEase.eo.at(_clamp(x));

double _eio(double x) => MotionEase.eio.at(_clamp(x));

double _ei(double x) => MotionEase.ei.at(_clamp(x));

/// The overshoot: 1 + 2.70158 (x - 1)^3 + 1.70158 (x - 1)^2.
double _back(double x) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final d = _clamp(x) - 1;
  return 1 + c3 * d * d * d + c1 * d * d;
}
