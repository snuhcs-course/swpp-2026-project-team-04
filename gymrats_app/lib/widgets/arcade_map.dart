import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/arcade_catalog.dart';
import '../models/arcade_progress.dart';
import '../models/arcade_stage.dart';
import '../theme/app_theme.dart';
import '../viewmodels/arcade_viewmodel.dart';
import 'arcade_parts.dart';
import 'battle_art_path.dart';
import 'battle_fx_motion.dart';
import 'character_figure.dart';
import 'gym_background.dart';

/// Where everything is on the arcade's map (P16 design `ArcMap`, `look`
/// m3, `state` all): one long picture 360 wide, 5F 공사중 on top and 1F at
/// the bottom, in the design's own points.
abstract final class ArcadeMapLayout {
  /// The design's width; the map is scaled to the screen's.
  static const width = 360.0;

  /// A floor's picture (`FH`), the band under each floor (`BAND`) and 5F's
  /// picture (`WIP`).
  static const floorHeight = 390.0;
  static const bandHeight = 46.0;
  static const wipHeight = 250.0;

  /// The top floor: 5F, under construction.
  static const topFloor = 5;

  /// The whole map's height: every floor with its band.
  static double get height => top(1) + floorHeight + bandHeight;

  /// The top of floor [floor]'s picture (`top(f)`).
  static double top(int floor) => floor == topFloor
      ? 0
      : wipHeight + bandHeight + (4 - floor) * (floorHeight + bandHeight);

  /// The height of floor [floor]'s picture.
  static double floorPicture(int floor) =>
      floor == topFloor ? wipHeight : floorHeight;

  /// The top of the band under floor [floor].
  static double band(int floor) => top(floor) + floorPicture(floor);

  /// The six stages' places on a floor (`P`), from its picture's top.
  static const slots = [
    Offset(84, 340),
    Offset(200, 302),
    Offset(292, 250),
    Offset(190, 196),
    Offset(82, 140),
    Offset(176, 82),
  ];

  /// The middle of stage [stage]'s round cell.
  static Offset center(ArcadeStage stage) =>
      slots[stage.slot - 1] + Offset(0, top(stage.floor));

  /// A stage cell's size: a boss match 70, the stage to play 64, any other
  /// 54.
  static double cellSize(ArcadeStage stage, {required bool current}) =>
      stage.kind == ArcadeStageKind.boss
      ? 70
      : current
      ? 64
      : 54;

  /// How large the face is drawn in a cell of [size] (`fk`).
  static double faceScale(double size) => switch (size) {
    70 => 0.64,
    64 => 0.6,
    _ => 0.5,
  };

  /// The scroll offset, in design points, that puts [stage]'s cell in the
  /// middle of a [viewport] high view (P16 spec 4), kept on the map; with
  /// no stage (all cleared) the top.
  static double scrollFor(ArcadeStage? stage, double viewport) {
    if (stage == null) return 0;
    final y = center(stage).dy - viewport / 2;
    return y.clamp(0.0, (height - viewport).clamp(0.0, height));
  }
}

/// The stage the map marks as the user's: the next to play, or after all
/// 24 the last one, where the user celebrates.
ArcadeStage arcadeMarkedStage(ArcadeProgress progress) =>
    ArcadeCatalog.stage(progress.currentStage ?? ArcadeProgress.stageCount);

/// The arcade's map (P16 spec 4): the building in cross-section, each floor
/// its gym's picture with its band under it, the path through the 24
/// stages, the stages' cells and the user beside the one to play.
///
/// It is drawn at the design's 360 points and scaled to [width]. A stage
/// that is open answers a tap with [onStage]; a locked one does nothing.
/// While a floor's band is out of [scroll]'s view its picture shows its
/// name tag ("4F") at its top right.
class ArcadeMap extends StatelessWidget {
  const ArcadeMap({
    super.key,
    required this.progress,
    required this.myCharacter,
    required this.onStage,
    required this.width,
    this.scroll,
  });

