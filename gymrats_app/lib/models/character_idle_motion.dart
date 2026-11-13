import 'dart:math' as math;

/// How a character moves while it stands in the idle pose (W3 spec 6,
/// "대기 움직임"): a hop up, a rock about the feet, and a stretch about the
/// feet. A period of 0 turns its part off.
class CharacterIdleMotion {
  const CharacterIdleMotion({
    this.hopAmp = 0,
    this.hopPeriodMs = 0,
    this.rockDeg = 0,
    this.rockPeriodMs = 0,
    this.stretch = 0,
    this.squash = 0,
    this.stretchPeriodMs = 0,
    this.stepped = false,
  });

  /// Reads the rig's `idleMotion` object; a missing value is 0 (or false).
  factory CharacterIdleMotion.fromJson(Map<String, dynamic> json) {
    double number(String key) => (json[key] as num? ?? 0).toDouble();
    return CharacterIdleMotion(
      hopAmp: number('hopAmp'),
      hopPeriodMs: number('hopPeriodMs'),
      rockDeg: number('rockDeg'),
      rockPeriodMs: number('rockPeriodMs'),
      stretch: number('stretch'),
      squash: number('squash'),
      stretchPeriodMs: number('stretchPeriodMs'),
      stepped: json['stepped'] as bool? ?? false,
    );
  }

  /// W2's breathing (`scaleY = 1 + 0.02 * sin(t / 280)`) in this form: the
  /// stage's motion when it is given no character's. The rig writes its
  /// period rounded (1759.29 ms); this is the exact one.
  static const w2Default = CharacterIdleMotion(
    stretch: 0.02,
    stretchPeriodMs: 2 * math.pi * 280,
  );

  /// Height of a hop in px, and the time of one hop (ground to ground).
  final double hopAmp;
  final double hopPeriodMs;

  /// Largest lean in degrees (forward is +) and the time of one rock.
  final double rockDeg;
  final double rockPeriodMs;

  /// How much taller ([stretch]) and narrower ([squash]) the body gets at
  /// the top of one stretch period.
  final double stretch;
  final double squash;
  final double stretchPeriodMs;

  /// The rock snaps from one side to the other instead of swaying (RepBot).
  final bool stepped;

  /// The motion at [tMs] on the stage clock, for a fighter facing right.
  IdleSample sampleAt(double tMs) {
    final up = hopPeriodMs == 0
        ? 0.0
        : hopAmp * math.sin(math.pi * tMs / hopPeriodMs).abs();
    var wave = rockPeriodMs == 0
        ? 0.0
        : math.sin(2 * math.pi * tMs / rockPeriodMs);
    if (stepped) wave = wave.sign;
    final breath = stretchPeriodMs == 0
        ? 0.0
        : math.sin(2 * math.pi * tMs / stretchPeriodMs);
    return IdleSample(
      up: up,
      rockDeg: rockDeg * wave,
      scaleX: 1 - squash * breath,
      scaleY: 1 + stretch * breath,
    );
  }
}

/// One moment of a [CharacterIdleMotion]: how far up (px), how far leaned
/// (degrees, clockwise for a fighter facing right) and how much sized, all
/// about the feet.
class IdleSample {
  const IdleSample({
    required this.up,
    required this.rockDeg,
    required this.scaleX,
    required this.scaleY,
  });

  /// No motion: the values for any pose but idle.
  static const rest = IdleSample(up: 0, rockDeg: 0, scaleX: 1, scaleY: 1);

  final double up;
  final double rockDeg;
  final double scaleX;
  final double scaleY;

  @override
  String toString() =>
      'IdleSample(up: $up, rockDeg: $rockDeg, scaleX: $scaleX, scaleY: $scaleY)';
}
