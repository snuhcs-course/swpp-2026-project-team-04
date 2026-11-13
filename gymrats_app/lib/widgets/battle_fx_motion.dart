import 'dart:math' as math;

import '../models/character_idle_motion.dart';
import '../models/game_score.dart';
import '../models/rep_event.dart';
import 'battle_stage_model.dart';

/// The picture a fighter shows. The stage swaps between these and moves,
/// turns and sizes the picture itself; there is no frame animation.
enum BattlePose {
  idle,
  attack,
  hit,

  /// Lying on the floor. The ring-out stage does not use it; it is part of
  /// the character sheet.
  knockedOut,
  win,
}

/// The fill behind a band, a tag or a chip. The widgets turn it into a
/// theme color; the text on it is always ink.
enum BattleFxTone { me, opponent, plain, average, fever, danger }

/// The two kinds of band text: Oxanium for numbers and English, Do Hyeon for
/// Korean.
enum BattleFxFont { number, display }

/// The numbers and curves of the battle stage's effects, ported from the
/// design prototype (FxA). Lengths are in the stage's 360 x 390 design
/// points, times in milliseconds, angles in degrees (clockwise positive).
abstract final class BattleFx {
  static const stageWidth = 360.0;
  static const stageHeight = 390.0;

  /// The feet's height: the top of the bar the fighters stand on.
  static const groundY = 346.0;

  /// How far each fighter's feet are from the point where they meet.
  static const reach = 56.0;

  /// The combo mark "N HIT": its text size, how far below the line between
  /// the stage and the camera its band's top is, and how far its outer end
  /// is from the screen's side.
  static const comboTextSize = 44.0;
  static const comboBelowLine = 14.0;
  static const comboSide = 6.0;

  /// The reconnect band's height in the design; the combo mark goes under
  /// it while it is up.
  static const reconnectBandHeight = 34.0;

  /// A rep lands this long after its event.
  static const impactDelay = 80.0;

  /// How far an attacker steps in, and how far a full knockback pushes.
  static const lungeLength = 26.0;
  static const knockbackLength = 24.0;

  /// The time constant with which the meeting point follows the score.
  static const followMs = 110.0;

  /// After the ending blow: when "K.O." appears, and when 결과 보기 does.
  static const knockoutBandAt = 1250.0;
  static const knockoutButtonAt = 2200.0;

  /// After the end by time or by a player leaving: the verdict, and 결과 보기.
  static const verdictAt = 1000.0;
  static const leftBandAt = 400.0;
  static const resultButtonAt = 1800.0;

  /// The setup's own layout (W2b 3-B): while the players set up, the line
  /// between the stage and the camera stands this high on the stage, so the
  /// camera takes most of the screen. From the countdown on it is at
  /// [stageHeight], half way down the screen.
  static const setupLineY = 156.0;

  /// How long the line takes to move the whole way between the two layouts.
  static const layoutMs = 350.0;

  /// Once the result is known the camera is no longer needed: the line goes
  /// on down to the bottom of the screen over this long, and the stage's
  /// ground fills the screen (W2b end screen, option A).
  static const endLayoutMs = 450.0;

  /// As the line comes down: how long the setup's own things take to fade
  /// out (the status band, the ready chips, and the camera's large hint and
  /// buttons), and how long the valid counts take to come in.
  static const setupFadeMs = 150.0;
  static const countsFadeMs = 200.0;

  /// Once the line is down the fighters pop up from [fighterPopFrom] of
  /// their size, over [fighterPopMs], and show over [fighterFadeInMs]. Back
  /// to the setup they fade out over [fighterFadeOutMs], keeping their size.
  static const fighterPopFrom = 0.6;
  static const fighterPopMs = 250.0;
  static const fighterFadeInMs = 70.0;
  static const fighterFadeOutMs = 100.0;

  /// The setup's status band, "자세 세팅 중": its top and text size.
  static const setupBandTop = 71.0;
  static const setupBandSize = 24.0;

  /// 0 at [a], 1 at [b], straight in between.
  static double seg(double d, double a, double b) =>
      d <= a ? 0 : (d >= b ? 1 : (d - a) / (b - a));

  /// Slows down at the end.
  static double easeOut(double x) {
    final y = 1 - x.clamp(0.0, 1.0);
    return 1 - y * y * y;
  }

  /// Starts slowly and stops slowly (the design's `io`, a cubic).
  static double easeInOut(double x) {
    final y = x.clamp(0.0, 1.0);
    if (y < 0.5) return 4 * y * y * y;
    final z = 2 - 2 * y;
    return 1 - z * z * z / 2;
  }

  /// Overshoots a little, then settles.
  static double back(double x) {
    final y = x.clamp(0.0, 1.0) - 1;
    return 1 + 2.70158 * y * y * y + 1.70158 * y * y;
  }

  /// A band popping in over 120 ms and fading over its last 120 ms; null
  /// outside its [length].
  static ({double scale, double opacity})? pop(double d, double length) {
    if (d < 0 || d > length) return null;
    return (
      scale: d < 120 ? 0.5 + 0.5 * back(d / 120) : 1,
      opacity: d > length - 120 ? (length - d) / 120 : 1,
    );
  }

  /// The word of a rep's [grade] (the design's `wordOf`), shown as its blow
  /// lands: where and how large, how long it stays, and how long after the
  /// blow its points follow. Excellent is the largest and stays longest.
  static ({
    String text,
    double top,
    double size,
    double scaleX,
    double length,
    double pointsAfter,
  })
  gradeWord(GameGrade grade) => switch (grade) {
    GameGrade.excellent => (
      text: 'EXCELLENT',
      top: 153,
      size: 84,
      scaleX: 0.54,
      length: 520,
      pointsAfter: 470,
    ),
    GameGrade.good => (
      text: 'GOOD',
      top: 158,
      size: 72,
      scaleX: 0.8,
      length: 400,
      pointsAfter: 350,
    ),
    GameGrade.average => (
      text: 'AVERAGE',
      top: 168,
      size: 48,
      scaleX: 0.68,
      length: 400,
      pointsAfter: 350,
    ),
  };

  /// How hard a rep of [grade] hits; 0 for one that misses.
  static double powerOf(GameGrade? grade) => switch (grade) {
    GameGrade.excellent => 1.6,
    GameGrade.good => 1,
    GameGrade.average => 0.5,
    null => 0,
  };

  /// How long both fighters freeze when a blow of [power] lands.
  static double hitStop(double power) =>
      power >= 1.6 ? 120 : (power >= 1 ? 90 : 40);

  /// How far the stage shakes for a blow of [power].
  static double shakeSize(double power) =>
      power >= 2 ? 16 : (power >= 1.6 ? 11 : (power >= 1 ? 4.5 : 1.5));

  /// The impact star's full width for a blow of [power].
  static double starSize(double power) =>
      power >= 2 ? 170 : (power >= 1.6 ? 130 : (power >= 1 ? 84 : 42));

  /// Where the fighters meet for a health-bar [share] from 0 to 1.
  static double meetX(double share) => 80 + 200 * share;

