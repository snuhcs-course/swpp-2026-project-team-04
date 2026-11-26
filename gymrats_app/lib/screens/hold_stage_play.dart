import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/arcade_floor.dart';
import '../models/arcade_stage.dart';
import '../models/hold_progress.dart';
import '../models/hold_reading.dart';
import '../models/pose_frame.dart';
import '../models/setup_hint_short.dart';
import '../models/setup_silhouette_alignment.dart';
import '../services/pose/hold_judge.dart';
import '../services/pose/hold_pose_definition.dart';
import '../services/pose/setup_checker.dart';
import '../theme/app_theme.dart';
import '../viewmodels/hold_stage_viewmodel.dart';
import '../viewmodels/setup_viewmodel.dart';
import '../widgets/battle_arena.dart';
import '../widgets/battle_banner.dart';
import '../widgets/battle_camera_area.dart';
import '../widgets/battle_camera_view.dart';
import '../widgets/battle_fx_motion.dart';
import '../widgets/character_figure.dart';
import '../widgets/gym_background.dart';
import '../widgets/gym_owner_figure.dart';
import '../widgets/hold_me_figure.dart';
import '../widgets/hold_me_rig.dart';
import '../widgets/hold_me_scene.dart';
import 'hold_stage_art.dart';
import 'hold_stage_brief.dart';

/// The hold stage from the setup to the end of the hold (arcade hold spec
/// 2, 5; the design's `P16Hold scene=hold` and `warn`): the floor's gym
/// with its owner above, the battle's camera area below, as the battle lays
/// them out ([BattleArenaLayout]).
///
/// - Setting up: the battle's own setup look (the cue board over the
///   stage, the silhouette, the progress bar, the camera switch).
/// - 3·2·1 and GO!: the battle's countdown bands over the stage.
/// - From the countdown on: the stage tag, the clock ("버틴 시간", or
///   "멈춤" while paused), the warning marks, and the bar with its star
///   marks and the user's face at its end (amber while paused).
/// - Holding: a green frame in the camera box; paused, a red one, the
///   warning's big words and icon, and the owner blowing the whistle.
/// - The user's character beside the owner, holding the pose along (A8):
///   it breathes, hops at a star while the star flies to its bar mark,
///   sags or rises on a warning, and strains toward the last star.
/// - The owner's bubbles (the hold effects spec 3 to 5), all above the
///   owner's side (A8 spec 6): the pose's start words after GO in the
///   whistle's white bubble; at the first and second star a big lime cheer
///   from 0.8 s to 2.4 s, with a smile from 0.7 s and the bar star lighting
///   and popping as the flying star lands at 0.9 s; at a second warning
///   with no star a big red "실패!" over the whistle, with the warning kept
///   in the camera box until the result.
class HoldStagePlay extends StatelessWidget {
  const HoldStagePlay({
    super.key,
    required this.stage,
    required this.floor,
    required this.definition,
    required this.state,
    required this.setup,
    required this.frame,
    required this.myCharacter,
    required this.goAge,
    required this.onLeave,
    required this.onGuideCrop,
    required this.onCameraBox,
  });

  final ArcadeHoldStage stage;
  final ArcadeFloor floor;
  final HoldPoseDefinition definition;
  final HoldStageState state;

  /// The camera and the setup.
  final SetupViewModel? setup;

  /// The frame the hold read last, for the guide lines.
  final PoseFrame? frame;

  /// The user's character, whose face rides the bar.
  final String myCharacter;

  /// Milliseconds since GO, for its band; null before GO.
  final double? goAge;

  /// The leave button's action. Null hides the button, as a battle does
  /// once it has ended: from a second warning on, the result comes next.
  final VoidCallback? onLeave;
  final ValueChanged<SetupCameraCrop> onGuideCrop;

  /// The camera box's size, for the setup's check.
  final ValueChanged<Size> onCameraBox;

