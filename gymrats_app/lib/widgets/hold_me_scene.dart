import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../models/character_rig.dart' show RigPoseTable;
import '../services/pose/hold_judge.dart' show HoldTiming;
import 'hold_me_rig.dart';
import 'victory_motion.dart' show blendPoseTables;

/// What the user's character is doing on a hold stage (A8 spec 4).
enum HoldMeKind {
  /// Before the time runs: the 3·2·1, and a chair pose's entry.
  go,

  /// Holding the pose.
  hold,

  /// Holding toward the last star, from 1.35 s after the second.
  strain,

  /// The 1.6 s after the first or the second star: the pop.
  star,

  /// Paused by a warning, or a second warning's end.
  warn,
}

/// One moment of the character: its [kind], and how far into it.
class HoldMeMoment {
  const HoldMeMoment.go()
    : kind = HoldMeKind.go,
      star = 0,
      ageMs = 0,
      sinceResumeMs = null;

  const HoldMeMoment.hold({this.sinceResumeMs})
    : kind = HoldMeKind.hold,
      star = 0,
      ageMs = 0;

  const HoldMeMoment.strain({this.sinceResumeMs})
    : kind = HoldMeKind.strain,
      star = 0,
      ageMs = 0;

  const HoldMeMoment.star(this.star, this.ageMs)
    : kind = HoldMeKind.star,
      sinceResumeMs = null;

  const HoldMeMoment.warn(this.ageMs)
    : kind = HoldMeKind.warn,
      star = 0,
      sinceResumeMs = null;

  final HoldMeKind kind;

  /// The star (1 or 2) of a [HoldMeKind.star] moment; 0 otherwise.
  final int star;

  /// Milliseconds since the star or the warning.
  final double ageMs;

  /// While holding again after a warning: milliseconds since the time ran
  /// again, for the way back to the hold pose; null once back.
  final double? sinceResumeMs;

  @override
  bool operator ==(Object other) =>
      other is HoldMeMoment &&
      other.kind == kind &&
      other.star == star &&
      other.ageMs == ageMs &&
      other.sinceResumeMs == sinceResumeMs;

  @override
  int get hashCode => Object.hash(kind, star, ageMs, sinceResumeMs);

  @override
  String toString() =>
      'HoldMeMoment(${kind.name}, $star, $ageMs, $sinceResumeMs)';
}

/// The times of the character's moments, in ms (A8 spec 4; the mockup's
/// `calc()` for `dir=a`, `act=pop`).
abstract final class HoldMeTimes {
  /// A star: the crouch, the hop's top at the middle, the landing's squash.
  static const crouch = 140.0;
  static const land = 780.0;
  static const settled = 950.0;

  /// The rays from the body, and the dust at the feet.
  static const sparkEnd = 640.0;
  static const dustEnd = 1150.0;

  /// The star's flight from the body to the bar: it lands as the bar star
  /// lights ([HoldTiming.starLands]).
  static const flyFrom = 220.0;
  static final flyTo = HoldTiming.starLands.inMilliseconds.toDouble();

  /// The chair pose's arms: up from [crouch] to [armsUp], down from
  /// [armsDownFrom] to [armsDown].
  static const armsUp = 300.0;
  static const armsDownFrom = 1100.0;
  static const armsDown = 1350.0;

  /// A star's moment, and when the second star's gives way to the strain.
  static const star = 1600.0;
  static const strainAfter = 1350.0;

  /// A warning's way into its pose (and back after it), and its jolt.
  static const warnRamp = 180.0;
  static const jolt = 420.0;

  /// The breathing's and the sweat's cycles.
  static const breath = 1500.0;
  static const sweat = 760.0;
}

/// Follows the play and says what the character is doing (A8 spec 4): fed
/// the play at each frame ([look]), it keeps when each star came, when a
/// warning began and when the time ran again. Pure, on a clock in ms given
/// from outside.
class HoldMeTimeline {
  HoldMeTimeline(this.starSeconds);

  /// The stage's stars, in seconds held.
  final List<int> starSeconds;

  final _starAt = <int, double>{};
  int? _earned;
  bool _counting = false;
  bool _entering = false;
  bool _stopped = false;
  double? _warnAt;
  double? _resumeAt;

