import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/game_score.dart';
import '../models/pose_frame.dart';
import '../models/rep_event.dart';
import '../models/tutorial_page.dart';
import '../services/pose/rep_judge.dart';
import '../theme/app_theme.dart';
import 'battle_banner.dart';
import 'battle_camera_area.dart';
import 'battle_fx_motion.dart';
import 'battle_reject_sign.dart';
import 'battle_stage.dart';
import 'battle_stage_model.dart';
import 'character_figure.dart';
import 'chest_height_overlay.dart';
import 'squat_height_overlay.dart';
import 'tutorial_figure_painters.dart';
import 'tutorial_person.dart';

/// One moment of a battle as the tutorial shows it (A12 design `TutGame`,
/// its table `T`, and the welcome clip `TutShotOnline`): the standing, the
/// blow landing, the bands, and what the user's camera sees.
class TutorialGameScene {
  const TutorialGameScene({
    required this.squat,
    required this.myScore,
    required this.opponentScore,
    required this.myReps,
    required this.opponentReps,
    required this.secondsLeft,
    required this.camera,
    this.grade,
    this.points,
    this.hit = 0,
    this.attacking,
    this.fever = false,
    this.knockout = false,
    this.frame,
    this.bottom = false,
    this.combo,
    this.sign,
    this.myLunge = 0,
    this.opponentKnock = 0,
    this.starOpacity = 1,
    this.starScale,
    this.bandOpacity = 1,
    this.bandScale = 1,
    this.bandNarrow = 1,
    this.myScoreBump = 1,
    this.myRepsBump = 1,
    this.bandTop = 150,
    this.starTop = 222,
    this.myName = '나',
    this.opponentName = '상대',
  });

  final bool squat;
  final int myScore;
  final int opponentScore;
  final int myReps;
  final int opponentReps;
  final int secondsLeft;

  /// The front-view person on the user's camera, with its line heights.
  final FrontFigure camera;

  /// The grade word band over the stage, and the points beside it (e.g.
  /// "+10", "+10 +5"); null for none.
  final GameGrade? grade;
  final String? points;

  /// How hard the user's blow lands: 0 none, 0.6 average, 1 good, 1.5
  /// excellent (the design's `hit`). From 1 the opponent is hit and the
  /// star shows.
  final double hit;

  /// Whether the user's character is attacking: from the blow on in the
  /// welcome clip, before the opponent is hit ([hit] from 80 ms); else
  /// whenever there is a blow.
  final bool? attacking;
  final bool fever;

  /// The user won by a knockout: the opponent lies down, K.O. over them.
  final bool knockout;

  /// The camera's status frame (green when the rep counted), or none.
  final BattleFxCameraFrame? frame;

  /// Whether the user is at the bottom of the rep: the shoulder or hip line
  /// is green.
  final bool bottom;

  /// "N HIT" over the camera; null for none.
  final int? combo;

  /// The reject sign across the line, for a rep that did not count fully.
  final BattleFxSign? sign;

  /// The welcome clip's motion: the user's lunge and the opponent's
  /// knockback, the star's and the band's pop, the numbers' bump.
  final double myLunge;
  final double opponentKnock;
  final double starOpacity;
  final double? starScale;
  final double bandOpacity;
  final double bandScale;

  /// How much narrower than tall the clip's band pops (the design's 0.8).
  final double bandNarrow;
  final double myScoreBump;
  final double myRepsBump;

  /// Where the grade row's top is, and the star box's top (the stills'
  /// `TutGame` 150 and 222; the clip's `TutShotOnline` 158 and 228).
  final double bandTop;
  final double starTop;

  /// The names over the scores: '나' and '상대' on the stills; the clip's
  /// players' nicknames.
  final String myName;
  final String opponentName;