  /// The size of a band of numbers or English for text [size] tall (the
  /// design's `bandBox`): Oxanium's capitals are 0.69 of the size, and the
  /// band leaves the same room above and below them, so they sit in its
  /// middle and never stick out of it. [padX] is the room on each side of
  /// the text, [baseline] how far down from the band's top the letters
  /// stand. The 3 in each is the band's ink edge.
  static ({double height, double padX, double baseline}) bandBox(double size) =>
      (
        height: 0.83 * size + 6,
        padX: 0.15 * size + 3,
        baseline: 0.76 * size + 3,
      );

  /// The size of a band of Korean: as tall as its 1.25 line, 16 beside the
  /// text.
  static ({double height, double padX}) koreanBandBox(double size) =>
      (height: 1.25 * size, padX: 16);

  /// Where the combo mark's band begins, in the design's 360 x 780 screen:
  /// [comboBelowLine] under the line, and under the reconnect band while it
  /// is up.
  static double comboTop({required bool reconnecting}) =>
      stageHeight + comboBelowLine + (reconnecting ? reconnectBandHeight : 0);

  /// The chip beside the clock; null while it is hidden, before the start.
  static ({String text, BattleFxTone tone})? chip({
    required int lead,
    required bool fever,
    required bool beforeStart,
    int feverMultiplier = 2,
  }) {
    if (beforeStart) return null;
    if (fever) {
      return (text: feverText(feverMultiplier), tone: BattleFxTone.fever);
    }
    if (lead > 0) return (text: '+$lead 앞섬', tone: BattleFxTone.me);
    if (lead < 0) return (text: '−${-lead} 추격 중', tone: BattleFxTone.opponent);
    return (text: '동점', tone: BattleFxTone.plain);
  }

  /// "FEVER ×2".
  static String feverText(int multiplier) => 'FEVER ×$multiplier';
}

/// One fighter in one frame.
class BattleFxFighter {
  const BattleFxFighter({
    required this.pose,
    required this.footX,
    required this.footY,
    required this.rotation,
    required this.scaleX,
    required this.scaleY,
    required this.opacity,
    required this.flash,
    required this.glow,
    required this.front,
  });

  final BattlePose pose;

  /// Where the picture's foot point is on the stage.
  final double footX;
  final double footY;

  /// Around the foot point.
  final double rotation;

  /// Negative for the opponent, who faces left.
  final double scaleX;
  final double scaleY;
  final double opacity;

  /// Drawn as a white shape with an ink edge: just hit.
  final bool flash;

  /// A white aura, in fever.
  final bool glow;

  /// Drawn over the other fighter: attacking.
  final bool front;
}

/// A pill over a fighter's head, e.g. "준비 완료".
class BattleFxTag {
  const BattleFxTag({
    required this.text,
    required this.tone,
    required this.centerX,
    this.opacity = 1,
  });

  final String text;
  final BattleFxTone tone;
  final double centerX;

  /// A ready tag shows as much as its fighter does while they pop up.
  final double opacity;
}

/// A player's ready chip between the two scores while setting up (W2b 3-B):
/// "세팅 중" on white, or "준비 완료" on the player's color. The user's chip
/// is left of the middle, the opponent's right of it.
class BattleFxReadyChip {
  const BattleFxReadyChip({
    required this.side,
    required this.ready,
    required this.opacity,
  });

  final BattleSide side;
  final bool ready;
  final double opacity;

  String get text => ready ? '준비 완료' : '세팅 중';

  BattleFxTone get tone => !ready
      ? BattleFxTone.plain
      : (side == BattleSide.me ? BattleFxTone.me : BattleFxTone.opponent);
}

/// The impact star in front of the fighter who is hit.
class BattleFxStar {
  const BattleFxStar({
    required this.centerX,
    required this.centerY,
    required this.rotation,
    required this.diameter,
    required this.opacity,
  });

  final double centerX;
  final double centerY;
  final double rotation;
  final double diameter;
  final double opacity;
}

/// The twinkle where a knocked-out fighter left the screen.
class BattleFxTwinkle {
  const BattleFxTwinkle({
    required this.centerX,
    required this.centerY,
    required this.rotation,
    required this.scale,
    required this.opacity,
  });

  final double centerX;
  final double centerY;
  final double rotation;
  final double scale;
  final double opacity;
}

/// The puff of smoke where a player who left was standing.
class BattleFxPuff {
  const BattleFxPuff({
    required this.centerX,
    required this.centerY,
    required this.scale,
    required this.opacity,
  });

  final double centerX;
  final double centerY;
  final double scale;
  final double opacity;
}

/// The sign for the user's rep that did not count: a pictogram tile over a
/// short label.
class BattleFxSign {
  const BattleFxSign({
    required this.reason,
    required this.average,
    required this.scale,
    required this.rotation,
    required this.opacity,
  });

  final RejectReason reason;

  /// Whether the rep still earned average points: an amber band instead of
  /// a red one. The points themselves show on the stage's bands.
  final bool average;
  final double scale;
  final double rotation;
  final double opacity;

  /// The label: the reason only, e.g. "무릎 떼기".
  String get text => reason.signLabel;

  BattleFxTone get tone => average ? BattleFxTone.average : BattleFxTone.danger;
}

/// One slanted band of text over the stage, centered across it.
class BattleFxBanner {
  const BattleFxBanner({
    required this.text,
    required this.top,
    required this.textSize,
    required this.tone,
    required this.opacity,
    this.font = BattleFxFont.number,
    this.dx = 0,
    this.dy = 0,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
  });

  final String text;

  /// The top of the band before it is turned.
  final double top;
  final double textSize;
  final BattleFxTone tone;
  final double opacity;
  final BattleFxFont font;

  /// Moved by this much, then turned by [rotation] and sized by [scaleX] and
  /// [scaleY] around the band's middle.
  final double dx;
  final double dy;
  final double rotation;
  final double scaleX;
  final double scaleY;

  /// How tall the band is, and the room on each side of its text.
  double get bandHeight => font == BattleFxFont.number
      ? BattleFx.bandBox(textSize).height
      : BattleFx.koreanBandBox(textSize).height;
  double get padX => font == BattleFxFont.number
      ? BattleFx.bandBox(textSize).padX
      : BattleFx.koreanBandBox(textSize).padX;
}

/// The combo mark of one side, "N HIT", in the camera area's top corner on
/// that side: a white band of [BattleFx.comboTextSize] numbers.
class BattleFxCombo {
  const BattleFxCombo({
    required this.side,
    required this.count,
    required this.opacity,
    required this.rotation,
    required this.scaleX,
    required this.scaleY,
  });

  final BattleSide side;

  /// Valid reps in a row.
  final int count;
  final double opacity;

  /// Turned and sized around the band's outer end at mid height.
  final double rotation;
  final double scaleX;
  final double scaleY;

  String get text => '$count HIT';
}

/// 결과 보기 coming up once the ending has played.
class BattleFxResultButton {
  const BattleFxResultButton({required this.opacity, required this.scale});

  final double opacity;
  final double scale;
}

/// Everything the stage draws at one moment.
class BattleFxFrame {
  const BattleFxFrame({
    required this.meetX,
    required this.me,
    required this.opponent,
    required this.myTag,
    required this.opponentTag,
    required this.shakeX,
    required this.shakeY,
    required this.zoom,
    required this.star,
    required this.twinkle,
    required this.puff,
    required this.sign,
    required this.banners,
    required this.combos,
    required this.myScoreBump,
    required this.opponentScoreBump,
    required this.myRepsBump,
    required this.opponentRepsBump,
    required this.feverOpacity,
    required this.stripeShift,
    required this.glowRadius,
    required this.dangerOpacity,
    required this.beforeStart,
    required this.resultButton,
    this.battleLayout = 1,
    this.endLayout = 0,
    this.setupLook = 0,
    this.countsOpacity = 1,
    this.readyChips = const [],
  });