  @override
  Widget build(BuildContext context) {
    final statusBar = MediaQuery.paddingOf(context).top;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final layout = BattleArenaLayout(size, statusBar: statusBar);
        final scale = layout.scale;
        final line = layout.line;
        final origin = layout.origin;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onCameraBox(
            Size(size.width, size.height - line - BattleCameraArea.lineWidth),
          );
        });
        return Stack(
          children: [
            Positioned(
              left: origin.dx,
              top: origin.dy,
              width: layout.stage.width,
              height: layout.stage.height,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: BattleFx.stageWidth,
                  height: BattleFx.stageHeight,
                  child: MediaQuery.withNoTextScaling(
                    child: _Stage(
                      stage: stage,
                      floor: floor,
                      state: state,
                      myCharacter: myCharacter,
                      goAge: goAge,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: line,
              bottom: 0,
              child: _CameraBox(
                definition: definition,
                state: state,
                setup: setup,
                frame: frame,
                boardOffset:
                    layout.boardOrigin -
                    Offset(0, line + BattleCameraArea.lineWidth),
                scale: scale,
                onLeave: onLeave,
                onGuideCrop: onGuideCrop,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// "0:22".
String holdClock(Duration held) {
  final seconds = held.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// The stage, in its 360 x 390 design points, drawn bottom to top (A8 spec
/// 3): the gym, the user's character, the owner, the HUD and the bar, a
/// star flying to the bar, the owner's bubbles, the 3·2·1 and GO! bands.
///
/// It keeps its own clock (a ticker, which reduced motion does not slow)
/// and a [HoldMeTimeline] that it feeds the play at each change: the
/// character's moments, the bar stars' lighting, the cheer bubble and the
/// owner's smile are timed from the star, the warning or the time running
/// again on that clock (A8 spec 4 to 7).
class _Stage extends StatefulWidget {
  const _Stage({
    required this.stage,
    required this.floor,
    required this.state,
    required this.myCharacter,
    required this.goAge,
  });

  final ArcadeHoldStage stage;
  final ArcadeFloor floor;
  final HoldStageState state;
  final String myCharacter;
  final double? goAge;

  /// Every bubble of the owner's ends at the owner's [holdBigBubbleRight]
  /// with its top here (A8 spec 6).
  static const _bubbleTop = 148.0;
  static const _ownerBottom = 34.0;

  /// The bar: its sides and top on the stage.
  static const _barSide = 22.0;
  static const _barTop = 102.0;

  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> with SingleTickerProviderStateMixin {
  late final _ticker = createTicker(
    (elapsed) => _now.value = elapsed.inMicroseconds / 1000,
  );

  /// Milliseconds on the stage's clock.
  final _now = ValueNotifier<double>(0);

  late HoldMeTimeline _timeline;

  @override
  void initState() {
    super.initState();
    _timeline = HoldMeTimeline(widget.stage.starSeconds);
    _look();
    _ticker.start();
  }

  @override
  void didUpdateWidget(_Stage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage != widget.stage) {
      _timeline = HoldMeTimeline(widget.stage.starSeconds);
    }
    _look();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _now.dispose();
    super.dispose();
  }

  /// Tells the timeline the play as it is now.
  void _look() {
    final state = widget.state;
    final holding = state.phase == HoldStagePhase.hold;
    _timeline.look(
      _now.value,
      counting: state.phase == HoldStagePhase.countdown,
      entering: holding && state.progress.state == HoldState.entering,
      stopped: holding && state.stopped,
      held: state.progress.held,
      ended: state.progress.ended,
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: _now,
    builder: (context, now, _) => _build(context, now),
  );

  Widget _build(BuildContext context, double now) {
    final stage = widget.stage;
    final floor = widget.floor;
    final state = widget.state;
    final progress = state.progress;
    final warned = state.phase == HoldStagePhase.hold && state.stopped;
    final callout = state.phase == HoldStagePhase.hold ? state.callout : null;
    final showHud = state.phase != HoldStagePhase.setup;
    final right = holdOwnerRight[floor.owner]?.stage ?? 8;
    final bubbleRight =
        holdBigBubbleRight[floor.owner] ?? holdBigBubbleRight['seal']!;
    final still = MediaQuery.disableAnimationsOf(context);
    final rig = HoldMeRig.standard;
    final place = rig.placeOf(widget.myCharacter, stage.pose);
    final top = place.topOn(rig);
    // The cheer's time comes from its star: the bubble and the smile show
    // in their part of it (A8 spec 6, 7).
    final cheerAge = callout?.kind == HoldCalloutKind.cheer
        ? _timeline.starAge(callout!.star, now)
        : null;
    final cheering =
        callout?.kind == HoldCalloutKind.cheer &&
        HoldMeCheer.bubbleAt(cheerAge, still: still);
    final smiling =
        callout?.kind == HoldCalloutKind.cheer &&
        HoldMeCheer.smileAt(cheerAge, still: still);
    final starAges = [
      for (var n = 1; n <= stage.starSeconds.length; n++)
        _timeline.starAge(n, now),
    ];
    final ends = stage.endsAt.inMilliseconds;
    const barWidth = BattleFx.stageWidth - 2 * _Stage._barSide;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: ExcludeSemantics(child: GymBackground(floor: floor.number)),
        ),
        if (showHud)
          Positioned(
            left: place.left,
            top: top,
            child: RepaintBoundary(
              child: HoldMeFigure(
                key: const ValueKey('hold-me'),
                frame: HoldMeScene.frameAt(
                  place,
                  _timeline.momentAt(now),
                  liveMs: now,
                  still: still,
                ),
              ),
            ),
          ),
        Positioned(
          right: right,
          bottom: _Stage._ownerBottom,
          child: ExcludeSemantics(
            child: HoldOwner(
              key: const ValueKey('hold-owner'),
              ownerId: floor.owner,
              scale: 1.2,
              face: warned
                  ? GymOwnerFace.blow
                  : smiling
                  ? GymOwnerFace.ok
                  : GymOwnerFace.watch,
              idle: true,
            ),
          ),
        ),
        if (showHud) ...[
          Positioned(
            left: 14,
            right: 14,
            top: 26,
            child: _Hud(stage: stage, progress: progress, stopped: warned),
          ),
          Positioned(
            left: _Stage._barSide,
            right: _Stage._barSide,
            top: _Stage._barTop,
            height: 52,
            child: _Bar(
              stage: stage,
              progress: progress,
              stopped: warned,
              myCharacter: widget.myCharacter,
              // A bar star lights when the star flying to it lands.
              lit: [
                for (final (i, seconds) in stage.starSeconds.indexed)
                  progress.held >= Duration(seconds: seconds) &&
                      HoldMeCheer.litAt(starAges[i], still: still),
              ],
              popStar: [
                for (final (i, age) in starAges.indexed)
                  if (HoldMeCheer.popAt(age, still: still)) i + 1,
              ].lastOrNull,
              animate: !still,
            ),
          ),
          for (final (i, age) in starAges.indexed)
            if (age != null)
              if (HoldMeScene.flightAt(
                    place,
                    top,
                    age,
                    Offset(
                      _Stage._barSide +
                          barWidth * stage.starSeconds[i] * 1000 / ends,
                      _Stage._barTop + _Bar._starTop + _Bar._star / 2,
                    ),
                    still: still,
                  )
                  case final flight?)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        key: ValueKey('hold-flying-star-$i'),
                        painter: HoldMeFlightPainter(flight),
                      ),
                    ),
                  ),
                ),
        ],
        // "실패!" takes the whistle's place; a start bubble gives way to it.
        if (warned && callout?.kind != HoldCalloutKind.fail)
          Positioned(
            right: bubbleRight,
            top: _Stage._bubbleTop,
            child: _Whistle(right: bubbleRight, animate: !still),
          ),
        if (!warned && callout?.kind == HoldCalloutKind.start)
          Positioned(
            right: bubbleRight,
            top: _Stage._bubbleTop,
            child: _StartBubble(
              lines: callout!.lines,
              right: bubbleRight,
              animate: !still,
            ),
          ),
        if (callout?.kind == HoldCalloutKind.fail || cheering)
          Positioned(
            right: bubbleRight,
            top: _Stage._bubbleTop,
            child: callout!.kind == HoldCalloutKind.fail
                ? HoldBigBubble.fail(
                    words: callout.words,
                    right: bubbleRight,
                    animate: !still,
                  )
                : HoldBigBubble.cheer(
                    words: callout.words,
                    right: bubbleRight,
                    animate: !still,
                  ),
          ),
        ..._bands(still),
      ],
    );
  }

  /// The battle's 3·2·1 and GO! (`battle_fx_motion.dart`), over the stage.
  List<Widget> _bands(bool reducedMotion) {
    final state = widget.state;
    final left = state.startIn;
    if (state.phase == HoldStagePhase.countdown && left != null) {
      final ms = left.inMilliseconds.toDouble().clamp(0.0, 3000.0);
      final number = math.max(1, (ms / 1000).ceil());
      final shown = number * 1000 - ms;
      final scale = reducedMotion
          ? 1.0
          : 1.5 - 0.5 * BattleFx.easeOut(shown / 160);
      return [
        BattleStageBanner(
          key: const ValueKey('hold-count'),
          banner: BattleFxBanner(
            text: '$number',
            top: 141,
            textSize: 160,
            tone: BattleFxTone.plain,
            opacity: 1,
            scaleX: scale,
            scaleY: scale,
          ),
        ),
      ];
    }
    final age = widget.goAge;
    final go = age == null ? null : BattleFx.pop(age, 700);
    if (go == null) return const [];
    return [
      BattleStageBanner(
        key: const ValueKey('hold-go'),
        banner: BattleFxBanner(
          text: 'GO!',
          top: 153,
          textSize: 130,
          tone: BattleFxTone.plain,
          opacity: go.opacity,
          rotation: -5,
          scaleX: go.scale,
          scaleY: go.scale,
        ),
      ),
    ];
  }
}

/// The stage tag, the clock and the warning marks along the top.
class _Hud extends StatelessWidget {
  const _Hud({
    required this.stage,
    required this.progress,
    required this.stopped,
  });

  final ArcadeHoldStage stage;
  final HoldProgress progress;

  /// Paused, or the second warning's moment: "멈춤".
  final bool stopped;

  static const _tagHeight = 24.0;
  static const _tagSide = 9.0;
  static const _tagPad = EdgeInsets.symmetric(horizontal: _tagSide);
  static const _strikesRaise = 2.0;
  static const _strikesTop = EdgeInsets.only(top: _strikesRaise);
  static const _strikeGap = 3.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final used = progress.warningCount;
    final paused = stopped;
    // Spread across the top with equal room between, as the design: the
    // clock sits in the middle of the room the tag and the marks leave,
    // and shrinks rather than overflow.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform(
          transform: AppHighlight.battleSlant,
          alignment: Alignment.center,
          // As wide as its words: a bare alignment would stretch it.
          child: Container(
            height: _tagHeight,
            padding: _tagPad,
            color: AppColors.ink,
            child: Center(
              widthFactor: 1,
              child: Transform(
                transform: Matrix4.skewX(12 * math.pi / 180),
                alignment: Alignment.center,
                child: Text(
                  HoldStageBrief.stageTag(stage),
                  style: text.holdStageTag,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(paused ? '멈춤' : '버틴 시간', style: text.holdClockLabel),
                Text(holdClock(progress.held), style: text.holdClock),
              ],
            ),
          ),
        ),
        Semantics(
          label: '경고 $used번, 2번이면 실패',
          image: true,
          child: ExcludeSemantics(
            child: Padding(
              padding: _strikesTop,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 1; i <= 2; i++) ...[
                    if (i > 1) const SizedBox(width: _strikeGap),
                    HoldStrike(
                      key: ValueKey('hold-strike-$i'),
                      size: const Size(24, 18),
                      fill: i <= used ? AppColors.danger : AppColors.card,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Where each character's face is in its 140 x 160 rig box, idle: the
/// design's centers for the face circle (`P16Hold` `FACE`).
const _faceCenters = <String, Offset>{
  'mouse': Offset(72, 55),
  'kangaroo': Offset(76, 50),
  'bear': Offset(72, 62),
  'penguin': Offset(70, 66),
  'seal': Offset(70, 66),
  'bot': Offset(78, 52),
};

/// The time held as a bar toward the third star, with the three star marks
/// and the user's face at its end.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.stage,
    required this.progress,
    required this.stopped,
    required this.myCharacter,
    required this.lit,
    required this.popStar,
    required this.animate,
  });

  final ArcadeHoldStage stage;
  final HoldProgress progress;

  /// Paused, or the second warning's moment: an amber fill.
  final bool stopped;
  final String myCharacter;

  /// Each star mark's light: on once the star flying to it lands (A8 spec
  /// 5), while the fill already passes it.
  final List<bool> lit;

  /// The star (1 or 2) that just lit: it pops, unless [animate] is off.
  final int? popStar;
  final bool animate;

  /// A star mark: its top over the bar and its size.
  static const _starTop = -6.0;
  static const _star = 22.0;

  static const _trackTop = 18.0;
  static const _trackHeight = 18.0;
  static const _edge = 2.5;
  static const _face = 30.0;
  static const _faceScale = 0.36;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ends = stage.endsAt.inMilliseconds;
    final share = (progress.held.inMilliseconds / ends).clamp(0.0, 1.0);
    final fill = stopped ? AppColors.warning : AppColors.accent;
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final x = width * share;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: _trackTop,
                height: _trackHeight,
                child: Container(
                  key: const ValueKey('hold-track'),
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.ink, width: _edge),
                    borderRadius: BorderRadius.circular(_trackHeight / 2),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      key: const ValueKey('hold-fill'),
                      widthFactor: share,
                      heightFactor: 1,
                      child: ColoredBox(color: fill),
                    ),
                  ),
                ),
              ),
              for (final (i, seconds) in stage.starSeconds.indexed) ...[
                Positioned(
                  left: width * seconds * 1000 / ends - 1,
                  top: 16,
                  width: 2.5,
                  height: 22,
                  child: const ColoredBox(color: AppColors.ink),
                ),
                Positioned(
                  left: width * seconds * 1000 / ends - _star / 2,
                  top: _starTop,
                  child: _StarPop(
                    popping: animate && popStar == i + 1,
                    index: i,
                    child: HoldStar(
                      key: ValueKey('hold-mark-star-$i'),
                      size: _star,
                      lit: lit[i],
                    ),
                  ),
                ),
                Positioned(
                  left: width * seconds * 1000 / ends - 20,
                  top: 40,
                  width: 40,
                  child: Text(
                    '$seconds초',
                    textAlign: TextAlign.center,
                    style: text.holdMarkSeconds,
                  ),
                ),
              ],
              Positioned(
                left: x - _face / 2,
                top: 12,
                child: _Face(characterId: myCharacter),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The user's face in a lime circle.
class _Face extends StatelessWidget {
  const _Face({required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context) {
    const inner = _Bar._face - 2 * _Bar._edge;
    final center =
        _faceCenters[characterId] ?? _faceCenters['mouse'] ?? Offset.zero;
    return Container(
      key: const ValueKey('hold-face'),
      width: _Bar._face,
      height: _Bar._face,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: _Bar._edge),
      ),
      child: ClipOval(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: inner / 2 - center.dx * _Bar._faceScale,
              top: inner / 2 - center.dy * _Bar._faceScale,
              child: CharacterFigure(
                characterId: characterId,
                scale: _Bar._faceScale,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The owner's "삐익!" bubble, popping in unless motion is reduced.
class _Whistle extends StatelessWidget {
  const _Whistle({required this.right, required this.animate});

  /// Where the bubble ends on the right of the stage.
  final double right;
  final bool animate;

  @override
  Widget build(BuildContext context) => _SmallBubble(
    boxKey: const ValueKey('hold-whistle'),
    right: right,
    animate: animate,
    child: Text('삐익!', style: Theme.of(context).textTheme.holdWhistle),
  );
}

/// The owner's start words after GO, a line each, in the whistle's bubble
/// (the hold effects spec 3; the design's `P16Hold scene=go guide=bubble`).
class _StartBubble extends StatelessWidget {
  const _StartBubble({
    required this.lines,
    required this.right,
    required this.animate,
  });

  final List<String> lines;

  /// Where the bubble ends on the right of the stage.
  final double right;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.holdStartBubble;
    return _SmallBubble(
      boxKey: const ValueKey('hold-start'),
      right: right,
      animate: animate,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Text(line, style: style, maxLines: 1, softWrap: false),
        ],
      ),
    );
  }
}

/// The whistle's white bubble with its tail toward the owner, popping in
/// unless motion is reduced. Its words shrink only where they would not fit
/// the stage left of its right end (A8 spec 6).
class _SmallBubble extends StatelessWidget {
  const _SmallBubble({
    required this.boxKey,
    required this.right,
    required this.animate,
    required this.child,
  });

  final Key boxKey;

  /// Where the bubble ends on the right of the 360-point stage.
  final double right;
  final bool animate;
  final Widget child;

  static const _padTop = 6.0;
  static const _padBottom = 8.0;
  static const _pad = EdgeInsets.fromLTRB(
    AppSpacing.s16,
    _padTop,
    AppSpacing.s16,
    _padBottom,
  );
  static const _edge = 2.5;
  static const _corner = 16.0;

  /// The room the bubble may take left of its right end, as the big one.
  static const _margin = AppSpacing.s8;

  @override
  Widget build(BuildContext context) {
    final bubble = Semantics(
      liveRegion: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: BattleFx.stageWidth - right - _margin,
            ),
            child: Container(
              key: boxKey,
              padding: _pad,
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.ink, width: _edge),
                borderRadius: BorderRadius.circular(_corner),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: child,
              ),
            ),
          ),
          const Positioned(
            right: -13,
            top: 18,
            child: CustomPaint(size: Size(13, 18), painter: _TailPainter()),
          ),
        ],
      ),
    );
    if (!animate) return bubble;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      builder: (context, t, child) => Transform.scale(
        scale: 0.5 + 0.5 * BattleFx.back(t),
        alignment: Alignment.centerRight,
        child: child,
      ),
      child: bubble,
    );
  }
}