  final ArcadeProgress progress;

  /// The user's chosen character, beside the stage to play.
  final String myCharacter;
  final ValueChanged<ArcadeStage> onStage;

  /// The width it is drawn at.
  final double width;

  /// The map's scroll, for the floors' name tags; none shows every tag.
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context) {
    final scale = width / ArcadeMapLayout.width;
    final marked = arcadeMarkedStage(progress);
    final allCleared = progress.currentStage == null;
    final playing = progress.currentStage;
    // A floor is open once the one under it is cleared (A2's progress).
    bool locked(int floor) =>
        floor != ArcadeMapLayout.topFloor &&
        floor > 1 &&
        !progress.isFloorCleared(floor - 1);
    return SizedBox(
      width: width,
      height: ArcadeMapLayout.height * scale,
      child: FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: ArcadeMapLayout.width,
          height: ArcadeMapLayout.height,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (var floor = ArcadeMapLayout.topFloor; floor >= 1; floor--)
                Positioned(
                  left: 0,
                  right: 0,
                  top: ArcadeMapLayout.top(floor),
                  height: ArcadeMapLayout.floorPicture(floor),
                  child: _FloorPicture(floor: floor, locked: locked(floor)),
                ),
              const _Walls(),
              Positioned.fill(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _PathPainter(markedStage: marked.number),
                  ),
                ),
              ),
              for (var floor = ArcadeMapLayout.topFloor; floor >= 1; floor--)
                Positioned(
                  left: 0,
                  right: 0,
                  top: ArcadeMapLayout.band(floor),
                  height: ArcadeMapLayout.bandHeight,
                  child: _Band(floor: floor, locked: locked(floor)),
                ),
              for (var floor = 4; floor >= 1; floor--)
                Positioned(
                  right: _FloorTag.right,
                  top: ArcadeMapLayout.top(floor) + _FloorTag.top,
                  child: _FloorTag(floor: floor, scroll: scroll, scale: scale),
                ),
              for (final stage in ArcadeCatalog.stages)
                ..._cell(
                  stage,
                  current: stage.number == marked.number,
                  stars: progress.bestOf(stage.number),
                  open: progress.isOpen(stage.number),
                  playing: stage.number == playing,
                ),
              ..._me(marked, celebrating: allCleared),
            ],
          ),
        ),
      ),
    );
  }

  /// A stage's cell, its tag, number, stars or lock, all around [stage]'s
  /// middle.
  List<Widget> _cell(
    ArcadeStage stage, {
    required bool current,
    required int stars,
    required bool open,
    required bool playing,
  }) {
    final c = ArcadeMapLayout.center(stage);
    final d = ArcadeMapLayout.cellSize(stage, current: current);
    final done = stars > 0;
    final locked = !open;
    final hold = stage.kind == ArcadeStageKind.hold;
    final boss = stage.kind == ArcadeStageKind.boss;
    final label = locked
        ? 'STAGE ${stage.number}, 잠김'
        : 'STAGE ${stage.number}, ${ArcadeWords.title(stage)}, 별 $stars개'
              '${playing ? ', 지금 판' : ''}';
    return [
      Positioned(
        left: c.dx - d / 2,
        top: c.dy - d / 2,
        width: d,
        height: d,
        child: Semantics(
          button: true,
          enabled: open,
          label: label,
          excludeSemantics: true,
          onTap: open ? () => onStage(stage) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: open ? () => onStage(stage) : null,
            child: _Cell(
              stage: stage,
              size: d,
              current: current,
              locked: locked,
            ),
          ),
        ),
      ),
      if (boss || hold)
        Positioned(
          left: c.dx - 30,
          top: c.dy - d / 2 - 16,
          child: IgnorePointer(
            child: _KindTag(boss: boss, locked: locked),
          ),
        ),
      Positioned(
        left: c.dx - 12 - (stage.number >= 10 ? 4 : 0),
        top: c.dy + d / 2 - 8,
        child: IgnorePointer(
          child: _Number(
            number: stage.number,
            current: current,
            locked: locked,
          ),
        ),
      ),
      if (done)
        Positioned(
          left: c.dx - 26,
          top: c.dy + d / 2 + 13,
          child: IgnorePointer(child: _CellStars(stars: stars)),
        ),
      if (locked)
        Positioned(
          left: hold ? c.dx - d / 2 - 8 : c.dx + d / 2 - 16,
          top: hold ? c.dy - 6 : c.dy - d / 2 - 4,
          child: const IgnorePointer(child: ArcadeLockBadge()),
        ),
    ];
  }

  /// The user beside [marked], and "나" over them: to its right when it is
  /// left of 150, else to its left (the design's `me`).
  List<Widget> _me(ArcadeStage marked, {required bool celebrating}) {
    final c = ArcadeMapLayout.center(marked);
    final left = c.dx < 150;
    return [
      Positioned(
        left: c.dx - 70 + (left ? 50 : -46),
        top: c.dy - 150 + 22,
        child: IgnorePointer(
          child: _Me(characterId: myCharacter, celebrating: celebrating),
        ),
      ),
      Positioned(
        left: left ? c.dx + 38 : c.dx - 84,
        top: c.dy - 78,
        child: const IgnorePointer(child: _MeTag()),
      ),
    ];
  }
}