  /// The two characters: GYM마우스 against 물렁범 for push-ups, 펭뚱이
  /// against 그루 for squats (A12 spec 1); the welcome clip pits GYM마우스
  /// against 펭뚱이.
  static BattleCharacters charactersOf(ExerciseType exercise) =>
      exercise == ExerciseType.squat
      ? const BattleCharacters(me: 'penguin', opponent: 'kangaroo')
      : const BattleCharacters(me: 'mouse', opponent: 'seal');
  static const welcomeCharacters = BattleCharacters(
    me: 'mouse',
    opponent: 'penguin',
  );

  /// The game screen of [step] for [exercise] (the design's `T`; the
  /// points from [battleRules]).
  static TutorialGameScene of(ExerciseType exercise, TutorialStep step) {
    final squat = exercise == ExerciseType.squat;
    // The squat has no average (the design shows its good instead).
    if (squat && step == TutorialStep.average) step = TutorialStep.good;
    final rules = battleRules;
    FrontFigure camera({bool deep = true}) => squat
        ? TutorialFront.squat(deep ? 1 : 0)
        : TutorialFront.push(deep ? 1 : 0);
    return switch (step) {
      TutorialStep.excellent => TutorialGameScene(
        squat: squat,
        myScore: 85,
        opponentScore: 45,
        myReps: 7,
        opponentReps: 4,
        secondsLeft: 16,
        grade: GameGrade.excellent,
        points: '+${rules.excellentPoints}',
        hit: 1.5,
        camera: camera(),
        frame: BattleFxCameraFrame.good,
        bottom: true,
      ),
      TutorialStep.average => TutorialGameScene(
        squat: squat,
        myScore: 65,
        opponentScore: 45,
        myReps: 6,
        opponentReps: 4,
        secondsLeft: 19,
        grade: GameGrade.average,
        points: '+${rules.averagePoints}',
        hit: 0.6,
        camera: TutorialFront.push(0.55),
        frame: BattleFxCameraFrame.average,
        sign: const BattleFxSign(
          reason: RejectReason.insufficientDepth,
          average: true,
          scale: 1,
          rotation: _signTurn,
          opacity: 1,
        ),
      ),
      TutorialStep.fail => TutorialGameScene(
        squat: squat,
        myScore: 60,
        opponentScore: 45,
        myReps: 5,
        opponentReps: 4,
        secondsLeft: 21,
        camera: squat
            ? TutorialFront.squat(0.45)
            : TutorialFront.push(1, knee: true),
        frame: BattleFxCameraFrame.rejected,
        sign: BattleFxSign(
          reason: squat ? RejectReason.shallowSquat : RejectReason.kneesDown,
          average: false,
          scale: 1,
          rotation: _signTurn,
          opacity: 1,
        ),
      ),
      TutorialStep.combo => TutorialGameScene(
        squat: squat,
        myScore: 85,
        opponentScore: 45,
        myReps: 7,
        opponentReps: 4,
        secondsLeft: 15,
        grade: GameGrade.good,
        points: '+${rules.goodPoints} +${rules.comboBonus}',
        hit: 1,
        camera: camera(),
        frame: BattleFxCameraFrame.good,
        bottom: true,
        combo: 2,
      ),
      TutorialStep.fever => TutorialGameScene(
        squat: squat,
        myScore: 190,
        opponentScore: 150,
        myReps: 14,
        opponentReps: 11,
        secondsLeft: 8,
        grade: GameGrade.excellent,
        points: '+${rules.excellentPoints * rules.feverMultiplier}',
        hit: 1.5,
        fever: true,
        camera: camera(),
        frame: BattleFxCameraFrame.good,
        bottom: true,
      ),
      TutorialStep.ko => TutorialGameScene(
        squat: squat,
        myScore: _koLoser + rules.koLead,
        opponentScore: _koLoser,
        myReps: 17,
        opponentReps: 11,
        secondsLeft: 12,
        knockout: true,
        camera: camera(deep: false),
      ),
      // The battle page, and good (the design's battle and good are one).
      _ => TutorialGameScene(
        squat: squat,
        myScore: 70,
        opponentScore: 45,
        myReps: 6,
        opponentReps: 4,
        secondsLeft: 18,
        grade: GameGrade.good,
        points: '+${rules.goodPoints}',
        hit: 1,
        camera: camera(),
        frame: BattleFxCameraFrame.good,
        bottom: true,
      ),
    };
  }