  /// The play at [nowMs]: before GO ([counting]), entering the pose with
  /// the time not yet running ([entering]), paused or ended by a warning
  /// ([stopped]), the time [held], and whether the hold [ended].
  ///
  /// A star earned since the last look is a star moment from [nowMs],
  /// unless it is the last one or the hold ended with it; the stars earned
  /// before the first look have none, and a warning on at the first look
  /// shows in full.
  void look(
    double nowMs, {
    required bool counting,
    required bool entering,
    required bool stopped,
    required Duration held,
    required bool ended,
  }) {
    final earned = starSeconds
        .where((s) => held >= Duration(seconds: s))
        .length;
    final before = _earned;
    if (before != null && !ended) {
      for (var n = before + 1; n <= earned && n < starSeconds.length; n++) {
        _starAt[n] = nowMs;
      }
    }
    _earned = earned;
    if (stopped && !_stopped) {
      // A warning on already at the first look began before it: in full.
      _warnAt = before == null ? null : nowMs;
      _resumeAt = null;
    } else if (!stopped && _stopped) {
      _resumeAt = nowMs;
    }
    _counting = counting;
    _entering = entering;
    _stopped = stopped;
  }

  /// Milliseconds since star [n] (1-based) came at [nowMs]; null when it
  /// has not, or came before the first look.
  double? starAge(int n, double nowMs) {
    final at = _starAt[n];
    return at == null ? null : nowMs - at;
  }

  /// What the character is doing at [nowMs].
  HoldMeMoment momentAt(double nowMs) {
    if (_counting || _entering) return const HoldMeMoment.go();
    if (_stopped) {
      final at = _warnAt;
      return HoldMeMoment.warn(at == null ? double.infinity : nowMs - at);
    }
    final last = _starAt.keys.fold<int?>(
      null,
      (a, n) => a == null || n > a ? n : a,
    );
    final warnAt = _warnAt;
    if (last != null) {
      final at = _starAt[last]!;
      final age = nowMs - at;
      // A warning in a star's moment ends it for good (A8 spec 4).
      final cut = warnAt != null && warnAt >= at;
      final strain = last == 2 && age >= HoldMeTimes.strainAfter;
      if (age < HoldMeTimes.star && !cut && !strain) {
        return HoldMeMoment.star(last, age);
      }
    }
    final resumeAt = _resumeAt;
    final sinceResume = resumeAt == null ? null : nowMs - resumeAt;
    final back = sinceResume != null && sinceResume < HoldMeTimes.warnRamp
        ? sinceResume
        : null;
    final second = starAge(2, nowMs);
    final strained =
        (_earned ?? 0) >= 2 &&
        (second == null || second >= HoldMeTimes.strainAfter);
    return strained
        ? HoldMeMoment.strain(sinceResumeMs: back)
        : HoldMeMoment.hold(sinceResumeMs: back);
  }
}

/// A star's rays: about [at] in the box, [scale]d, [opacity].
typedef HoldMeSpark = ({Offset at, double scale, double opacity});

/// The landing's dust: [scaleX] across about x = 70, [opacity].
typedef HoldMeDust = ({double scaleX, double opacity});

/// A sweat drop: [at] in the box, turned [rotDeg], [scale]d, [opacity].
typedef HoldMeDrop = ({Offset at, double rotDeg, double scale, double opacity});

/// One picture of the character (A8 spec 4): the whole box's move about
/// the feet, the rig's pose or the drawing's turns, the expression and the
/// effects around it, all in the box's coordinates.
class HoldMeFrame {
  const HoldMeFrame({
    required this.place,
    this.jx = 0,
    this.hop = 0,
    this.sx = 1,
    this.sy = 1,
    required this.pose,
    required this.expression,
    this.tilt = 0,
    this.armSwing = 0,
    this.spark,
    this.dust,
    this.sweat = const [],
    this.shake = false,
  });

  final HoldMePlace place;

  /// Across and up, in the box's points; the scale about the feet.
  final double jx;
  final double hop;
  final double sx;
  final double sy;

  /// The rig's pose, blended between its key poses; null for a drawing.
  final RigPoseTable? pose;