/// Where each owner's big bubble ends on the right of the stage, so that its
/// tail reaches the owner's face (the design's `bubR`).
const holdBigBubbleRight = <String, double>{
  'seal': 140,
  'penguin': 142,
  'kangaroo': 140,
  'bear': 150,
};

/// The owner's big bubble (the hold effects spec 4 and 5; the design's
/// `P16Hold scene=star fx=big` and `scene=out out=say`): a lime cheer at
/// the first and second star, or a red "실패!" at a second warning with no
/// star. One widget, its color and words told apart. The cheer pops in as
/// the whistle does; "실패!" comes in big and settles in
/// [HoldTiming.failPop]. No motion when [animate] is off.
class HoldBigBubble extends StatelessWidget {
  const HoldBigBubble.cheer({
    super.key,
    required this.words,
    required this.right,
    this.animate = true,
  }) : color = AppColors.accent,
       textColor = AppColors.ink,
       failing = false;

  const HoldBigBubble.fail({
    super.key,
    required this.words,
    required this.right,
    this.animate = true,
  }) : color = AppColors.danger,
       textColor = AppColors.onInk,
       failing = true;

  final String words;

  /// Where the bubble ends on the right of the 360-point stage.
  final double right;
  final Color color;
  final Color textColor;
  final bool failing;
  final bool animate;

