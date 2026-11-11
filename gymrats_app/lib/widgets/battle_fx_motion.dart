import 'dart:math' as math;

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

/// Where a band sits across the stage.
enum BattleFxAlign { left, center, right }

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

  /// The top of the band texts.
  static const bandTop = 132.0;

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

  /// 0 at [a], 1 at [b], straight in between.
  static double seg(double d, double a, double b) =>
      d <= a ? 0 : (d >= b ? 1 : (d - a) / (b - a));

  /// Slows down at the end.
  static double easeOut(double x) {
    final y = 1 - x.clamp(0.0, 1.0);
    return 1 - y * y * y;
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
  });

  final String text;
  final BattleFxTone tone;
  final double centerX;
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
    required this.points,
    required this.scale,
    required this.rotation,
    required this.opacity,
  });

  final RejectReason reason;

  /// Whether the rep still earned average points: an amber band with the
  /// points, instead of a red one.
  final bool average;
  final int points;
  final double scale;
  final double rotation;
  final double opacity;

  /// The label, e.g. "무릎 떼기" or "더 깊게 +5".
  String get text =>
      average ? '${reason.signLabel} +$points' : reason.signLabel;

  BattleFxTone get tone => average ? BattleFxTone.average : BattleFxTone.danger;
}

/// One slanted band of text over the stage.
class BattleFxBanner {
  const BattleFxBanner({
    required this.text,
    required this.top,
    required this.textSize,
    required this.tone,
    required this.opacity,
    this.font = BattleFxFont.number,
    this.align = BattleFxAlign.center,
    this.dx = 0,
    this.dy = 0,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
  });

  final String text;
  final double top;
  final double textSize;
  final BattleFxTone tone;
  final double opacity;
  final BattleFxFont font;
  final BattleFxAlign align;

  /// Moved by this much, then turned by [rotation] and sized by [scaleX] and
  /// [scaleY] around the band's own anchor ([align]) at mid height.
  final double dx;
  final double dy;
  final double rotation;
  final double scaleX;
  final double scaleY;
}

/// 결과 보기 coming up over the camera once the ending has played.
class BattleFxResultButton {
  const BattleFxResultButton({
    required this.opacity,
    required this.scale,
    required this.scrim,
  });

  final double opacity;
  final double scale;

  /// How strongly the camera area is covered with the background color.
  final double scrim;
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
  final List<BattleFxBanner> banners;

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

  /// When this side's "MISS" pops up.
  double missAt = double.negativeInfinity;
}

class _Sign {
  const _Sign(this.at, this.reason, this.average, this.points);

  final double at;
  final RejectReason reason;
  final bool average;
  final int points;
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
  BattleFxTimeline({double share = 0.5, this.feverMultiplier = 2})
    : _shareFrom = share.clamp(0.0, 1.0),
      _shareTarget = share.clamp(0.0, 1.0);

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

  bool _setup = false;
  bool _meReady = false;
  bool _opponentReady = false;
  double? _countEnd;

  /// Whether the user is far enough behind to lose soon.
  bool danger = false;

  /// Whether the opponent's connection is down, before it counts as leaving.
  bool opponentGone = false;

  /// The ending being played, if any.
  BattleStageEnd? get end => _end;

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
  /// later, or a swing that misses. Nothing plays once the battle has ended.
  void rep(BattleStageEvent event, double now) {
    if (_end != null) return;
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
      side.missAt = double.negativeInfinity;
    } else {
      side.act = _Act(_ActKind.miss, now, power);
      side.missAt = now + 110;
    }
    // The sign is only for the user's own rep that did not count; the latest
    // one replaces the one before, and one without a reason shows none.
    if (event.side == BattleSide.me && !event.counted) {
      final reason = event.reason;
      _sign = reason == null
          ? null
          : _Sign(now, reason, event.grade == GameGrade.average, event.points);
    }
    // Only a blow that lands can knock out.
    if (event.knockout && power > 0) {
      _hit!.power = 2.4;
      _end = BattleStageEnd(kind: BattleEndKind.knockout, winner: event.side);
      _endAt = impact;
      _decidedAt = impact;
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
    if (!settles) _endAt = now;
    _decidedAt = end.decided ? now : null;
  }