  /// idle, atk, win, hit or grit (atk with the teeth, W5).
  final String expression;

  /// A drawing's warning look, 0 to 1: 곰탱이 tips forward, the lying ones
  /// flatten.
  final double tilt;

  /// How far a drawing's near arm (and head) has turned for a star, 0 to 1.
  final double armSwing;

  final HoldMeSpark? spark;
  final HoldMeDust? dust;
  final List<HoldMeDrop> sweat;

  /// Whether the strain's shake lines show either side of the body.
  final bool shake;

  /// The shadow's centre across and its width, shrinking as it hops.
  double get shadowX => place.standing ? 70 : 72;
  double get shadowRx => (place.standing ? 44 : 70) * (1 - hop / 50);

  /// A drawing's expression tags: grit is its atk face with the teeth.
  Set<String> get drawingTags =>
      expression == 'grit' ? const {'atk', 'teeth'} : {expression};

  /// The near arm's turn in degrees, and the head's.
  double get nearArmDeg => armSwing * (place.nearArm?.deg ?? 0);
  double get headDeg => armSwing * (place.headTilt?.deg ?? 0);

  /// The shake lines: two curves either side of the body, bowing outward
  /// (the mockup's `arc`), each as its start, control and end points.
  List<(Offset, Offset, Offset)> get shakeArcs {
    final centres = place.standing
        ? const [Offset(30, 70), Offset(112, 70)]
        : const [Offset(30, 126), Offset(116, 126)];
    return [
      for (final (i, c) in centres.indexed)
        ...() {
          final s = i == 0 ? 1.0 : -1.0;
          return [
            (
              Offset(c.dx - 5 * s, c.dy - 10),
              Offset(c.dx - 9 * s, c.dy),
              Offset(c.dx - 5 * s, c.dy + 10),
            ),
            (
              Offset(c.dx - 11 * s, c.dy - 7),
              Offset(c.dx - 14 * s, c.dy),
              Offset(c.dx - 11 * s, c.dy + 7),
            ),
          ];
        }(),
    ];
  }
}

/// When the owner's cheer and the bar's star show, by the time since the
/// star (A8 spec 5 to 7). A null age (a star that came before the stage
/// looked) shows them.
abstract final class HoldMeCheer {
  /// The cheer bubble: from 0.8 s to 2.4 s; with reduced motion at once
  /// for 1.6 s.
  static bool bubbleAt(double? ageMs, {bool still = false}) =>
      _from(ageMs, still, HoldTiming.cheerBubble);

  /// The owner's smile: from 0.7 s to 2.4 s; with reduced motion with the
  /// bubble.
  static bool smileAt(double? ageMs, {bool still = false}) =>
      _from(ageMs, still, HoldTiming.cheerSmile);

  /// The bar's star: lit once the flying star lands; with reduced motion at
  /// once.
  static bool litAt(double? ageMs, {bool still = false}) =>
      ageMs == null || still || ageMs >= _ms(HoldTiming.starLands);

  /// The bar's star pops from when it lights to the end of the star's
  /// moment; never with reduced motion.
  static bool popAt(double? ageMs, {bool still = false}) =>
      !still &&
      ageMs != null &&
      ageMs >= _ms(HoldTiming.starLands) &&
      ageMs < HoldMeTimes.star;

  static bool _from(double? ageMs, bool still, Duration from) {
    if (ageMs == null) return true;
    if (still) return ageMs < _ms(HoldTiming.cheerStill);
    return ageMs >= _ms(from) && ageMs < _ms(HoldTiming.cheer);
  }

  static double _ms(Duration d) => d.inMicroseconds / 1000;
}

/// The star flying from the character to its bar mark (A8 spec 4), on the
/// 360 x 390 stage: [at], turned [rotDeg], [scale]d, with its [trail]
/// behind.
typedef HoldMeFlight = ({
  Offset at,
  double rotDeg,
  double scale,
  List<Offset> trail,
});

/// The character's pictures (A8 spec 4, 7): the mockup's `calc()` for
/// `dir=a`, `act=pop`, `lie=a` in the app's moments.
abstract final class HoldMeScene {
  /// The breathing's height, the strain's shake, the star's hop.
  static const breath = 0.012;
  static const shakeAmp = 0.9;
  static const hopHeight = 16.0;

