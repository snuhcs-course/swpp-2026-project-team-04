import 'package:flutter/material.dart';

import '../models/arcade_floor.dart';
import '../models/arcade_stage.dart';
import '../services/pose/hold_pose_definition.dart';
import '../theme/app_theme.dart';
import '../widgets/gym_background.dart';
import '../widgets/gym_owner_figure.dart';
import 'hold_stage_art.dart';

/// The hold stage's briefing (arcade hold spec 2, the design's
/// `P16Hold scene=brief`): the stage, the floor's owner on its gym, the
/// pose with its star times and checks, the warning rule, and 자세 잡기.
class HoldStageBrief extends StatelessWidget {
  const HoldStageBrief({
    super.key,
    required this.stage,
    required this.floor,
    required this.definition,
    required this.onBack,
    required this.onStart,
  });

  final ArcadeHoldStage stage;
  final ArcadeFloor floor;
  final HoldPoseDefinition definition;

  /// Back to the arcade.
  final VoidCallback onBack;

  /// 자세 잡기.
  final VoidCallback onStart;

  /// "STAGE 3 · 1F".
  static String stageTag(ArcadeStage stage) =>
      'STAGE ${stage.number} · ${stage.floor}F';

  static const _padSide = AppSpacing.s20;
  static const _padBottom = 22.0;
  static const _ownerCardHeight = 286.0;
  static const _ownerCardEdge = 2.5;
  static const _ownerCardCorner = 22.0;
  static const _ownerCardGap = 14.0;
  static const _sectionGap = 10.0;
  static const _buttonHeight = 58.0;
  static const _arrowSize = 22.0;
  static const _arrowGap = 10.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _padSide,
                  0,
                  _padSide,
                  _padBottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(tag: stageTag(stage), onBack: onBack),
                    const SizedBox(height: _ownerCardGap),
                    SizedBox(
                      height: _ownerCardHeight,
                      child: _OwnerCard(floor: floor),
                    ),
                    const SizedBox(height: _sectionGap),
                    _PoseCard(stage: stage, definition: definition),
                    const Spacer(),
                    const SizedBox(height: AppSpacing.s16),
                    HoldDarkButton(
                      label: '자세 잡기',
                      style: Theme.of(context).textTheme.holdStartButton,
                      height: _buttonHeight,
                      arrowSize: _arrowSize,
                      gap: _arrowGap,
                      onPressed: onStart,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tag, required this.onBack});

  final String tag;
  final VoidCallback onBack;

  static const _button = 44.0;
  static const _corner = 14.0;
  static const _gap = AppSpacing.s12;
  static const _titleGap = 2.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Semantics(
          button: true,
          label: '지도로',
          child: ExcludeSemantics(
            child: Material(
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_corner),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(_corner),
                child: const SizedBox.square(
                  dimension: _button,
                  child: Center(
                    child: CustomPaint(
                      size: Size.square(22),
                      painter: HoldArrowPainter.back(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: _gap),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tag, style: text.holdBriefTag),
            const SizedBox(height: _titleGap),
            Transform(
              transform: AppHighlight.slant,
              alignment: Alignment.bottomLeft,
              child: Semantics(
                header: true,
                child: Text('버티기', style: text.holdBriefTitle),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Where the floor's owner stands on the briefing card and over the
/// stage, from the box's right edge (the design's `coachR2`, `coachR`).
const holdOwnerRight = <String, ({double card, double stage})>{
  'seal': (card: 6, stage: 8),
  'penguin': (card: 2, stage: 6),
  'kangaroo': (card: 12, stage: 14),
  'bear': (card: 22, stage: 24),
};

/// [child] with a white outline [width] wide all around, as the design
/// draws its figures (four white drop shadows).
class HoldOutlined extends StatelessWidget {
  const HoldOutlined({super.key, required this.child, this.width = 2.5});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    Widget shadow(Offset offset) => Transform.translate(
      offset: offset,
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(AppColors.card, BlendMode.srcIn),
        child: child,
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        shadow(Offset(width, 0)),
        shadow(Offset(-width, 0)),
        shadow(Offset(0, width)),
        shadow(Offset(0, -width)),
        child,
      ],
    );
  }
}

/// The floor's owner, flipped to face left, [scale] times the 140 x 160
/// box about the feet (70, 150), outlined in white.
class HoldOwner extends StatelessWidget {
  const HoldOwner({
    super.key,
    required this.ownerId,
    required this.scale,
    this.face = GymOwnerFace.watch,
    this.idle = false,
  });

  final String ownerId;
  final double scale;
  final GymOwnerFace face;
  final bool idle;

  /// The figures' box, as the art draws them.
  static const box = Size(140, 160);

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: box,
    child: Transform(
      transform: Matrix4.diagonal3Values(-scale, scale, 1),
      origin: const Offset(70, 150),
      child: HoldOutlined(
        child: GymOwnerFigure(ownerId: ownerId, face: face, idle: idle),
      ),
    ),
  );
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.floor});

  final ArcadeFloor floor;

  static const _inset = AppSpacing.s16;
  static const _ownerBottom = 26.0;
  static const _tagHeight = 24.0;
  static const _tagPad = 9.0;
  static const _markLeft = 4.0;
  static const _markRight = 8.0;
  static const _markBottom = 3.0;
  static const _markHeight = 15.0;
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final right = holdOwnerRight[floor.owner]?.card ?? 6;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HoldColors.ownerCard,
        border: Border.all(
          color: AppColors.ink,
          width: HoldStageBrief._ownerCardEdge,
        ),
        borderRadius: BorderRadius.circular(HoldStageBrief._ownerCardCorner),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: -20,
            top: -100,
            width: 360,
            height: 390,
            child: GymBackground(floor: floor.number),
          ),
          Positioned(
            right: right,
            bottom: _ownerBottom,
            child: ExcludeSemantics(
              child: HoldOwner(ownerId: floor.owner, scale: 1.5, idle: true),
            ),
          ),
          Positioned(
            left: _inset,
            top: _inset,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform(
                  transform: AppHighlight.battleSlant,
                  alignment: Alignment.center,
                  child: Container(
                    height: _tagHeight,
                    padding: const EdgeInsets.symmetric(horizontal: _tagPad),
                    color: AppColors.ink,
                    alignment: Alignment.center,
                    child: Transform(
                      transform: Matrix4.skewX(12 * 3.141592653589793 / 180),
                      alignment: Alignment.center,
                      child: Text('COACH', style: text.holdCoachTag),
                    ),
                  ),
                ),
                const SizedBox(height: _gap),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -_markLeft,
                      right: -_markRight,
                      bottom: _markBottom,
                      height: _markHeight,
                      child: Transform(
                        transform: Matrix4.skewX(-14 * 3.141592653589793 / 180),
                        alignment: Alignment.center,
                        child: const ColoredBox(color: AppColors.accent),
                      ),
                    ),
                    Text(floor.ownerName, style: text.holdOwnerName),
                  ],
                ),
                const SizedBox(height: _gap),
                Text('${floor.number}F 체육관 관장', style: text.holdNote),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PoseCard extends StatelessWidget {
  const _PoseCard({required this.stage, required this.definition});

  final ArcadeHoldStage stage;
  final HoldPoseDefinition definition;

  static const _padTop = 14.0;
  static const _pad = EdgeInsets.symmetric(
    horizontal: AppSpacing.s16,
    vertical: _padTop,
  );
  static const _edge = 2.0;
  static const _gap = AppSpacing.s12;
  static const _iconSize = 30.0;
  static const _rowGap = 10.0;
  static const _labelGap = 2.0;
  static const _chipGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '이번 시험',
      child: Container(
        padding: _pad,
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.ink, width: _edge),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CustomPaint(
                  size: const Size.square(_iconSize),
                  painter: HoldPoseIconPainter(definition.silhouette),
                ),
                const SizedBox(width: _rowGap),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Transform(
                      transform: AppHighlight.slant,
                      alignment: Alignment.bottomLeft,
                      child: Text(stage.pose.label, style: text.holdPoseName),
                    ),
                  ),
                ),
                Text('최대 ${stage.starSeconds.last}초', style: text.holdMaxTime),
              ],
            ),
            const SizedBox(height: _gap),
            Row(
              children: [
                for (final (i, seconds) in stage.starSeconds.indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: _GoalTile(stars: i + 1, seconds: seconds),
                  ),
                ],
              ],
            ),
            const SizedBox(height: _gap),
            Wrap(
              spacing: _chipGap,
              runSpacing: _chipGap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: _labelGap),
                  child: Text('판정', style: text.holdChecksLabel),
                ),
                for (final check in definition.checks) _CheckChip(check),
              ],
            ),
            const SizedBox(height: _gap),
            const Divider(height: 1, thickness: 1, color: HoldColors.starOff),
            const SizedBox(height: _rowGap),
            Row(
              children: [
                const ExcludeSemantics(
                  child: Row(
                    children: [
                      HoldStrike(size: Size(22, 16), fill: AppColors.card),
                      SizedBox(width: AppSpacing.s4),
                      HoldStrike(size: Size(22, 16), fill: AppColors.card),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text('경고 2번이면 실패', style: text.holdNote),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.stars, required this.seconds});

  /// The star this time lights: 1 to 3.
  final int stars;
  final int seconds;

  static const _pad = EdgeInsets.symmetric(
    horizontal: AppSpacing.s4,
    vertical: AppSpacing.s8,
  );
  static const _edge = 1.5;
  static const _star = 15.0;
  static const _starGap = 1.0;
  static const _secondsGap = 3.0;

  @override
  Widget build(BuildContext context) => Container(
    padding: _pad,
    decoration: BoxDecoration(
      color: HoldColors.tile,
      border: Border.all(color: AppColors.border, width: _edge),
      borderRadius: BorderRadius.circular(AppRadius.small),
    ),
    child: Column(
      children: [
        ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 3; i++) ...[
                if (i > 1) const SizedBox(width: _starGap),
                HoldStar(size: _star, lit: i <= stars),
              ],
            ],
          ),
        ),
        const SizedBox(height: _secondsGap),
        Text(
          '$seconds초',
          style: Theme.of(context).textTheme.holdGoalSeconds,
          semanticsLabel: '별 $stars개 $seconds초',
        ),
      ],
    ),
  );
}

