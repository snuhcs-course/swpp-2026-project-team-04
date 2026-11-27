import 'package:flutter/material.dart';

import '../models/arcade_catalog.dart';
import '../models/arcade_progress.dart';
import '../models/arcade_stage.dart';
import '../theme/app_theme.dart';
import '../viewmodels/arcade_viewmodel.dart';
import 'arcade_map.dart';
import 'arcade_parts.dart';
import 'lobby_parts.dart';
import 'tutorial_draft.dart';
import 'tutorial_game_shot.dart';
import 'tutorial_setup_scenes.dart';

/// The page about the game (A12 design `TutX` g0, 316 x 326): two
/// screenshots side by side, an online battle playing (`TutShotOnline`)
/// and the arcade map (`ArcMap`), each over its name.
class TutorialWelcome extends StatelessWidget {
  const TutorialWelcome({super.key});

  static const size = Size(316, 326);

  /// What a screen reader hears (the design's `aria-label`).
  static const label = '온라인 대결 게임 중 화면과 아케이드 지도 화면 스크린샷';

  /// The two screenshots' places, their width, and where their names sit.
  static const _onlineLeft = 22.0;
  static const _arcadeLeft = 164.0;
  static const _shotTop = 12.0;
  static const _nameTop = 290.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: TutorialGridPainter(background: AppColors.cardHigh),
            ),
          ),
          const Positioned(
            left: _onlineLeft,
            top: _shotTop,
            child: TutorialScreenshot(child: TutorialOnlineClip()),
          ),
          const Positioned(
            left: _arcadeLeft,
            top: _shotTop,
            child: TutorialScreenshot(child: TutorialArcadeShot()),
          ),
          for (final (left, name, color) in const [
            (_onlineLeft, '온라인 대결', AppColors.accent),
            (_arcadeLeft, '아케이드', AppColors.opponent),
          ])
            Positioned(
              left: left,
              width: TutorialScreenshot.width,
              top: _nameTop,
              child: Center(child: _ShotName(name, color: color)),
            ),
        ],
      ),
    );
  }
}

/// A phone screenshot in small (`TutShot`, 130 wide): a 360 x 780 screen
/// shrunk inside a 2 ink edge with 12 corners and a drop shadow.
class TutorialScreenshot extends StatelessWidget {
  const TutorialScreenshot({super.key, required this.child});

  /// The 360 x 780 screen.
  final Widget child;

  static const width = 130.0;
  static const _edge = 2.0;
  static const _corner = 12.0;
  static const _screen = Size(360, 780);

  static double get scale => (width - 2 * _edge) / _screen.width;
  static double get height =>
      (_screen.height * scale + 2 * _edge).roundToDouble();

  @override
  Widget build(BuildContext context) {
    const corner = BorderRadius.all(Radius.circular(_corner));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: corner,
        boxShadow: [TutorialShadow.drop],
      ),
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: corner,
        ),
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: AppColors.ink, width: _edge),
          borderRadius: corner,
        ),
        // The screen starts inside the edge, as the design's box.
        padding: const EdgeInsets.all(_edge),
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(size: _screen, child: child),
          ),
        ),
      ),
    );
  }
}

/// A screenshot's name under it: Do Hyeon on [color] in an ink-edged tag.
class _ShotName extends StatelessWidget {
  const _ShotName(this.name, {required this.color});

  final String name;
  final Color color;

  static const _height = 28.0;
  static const _side = 12.0;
  static const _edge = 2.5;
  static const _corner = 10.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: _side),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppColors.ink, width: _edge),
        borderRadius: const BorderRadius.all(Radius.circular(_corner)),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          name,
          maxLines: 1,
          style: Theme.of(context).textTheme.goalMissionSticker
              .copyWith(color: AppColors.ink),
        ),
      ),
    );
  }
}

/// The online battle playing over and over (`TutShotOnline`, a 3 s loop,
/// the scores starting over every third): GYM마우스's push-up reaching the
/// bottom, its shoulder line turning green, the camera's frame green, the
/// blow landing with GOOD alone. Held at its still
/// ([TutorialGameScene.welcomeStillMs]) when the device asks for reduced
/// motion.
class TutorialOnlineClip extends StatefulWidget {
  const TutorialOnlineClip({super.key});

  /// Three loops of 3 s, as the scores start over every third.
  static const length = Duration(milliseconds: 9000);

  @override
  State<TutorialOnlineClip> createState() => _TutorialOnlineClipState();
}

class _TutorialOnlineClipState extends State<TutorialOnlineClip>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: TutorialOnlineClip.length,
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// Where in the clip it is now, in milliseconds.
  double get _ms => _still
      ? TutorialGameScene.welcomeStillMs
      : _clock.value * TutorialOnlineClip.length.inMilliseconds;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) => TutorialGameShot(
        scene: TutorialGameScene.online(_ms),
        characters: TutorialGameScene.welcomeCharacters,
      ),
    );
  }
}

/// The arcade's map screen at stage 8 (`ArcMap` cur, 8): its header with
/// the stars, the app's own [ArcadeMap] at the second floor, and the bar
/// with stage 8 and 도전. The header and the bar are drawn here as the
/// arcade screen draws them (user 2026-11-28: the same tokens, the arcade
/// screen's file untouched). Nothing moves or takes a tap.
class TutorialArcadeShot extends StatefulWidget {
  const TutorialArcadeShot({super.key});