  /// The sweat drops' places in their cycle when nothing moves, and their
  /// ways out.
  static const stillSweat = [0.35, 0.62, 0.18];
  static const sweatWays = [
    Offset(-0.55, -0.85),
    Offset(0.25, -1),
    Offset(0.95, -0.35),
  ];

  /// How much of the sag (a plank) and the rise (the chair pose) a warning
  /// takes.
  static const sagShare = 0.85;
  static const riseShare = 0.45;

  /// [place] at [moment]. [liveMs] runs the breathing, the strain's shake
  /// and the sweat's cycle; null keeps them still, as the mockup's still
  /// pictures do. [still] (reduced motion) leaves only each moment's pose
  /// and expression (A8 spec 7).
  static HoldMeFrame frameAt(
    HoldMePlace place,
    HoldMeMoment moment, {
    double? liveMs,
    bool still = false,
  }) {
    final live = still ? null : liveMs;
    final keys = place.keyPoses;
    final drawn = place.drawing != null;
    RigPoseTable? pose = keys['hold'];
    var expression = switch (moment.kind) {
      HoldMeKind.go => 'idle',
      HoldMeKind.hold => 'atk',
      HoldMeKind.strain => 'grit',
      HoldMeKind.warn => 'hit',
      HoldMeKind.star => 'win',
    };
    var hop = 0.0, sx = 1.0, sy = 1.0, jx = 0.0, tilt = 0.0, swing = 0.0;
    HoldMeSpark? spark;
    HoldMeDust? dust;
    final kind = moment.kind;
    if (live != null &&
        (kind == HoldMeKind.go ||
            kind == HoldMeKind.hold ||
            kind == HoldMeKind.strain)) {
      sy *= 1 + breath * math.sin(2 * math.pi * live / HoldMeTimes.breath);
    }
    final strain = kind == HoldMeKind.strain;
    if (strain && live != null) {
      jx =
          shakeAmp *
          (math.sin(live * 0.75) * 0.7 + math.sin(live * 1.31) * 0.3);
    }
    // A warning's pose, [ramp] of the way: on a warning, and on the way back.
    void warned(double ramp) {
      if (drawn) {
        tilt = ramp;
      } else if (place.standing) {
        pose = blendPoseTables(keys['hold']!, keys['rise']!, riseShare * ramp);
      } else {
        pose = blendPoseTables(keys['hold']!, keys['sag']!, sagShare * ramp);
      }
    }

    switch (kind) {
      case HoldMeKind.warn:
        final t = moment.ageMs;
        warned(still ? 1 : _clamp(t / HoldMeTimes.warnRamp));
        if (!still && t.isFinite) {
          jx = 2.4 * math.sin(t * 0.09) * (1 - _clamp(t / HoldMeTimes.jolt));
        }
      case HoldMeKind.hold || HoldMeKind.strain:
        final back = moment.sinceResumeMs;
        if (back != null && !still) {
          warned(1 - _clamp(back / HoldMeTimes.warnRamp));
        }
      case HoldMeKind.star when still:
        // Reduced motion: the star's pose at once (the chair pose's arms
        // up), with its smile (user, 2026-11-26).
        if (place.standing) pose = keys['up'];
      case HoldMeKind.star:
        final t = moment.ageMs;
        if (t < HoldMeTimes.crouch) {
          sy *= 1 - 0.07 * t / HoldMeTimes.crouch;
          expression = 'atk';
        } else if (t < HoldMeTimes.land) {
          final v =
              (t - HoldMeTimes.crouch) /
              (HoldMeTimes.land - HoldMeTimes.crouch);
          hop = hopHeight * math.sin(math.pi * v);
          sy *= 1 + 0.03 * math.sin(math.pi * v);
          swing = math.sin(math.pi * v);
        } else if (t < HoldMeTimes.settled) {
          sy *=
              1 -
              0.08 *
                  math.sin(
                    math.pi *
                        (t - HoldMeTimes.land) /
                        (HoldMeTimes.settled - HoldMeTimes.land),
                  );
        }
        if (place.standing) {
          pose = blendPoseTables(keys['hold']!, keys['up']!, armsAt(t));
        }
        if (t >= HoldMeTimes.crouch && t < HoldMeTimes.sparkEnd) {
          final v =
              (t - HoldMeTimes.crouch) /
              (HoldMeTimes.sparkEnd - HoldMeTimes.crouch);
          spark = (at: place.spark, scale: 0.75 + 0.6 * v, opacity: 1 - v);
        }
        if (t >= HoldMeTimes.land && t < HoldMeTimes.dustEnd) {
          final v =
              (t - HoldMeTimes.land) / (HoldMeTimes.dustEnd - HoldMeTimes.land);
          dust = (scaleX: 0.7 + 0.5 * v, opacity: 1 - v);
        }
      case HoldMeKind.go:
        break;
    }
    final sweaty = strain || kind == HoldMeKind.warn;
    return HoldMeFrame(
      place: place,
      jx: jx,
      hop: hop,
      sx: sx,
      sy: sy,
      pose: drawn ? null : pose,
      expression: expression,
      tilt: tilt,
      armSwing: swing,
      spark: spark,
      dust: dust,
      sweat: sweaty ? _sweat(place.sweat, live) : const [],
      shake: strain,
    );
  }