class _CheckChip extends StatelessWidget {
  const _CheckChip(this.label);

  final String label;

  static const _padSide = 9.0;
  static const _padTop = 2.0;
  static const _pad = EdgeInsets.symmetric(
    horizontal: _padSide,
    vertical: _padTop,
  );
  static const _edge = 1.5;
  static const _corner = 8.0;

  @override
  Widget build(BuildContext context) => Container(
    padding: _pad,
    decoration: BoxDecoration(
      color: AppColors.selectedFill,
      border: Border.all(color: AppColors.ink, width: _edge),
      borderRadius: BorderRadius.circular(_corner),
    ),
    child: Text(label, style: Theme.of(context).textTheme.holdCheck),
  );
}

/// The ink button with slanted white words and a lime arrow: 자세 잡기, and
/// the result's right button.
class HoldDarkButton extends StatelessWidget {
  const HoldDarkButton({
    super.key,
    required this.label,
    required this.style,
    required this.height,
    required this.arrowSize,
    required this.gap,
    required this.onPressed,
  });

  final String label;
  final TextStyle style;
  final double height;
  final double arrowSize;
  final double gap;
  final VoidCallback onPressed;

  static const _corner = 16.0;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: ExcludeSemantics(
      child: Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(_corner),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(_corner),
          child: SizedBox(
            height: height,
            child: Padding(
              // A margin for shrunk words and the arrow; within the room the
              // design leaves at its own size.
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The design's words where they fit; on a narrow button or
                  // with large text they shrink to fit instead of overflowing.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Transform(
                        transform: AppHighlight.slant,
                        alignment: Alignment.center,
                        child: Text(label, style: style, maxLines: 1),
                      ),
                    ),
                  ),
                  SizedBox(width: gap),
                  CustomPaint(
                    size: Size.square(arrowSize),
                    painter: const HoldArrowPainter.forward(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