  /// Where the two fighters meet; also where the bar turns from lime to
  /// pink, and the point the KO zoom grows from (at height 300).
  final double meetX;

  final BattleFxFighter me;
  final BattleFxFighter opponent;
  final BattleFxTag? myTag;
  final BattleFxTag? opponentTag;

  /// The shake and the zoom of the fighters' layer. The HUD and the
  /// background hold still.
  final double shakeX;
  final double shakeY;
  final double zoom;

  final BattleFxStar? star;
  final BattleFxTwinkle? twinkle;
  final BattleFxPuff? puff;
  final BattleFxSign? sign;

  /// The bands over the stage, in the order they are drawn: a later one
  /// over an earlier one, so the user's over the opponent's.
  final List<BattleFxBanner> banners;

  /// The combo marks over the camera, the opponent's first.
  final List<BattleFxCombo> combos;

  /// What the big scores and the valid rep counts are sized by.
  final double myScoreBump;
  final double opponentScoreBump;
  final double myRepsBump;
  final double opponentRepsBump;

  /// The fever background, its stripes' drift and the fighters' aura.
  final double feverOpacity;
  final double stripeShift;
  final double glowRadius;

  /// The red edge while the user is about to lose.
  final double dangerOpacity;

  /// Before the round: setting up, waiting or counting down. The chip is
  /// hidden.
  final bool beforeStart;

  /// Null until the ending has played.
  final BattleFxResultButton? resultButton;

  /// How far the screen is from the setup's layout (0: the camera over most
  /// of the screen, [BattleFx.setupLineY]) to the battle's (1: half and
  /// half), eased: where the line between the stage and the camera is.
  final double battleLayout;

  /// How far the line has gone on down once the result is known (W2b end
  /// screen, option A), eased: 0 where [battleLayout] puts it, 1 at the
  /// bottom of the screen, the camera gone and the stage's ground filling
  /// the screen.
  final double endLayout;

  /// How strongly the setup's own things show, from 1 to 0: the status
  /// band, the ready chips, and the camera's large hint and buttons.
  final double setupLook;

  /// How strongly the valid rep counts show: they are hidden while setting
  /// up, where the ready chips take their place.
  final double countsOpacity;

  /// The two ready chips while setting up, the user's first; empty when
  /// they are gone.
  final List<BattleFxReadyChip> readyChips;
}

enum _ActKind { attack, miss, hit }

class _Act {
  const _Act(this.kind, this.at, this.power);

  final _ActKind kind;
  final double at;
  final double power;
}

class _Hit {
  _Hit(this.by, this.at, this.power, this.fever, this.count);

  final BattleSide by;
  final double at;
  double power;
  final bool fever;

  /// Which blow of the battle this is; it turns the star.
  final int count;
}

class _SideFx {
  int combo = 0;
  _Act? act;
  double scoreBumpAt = double.negativeInfinity;
  double comboAt = double.negativeInfinity;
  double repsBumpAt = double.negativeInfinity;

  /// The bands of this side's latest rep; the next rep replaces them.
  _Pop? pop;
}

/// The bands of one rep: "MISS" for a swing that missed, or the grade word
/// and then the points for a blow that landed.
class _Pop {
  const _Pop(this.at, this.grade, this.points);

  /// When the first band pops up: as the blow lands, or 110 ms into a miss.
  final double at;

  /// Null for a miss.
  final GameGrade? grade;
  final int points;
}

class _Sign {
  const _Sign(this.at, this.reason, this.average);

  final double at;
  final RejectReason reason;
  final bool average;
}

/// What the fighters' characters change in the effects (W3 spec 6): how
/// each one moves while idle, how much later the opponent's idle motion
/// runs, and where the hit star sits. The default is W2's stand-in: both
/// breathe in step and the star is 34 px from the middle, 76 px up.
class BattleFxCast {
  const BattleFxCast({
    this.meIdle = CharacterIdleMotion.w2Default,
    this.opponentIdle = CharacterIdleMotion.w2Default,
    this.opponentIdleOffsetMs = 0,
    this.hitStarDx = 34,
    this.hitStarUp = 76,
  });

  final CharacterIdleMotion meIdle;
  final CharacterIdleMotion opponentIdle;

  /// Added to the opponent's clock for their idle motion.
  final double opponentIdleOffsetMs;

  /// The hit star's center: [hitStarDx] from the meeting point toward the
  /// one hit, [hitStarUp] above the floor.
  final double hitStarDx;
  final double hitStarUp;

  /// The idle motion of [who] at [now] on the stage clock.
  IdleSample idleAt(BattleSide who, double now) => who == BattleSide.me
      ? meIdle.sampleAt(now)
      : opponentIdle.sampleAt(now + opponentIdleOffsetMs);
}

class _Motion {
  BattlePose pose = BattlePose.idle;
  double lunge = 0;
  double back = 0;
  bool flash = false;
  double tilt = 0;
  double hop = 0;

  /// In an ending: whether this side lost. Null otherwise.
  bool? lost;
  double sinceEnd = -1;
}

/// What happened on the stage and when, and from it the frame to draw at any
/// moment. A port of the design prototype's script (FxA): the events come in
/// from the game, nothing here decides a score.
///
/// Every time is on the stage's own clock, in milliseconds.
class BattleFxTimeline {
  /// A stage made [setup] begins in the setup's layout, setting up; any
  /// other stands in the battle's layout at once, with no move to it, as a
  /// screen that opens on a battle already counting down, running or over.
  BattleFxTimeline({
    double share = 0.5,
    this.feverMultiplier = 2,
    bool setup = false,
  }) : _shareFrom = share.clamp(0.0, 1.0),
       _shareTarget = share.clamp(0.0, 1.0),
       _setup = setup,
       _toBattle = !setup,
       _layoutFrom = setup ? 0 : 1;

  /// How far a new countdown end may be from the running one and still be
  /// the same countdown: the server's clock is corrected by a few
  /// milliseconds now and then, and the numbers should not jump with it.
  static const _countSlack = 100.0;

  /// What fever multiplies points by, for the "FEVER ×2" band.
  final int feverMultiplier;

  final _sides = {BattleSide.me: _SideFx(), BattleSide.opponent: _SideFx()};

  double _shareFrom;
  double _shareTarget;
  double _shareSince = 0;

  _Hit? _hit;
  int _hits = 0;
  _Sign? _sign;

  bool _fever = false;
  double _feverAt = double.negativeInfinity;

  BattleStageEnd? _end;
  double _endAt = 0;
  double? _decidedAt;

  /// Whether the knockout came with the blow that caused it.
  bool _endByBlow = false;

  /// How long after a knockout was reported its blow may still arrive and
  /// be played as the ending blow.
  static const _blowSlack = 250.0;

  bool _setup;
  bool _meReady = false;
  bool _opponentReady = false;
  double? _countEnd;

  /// The status band's words as the setup left them: it fades out with
  /// them as the line comes down. Null when it showed none.
  String? _leftWords;