  /// The loser's score on the KO page; the winner's is the KO lead more.
  static const _koLoser = 145;

  /// The reject sign's turn, as on the battle screen's design.
  static const _signTurn = -3.0;

  /// The welcome clip [ms] in (`TutShotOnline`, a 3 s loop): GYM마우스's
  /// push-up goes down, reaches the bottom at 0.95 s (its shoulder line
  /// green, the camera's frame green, the blow landing with GOOD alone),
  /// and comes back up; every third loop the scores start over.
  static TutorialGameScene online(double ms) {
    const cycle = 3000.0, down0 = 250.0, down1 = 950.0, up0 = 1250.0;
    const up1 = 1950.0;
    final u = ((ms % cycle) + cycle) % cycle;
    final loop = (ms / cycle).floor() % 3;
    var k = 0.0;
    if (u >= down0 && u < down1) {
      k = TutorialSide.ease((u - down0) / (down1 - down0));
    } else if (u >= down1 && u < up0) {
      k = 1;
    } else if (u >= up0 && u < up1) {
      k = 1 - TutorialSide.ease((u - up0) / (up1 - up0));
    }
    final d = u - down1;
    final hit = d >= 0;
    final good = battleRules.goodPoints;
    final score = 60 + good * loop + (hit ? good : 0);
    final attack = hit && d < 420;
    final double lunge = attack
        ? (d < 80
              ? 26 * (1 - math.pow(1 - d / 80, 3)).toDouble()
              : 26 * math.max(0.0, 1 - (d - 80) / 340))
        : 0.0;
    final knock = attack && d >= 80
        ? 16 * math.sin(math.min(1.0, (d - 80) / 340) * math.pi)
        : 0.0;
    double pop(double x) => x < 0
        ? 0
        : (x < 1
              ? 1 +
                    1.70158 * math.pow(x - 1, 3).toDouble() +
                    0.70158 * math.pow(x - 1, 2).toDouble()
              : 1);
    final bandIn = hit ? math.min(1.0, d / 160) : 0.0;
    final bandOut = hit ? ((d - 900) / 200).clamp(0.0, 1.0) : 0.0;
    final camera = TutorialFront.push(k);
    return TutorialGameScene(
      squat: false,
      myScore: score,
      opponentScore: 45,
      myReps: 5 + loop + (hit ? 1 : 0),
      opponentReps: 4,
      secondsLeft: math.max(1, 24 - (ms / 1000).floor() % 9),
      grade: bandIn > 0 ? GameGrade.good : null,
      // GOOD alone on the clip's stage (`TutShotOnline`).
      points: null,
      hit: attack && d >= 80 ? 1 : 0,
      attacking: attack,
      camera: camera,
      frame: hit && d < 720 ? BattleFxCameraFrame.good : null,
      bottom: camera.lineY! >= 233,
      myLunge: lunge,
      opponentKnock: knock,
      starOpacity: hit && d >= 80 && d < 420
          ? 1 - math.max(0.0, (d - 300) / 120)
          : 0,
      starScale: hit && d >= 80
          ? 0.5 + 0.4 * math.min(1.0, (d - 80) / 120)
          : 0.5,
      bandOpacity: bandIn * (1 - bandOut),
      bandScale: pop(bandIn),
      bandNarrow: _clipBandNarrow,
      bandTop: _clipBandTop,
      starTop: _clipStarTop,
      myName: 'hellohello',
      opponentName: 'squatking',
      myScoreBump: hit && d < 280 ? 1 + 0.2 * math.sin(math.pi * d / 280) : 1,
      myRepsBump: hit && d >= 80 && d < 340
          ? 1 + 0.3 * math.sin(math.pi * (d - 80) / 260)
          : 1,
    );
  }