  /// A8 spec 6: 5, 22 and 7 (were 8, 24 and 12).
  static const _padTop = 5.0;
  static const _padSide = 22.0;
  static const _padBottom = 7.0;
  static const _pad = EdgeInsets.fromLTRB(
    _padSide,
    _padTop,
    _padSide,
    _padBottom,
  );
  static const _edge = 3.0;
  static const _corner = 22.0;
  static const _tail = Size(24, 30);
  static const _tailBottom = 10.0;

  /// "실패!" starts this much bigger.
  static const _failFrom = 1.4;

  /// The room the bubble may take left of its right end.
  static const _margin = AppSpacing.s8;

  @override
  Widget build(BuildContext context) {
    final bubble = Semantics(
      liveRegion: true,
      label: words,
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: BattleFx.stageWidth - right - _margin,
              ),
              child: Container(
                key: ValueKey(failing ? 'hold-fail' : 'hold-cheer'),
                padding: _pad,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: AppColors.ink, width: _edge),
                  borderRadius: BorderRadius.circular(_corner),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    words,
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.holdBigBubble
                        .copyWith(color: textColor),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -_tail.width,
              bottom: _tailBottom,
              child: CustomPaint(size: _tail, painter: _BigTailPainter(color)),
            ),
          ],
        ),
      ),
    );
    if (!animate) return bubble;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: failing
          ? HoldTiming.failPop
          : const Duration(milliseconds: 220),
      builder: (context, t, child) => Transform.scale(
        scale: failing
            ? _failFrom - (_failFrom - 1) * BattleFx.easeOut(t)
            : 0.5 + 0.5 * BattleFx.back(t),
        alignment: Alignment.centerRight,
        child: child,
      ),
      child: bubble,
    );
  }
}