  /// The layout around the stage (W2b 3-B), from 0 (the setup's) to 1 (the
  /// battle's): it moves toward the battle's while [_toBattle], back
  /// otherwise, at an even speed, [BattleFx.layoutMs] for the whole way,
  /// from [_layoutFrom] at [_layoutSince].
  bool _toBattle;
  double _layoutFrom;
  double _layoutSince = 0;

  /// When the fighters start to pop up: the moment the layout reaches the
  /// battle's. Null on a stage that began in it, where they just stand.
  double? _popAt;

  /// The fighters fading out as the layout goes back to the setup's: from
  /// when, from how visible, at what size.
  double _outAt = double.negativeInfinity;
  double _outOpacity = 0;
  double _outScale = BattleFx.fighterPopFrom;

  /// The cues still to come, each with its moment.
  final _cues = <(double, BattleStageCue)>[];

  /// The last countdown number given as a cue (4 before the first), and
  /// whether the start was.
  int _countSaid = 4;
  bool _goSaid = false;
  bool _verdictSaid = false;

  /// Whether the user is far enough behind to lose soon.
  bool danger = false;

  /// The characters' idle motions and hit-star place.
  BattleFxCast cast = const BattleFxCast();

  /// Whether the opponent's connection is down, before it counts as leaving.
  bool opponentGone = false;

  /// The scores on screen: a score of three digits has no room to grow when
  /// it bumps, so it shrinks instead.
  int _myScore = 0;
  int _opponentScore = 0;

  /// The ending being played, if any.
  BattleStageEnd? get end => _end;

  /// Takes the scores the HUD shows now.
  void setScores(int mine, int theirs) {
    _myScore = mine;
    _opponentScore = theirs;
  }

  /// Moves the meeting point toward a new health-bar [share].
  void setShare(double share, double now) {
    final target = share.clamp(0.0, 1.0);
    if (target == _shareTarget) return;
    _shareFrom = _shareAt(now);
    _shareSince = now;
    _shareTarget = target;
  }

  double _shareAt(double now) {
    final dt = math.max(0.0, now - _shareSince);
    return _shareTarget +
        (_shareFrom - _shareTarget) * math.exp(-dt / BattleFx.followMs);
  }

  /// Plays a rep: the attack and the blow that lands [BattleFx.impactDelay]
  /// later, or a swing that misses. Nothing plays once the battle has ended,
  /// and it then returns false.
  ///
  /// One rep is still played after the end: the blow of a knockout that was
  /// reported just before it. The game ends the round the moment a KO lead is
  /// reached, and the rep that reached it can be heard of a moment later.
  bool rep(BattleStageEvent event, double now) {
    final end = _end;
    if (end != null) {
      final itsBlow =
          event.knockout &&
          event.grade != null &&
          end.kind == BattleEndKind.knockout &&
          end.winner == event.side &&
          !_endByBlow &&
          now - _endAt <= _blowSlack;
      if (!itsBlow) return false;
      // The ring-out starts over from this blow; its cue replaces the one
      // of the report, unless that was already given.
      final pending = _cues.length;
      _cues.removeWhere((cue) => cue.$2.kind == BattleCueKind.knockout);
      _play(event, now, cue: _cues.length < pending);
      return true;
    }
    _play(event, now, cue: true);
    return true;
  }

  void _play(BattleStageEvent event, double now, {required bool cue}) {
    final side = _sides[event.side]!;
    final other = _sides[event.side.other]!;
    final impact = now + BattleFx.impactDelay;
    if (event.counted) {
      side.combo = event.combo;
      if (event.combo >= 2) side.comboAt = now;
      side.repsBumpAt = impact;
    } else {
      side.combo = 0;
    }
    final power = BattleFx.powerOf(event.grade);
    _hits += 1;
    if (power > 0) {
      side.act = _Act(_ActKind.attack, now, power);
      other.act = _Act(_ActKind.hit, impact, power);
      _hit = _Hit(event.side, impact, power, event.fever, _hits);
      side.scoreBumpAt = impact;
      side.pop = _Pop(impact, event.grade, event.points);
      if (cue) {
        _cues.add((
          impact,
          BattleStageCue(
            event.knockout ? BattleCueKind.knockout : BattleCueKind.hit,
            side: event.side,
            grade: event.grade,
          ),
        ));
      }
    } else {
      side.act = _Act(_ActKind.miss, now, power);
      side.pop = _Pop(now + 110, null, 0);
      _cues.add((now, BattleStageCue(BattleCueKind.miss, side: event.side)));
    }
    // The sign is only for the user's own rep that did not count; the latest
    // one replaces the one before, and one without a reason shows none.
    if (event.side == BattleSide.me && !event.counted) {
      final reason = event.reason;
      _sign = reason == null
          ? null
          : _Sign(now, reason, event.grade == GameGrade.average);
    }
    // Only a blow that lands can knock out.
    if (event.knockout && power > 0) {
      _hit!.power = 2.4;
      _end = BattleStageEnd(kind: BattleEndKind.knockout, winner: event.side);
      _endAt = impact;
      // Known from the report already, when one came first: the line that
      // has started down after it does not go back up.
      _decidedAt = math.min(_decidedAt ?? impact, impact);
      _endByBlow = true;
    }
  }

  /// Turns fever on or off.
  void setFever(bool on, double now) {
    if (on == _fever) return;
    _fever = on;
    _feverAt = on ? now : double.negativeInfinity;
  }

  /// Ends the battle. Once an ending is decided, a later call is ignored.
  ///
  /// A time-up that is not [BattleStageEnd.decided] shows "TIME!" and waits.
  /// The result that then comes decides it: a time-up keeps its "TIME!" and
  /// adds the verdict; a knockout or a player leaving plays as that ending
  /// from the moment it is known, so the stage says what the result says.
  void finish(BattleStageEnd end, double now) {
    final current = _end;
    if (current != null && (current.decided || !end.decided)) return;
    final settles = current != null && end.kind == BattleEndKind.timeUp;
    _end = end;
    if (!settles) {
      _endAt = now;
      _cues.add((
        now,
        switch (end.kind) {
          BattleEndKind.knockout => BattleStageCue(
            BattleCueKind.knockout,
            side: end.winner,
          ),
          BattleEndKind.timeUp => const BattleStageCue(BattleCueKind.timeUp),
          BattleEndKind.playerLeft => BattleStageCue(
            BattleCueKind.playerLeft,
            side: end.winner,
          ),
        },
      ));
    }
    _decidedAt = end.decided ? now : null;
  }

  /// The cues whose moment has come by [now], each given once, in order: a
  /// blow landing, a miss, the countdown numbers, the start, the ending, and
  /// after a time-up its verdict.
  List<BattleStageCue> takeCues(double now) {
    _cues.sort((a, b) => a.$1.compareTo(b.$1));
    final due = <BattleStageCue>[];
    while (_cues.isNotEmpty && _cues.first.$1 <= now) {
      due.add(_cues.removeAt(0).$2);
    }
    final countEnd = _countEnd;
    if (countEnd != null) {
      if (now < countEnd) {
        // The number on screen now; one that was skipped is not said late.
        final number = ((countEnd - now) / 1000).ceil();
        if (number <= 3 && number < _countSaid) {
          _countSaid = number;
          due.add(BattleStageCue(BattleCueKind.countdown, number: number));
        }
      } else if (!_goSaid) {
        _goSaid = true;
        due.add(const BattleStageCue(BattleCueKind.go));
      }
    }
    final verdictAt = _verdictAt;
    if (!_verdictSaid &&
        _end?.kind == BattleEndKind.timeUp &&
        verdictAt != null &&
        now > verdictAt) {
      _verdictSaid = true;
      due.add(BattleStageCue(BattleCueKind.verdict, side: _end?.winner));
    }
    return due;
  }