  /// How far the chair pose's arms are up, [t] ms into a star.
  static double armsAt(double t) {
    if (t < HoldMeTimes.crouch) return 0;
    if (t < HoldMeTimes.armsUp) {
      return _eio(
        (t - HoldMeTimes.crouch) / (HoldMeTimes.armsUp - HoldMeTimes.crouch),
      );
    }
    if (t < HoldMeTimes.armsDownFrom) return 1;
    if (t < HoldMeTimes.armsDown) {
      return 1 -
          _eio(
            (t - HoldMeTimes.armsDownFrom) /
                (HoldMeTimes.armsDown - HoldMeTimes.armsDownFrom),
          );
    }
    return 0;
  }

  /// The hop's height [t] ms into a star (the flight leaves from it).
  static double hopAt(double t) {
    if (t < HoldMeTimes.crouch || t >= HoldMeTimes.land) return 0;
    return hopHeight *
        math.sin(
          math.pi *
              (t - HoldMeTimes.crouch) /
              (HoldMeTimes.land - HoldMeTimes.crouch),
        );
  }

  /// The star flying [ageMs] after it was earned from [place], whose box
  /// is at [top] on the stage, to its bar mark [target]; null outside its
  /// flight or with [still].
  static HoldMeFlight? flightAt(
    HoldMePlace place,
    double top,
    double ageMs,
    Offset target, {
    bool still = false,
  }) {
    final from = HoldMeTimes.flyFrom, to = HoldMeTimes.flyTo;
    if (still || ageMs < from || ageMs >= to) return null;
    final v = _eio((ageMs - from) / (to - from));
    final scale = place.scale;
    final start = Offset(
      place.left + place.spark.dx * scale,
      top + (place.spark.dy - 20) * scale - hopAt(ageMs),
    );
    final bend = Offset(
      (start.dx + target.dx) / 2 - 20,
      math.min(start.dy, target.dy) - 50,
    );
    Offset along(double w) {
      final a = 1 - w;
      return start * (a * a) + bend * (2 * a * w) + target * (w * w);
    }

    return (
      at: along(v),
      rotDeg: 360 * v,
      scale: 1.5 - 0.5 * v,
      trail: [
        for (final d in const [0.06, 0.12, 0.18]) along(math.max(0, v - d)),
      ],
    );
  }

  static List<HoldMeDrop> _sweat(Offset from, double? live) => [
    for (var i = 0; i < 3; i++)
      () {
        final q = live == null
            ? stillSweat[i]
            : ((live / HoldMeTimes.sweat + i / 3) % 1);
        final way = sweatWays[i];
        return (
          at: from + way * (4 + 16 * q),
          rotDeg: math.atan2(way.dx, -way.dy) * 180 / math.pi,
          scale: 0.75 + 0.35 * (1 - q),
          opacity: 1 - 0.75 * q,
        );
      }(),
  ];

  static double _eio(double x) =>
      x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

  static double _clamp(double x) => x.clamp(0.0, 1.0);
}