/// The big bubble's tail toward the owner: an ink triangle with one of the
/// bubble's color inside.
class _BigTailPainter extends CustomPainter {
  const _BigTailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(24, 15)
        ..lineTo(0, 30)
        ..close(),
      Paint()..color = AppColors.ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-1, 4)
        ..lineTo(17, 15)
        ..lineTo(-1, 26)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BigTailPainter oldDelegate) => oldDelegate.color != color;
}

/// A star mark that pops when it fills and is cheered: bigger with rays,
/// then back, over [HoldTiming.starPop] (the design's pop star, 22 to 34
/// points).
class _StarPop extends StatelessWidget {
  const _StarPop({
    required this.popping,
    required this.index,
    required this.child,
  });

  final bool popping;
  final int index;
  final Widget child;

  static const _grow = 34 / 22 - 1;
  static const _rays = 60.0;
  static const _star = 22.0;

  @override
  Widget build(BuildContext context) {
    if (!popping) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey('hold-star-pop-$index'),
      tween: Tween(begin: 0, end: 1),
      duration: HoldTiming.starPop,
      builder: (context, t, child) {
        final swell = math.sin(math.pi * t);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: (_star - _rays) / 2,
              top: (_star - _rays) / 2,
              child: Opacity(
                opacity: swell.clamp(0.0, 1.0),
                child: const CustomPaint(
                  size: Size.square(_rays),
                  painter: _RaysPainter(),
                ),
              ),
            ),
            Transform.scale(scale: 1 + _grow * swell, child: child),
          ],
        );
      },
      child: child,
    );
  }
}