  /// Before the round: who has finished setting up. Setting up again stops a
  /// countdown that was running (a player left the ready pose), and the
  /// layout goes back to the setup's from [now]. [active] is false once the
  /// countdown or the round is on.
  void setSetup({
    required bool active,
    bool meReady = false,
    bool opponentReady = false,
    required double now,
  }) {
    if (_setup && !active) _leftWords = _setupWords;
    _setup = active;
    _meReady = meReady;
    _opponentReady = opponentReady;
    if (active) {
      _countEnd = null;
      _countSaid = 4;
      _goSaid = false;
    }
    _layoutTo(battle: !active, now: now);
  }

  /// Counts down to the start, [remaining] from [now], and ends the setup:
  /// the layout moves to the battle's from [now]. The round starts, and
  /// "GO!" shows, when it reaches zero.
  ///
  /// Called again while counting, it follows a start that really moved and
  /// keeps its own clock for a small correction. Once the round has started
  /// it does nothing. [remaining] must be exact to the millisecond (online:
  /// the start time minus the server's time now), not whole seconds, or the
  /// numbers jump.
  void countDown(double remaining, double now) {
    final running = _countEnd;
    if (running != null && now >= running) return;
    if (_setup) _leftWords = _setupWords;
    _setup = false;
    final end = now + remaining;
    if (running == null || (end - running).abs() > _countSlack) {
      _countEnd = end;
    }
    _layoutTo(battle: true, now: now);
  }

  /// The status band's words while setting up: whom the setup waits for;
  /// none once both are ready.
  String? get _setupWords =>
      _meReady && _opponentReady ? null : (_meReady ? '상대를 기다리는 중' : '자세 세팅 중');

  /// Turns the layout toward the battle's or back to the setup's from [now],
  /// from wherever it is: the line never jumps. Back to the setup the
  /// fighters fade out from how they look now.
  void _layoutTo({required bool battle, required double now}) {
    if (battle == _toBattle) return;
    final at = _layoutAt(now);
    if (!battle) {
      final look = _fighterLook(now);
      _outAt = now;
      _outOpacity = look.opacity;
      _outScale = look.scale;
    }
    _toBattle = battle;
    _layoutFrom = at;
    _layoutSince = now;
    if (battle) _popAt = now + (1 - at) * BattleFx.layoutMs;
  }

  /// The layout at [now], from 0 (the setup's) to 1 (the battle's), before
  /// it is eased.
  double _layoutAt(double now) {
    final moved = math.max(0.0, now - _layoutSince) / BattleFx.layoutMs;
    return _toBattle
        ? math.min(1.0, _layoutFrom + moved)
        : math.max(0.0, _layoutFrom - moved);
  }

  /// How large the fighters are drawn, as a share of their size, and how
  /// visible: hidden while setting up, popping up once the line is down,
  /// fading out when the setup comes back (whichever shows more, should the
  /// two meet). With [reducedMotion] they are there or not.
  ({double scale, double opacity}) _fighterLook(
    double now, {
    bool reducedMotion = false,
  }) {
    final fading = (
      scale: _outScale,
      opacity:
          _outOpacity *
          (1 - BattleFx.seg(now, _outAt, _outAt + BattleFx.fighterFadeOutMs)),
    );
    if (!_toBattle) return reducedMotion ? (scale: 1, opacity: 0) : fading;
    final popAt = _popAt;
    if (popAt == null || reducedMotion) return (scale: 1, opacity: 1);
    final popping = (
      scale:
          BattleFx.fighterPopFrom +
          (1 - BattleFx.fighterPopFrom) *
              BattleFx.back(
                BattleFx.seg(now, popAt, popAt + BattleFx.fighterPopMs),
              ),
      opacity: BattleFx.seg(now, popAt, popAt + BattleFx.fighterFadeInMs),
    );
    return fading.opacity > popping.opacity ? fading : popping;
  }

  /// When "TIME!" gives way to the verdict; null while it is not decided.
  double? get _verdictAt {
    final decidedAt = _decidedAt;
    if (decidedAt == null) return null;
    return math.max(_endAt + BattleFx.verdictAt, decidedAt);
  }

  /// When 결과 보기 comes up; null while the result is not decided.
  double? get _buttonAt {
    final end = _end;
    if (end == null) return null;
    return switch (end.kind) {
      BattleEndKind.knockout => _endAt + BattleFx.knockoutButtonAt,
      BattleEndKind.playerLeft => _endAt + BattleFx.resultButtonAt,
      BattleEndKind.timeUp => switch (_verdictAt) {
        final at? => at + BattleFx.resultButtonAt - BattleFx.verdictAt,
        null => null,
      },
    };
  }

  /// Whether 결과 보기 is up at [now], so it may be pressed.
  bool resultButtonUp(double now) {
    final at = _buttonAt;
    return at != null && now >= at;
  }

  /// How far the line has gone down after the battle at [now], eased: 0
  /// until the result is known, then 1 after [BattleFx.endLayoutMs] (W2b
  /// end screen, option A). A knockout is known when its blow lands, or
  /// when the screen reports it, if that comes first; a player leaving as it
  /// is reported; a time-up when it is decided, so online the camera, and
  /// the way out, stay while the server's result is awaited. With
  /// [reducedMotion] it is 1 at once.
  double _endLayoutAt(double now, {required bool reducedMotion}) {
    final at = _decidedAt;
    // A knockout's blow is played a moment before it lands.
    if (_end == null || at == null || now < at) return 0;
    if (reducedMotion) return 1;
    return BattleFx.easeInOut(BattleFx.seg(now, at, at + BattleFx.endLayoutMs));
  }