/// A floor's picture: its gym (A3's [GymBackground]) on the map's grey,
/// grey and faded while the floor is locked; 5F's construction site.
class _FloorPicture extends StatelessWidget {
  const _FloorPicture({required this.floor, required this.locked});

  final int floor;
  final bool locked;

  /// A locked floor shows this much (`opacity(0.6)`).
  static const _lockedOpacity = 0.6;

  @override
  Widget build(BuildContext context) {
    final Widget picture = floor == ArcadeMapLayout.topFloor
        ? const _UnderConstruction()
        : ColoredBox(
            color: AppColors.facetLight,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: gymBackgroundSize.width,
                maxWidth: gymBackgroundSize.width,
                minHeight: gymBackgroundSize.height,
                maxHeight: gymBackgroundSize.height,
                child: GymBackground(floor: floor),
              ),
            ),
          );
    if (!locked) return ExcludeSemantics(child: picture);
    return ExcludeSemantics(
      child: Opacity(
        opacity: _lockedOpacity,
        child: ArcadeFace.grayed(picture),
      ),
    );
  }
}

/// 5F 공사중: beams on a sand wall, a striped barrier, two cones and the
/// "공사중" sign.
class _UnderConstruction extends StatelessWidget {
  const _UnderConstruction();

  static const _signTop = 82.0;
  static const _signSide = 24.0;
  static const _signOver = 6.0;
  static const _signUnder = 8.0;
  static const _signPadding = EdgeInsets.fromLTRB(
    _signSide,
    _signOver,
    _signSide,
    _signUnder,
  );
  static const _barrierBottom = 22.0;
  static const _barrierHeight = 26.0;
  static const _barrierOut = -10.0;
  static const _coneSide = 40.0;
  static const _coneBottom = 52.0;
  static const _coneSize = Size(40, 48);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.wipWall,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned.fill(child: CustomPaint(painter: _BeamsPainter())),
          const Positioned(
            left: _barrierOut,
            right: _barrierOut,
            bottom: _barrierBottom,
            height: _barrierHeight,
            child: ArcadeStripes(stripe: 16, edge: 3, edgeSides: false),
          ),
          Positioned(
            left: _coneSide,
            bottom: _coneBottom,
            child: CustomPaint(size: _coneSize, painter: const _ConePainter()),
          ),
          Positioned(
            right: _coneSide,
            bottom: _coneBottom,
            child: CustomPaint(size: _coneSize, painter: const _ConePainter()),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _signTop,
            child: Center(
              child: Transform.rotate(
                angle: -3 * math.pi / 180,
                child: Container(
                  padding: _signPadding,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(_ArcadeEdges.sign),
                    border: Border.all(color: AppColors.ink, width: 3),
                    boxShadow: const [
                      BoxShadow(color: AppColors.ink, offset: Offset(4, 5)),
                    ],
                  ),
                  child: Text(
                    '공사중',
                    style: Theme.of(context).textTheme.arcadeWipSign,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Corner radii of the map's parts, in design points.
abstract final class _ArcadeEdges {
  static const sign = 10.0;
  static const chip = 8.0;
  static const tag = 6.0;
  static const floorTag = 7.0;
  static const stripes = 4.0;
}

/// 5F's beams and ledge (the design's two paths, 360 x 250).
class _BeamsPainter extends CustomPainter {
  const _BeamsPainter();

  static const _beams =
      'M40 0V400M180 0V400M320 0V400M40 30L180 130M180 30L40 130M180 30L320 '
      '130M320 30L180 130';
  static const _ledge = 'M0 150H360';

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawPath(
        battleArtPath(_beams),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.wipBeam
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      )
      ..drawPath(
        battleArtPath(_ledge),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.wipLedge
          ..strokeWidth = 8,
      );
  }

  @override
  bool shouldRepaint(_BeamsPainter oldDelegate) => false;
}

/// A traffic cone (the design's 34 x 40 drawing, drawn 40 x 48).
class _ConePainter extends CustomPainter {
  const _ConePainter();

  static const _body = 'M12 4h10l8 32H4z';
  static const _bands = 'M9.5 18h15M7.5 26h19';
  static const _foot = 'M1 37h32';

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 34, size.height / 40);
    final body = battleArtPath(_body);
    canvas
      ..drawPath(body, Paint()..color = AppColors.wipCone)
      ..drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.ink
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        battleArtPath(_bands),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.card
          ..strokeWidth = 4,
      )
      ..drawPath(
        battleArtPath(_foot),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.ink
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_ConePainter oldDelegate) => false;
}

/// Amber and ink stripes at 135°, [stripe] wide each: the barrier and the
/// 5F marks. With [edgeSides] the box is edged all round ([edge] wide,
/// [radius] corners); otherwise only top and bottom.
class ArcadeStripes extends StatelessWidget {
  const ArcadeStripes({
    super.key,
    required this.stripe,
    required this.edge,
    this.edgeSides = true,
    this.radius = 0,
  });

  final double stripe;
  final double edge;
  final bool edgeSides;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: AppColors.ink, width: edge);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius == 0 ? null : BorderRadius.circular(radius),
        border: edgeSides
            ? Border.fromBorderSide(side)
            : Border(top: side, bottom: side),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(painter: ArcadeStripesPainter(stripe)),
      ),
    );
  }
}