/// The pop star's eight ink rays, in its 60 x 60 box.
class _RaysPainter extends CustomPainter {
  const _RaysPainter();

  static const _lines = [
    (Offset(30, 2), Offset(30, 9)),
    (Offset(30, 51), Offset(30, 58)),
    (Offset(2, 30), Offset(9, 30)),
    (Offset(51, 30), Offset(58, 30)),
    (Offset(10, 10), Offset(15, 15)),
    (Offset(45, 45), Offset(50, 50)),
    (Offset(50, 10), Offset(45, 15)),
    (Offset(15, 45), Offset(10, 50)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final (from, to) in _lines) {
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) => false;
}

/// The bubble's tail toward the owner: an ink triangle with a white one
/// inside.
class _TailPainter extends CustomPainter {
  const _TailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(13, 9)
        ..lineTo(0, 18)
        ..close(),
      Paint()..color = AppColors.ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-1, 3)
        ..lineTo(8, 9)
        ..lineTo(-1, 15)
        ..close(),
      Paint()..color = AppColors.card,
    );
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) => false;
}

/// The camera box: the battle's camera area, and over it while holding the
/// hold's frame and warning.
class _CameraBox extends StatelessWidget {
  const _CameraBox({
    required this.definition,
    required this.state,
    required this.setup,
    required this.frame,
    required this.boardOffset,
    required this.scale,
    required this.onLeave,
    required this.onGuideCrop,
  });