  /// The clip's band and star tops (`TutShotOnline`).
  static const _clipBandTop = 158.0;
  static const _clipStarTop = 228.0;

  /// The clip's GOOD band, narrower than tall as it pops (`goodS`).
  static const _clipBandNarrow = 0.8;

  /// Where the welcome clip holds when the device asks for reduced motion:
  /// 0.2 s after the blow landed, GOOD at its full size and the star up, the
  /// frame and the shoulder line still green (the design's still, `t` 1150).
  static const welcomeStillMs = 1150.0;

  /// Whether the user's character attacks.
  bool get attacks => attacking ?? hit > 0;

  /// The user's lead, and the user's share of the health bar.
  int get lead => myScore - opponentScore;
  double get share => (0.5 + 0.5 * lead / battleRules.koLead).clamp(0.0, 1.0);
}

/// The battle screen stopped at one [scene] (A12 design `TutGame`, 360 x
/// 780): the app's own stage on top ([BattleStage] with its HUD, bar,
/// characters and star), the app's camera area below ([BattleCameraArea]
/// with its status frame, combo mark and leave button) over a drawn camera
/// picture with the game's own lines ([ChestHeightGuidePainter],
/// [SquatHeightPainter]), and the app's reject sign across the line
/// ([BattleRejectSignView]). Nothing in it takes a tap: the camera area's
/// leave button is held still.
class TutorialGameShot extends StatelessWidget {
  const TutorialGameShot({super.key, required this.scene, this.characters});

  final TutorialGameScene scene;

  /// Who fights; the exercise's pair unless given.
  final BattleCharacters? characters;

  static const size = Size(360, 780);

  /// The meeting point on a knockout: the loser still on the stage, lying
  /// down (the design's `xm` 220), while the bar is all the user's.
  static const _knockoutMeet = 220.0;

  /// The camera picture's box on the camera area (the design's 292 x 390 at
  /// 34 from the left), and the start height's line.
  static const _cameraLeft = 34.0;
  static const _cameraSize = Size(292, 390);
  static const _startLineY = 156.0;

  /// The grade row's turn, and the points' size.
  static const _bandTurn = -4.0;
  static const _pointsSize = 40.0;
  static const _bandGap = 8.0;

  /// The K.O. band (design: 92 on a 96 band at 148).
  static const _knockoutTop = 148.0;
  static const _knockoutSize = 92.0;

  /// The star: its middle from the meeting point and from its box's top
  /// ([TutorialGameScene.starTop]), its turn, and its size for a hard
  /// (excellent) blow and a good one.
  static const _starOffset = Offset(-14 + 60, 60);
  static const _starTurn = 8.0;
  static const _hardStar = 0.95;
  static const _goodStar = 0.75;

  /// The fighters' step in on a blow and the opponent's knockback.
  static const _attackStep = 18.0;
  static const _hitBack = 12.0;
  static const _knockedBack = 20.0;

  /// The user's combo mark at rest, as the game draws it (its inner end
  /// risen, narrowed).
  static const _comboTurn = -6.0;
  static const _comboNarrow = 0.72;

  /// The fighters' fever aura.
  static const _feverGlow = 9.0;

  BattleCharacters _characters() =>
      characters ??
      TutorialGameScene.charactersOf(
        scene.squat ? ExerciseType.squat : ExerciseType.pushUp,
      );

