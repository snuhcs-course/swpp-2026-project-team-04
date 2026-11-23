import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/arcade_floor.dart';
import '../models/arcade_stage.dart';
import '../models/hold_progress.dart';
import '../models/hold_reading.dart';
import '../models/pose_frame.dart';
import '../models/setup_hint_short.dart';
import '../models/setup_silhouette_alignment.dart';
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

  final VoidCallback onLeave;
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

/// The stage, in its 360 x 390 design points.
class _Stage extends StatelessWidget {
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

  static const _bubbleLeft = 30.0;
  static const _bubbleTop = 196.0;
  static const _ownerBottom = 34.0;

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    final warned = state.phase == HoldStagePhase.hold && progress.paused;
    final showHud = state.phase != HoldStagePhase.setup;
    final right = holdOwnerRight[floor.owner]?.stage ?? 8;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: ExcludeSemantics(child: GymBackground(floor: floor.number)),
        ),
        Positioned(
          right: right,
          bottom: _ownerBottom,
          child: ExcludeSemantics(
            child: HoldOwner(
              key: const ValueKey('hold-owner'),
              ownerId: floor.owner,
              scale: 1.2,
              face: warned ? GymOwnerFace.blow : GymOwnerFace.watch,
              idle: true,
            ),
          ),
        ),
        if (showHud) ...[
          Positioned(
            left: 14,
            right: 14,
            top: 26,
            child: _Hud(stage: stage, progress: progress),
          ),
          Positioned(
            left: 22,
            right: 22,
            top: 102,
            height: 52,
            child: _Bar(
              stage: stage,
              progress: progress,
              myCharacter: myCharacter,
            ),
          ),
        ],
        if (warned)
          Positioned(
            left: _bubbleLeft,
            top: _bubbleTop,
            child: _Whistle(animate: !reducedMotion),
          ),
        ..._bands(reducedMotion),
      ],
    );
  }

  /// The battle's 3·2·1 and GO! (`battle_fx_motion.dart`), over the stage.
  List<Widget> _bands(bool reducedMotion) {
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
    final age = goAge;
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
  const _Hud({required this.stage, required this.progress});

  final ArcadeHoldStage stage;
  final HoldProgress progress;

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
    final paused = progress.paused;
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
    required this.myCharacter,
  });

  final ArcadeHoldStage stage;
  final HoldProgress progress;
  final String myCharacter;

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
    final fill = progress.paused ? AppColors.warning : AppColors.accent;
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
                  left: width * seconds * 1000 / ends - 11,
                  top: -6,
                  child: HoldStar(
                    key: ValueKey('hold-mark-star-$i'),
                    size: 22,
                    lit: progress.held >= Duration(seconds: seconds),
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
  const _Whistle({required this.animate});

  final bool animate;

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

  @override
  Widget build(BuildContext context) {
    final bubble = Semantics(
      liveRegion: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            key: const ValueKey('hold-whistle'),
            padding: _pad,
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.ink, width: _edge),
              borderRadius: BorderRadius.circular(_corner),
            ),
            child: Text('삐익!', style: Theme.of(context).textTheme.holdWhistle),
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
  final VoidCallback onLeave;
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
        if (holding && !progress.ended)
          Positioned.fill(
            top: BattleCameraArea.lineWidth,
            child: IgnorePointer(
              child: _HoldOverlay(
                fault: progress.paused ? progress.fault : null,
                frameColor: progress.paused
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