  /// Before the round: who has finished setting up. Setting up again stops a
  /// countdown that was running (a player left the ready pose). [active] is
  /// false once the countdown or the round is on.
  void setSetup({
    required bool active,
    bool meReady = false,
    bool opponentReady = false,
  }) {
    _setup = active;
    _meReady = meReady;
    _opponentReady = opponentReady;
    if (active) _countEnd = null;
  }

  /// Counts down to the start, [remaining] from [now], and ends the setup.
  /// The round starts, and "GO!" shows, when it reaches zero.
  ///
  /// Called again while counting, it follows a start that really moved and
  /// keeps its own clock for a small correction. Once the round has started
  /// it does nothing. [remaining] must be exact to the millisecond (online:
  /// the start time minus the server's time now), not whole seconds, or the
  /// numbers jump.
  void countDown(double remaining, double now) {
    final running = _countEnd;
    if (running != null && now >= running) return;
    _setup = false;
    final end = now + remaining;
    if (running == null || (end - running).abs() > _countSlack) {
      _countEnd = end;
    }
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

  /// The frame at [now]. With [reducedMotion] the hit-stop, the shake, the
  /// zoom, the flash, the breathing, the stripes' drift, the count bump, the
  /// countdown's growing numbers, the puff and the button's growing are off;
  /// poses, scores, bands, the sign and the button stay.
  BattleFxFrame frame(double now, {bool reducedMotion = false}) {
    final end = _end;
    final endKind = end?.kind;
    final sinceEnd = now - _endAt;
    final countEnd = _countEnd;
    final counting = countEnd != null && now < countEnd;
    final beforeStart = _setup || counting;
    final inDanger = danger && end == null && !beforeStart;
    final meetX = BattleFx.meetX(_shareAt(now));
    final breath = reducedMotion ? 0.0 : math.sin(now / 280) * 0.02;

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
      if (who == BattleSide.me && inDanger && m.pose == BattlePose.idle) {
        rotation += -7 + math.sin(now / 85) * 6;
      }
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
      return BattleFxFighter(
        pose: m.pose,
        footX: x + dx,
        footY: BattleFx.groundY + dy,
        rotation: rotation,
        scaleX: dir * scale,
        scaleY: scale * (m.pose == BattlePose.idle ? 1 + breath : 1),
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

    // More than three seconds before the start both stand ready; the
    // numbers take over from there.
    final earlyCount = counting && countEnd - now > 3000;
    final showTags = _setup || earlyCount;
    final meReady = earlyCount || _meReady;
    final opponentReady = earlyCount || _opponentReady;
    BattleFxTag readyTag(BattleSide who, bool ready, double centerX) =>
        BattleFxTag(
          text: ready ? '준비 완료' : '세팅 중',
          tone: !ready
              ? BattleFxTone.plain
              : (who == BattleSide.me
                    ? BattleFxTone.me
                    : BattleFxTone.opponent),
          centerX: centerX,
        );
    final opponentX = meetX + BattleFx.reach;
    final BattleFxTag? opponentTag;
    if (showTags) {
      opponentTag = readyTag(BattleSide.opponent, opponentReady, opponentX);
    } else if (opponentGone && end == null) {
      opponentTag = BattleFxTag(
        text: '연결 끊김',
        tone: BattleFxTone.plain,
        centerX: opponentX,
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
        scrim:
            0.62 *
            BattleFx.easeOut(BattleFx.seg(now, buttonAt, buttonAt + 200)),
      );
    }

    final mine = _sides[BattleSide.me]!;
    final theirs = _sides[BattleSide.opponent]!;
    return BattleFxFrame(
      meetX: meetX,
      me: build(BattleSide.me),
      opponent: build(BattleSide.opponent),
      myTag: showTags
          ? readyTag(BattleSide.me, meReady, meetX - BattleFx.reach)
          : null,
      opponentTag: opponentTag,
      shakeX: shake.$1,
      shakeY: shake.$2,
      zoom: zoom,
      star: _star(now, meetX, reducedMotion),
      twinkle: twinkle,
      puff: puff,
      sign: _signAt(now),
      banners: _banners(now, counting, reducedMotion),
      myScoreBump: _bump(now - mine.scoreBumpAt, 280, 0.2),
      opponentScoreBump: _bump(now - theirs.scoreBumpAt, 280, 0.2),
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
    );
  }

  /// A number growing by [extra] and back over [length].
  static double _bump(double d, double length, double extra) =>
      d >= 0 && d < length ? 1 + extra * math.sin(d / length * math.pi) : 1;

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
      centerX: meetX + (hit.by == BattleSide.me ? 34 : -34),
      centerY: BattleFx.groundY - 76,
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
      points: sign.points,
      scale: d < 130 ? 0.6 + 0.4 * BattleFx.back(d / 130) : 1,
      rotation: d < 280 ? math.sin(d / 40) * 3 * (1 - d / 280) : 0,
      opacity: d > 1150 ? (1300 - d) / 150 : math.min(1, 0.5 + d / 80),
    );
  }