  @override
  Widget build(BuildContext context) {
    final s = scene;
    final meet = BattleFx.meetX(s.share);
    final fightAt = s.knockout ? _knockoutMeet : meet;
    final struck = s.hit >= 1;
    BattleFxFighter fighter({
      required BattlePose pose,
      required double footX,
      required bool mine,
    }) => BattleFxFighter(
      pose: pose,
      footX: footX,
      footY: BattleFx.groundY,
      rotation: 0,
      scaleX: mine ? 1 : -1,
      scaleY: 1,
      opacity: 1,
      flash: false,
      glow: s.fever,
      front: mine,
    );
    final me = fighter(
      pose: s.knockout
          ? BattlePose.win
          : (s.attacks ? BattlePose.attack : BattlePose.idle),
      footX:
          fightAt -
          BattleFx.reach +
          (s.hit > 0 && s.myLunge == 0 ? _attackStep : s.myLunge),
      mine: true,
    );
    final opponent = fighter(
      pose: s.knockout
          ? BattlePose.knockedOut
          : (struck ? BattlePose.hit : BattlePose.idle),
      footX:
          fightAt +
          BattleFx.reach +
          (struck && s.opponentKnock == 0 ? _hitBack : s.opponentKnock) +
          (s.knockout ? _knockedBack : 0),
      mine: false,
    );
    final starScale = s.starScale ?? (s.hit > 1 ? _hardStar : _goodStar);
    final frame = BattleFxFrame(
      meetX: meet,
      me: me,
      opponent: opponent,
      myTag: null,
      opponentTag: null,
      shakeX: 0,
      shakeY: 0,
      zoom: 1,
      star: struck && s.starOpacity > 0
          ? BattleFxStar(
              centerX: fightAt + _starOffset.dx,
              centerY: s.starTop + _starOffset.dy,
              rotation: _starTurn,
              diameter: BattleStarPainter.width * starScale,
              opacity: s.starOpacity,
            )
          : null,
      twinkle: null,
      puff: null,
      sign: s.sign,
      banners: [
        if (s.knockout)
          const BattleFxBanner(
            text: 'K.O.',
            top: _knockoutTop,
            textSize: _knockoutSize,
            tone: BattleFxTone.me,
            opacity: 1,
            rotation: _bandTurn,
          ),
      ],
      combos: const [],
      myScoreBump: s.myScoreBump,
      opponentScoreBump: 1,
      myRepsBump: s.myRepsBump,
      opponentRepsBump: 1,
      feverOpacity: s.fever ? 1 : 0,
      stripeShift: 0,
      glowRadius: s.fever ? _feverGlow : 0,
      dangerOpacity: 0,
      beforeStart: false,
      resultButton: null,
      cameraFrame: s.frame,
    );
    final state = BattleStageState(
      phase: BattleStagePhase.playing,
      myName: s.myName,
      opponentName: s.opponentName,
      remaining: Duration(seconds: s.secondsLeft),
      roundLength: battleDuration,
      myScore: s.myScore,
      opponentScore: s.opponentScore,
      myReps: s.myReps,
      opponentReps: s.opponentReps,
      barShare: s.share,
      fever: s.fever,
      feverMultiplier: battleRules.feverMultiplier,
    );
    const stage = Size(BattleFx.stageWidth, BattleFx.stageHeight);
    final sign = s.sign;
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fromRect(
            rect: Offset.zero & stage,
            child: BattleStageBackdrop(
              feverOpacity: frame.feverOpacity,
              stripeShift: 0,
            ),
          ),
          Positioned.fromRect(
            rect: Offset.zero & stage,
            child: BattleStage(
              frame: frame,
              state: state,
              characters: _characters(),
            ),
          ),
          if (s.grade case final grade?)
            Positioned(
              left: AppSpacing.s12,
              right: AppSpacing.s12,
              top: s.bandTop,
              child: Opacity(
                opacity: s.bandOpacity.clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: _bandTurn * math.pi / 180,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(
                      s.bandScale * s.bandNarrow,
                      s.bandScale,
                      1,
                    ),
                    child: _GradeRow(grade: grade, points: s.points),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            top: BattleFx.stageHeight,
            width: size.width,
            height: size.height - BattleFx.stageHeight,
            // Its leave button is a picture here: it takes no tap.
            child: IgnorePointer(
              child: BattleCameraArea(
                camera: _CameraPicture(scene: s),
                frame: s.frame,
                onLeave: _stay,
                combos: [
                  if (s.combo case final count?)
                    BattleFxCombo(
                      side: BattleSide.me,
                      count: count,
                      opacity: 1,
                      rotation: _comboTurn,
                      scaleX: _comboNarrow,
                      scaleY: 1,
                    ),
                ],
              ),
            ),
          ),
          if (sign != null)
            Positioned(
              left: (size.width - BattleRejectSignView.size.width) / 2,
              top: BattleFx.stageHeight - BattleRejectSignView.riseAboveLine,
              child: BattleRejectSignView(sign: sign),
            ),
        ],
      ),
    );
  }

  static void _stay() {}
}