/// The building's side walls, 6 wide, the bands' color.
class _Walls extends StatelessWidget {
  const _Walls();

  static const _width = 6.0;

  @override
  Widget build(BuildContext context) => const Positioned.fill(
    child: ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: _width,
            child: ColoredBox(color: AppColors.arcadeBand),
          ),
          SizedBox(
            width: _width,
            child: ColoredBox(color: AppColors.arcadeBand),
          ),
        ],
      ),
    ),
  );
}

/// The path through the 24 stages: solid ink up to [markedStage], dotted
/// grey from it on, each on a white casing 11 wide.
class _PathPainter extends CustomPainter {
  const _PathPainter({required this.markedStage});

  final int markedStage;

  static const _casing = 11.0;
  static const _done = 5.0;
  static const _next = 4.0;
  static const _dash = 2.0;
  static const _gap = 11.0;

  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      for (final stage in ArcadeCatalog.stages) ArcadeMapLayout.center(stage),
    ];
    final done = points.sublist(0, markedStage);
    final next = points.sublist(markedStage - 1);
    final casing = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.card
      ..strokeWidth = _casing
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(_line(done), casing)
      ..drawPath(_line(next), casing)
      ..drawPath(
        _line(done),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.ink
          ..strokeWidth = _done
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    final dots = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.line
      ..strokeWidth = _next
      ..strokeCap = StrokeCap.round;
    for (final metric in _line(next).computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += _dash + _gap) {
        canvas.drawPath(
          metric.extractPath(at, (at + _dash).clamp(0, metric.length)),
          dots,
        );
      }
    }
  }

  static Path _line(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(_PathPainter oldDelegate) =>
      oldDelegate.markedStage != markedStage;
}