  /// The frame at [now]. With [reducedMotion] the hit-stop, the shake, the
  /// zoom, the flash, the idle motion, the stripes' drift, the count bump, the
  /// countdown's growing numbers, the puff and the button's growing are off;
  /// and the layout's moves (W2b 3-B: the line, the setup's things fading,
  /// the valid counts coming in, the fighters popping up or fading out; and
  /// after the battle the line going down) jump to their ends. Poses,
  /// scores, bands, the sign and the button stay.
  BattleFxFrame frame(double now, {bool reducedMotion = false}) {
    final end = _end;
    final endKind = end?.kind;
    final sinceEnd = now - _endAt;
    final countEnd = _countEnd;
    final counting = countEnd != null && now < countEnd;
    final beforeStart = _setup || counting;
    final inDanger = danger && end == null && !beforeStart;
    final meetX = BattleFx.meetX(_shareAt(now));
    // The layout around the stage, and what shows with it (W2b 3-B).
    final layout = reducedMotion ? (_toBattle ? 1.0 : 0.0) : _layoutAt(now);
    final setupLook =
        1 - (layout * BattleFx.layoutMs / BattleFx.setupFadeMs).clamp(0.0, 1.0);
    final look = _fighterLook(now, reducedMotion: reducedMotion);

    BattleFxFighter build(BattleSide who) {
      final dir = who == BattleSide.me ? 1.0 : -1.0;
      final x = meetX - dir * BattleFx.reach;
      final m = _motion(who, now, reducedMotion);
      var dx =
          dir *
          (m.lunge * BattleFx.lungeLength - m.back * BattleFx.knockbackLength);
      var dy = -m.hop;
      var rotation = dir * m.tilt;
      var scale = 1.0;
      var opacity = 1.0;
      // The character's idle motion (W2's breathing by default), in the
      // idle pose only.
      final idle = m.pose == BattlePose.idle && !reducedMotion
          ? cast.idleAt(who, now)
          : IdleSample.rest;
      final swaying =
          who == BattleSide.me && inDanger && m.pose == BattlePose.idle;
      if (swaying) rotation += -7 + math.sin(now / 85) * 6;
      if (who == BattleSide.opponent && opponentGone) opacity = 0.45;
      if (m.lost == true && m.sinceEnd >= 0) {
        if (endKind == BattleEndKind.knockout) {
          // Flies out and up over the edge behind them, spinning.
          final u = BattleFx.seg(m.sinceEnd, 240, 1500);
          final s = u * u * (0.35 + 0.65 * u);
          dx = -dir * 430 * s;
          dy = -300 * s;
          rotation = -dir * 900 * s;
          scale = 1 + 0.4 * s;
          opacity = u >= 1 ? 0 : 1;
        } else if (endKind == BattleEndKind.playerLeft) {
          final u = BattleFx.easeOut(BattleFx.seg(m.sinceEnd, 0, 400));
          opacity *= 1 - u;
          scale = 1 - 0.3 * u;
          dy = -10 * u;
        }
      }
      dy -= idle.up;
      // The danger sway replaces the rock; the rest of the motion stays.
      if (!swaying) rotation += dir * idle.rockDeg;
      // Hidden while setting up, popping up around the foot once the line
      // is down.
      scale *= look.scale;
      opacity *= look.opacity;
      return BattleFxFighter(
        pose: m.pose,
        footX: x + dx,
        footY: BattleFx.groundY + dy,
        rotation: rotation,
        scaleX: dir * scale * idle.scaleX,
        scaleY: scale * idle.scaleY,
        opacity: opacity,
        flash: m.flash,
        glow: _fever && !m.flash,
        front: m.pose == BattlePose.attack,
      );
    }

    final shake = reducedMotion ? (0.0, 0.0) : _shake(now);
    var zoom = 1.0;
    BattleFxTwinkle? twinkle;
    BattleFxPuff? puff;
    if (endKind == BattleEndKind.knockout) {
      if (sinceEnd >= 0 && !reducedMotion) {
        zoom =
            1 +
            0.16 *
                BattleFx.easeOut(BattleFx.seg(sinceEnd, 0, 200)) *
                (1 - BattleFx.easeOut(BattleFx.seg(sinceEnd, 1000, 1400)));
      }
      if (sinceEnd > 1450 && sinceEnd < 2300) {
        final u = (sinceEnd - 1450) / 850;
        twinkle = BattleFxTwinkle(
          centerX: end!.winner == BattleSide.me ? 320 : 40,
          centerY: 158,
          rotation: u * 180,
          scale: 0.4 + math.sin(u * math.pi) * 1.1,
          opacity: 1 - u,
        );
      }
    }
    if (endKind == BattleEndKind.playerLeft &&
        !reducedMotion &&
        sinceEnd >= 80 &&
        sinceEnd < 620) {
      final dir = end!.winner == BattleSide.me ? 1.0 : -1.0;
      puff = BattleFxPuff(
        centerX: meetX + dir * BattleFx.reach,
        centerY: BattleFx.groundY - 60,
        scale: 0.5 + 0.9 * BattleFx.easeOut(BattleFx.seg(sinceEnd, 80, 620)),
        opacity: 1 - BattleFx.seg(sinceEnd, 300, 620),
      );
    }

    // More than three seconds before the start both stand ready, with a tag
    // over their heads that shows as they do; the numbers take over from
    // there. While setting up the ready chips between the scores say it
    // instead, and there are no fighters to tag.
    final earlyCount = counting && countEnd - now > 3000;
    BattleFxTag readyTag(BattleSide who, double centerX) => BattleFxTag(
      text: '준비 완료',
      tone: who == BattleSide.me ? BattleFxTone.me : BattleFxTone.opponent,
      centerX: centerX,
      opacity: look.opacity,
    );
    final opponentX = meetX + BattleFx.reach;
    final BattleFxTag? opponentTag;
    if (earlyCount) {
      opponentTag = readyTag(BattleSide.opponent, opponentX);
    } else if (opponentGone && end == null && !_setup) {
      // Over the fighter, so not while setting up, where there is none, and
      // showing as the fighter does when they pop up.
      opponentTag = BattleFxTag(
        text: '연결 끊김',
        tone: BattleFxTone.plain,
        centerX: opponentX,
        opacity: look.opacity,
      );
    } else {
      opponentTag = null;
    }

    final buttonAt = _buttonAt;
    BattleFxResultButton? button;
    if (buttonAt != null && now >= buttonAt) {
      button = BattleFxResultButton(
        opacity: BattleFx.seg(now, buttonAt, buttonAt + 120),
        scale: reducedMotion
            ? 1
            : 0.8 +
                  0.2 *
                      BattleFx.back(
                        BattleFx.seg(now, buttonAt, buttonAt + 160),
                      ),
      );
    }

    final mine = _sides[BattleSide.me]!;
    final theirs = _sides[BattleSide.opponent]!;
    return BattleFxFrame(
      meetX: meetX,
      me: build(BattleSide.me),
      opponent: build(BattleSide.opponent),
      myTag: earlyCount
          ? readyTag(BattleSide.me, meetX - BattleFx.reach)
          : null,
      opponentTag: opponentTag,
      shakeX: shake.$1,
      shakeY: shake.$2,
      zoom: zoom,
      star: _star(now, meetX, reducedMotion),
      twinkle: twinkle,
      puff: puff,
      sign: _signAt(now),
      banners: _banners(now, counting, reducedMotion, setupLook),
      combos: _combos(now),
      myScoreBump: _scoreBump(now - mine.scoreBumpAt, _myScore),
      opponentScoreBump: _scoreBump(now - theirs.scoreBumpAt, _opponentScore),
      myRepsBump: reducedMotion ? 1 : _bump(now - mine.repsBumpAt, 260, 0.3),
      opponentRepsBump: reducedMotion
          ? 1
          : _bump(now - theirs.repsBumpAt, 260, 0.3),
      feverOpacity: _fever ? ((now - _feverAt) / 200).clamp(0.0, 1.0) : 0,
      stripeShift: reducedMotion ? 0 : (now * 0.09) % 61.8,
      glowRadius: 9 + 4 * math.sin(now / 120),
      dangerOpacity: inDanger ? ((now / 240).floor().isOdd ? 0.95 : 0.3) : 0,
      beforeStart: beforeStart,
      resultButton: button,
      battleLayout: BattleFx.easeInOut(layout),
      endLayout: _endLayoutAt(now, reducedMotion: reducedMotion),
      setupLook: setupLook,
      countsOpacity: (layout * BattleFx.layoutMs / BattleFx.countsFadeMs).clamp(
        0.0,
        1.0,
      ),
      // As the line comes down the countdown says both are ready.
      readyChips: setupLook <= 0
          ? const []
          : [
              BattleFxReadyChip(
                side: BattleSide.me,
                ready: !_setup || _meReady,
                opacity: setupLook,
              ),
              BattleFxReadyChip(
                side: BattleSide.opponent,
                ready: !_setup || _opponentReady,
                opacity: setupLook,
              ),
            ],
    );
  }