/// The grade's word band and its points beside it, both shaped as the
/// game's bands ([BattleBand.number] in the grade's color), held in one
/// row and shrunk to fit the stage's width (user 2026-11-28: as the design,
/// shaped as the game's points).
class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.grade, required this.points});

  final GameGrade grade;
  final String? points;

  /// The word's size by grade, as designed (`TutGame` `bandBig`).
  static double sizeOf(GameGrade grade) => switch (grade) {
    GameGrade.excellent => 50,
    GameGrade.good => 72,
    GameGrade.average => 56,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final color = grade == GameGrade.average
        ? BattleFxTone.average.color
        : BattleFxTone.me.color;
    final points = this.points;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BattleBand.number(
              text: BattleFx.gradeWord(grade).text,
              size: sizeOf(grade),
              color: color,
              theme: theme,
            ),
            if (points != null) ...[
              const SizedBox(width: TutorialGameShot._bandGap),
              BattleBand.number(
                text: points,
                size: TutorialGameShot._pointsSize,
                color: color,
                theme: theme,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What the user's camera sees in a [scene]: the room and the person from
/// the front (`cam3.js`) with the game's own lines over them, the
/// push-up's start height and shoulders ([ChestHeightGuidePainter]) or the
/// squat's knees and hips ([SquatHeightPainter]), in the design's 292 x 390
/// box in the middle of the area.
class _CameraPicture extends StatelessWidget {
  const _CameraPicture({required this.scene});

  final TutorialGameScene scene;

  @override
  Widget build(BuildContext context) {
    final figure = scene.camera;
    final box = TutorialFront.box;
    // The lines' painters place a pose frame's points; one as large as the
    // box puts them where the design does.
    final phase = scene.bottom ? RepPhase.bottom : RepPhase.descending;
    final CustomPainter lines;
    if (scene.squat) {
      lines = SquatHeightPainter(
        frame: PoseFrame.empty(imageWidth: box.width, imageHeight: box.height),
        snapshot: JudgeSnapshot(
          phase: phase,
          squatHipY: figure.lineY,
          squatKneeY: figure.kneeY,
        ),
      );
    } else {
      final shoulderY = figure.lineY!;
      lines = ChestHeightGuidePainter(
        frame: PoseFrame(
          imageWidth: box.width,
          imageHeight: box.height,
          keypoints: {
            BodyLandmark.leftShoulder: Keypoint(
              landmark: BodyLandmark.leftShoulder,
              x: box.width / 2 - 40,
              y: shoulderY,
              likelihood: 1,
            ),
            BodyLandmark.rightShoulder: Keypoint(
              landmark: BodyLandmark.rightShoulder,
              x: box.width / 2 + 40,
              y: shoulderY,
              likelihood: 1,
            ),
          },
        ),
        baselineY: TutorialGameShot._startLineY,
        mirror: false,
        phase: phase,
      );
    }
    return SizedBox.expand(
      child: ColoredBox(
        color: HoldColors.cameraBox,
        child: Stack(
          children: [
            Positioned(
              left: TutorialGameShot._cameraLeft,
              top: 0,
              width: TutorialGameShot._cameraSize.width,
              height: TutorialGameShot._cameraSize.height,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox.fromSize(
                  size: box,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(
                          painter: TutorialCameraBackdropPainter(),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: TutorialFrontPainter(figure),
                        ),
                      ),
                      Positioned.fill(child: CustomPaint(painter: lines)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