/// The band under a floor: its lime floor chip, its name, a lock while it
/// is locked, and its rule chip at the right (grey while locked); 5F's says
/// 공사중 with stripes.
class _Band extends StatelessWidget {
  const _Band({required this.floor, required this.locked});

  final int floor;
  final bool locked;

  static const _edge = 3.0;
  static const _side = 16.0;
  static const _gap = 10.0;
  static const _chipHeight = 26.0;
  static const _ruleHeight = 24.0;
  static const _ruleSide = 8.0;
  static const _ruleGap = 4.0;
  static const _ruleEdge = 2.0;
  static const _boltSize = 13.0;
  static const _stripesSize = Size(96, 18);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final wip = floor == ArcadeMapLayout.topFloor;
    final rule = wip ? null : ArcadeCatalog.floor(floor).rule;
    final name = wip ? '공사중' : ArcadeCatalog.floor(floor).name;
    return Semantics(
      header: true,
      label: '${floor}F $name${locked ? ', 잠김' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: _side),
        decoration: const BoxDecoration(
          color: AppColors.arcadeBand,
          border: Border(
            top: BorderSide(color: AppColors.ink, width: _edge),
            bottom: BorderSide(color: AppColors.ink, width: _edge),
          ),
        ),
        child: Row(
          children: [
            ArcadeSlantChip(
              label: '${floor}F',
              color: AppColors.accent,
              height: _chipHeight,
              style: text.arcadeBandFloor.copyWith(
                color: wip ? AppColors.warning : AppColors.ink,
              ),
            ),
            const SizedBox(width: _gap),
            // The name gives way before the rule chip on a narrow screen.
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: text.arcadeBandName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (locked) ...[
                    const SizedBox(width: _gap),
                    const ArcadeLockBadge(),
                  ],
                ],
              ),
            ),
            if (wip)
              SizedBox.fromSize(
                size: _stripesSize,
                child: const ArcadeStripes(
                  stripe: 8,
                  edge: 2,
                  radius: _ArcadeEdges.stripes,
                ),
              )
            else if (rule != null)
              Container(
                height: _ruleHeight,
                padding: const EdgeInsets.symmetric(horizontal: _ruleSide),
                decoration: BoxDecoration(
                  color: locked ? AppColors.starOff : AppColors.warning,
                  borderRadius: BorderRadius.circular(_ArcadeEdges.chip),
                  border: Border.all(color: AppColors.ink, width: _ruleEdge),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ArcadeGlyphIcon(ArcadeGlyph.bolt, size: _boltSize),
                    const SizedBox(width: _ruleGap),
                    Text(rule.label, style: text.arcadeRuleChip),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "4F" at a floor picture's top right while the floor's band is out of
/// the map's view.
class _FloorTag extends StatefulWidget {
  const _FloorTag({
    required this.floor,
    required this.scroll,
    required this.scale,
  });

  final int floor;
  final ScrollController? scroll;

  /// Design points to the scroll's.
  final double scale;

  static const right = 12.0;
  static const top = 10.0;
  static const _over = 1.0;
  static const _padding = EdgeInsets.symmetric(
    horizontal: AppSpacing.s8,
    vertical: _over,
  );
  static const _shade = 0.9;

  /// Whether floor [floor]'s band shows in a view from [offset] down
  /// [viewport] (both in design points).
  static bool bandShows(int floor, double offset, double viewport) {
    final y = ArcadeMapLayout.band(floor);
    return y + ArcadeMapLayout.bandHeight > offset && y < offset + viewport;
  }

  @override
  State<_FloorTag> createState() => _FloorTagState();
}

class _FloorTagState extends State<_FloorTag> {
  @override
  void initState() {
    super.initState();
    // The view's height is known only after the first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final scroll = widget.scroll;
    if (scroll == null) return _tag(context);
    return ListenableBuilder(
      listenable: scroll,
      builder: (context, _) {
        if (!scroll.hasClients) return const SizedBox.shrink();
        final position = scroll.position;
        if (!position.hasViewportDimension) return const SizedBox.shrink();
        final shows = _FloorTag.bandShows(
          widget.floor,
          position.pixels / widget.scale,
          position.viewportDimension / widget.scale,
        );
        return shows ? const SizedBox.shrink() : _tag(context);
      },
    );
  }

  Widget _tag(BuildContext context) => ExcludeSemantics(
    child: Container(
      padding: _FloorTag._padding,
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: _FloorTag._shade),
        borderRadius: BorderRadius.circular(_ArcadeEdges.floorTag),
      ),
      child: Text(
        '${widget.floor}F',
        style: Theme.of(context).textTheme.arcadeFloorTag,
      ),
    ),
  );
}

/// A stage's round cell: the face of who is met there on white (a boss
/// match on pink), the stage to play larger on lime with a lime glow and an
/// ink ring, a locked stage grey.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.stage,
    required this.size,
    required this.current,
    required this.locked,
  });

  final ArcadeStage stage;
  final double size;
  final bool current;
  final bool locked;

  static const _glow = 6.0;
  static const _ring = 8.0;
  static const _halo = 3.0;
  static const _glowShade = 0.7;

  @override
  Widget build(BuildContext context) {
    final boss = stage.kind == ArcadeStageKind.boss;
    final hold = stage.kind == ArcadeStageKind.hold;
    final edge = current
        ? 3.5
        : locked
        ? 2.5
        : 3.0;
    final inner = size - 2 * edge;
    final face = size - 6;
    final scale = ArcadeMapLayout.faceScale(size);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: current
            ? AppColors.accent
            : locked
            ? AppColors.facetDark
            : boss
            ? AppColors.opponent
            : AppColors.card,
        border: Border.all(
          color: locked ? AppColors.lockedEdge : AppColors.ink,
          width: edge,
        ),
        boxShadow: current
            ? [
                const BoxShadow(color: AppColors.ink, spreadRadius: _ring),
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: _glowShade),
                  spreadRadius: _glow,
                ),
              ]
            : const [BoxShadow(color: AppColors.card, spreadRadius: _halo)],
      ),
      child: Padding(
        padding: EdgeInsets.all(edge),
        child: ClipOval(
          child: SizedBox.square(
            dimension: inner,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: ArcadeFace(
                    id: stage.character,
                    size: face,
                    scale: scale,
                    owner: hold,
                    gray: locked,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The tag over a boss match ("BOSS" with the crown, on pink) or a hold
/// ("HOLD" with the stopwatch, on white).
class _KindTag extends StatelessWidget {
  const _KindTag({required this.boss, required this.locked});

  final bool boss;
  final bool locked;

  static const _height = 20.0;
  static const _side = 6.0;
  static const _gap = 3.0;
  static const _edge = 2.0;
  static const _halo = 2.0;
  static const _crown = 13.0;
  static const _timer = 12.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ink = locked ? AppColors.textMuted : AppColors.ink;
    return Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: _side),
      decoration: BoxDecoration(
        color: boss ? AppColors.opponent : AppColors.card,
        borderRadius: BorderRadius.circular(_ArcadeEdges.tag),
        border: Border.all(
          color: boss || !locked ? AppColors.ink : AppColors.lockedEdge,
          width: _edge,
        ),
        boxShadow: boss
            ? const [BoxShadow(color: AppColors.card, spreadRadius: _halo)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (boss)
            const ArcadeGlyphIcon(ArcadeGlyph.crown, size: _crown)
          else
            ArcadeGlyphIcon(ArcadeGlyph.timer, size: _timer, color: ink),
          const SizedBox(width: _gap),
          Text(
            boss ? 'BOSS' : 'HOLD',
            style: text.arcadeNodeTag.copyWith(
              color: boss ? AppColors.ink : ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// A stage's number under its cell: lime on ink for the stage to play,
/// grey while locked.
class _Number extends StatelessWidget {
  const _Number({
    required this.number,
    required this.current,
    required this.locked,
  });

  final int number;
  final bool current;
  final bool locked;

  static const _minWidth = 24.0;
  static const _height = 20.0;
  static const _side = 5.0;
  static const _edge = 2.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: _minWidth),
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: _side),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: current
            ? AppColors.ink
            : locked
            ? AppColors.facetDark
            : AppColors.card,
        borderRadius: BorderRadius.circular(_ArcadeEdges.tag),
        border: Border.all(
          color: locked ? AppColors.lockedEdge : AppColors.ink,
          width: _edge,
        ),
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.arcadeNodeNumber.copyWith(
          color: current
              ? AppColors.accent
              : locked
              ? AppColors.textMuted
              : AppColors.ink,
        ),
      ),
    );
  }
}

/// A played stage's stars under its number, on a white chip.
class _CellStars extends StatelessWidget {
  const _CellStars({required this.stars});

  final int stars;

  static const _size = 14.0;
  static const _gap = 1.0;
  static const _side = 3.0;
  static const _over = 1.0;
  static const _padding = EdgeInsets.symmetric(
    horizontal: _side,
    vertical: _over,
  );
  static const _shade = 0.9;

  @override
  Widget build(BuildContext context) => Container(
    padding: _padding,
    decoration: BoxDecoration(
      color: AppColors.card.withValues(alpha: _shade),
      borderRadius: BorderRadius.circular(_ArcadeEdges.tag),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 3; star++) ...[
          if (star > 1) const SizedBox(width: _gap),
          ArcadeGlyphIcon(
            ArcadeGlyph.star,
            size: _size,
            fill: star <= stars ? AppColors.starOn : AppColors.starOff,
          ),
        ],
      ],
    ),
  );
}

/// A lock in a white circle with a grey edge: a locked stage, a locked
/// floor's band.
class ArcadeLockBadge extends StatelessWidget {
  const ArcadeLockBadge({super.key});

  static const size = 22.0;
  static const _edge = 2.0;
  static const _icon = 12.0;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.card,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.lockedEdge, width: _edge),
    ),
    child: const ArcadeGlyphIcon(
      ArcadeGlyph.lock,
      size: _icon,
      color: AppColors.textMuted,
    ),
  );
}

/// The user's character beside the stage to play, at 0.52 about its feet
/// and edged white: idling, or celebrating once all 24 are cleared.
class _Me extends StatelessWidget {
  const _Me({required this.characterId, required this.celebrating});

  final String characterId;
  final bool celebrating;

  static const _scale = 0.52;
  static const _feet = Offset(70, 150);
  static const _box = Size(140, 160);
  static const _edge = 2.0;

  @override
  Widget build(BuildContext context) {
    final figure = celebrating
        ? CharacterFigure(characterId: characterId, pose: BattlePose.win)
        : CharacterIdleFigure(characterId: characterId);
    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: _box,
        child: Transform.scale(
          scale: _scale,
          alignment: Alignment.topLeft,
          origin: _feet,
          child: ArcadeWhiteOutline(width: _edge, child: figure),
        ),
      ),
    );
  }
}

/// "나" on lime by the user's character.
class _MeTag extends StatelessWidget {
  const _MeTag();

  static const _side = 7.0;
  static const _edge = 2.0;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: _side),
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(_ArcadeEdges.floorTag),
      border: Border.all(color: AppColors.ink, width: _edge),
    ),
    child: Text('나', style: Theme.of(context).textTheme.arcadeMeTag),
  );
}