  /// A number growing by [extra] and back over [length].
  static double _bump(double d, double length, double extra) =>
      d >= 0 && d < length ? 1 + extra * math.sin(d / length * math.pi) : 1;

  /// A [score] bumping [d] after its blow: up by a fifth and back over
  /// 280 ms, or, from 100 on, down by a tenth and back, since three digits
  /// already fill the room beside the valid counts and under the clock.
  static double _scoreBump(double d, int score) =>
      score >= 100 ? 2 - _bump(d, 280, 0.1) : _bump(d, 280, 0.2);

  /// A fighter's pose and how far through each move they are.
  _Motion _motion(BattleSide who, double now, bool noHitStop) {
    final m = _Motion();
    final act = _sides[who]!.act;
    if (act != null && now >= act.at) {
      final d = now - act.at;
      final stop = noHitStop ? 0.0 : BattleFx.hitStop(act.power);
      switch (act.kind) {
        case _ActKind.attack:
          const step = BattleFx.impactDelay;
          if (d < step + stop + 180) m.pose = BattlePose.attack;
          m.lunge = d < step
              ? BattleFx.easeOut(d / step)
              : (d < step + stop
                    ? 1
                    : 1 -
                          BattleFx.easeOut(
                            BattleFx.seg(d, step + stop, step + stop + 220),
                          ));
        case _ActKind.miss:
          if (d < 560) m.pose = BattlePose.attack;
          m.lunge = d < 110
              ? BattleFx.easeOut(d / 110)
              : 1 - BattleFx.easeOut(BattleFx.seg(d, 300, 560));
          m.tilt = d < 560
              ? math.sin(BattleFx.seg(d, 60, 560) * math.pi) * 16
              : 0;
        case _ActKind.hit:
          if (d < stop + 400) m.pose = BattlePose.hit;
          m.flash = !noHitStop && d < stop + 60;
          final pushed = d < stop
              ? 0.2
              : 0.2 + 0.8 * BattleFx.easeOut(BattleFx.seg(d, stop, stop + 150));
          m.back =
              pushed *
              (1 - BattleFx.easeOut(BattleFx.seg(d, stop + 150, stop + 480))) *
              math.min(1.6, 0.5 + act.power * 0.7);
      }
    }
    final end = _end;
    if (end == null) return m;
    final since = now - _endAt;
    m.sinceEnd = since;
    final won = end.winner == who;
    switch (end.kind) {
      case BattleEndKind.knockout:
        m.lost = !won;
        if (since < 0) break;
        m.back = 0;
        m.tilt = 0;
        if (!won) {
          m.pose = BattlePose.hit;
          m.lunge = 0;
          m.flash = !noHitStop && since < 240 && (since / 60).floor().isEven;
        } else if (since < 1000) {
          m.pose = BattlePose.attack;
          m.lunge = since < 240
              ? 1
              : 1 - BattleFx.easeOut(BattleFx.seg(since, 240, 700));
          m.flash = false;
        } else {
          m.pose = BattlePose.win;
          m.lunge = 0;
          m.hop = _hop(since - 1000);
        }
      case BattleEndKind.playerLeft:
        m.lost = !won;
        if (since < 0) break;
        m.lunge = 0;
        m.back = 0;
        m.tilt = 0;
        m.flash = false;
        m.pose = BattlePose.idle;
        if (won && since >= 300) {
          m.pose = BattlePose.win;
          m.hop = _hop(since - 300);
        }
      case BattleEndKind.timeUp:
        final verdictAt = _verdictAt;
        if (verdictAt == null || now <= verdictAt || end.winner == null) break;
        m.lost = !won;
        m.lunge = 0;
        m.back = 0;
        m.tilt = 0;
        m.flash = false;
        if (won) {
          m.pose = BattlePose.win;
          m.hop = _hop(now - verdictAt);
        } else {
          m.pose = BattlePose.hit;
        }
    }
    return m;
  }

  /// The winner's hops, [d] after they start.
  static double _hop(double d) => math.sin(d / 230).abs() * 16;

  (double, double) _shake(double now) {
    final hit = _hit;
    if (hit == null) return (0, 0);
    final d = now - hit.at;
    if (d < 0 || d > 340) return (0, 0);
    final size =
        BattleFx.shakeSize(hit.power) * (hit.fever ? 1.5 : 1) * (1 - d / 340);
    return (size * math.sin(d * 0.09), size * 0.6 * math.cos(d * 0.13));
  }

  BattleFxStar? _star(double now, double meetX, bool noHitStop) {
    final hit = _hit;
    if (hit == null) return null;
    final d = now - hit.at;
    final stop = noHitStop ? 0.0 : BattleFx.hitStop(hit.power);
    if (d < 0 || d > stop + 300) return null;
    final size = BattleFx.starSize(hit.power) * (hit.fever ? 1.5 : 1);
    final grown = 0.45 + 0.75 * BattleFx.easeOut(BattleFx.seg(d, 0, stop + 60));
    return BattleFxStar(
      centerX:
          meetX + (hit.by == BattleSide.me ? cast.hitStarDx : -cast.hitStarDx),
      centerY: BattleFx.groundY - cast.hitStarUp,
      rotation: (hit.count * 37) % 60 + d * 0.05,
      diameter: grown * size,
      opacity: d > stop + 140 ? math.max(0, 1 - (d - stop - 140) / 160) : 1,
    );
  }

  BattleFxSign? _signAt(double now) {
    final sign = _sign;
    if (sign == null) return null;
    final d = now - sign.at;
    if (d < 0 || d >= 1300) return null;
    return BattleFxSign(
      reason: sign.reason,
      average: sign.average,
      scale: d < 130 ? 0.6 + 0.4 * BattleFx.back(d / 130) : 1,
      rotation: d < 280 ? math.sin(d / 40) * 3 * (1 - d / 280) : 0,
      opacity: d > 1150 ? (1300 - d) / 150 : math.min(1, 0.5 + d / 80),
    );
  }