  List<BattleFxBanner> _banners(double now, bool counting, bool reducedMotion) {
    const top = BattleFx.bandTop;
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

    // A knockout clears the bands of the blow that caused it.
    final cleared = end?.kind == BattleEndKind.knockout && sinceEnd > 300;
    for (final who in BattleSide.values) {
      final sign = who == BattleSide.me ? 1.0 : -1.0;
      final side = _sides[who]!;
      final missed = now - side.missAt;
      final miss = cleared ? null : BattleFx.pop(missed, 760);
      if (miss != null) {
        add(
          BattleFxBanner(
            text: 'MISS',
            top: top + 14,
            textSize: 84,
            tone: BattleFxTone.plain,
            opacity: miss.opacity,
            dx: -sign * 56,
            dy: -missed * 0.02,
            rotation: sign * 7,
            scaleX: 0.78 * miss.scale,
            scaleY: miss.scale,
          ),
        );
      }
      // The points and the grade words of a blow follow spec v2.1.
      final combo = now - side.comboAt;
      if (end == null && side.combo >= 2 && combo >= 0 && combo < 1700) {
        final scale = combo < 120
            ? 0.6 + 0.4 * BattleFx.back(combo / 120)
            : 1.0;
        add(
          BattleFxBanner(
            text: '${side.combo} HIT',
            top: top + 4,
            textSize: 44,
            tone: BattleFxTone.plain,
            opacity: combo > 1500 ? (1700 - combo) / 200 : 1,
            align: who == BattleSide.me
                ? BattleFxAlign.left
                : BattleFxAlign.right,
            rotation: -6 * sign,
            scaleX: 0.72 * scale,
            scaleY: scale,
          ),
        );
      }
    }

    final fever = now - _feverAt;
    if (_fever && fever >= 0 && fever < 1300) {
      add(
        BattleFxBanner(
          text: BattleFx.feverText(feverMultiplier),
          top: top + 62,
          textSize: 80,
          tone: BattleFxTone.fever,
          opacity: 1,
          // In from the left, out to the right.
          dx: fever < 160
              ? -400 * (1 - BattleFx.easeOut(fever / 160))
              : (fever > 1100
                    ? 400 * BattleFx.easeOut((fever - 1100) / 200)
                    : 0),
          rotation: -5,
          scaleX: 0.7,
        ),
      );
    }

    if (_setup && (!_meReady || !_opponentReady)) {
      add(
        BattleFxBanner(
          text: _meReady ? '상대를 기다리는 중' : '자세 세팅 중',
          top: top + 16,
          textSize: 34,
          tone: BattleFxTone.plain,
          opacity: 1,
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
            top: top + 10,
            textSize: 190,
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
            top: top + 10,
            textSize: 150,
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
          final scale = landing(d, 2.4, 180);
          add(
            BattleFxBanner(
              text: 'K.O.',
              top: top - 4,
              textSize: 124,
              tone: toneOf(end.winner),
              opacity: 1,
              rotation: -7,
              scaleX: scale,
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
              top: top + 18,
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
              top: top + 26,
              textSize: 110,
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
              top: top,
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
}