  final HoldPoseDefinition definition;
  final HoldStageState state;
  final SetupViewModel? setup;
  final PoseFrame? frame;
  final Offset boardOffset;
  final double scale;
  final VoidCallback? onLeave;
  final ValueChanged<SetupCameraCrop> onGuideCrop;

  static const _frame = 8.0;

  @override
  Widget build(BuildContext context) {
    final setup = this.setup;
    final setupState = setup?.state ?? const SetupState();
    final phase = state.phase;
    final settingUp = phase == HoldStagePhase.setup;
    final holding = phase == HoldStagePhase.hold;
    final running = setupState.phase == SetupPhase.running;
    final controller = setup?.cameraController;
    final progress = state.progress;
    final guide = !holding && running
        ? BattleCameraView.setupGuide(
            definition.setupExercise,
            ready:
                setupState.status.isReady &&
                setupState.guideAligned &&
                setupState.status.reason == SetupReason.ready,
          )
        : null;
    final Widget camera = holding && controller == null
        ? SizedBox.expand(
            child: CustomPaint(
              key: const ValueKey('hold-silhouette'),
              painter: HoldSilhouettePainter(definition.silhouette),
            ),
          )
        : BattleCameraView(
            controller: controller,
            frame: running ? frame ?? setupState.lastFrame : null,
            mirror: setup?.isFrontCamera ?? true,
            chestSnapshot: holding && definition.guide == HoldGuide.chestHeight
                ? state.guide
                : null,
            squatSnapshot: holding && definition.guide == HoldGuide.squatHeight
                ? state.guide
                : null,
            guide: guide?.widget,
            guideFit: guide?.fit ?? BoxFit.cover,
            onGuideCrop: guide != null ? onGuideCrop : null,
          );
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        BattleCameraArea(
          camera: _failed(setupState) ?? camera,
          onLeave: onLeave,
          setupCue: settingUp && running ? _cue(setupState) : null,
          settingUp: settingUp,
          setupLook: settingUp ? 1 : 0,
          setupProgress: settingUp && running
              ? (setupState.guideAligned ? setupState.status.readyProgress : 0)
              : null,
          onSwitchCamera: settingUp && running && setup!.canSwitchCamera
              ? () => setup.switchCamera()
              : null,
          boardOffset: boardOffset,
          boardScale: scale,
          stageScale: scale,
        ),
        // Through a second warning's moment too, its warning kept.
        if (holding && (!progress.ended || state.ending))
          Positioned.fill(
            top: BattleCameraArea.lineWidth,
            child: IgnorePointer(
              child: _HoldOverlay(
                fault: state.shownFault,
                frameColor: state.stopped
                    ? AppColors.danger
                    : AppColors.statusGood,
              ),
            ),
          ),
      ],
    );
  }

  /// The setup's short cue (A9), as the battle gives it.
  SetupHintShort _cue(SetupState setupState) => SetupHintShort.of(
    setupState.status,
    outsideSilhouette:
        setupState.status.reason == SetupReason.ready &&
        !setupState.guideAligned,
  );

  /// Why the camera stopped, with the way back, as the setup gives it.
  Widget? _failed(SetupState setupState) {
    final setup = this.setup;
    if (setup == null) return null;
    final (
      String title,
      String action,
      VoidCallback onPressed,
    ) = switch (setupState.phase) {
      SetupPhase.permissionDenied when setupState.permanentlyDenied => (
        '카메라 권한이 꺼져 있어요',
        '설정 열기',
        () => setup.openSettings(),
      ),
      SetupPhase.permissionDenied => (
        '카메라 권한이 필요해요',
        '다시 시도',
        () => setup.retry(),
      ),
      SetupPhase.cameraError => ('카메라를 켜지 못했어요', '다시 시도', () => setup.retry()),
      SetupPhase.detectorError => ('자세 인식이 멈췄어요', '다시 시도', () => setup.retry()),
      _ => ('', '', () {}),
    };
    if (title.isEmpty) return null;
    return _CameraFailed(title: title, action: action, onPressed: onPressed);
  }
}