  List<BattleFxBanner> _banners(
    double now,
    bool counting,
    bool reducedMotion,
    double setupLook,
  ) {
    final end = _end;
    final sinceEnd = now - _endAt;
    final out = <BattleFxBanner>[];
    void add(BattleFxBanner banner) {
      if (banner.opacity > 0.01) out.add(banner);
    }

    BattleFxTone toneOf(BattleSide? side) => switch (side) {
      BattleSide.me => BattleFxTone.me,
      BattleSide.opponent => BattleFxTone.opponent,
      null => BattleFxTone.plain,
    };

    // A knockout clears the bands of the blow that caused it. The
    // opponent's bands come first, so the user's are drawn over them.
    final cleared = end?.kind == BattleEndKind.knockout && sinceEnd > 300;
    for (final who in const [BattleSide.opponent, BattleSide.me]) {
      final rep = cleared ? null : _sides[who]!.pop;
      if (rep == null) continue;
      final sign = who == BattleSide.me ? 1.0 : -1.0;
      final d = now - rep.at;
      final grade = rep.grade;
      if (grade == null) {
        final miss = BattleFx.pop(d, 760);
        if (miss != null) {
          add(
            BattleFxBanner(
              text: 'MISS',
              top: 155,
              textSize: 84,
              tone: BattleFxTone.plain,
              opacity: miss.opacity,
              dx: -sign * 56,
              rotation: sign * 7,
              scaleX: 0.78 * miss.scale,
              scaleY: miss.scale,
            ),
          );
        }
        continue;
      }
      // The grade word as the blow lands, then the points, which come up
      // while the word fades. Average's are amber and smaller.
      final word = BattleFx.gradeWord(grade);
      final average = grade == GameGrade.average;
      final tone = average ? BattleFxTone.average : toneOf(who);
      final shown = BattleFx.pop(d, word.length);
      if (shown != null) {
        add(
          BattleFxBanner(
            text: word.text,
            top: word.top,
            textSize: word.size,
            tone: tone,
            opacity: shown.opacity,
            rotation: -4 * sign,
            scaleX: word.scaleX * shown.scale,
            scaleY: shown.scale,
          ),
        );
      }
      final points = BattleFx.pop(d - word.pointsAfter, average ? 720 : 880);
      if (points != null) {
        add(
          BattleFxBanner(
            text: '+${rep.points}',
            top: average ? 165 : 152,
            textSize: average ? 72 : 104,
            tone: tone,
            opacity: points.opacity,
            dx: sign * 34,
            rotation: -4 * sign,
            scaleX: points.scale,
            scaleY: points.scale,
          ),
        );
      }
    }

    final fever = now - _feverAt;
    if (_fever && fever >= 0 && fever < 1300) {
      add(
        BattleFxBanner(
          text: BattleFx.feverText(feverMultiplier),
          top: 263,
          textSize: 80,
          tone: BattleFxTone.plain,
          opacity: 1,
          // In from the left, out to the right, over both fighters.
          dx: fever < 160
              ? -400 * (1 - BattleFx.easeOut(fever / 160))
              : (fever > 1100
                    ? 400 * BattleFx.easeOut((fever - 1100) / 200)
                    : 0),
          rotation: -4,
          scaleX: 0.7,
        ),
      );
    }

    // The setup's status band, between the scores; it fades out with the
    // setup's other things, with the words it had.
    final setupWords = _setup ? _setupWords : _leftWords;
    if (setupWords != null) {
      add(
        BattleFxBanner(
          text: setupWords,
          top: BattleFx.setupBandTop,
          textSize: BattleFx.setupBandSize,
          tone: BattleFxTone.plain,
          opacity: setupLook,
          font: BattleFxFont.display,
          rotation: -3,
        ),
      );
    }

    final countEnd = _countEnd;
    if (countEnd != null) {
      final left = countEnd - now;
      if (counting && left <= 3000) {
        final number = (left / 1000).ceil();
        final shown = number * 1000 - left;
        final scale = reducedMotion
            ? 1.0
            : 1.5 - 0.5 * BattleFx.easeOut(shown / 160);
        add(
          BattleFxBanner(
            text: '$number',
            top: 141,
            textSize: 160,
            tone: BattleFxTone.plain,
            opacity: 1,
            scaleX: scale,
            scaleY: scale,
          ),
        );
      }
      final go = BattleFx.pop(now - countEnd, 700);
      if (go != null) {
        add(
          BattleFxBanner(
            text: 'GO!',
            top: 153,
            textSize: 130,
            tone: BattleFxTone.plain,
            opacity: go.opacity,
            rotation: -5,
            scaleX: go.scale,
            scaleY: go.scale,
          ),
        );
      }
    }

    if (end == null) return out;
    // A band that lands big and settles to its size over [length].
    double landing(double d, double from, double length) =>
        d < length ? from - (from - 1) * BattleFx.easeOut(d / length) : 1;
    switch (end.kind) {
      case BattleEndKind.knockout:
        final d = sinceEnd - BattleFx.knockoutBandAt;
        if (d >= 0) {
          // On the half the winner left empty: the loser was pushed to
          // their end of the bar, so the winner stands toward it. The
          // winner's end of the band is the higher one.
          final winner = end.winner == BattleSide.opponent ? -1.0 : 1.0;
          final scale = landing(d, 2.4, 180);
          add(
            BattleFxBanner(
              text: 'K.O.',
              top: 166,
              textSize: 110,
              tone: toneOf(end.winner),
              opacity: 1,
              dx: -102 * winner,
              rotation: -7 * winner,
              scaleX: 0.6 * scale,
              scaleY: scale,
            ),
          );
        }
      case BattleEndKind.playerLeft:
        final d = sinceEnd - BattleFx.leftBandAt;
        if (d >= 0) {
          final scale = landing(d, 1.8, 160);
          add(
            BattleFxBanner(
              text: end.winner == BattleSide.me
                  ? '상대가 나가서 이겼어요'
                  : '연결이 끊겨서 졌어요',
              top: 150,
              textSize: 28,
              tone: toneOf(end.winner),
              opacity: 1,
              font: BattleFxFont.display,
              rotation: -3,
              scaleX: scale,
              scaleY: scale,
            ),
          );
        }
      case BattleEndKind.timeUp:
        final time = BattleFx.pop(sinceEnd, 1000);
        if (time != null) {
          add(
            BattleFxBanner(
              text: 'TIME!',
              top: 157,
              textSize: 96,
              tone: BattleFxTone.plain,
              opacity: time.opacity,
              rotation: -5,
              scaleX: time.scale,
              scaleY: time.scale,
            ),
          );
        }
        final verdictAt = _verdictAt;
        if (verdictAt != null && now > verdictAt) {
          final scale = landing(now - verdictAt, 1.8, 160);
          add(
            BattleFxBanner(
              text: switch (end.winner) {
                BattleSide.me => 'WIN!',
                BattleSide.opponent => 'LOSE',
                null => 'DRAW',
              },
              top: 159,
              textSize: 88,
              tone: toneOf(end.winner),
              opacity: 1,
              rotation: -6,
              scaleX: scale,
              scaleY: scale,
            ),
          );
        }
    }
    return out;
  }

  /// The combo marks, the opponent's first: from a second valid rep in a
  /// row, for 1700 ms, popping in and fading over the last 200. A rep that
  /// did not count takes its side's mark down at once; none once the battle
  /// has ended.
  List<BattleFxCombo> _combos(double now) {
    if (_end != null) return const [];
    final out = <BattleFxCombo>[];
    for (final who in const [BattleSide.opponent, BattleSide.me]) {
      final side = _sides[who]!;
      final d = now - side.comboAt;
      if (side.combo < 2 || d < 0 || d >= 1700) continue;
      final opacity = d > 1500 ? (1700 - d) / 200 : 1.0;
      if (opacity <= 0.01) continue;
      final scale = d < 120 ? 0.6 + 0.4 * BattleFx.back(d / 120) : 1.0;
      // The inner end rises: my mark turns counterclockwise, the
      // opponent's clockwise.
      final sign = who == BattleSide.me ? 1.0 : -1.0;
      out.add(
        BattleFxCombo(
          side: who,
          count: side.combo,
          opacity: opacity,
          rotation: -6 * sign,
          scaleX: 0.72 * scale,
          scaleY: scale,
        ),
      );
    }
    return out;
  }
}