  /// The design's sample: stages 1 to 7 cleared with these stars, 8 next.
  static final progress = ArcadeProgress([
    3, 2, 3, 3, 3, 2, 1, //
    for (var i = 7; i < ArcadeProgress.stageCount; i++) 0,
  ]);

  /// Where the map is seen from (the design's `view.off`).
  static const mapTop = 1076.0;

  /// The character on the map: the welcome clip's.
  static const character = 'mouse';

  @override
  State<TutorialArcadeShot> createState() => _TutorialArcadeShotState();
}

class _TutorialArcadeShotState extends State<TutorialArcadeShot> {
  /// Held at [TutorialArcadeShot.mapTop]: the map shows a floor's name tag
  /// only while that floor's band is out of view, as the arcade screen does.
  final _scroll = ScrollController(
    initialScrollOffset: TutorialArcadeShot.mapTop,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = TutorialArcadeShot.progress;
    final stage = ArcadeCatalog.stage(progress.currentStage!);
    return IgnorePointer(
      // The character on the map holds still, as in the design.
      child: TickerMode(
        enabled: false,
        child: ColoredBox(
          color: AppColors.background,
          child: Column(
            children: [
              _ArcadeHeader(stars: progress.totalStars),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  physics: const NeverScrollableScrollPhysics(),
                  child: ArcadeMap(
                    progress: progress,
                    myCharacter: TutorialArcadeShot.character,
                    onStage: _none,
                    width: ArcadeMapLayout.width,
                    scroll: _scroll,
                  ),
                ),
              ),
              _ArcadeBar(stage: stage),
            ],
          ),
        ),
      ),
    );
  }

  static void _none(ArcadeStage stage) {}
}

/// The arcade map's header, as the arcade screen draws it: back, "PLAY /
/// ARCADE" over "아케이드", and the stars out of all.
class _ArcadeHeader extends StatelessWidget {
  const _ArcadeHeader({required this.stars});

  final int stars;

  static const _side = AppSpacing.s16;
  static const _below = 26.0;
  static const _edge = 2.0;
  static const _titleGap = 2.0;

  /// The room over the header that the arcade screen leaves for the status
  /// bar, as the design draws it (`ArcMap`, 28).
  static const _statusRoom = 28.0;
  static const _pillTop = AppSpacing.s8;
  static const _pillHeight = 30.0;
  static const _pillSide = 10.0;
  static const _pillCorners = 10.0;
  static const _pillGap = 5.0;
  static const _star = 17.0;
  static const _titleLean = 8.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(_side, _statusRoom, _side, _below),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.ink, width: _edge),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LobbySquareButton(
            icon: Icons.chevron_left_rounded,
            tooltip: '게임 시작으로',
            onPressed: _none,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PLAY / ARCADE', style: text.arcadeTag),
                const SizedBox(height: _titleGap),
                LobbySkew(
                  degrees: _titleLean,
                  child: Text('아케이드', style: text.arcadeTitle),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: _pillTop),
            child: Container(
              height: _pillHeight,
              padding: const EdgeInsets.symmetric(horizontal: _pillSide),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(_pillCorners),
                border: Border.all(color: AppColors.ink, width: _edge),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ArcadeGlyphIcon(ArcadeGlyph.star, size: _star),
                  const SizedBox(width: _pillGap),
                  Text('$stars', style: text.arcadeStarSum),
                  const SizedBox(width: _pillGap),
                  Text(
                    '/ ${ArcadeProgress.maxStars}',
                    style: text.arcadeStarMax,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _none() {}
}

/// The bar under the map, as the arcade screen draws it: the stage's face,
/// "STAGE 8 · 2F", its title, and 도전.
class _ArcadeBar extends StatelessWidget {
  const _ArcadeBar({required this.stage});

  final ArcadeStage stage;

  static const _edge = 2.0;
  static const _top = 14.0;
  static const _side = AppSpacing.s16;
  static const _bottom = 22.0;
  static const _face = 50.0;
  static const _faceEdge = 2.5;
  static const _faceScale = 0.6;
  static const _buttonHeight = 52.0;
  static const _buttonGap = 6.0;
  static const _titleGap = 1.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(_side, _top, _side, _bottom),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(
          top: BorderSide(color: AppColors.ink, width: _edge),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: _face,
            height: _face,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: _faceEdge),
            ),
            child: ClipOval(
              child: ArcadeFace(
                id: stage.character,
                size: _face - 2 * _faceEdge,
                scale: _faceScale,
                owner: stage.kind == ArcadeStageKind.hold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ArcadeWords.stageTag(stage), style: text.arcadeBarTag),
                const SizedBox(height: _titleGap),
                Text(
                  ArcadeWords.title(stage),
                  style: text.arcadeBarTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          ArcadeDarkButton(
            label: '도전',
            onPressed: _none,
            height: _buttonHeight,
            gap: _buttonGap,
            padding: AppSpacing.s16,
          ),
        ],
      ),
    );
  }

  static void _none() {}
}