class _CameraFailed extends StatelessWidget {
  const _CameraFailed({
    required this.title,
    required this.action,
    required this.onPressed,
  });

  final String title;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.s16),
          FilledButton(onPressed: onPressed, child: Text(action)),
        ],
      ),
    );
  }
}

/// While holding: the green frame, or the red one with the warning's words
/// and icon (spec 4, 5).
class _HoldOverlay extends StatelessWidget {
  const _HoldOverlay({required this.fault, required this.frameColor});

  final HoldFault? fault;
  final Color frameColor;

  static const _side = AppSpacing.s16;
  static const _top = 112.0;
  static const _padSide = 14.0;
  static const _pad = EdgeInsets.symmetric(
    horizontal: _padSide,
    vertical: AppSpacing.s12,
  );
  static const _edge = 3.0;
  static const _corner = 22.0;
  static const _gap = 14.0;
  static const _iconBox = 68.0;
  static const _iconCorner = 18.0;

  @override
  Widget build(BuildContext context) {
    final fault = this.fault;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            key: const ValueKey('hold-frame'),
            decoration: BoxDecoration(
              border: Border.all(color: frameColor, width: _CameraBox._frame),
            ),
          ),
        ),
        if (fault != null)
          Positioned(
            left: _side,
            right: _side,
            top: _top,
            child: Semantics(
              liveRegion: true,
              label: fault.words,
              child: ExcludeSemantics(
                child: Container(
                  key: const ValueKey('hold-cue'),
                  padding: _pad,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.ink, width: _edge),
                    borderRadius: BorderRadius.circular(_corner),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: _iconBox,
                        height: _iconBox,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          border: Border.all(
                            color: AppColors.ink,
                            width: _edge,
                          ),
                          borderRadius: BorderRadius.circular(_iconCorner),
                        ),
                        child: HoldWarningIcon(fault.icon),
                      ),
                      const SizedBox(width: _gap),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${fault.cue.$1}\n${fault.cue.$2}',
                            maxLines: 2,
                            softWrap: false,
                            textScaler: TextScaler.noScaling,
                            style: Theme.of(context).textTheme.holdCue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
