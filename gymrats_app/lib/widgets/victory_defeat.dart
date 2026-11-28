import 'dart:math' as math;
import 'dart:ui' show Color, Offset, lerpDouble;

import '../models/character_idle_motion.dart';
import '../models/character_rig.dart';
import '../theme/app_theme.dart';
import 'battle_fx_motion.dart' show BattlePose;
import 'battle_stage_model.dart' show BattleSide;
import 'character_motion.dart' show MotionEase;
import 'victory_motion.dart';
import 'victory_scene.dart';

/// The scenes of a loss and a draw over the battle report (A7, the design
/// `LdA.dc.html`, "거울 컷인"). They take the place of the W5 rig's rule that
/// a loss and a draw are the same frustration on the seat
/// (`scene.lose.rule` in `victory_rig_data.dart`, which stays the bundle's
/// file).
///
/// A loss is the win's cut-in in red: a red panel shuts down from the top
/// with white rain on its stripes, my character drops in 2.2 times its size
/// and frustrates (the W5 `frustrate` motion), the band 패배 comes in from
/// the left and sags, then the panel and the character shrink onto the
/// seat's white stand (the loss's end look as before).
///
/// A draw has no frustration and no 패배: a lime half and a pink half meet
/// on a slant, my character and the opponent hop in and bump fists (a spark,
/// a shake), spring back into the battle stage's guard pose, the band 무승부
/// drops in, the opponent leaves to the right, and mine sits on a stand
/// half lime and half pink.
///
/// The values are the design's `renderVals()` as they are, in its 360 x 780
/// points and in ms from the moment the report opens. They go on other
/// screens as the win's do ([VictoryLayout]): the panels fill the screen,
/// the big scene is the design's screen scaled to fit, and the end follows
/// the seat.
abstract final class VictoryDefeat {
  /// Both scenes end at 2000 ms, whatever the character.
  static const endMs = 2000.0;

  /// The panels come in over 0 to [panelInMs]. The loss's shutter edge ends
  /// [shutterPast] below the screen (860 on 780) and leans [shutterLean]
  /// either way, lower on the left.
  static const panelInMs = 300.0;
  static const shutterPast = 80.0;
  static const shutterLean = 60.0;

  /// The draw's halves start [splitFrom] outside their sides and meet in
  /// the middle; their edges lean [splitLean] either way. The ink seam
  /// ([seamWidth] wide) shows from [seamFromMs].
  static const splitFrom = 40.0;
  static const splitLean = 36.0;
  static const seamFromMs = 280.0;
  static const seamWidth = 5.0;

  /// The way out: the panels shrink into the seat's rectangle (the win's)
  /// from [outFromMs] for [panelShrinkMs] and fade from [panelFadeFromMs]
  /// for [panelFadeMs]; my character goes to the seat over [seatMs].
  static const outFromMs = 1500.0;
  static const panelShrinkMs = 420.0;
  static const panelFadeFromMs = 1780.0;
  static const panelFadeMs = 220.0;
  static const seatMs = 500.0;

  /// The stand opens from [standFromMs] for [standMs].
  static const standFromMs = 1800.0;
  static const standMs = 200.0;

  /// The characters show from [enterFromMs].
  static const enterFromMs = 120.0;

  // The loss.

  /// The panel: [AppColors.danger] with white stripes at [loseStripeAlpha]
  /// (the win's angle and widths).
  static const loseFill = AppColors.danger;
  static const loseStripeAlpha = 0.16;

  /// The rain: [rainCount] white streaks ([rainAlpha]) [rainSize] with
  /// corners [rainRadius], turned [rainTurnDeg] about their middles. Each
  /// falls through a loop of [rainLoop] from [rainTop], at 1 to 1.5 points a
  /// ms, and drifts left a quarter of its fall ([rainSlant]) from a place in
  /// a [rainSpread] wide band starting at [rainLeft].
  static const rainCount = 18;
  static const rainAlpha = 0.5;
  static const rainWidth = 3.0;
  static const rainHeight = 34.0;
  static const rainRadius = 2.0;
  static const rainTurnDeg = 14.0;
  static const rainLoop = 900.0;
  static const rainTop = -60.0;
  static const rainSpread = 440.0;
  static const rainLeft = -20.0;
  static const rainSlant = 0.25;

  /// My character falls from [fallTop] onto the big feet line (the W5
  /// rig's: y 640, x its `bigFootX`, 2.2 times) over [enterFromMs] to
  /// [landMs], easing in; the landing squashes it [thudWide] wider and
  /// [thudLow] lower over [thudMs]. The frustration's clock is
  /// [frustrateFromMs] at the landing and stops at [frustrateStopMs].
  static const fallTop = -60.0;
  static const landMs = 460.0;
  static const thudMs = 140.0;
  static const thudWide = 0.06;
  static const thudLow = 0.1;
  static const frustrateFromMs = 150.0;
  static const frustrateStopMs = 760.0;

  /// The band 패배 slides in from [loseBandSlide] to the left from
  /// [loseBandFromMs] over [bandInMs], turned [loseBandTurnDeg]; from
  /// [sagFromMs] over [sagMs] it sags [sagDrop] and turns [sagTurnDeg]
  /// more; from [outFromMs] over [bandOutMs] it drops [loseBandDrop] and
  /// fades.
  static const loseBandFromMs = 320.0;
  static const bandInMs = 300.0;
  static const loseBandSlide = 440.0;
  static const loseBandTurnDeg = 4.0;
  static const sagFromMs = 1050.0;
  static const sagMs = 250.0;
  static const sagDrop = 14.0;
  static const sagTurnDeg = 5.0;
  static const bandOutMs = 180.0;
  static const loseBandDrop = 40.0;

  // The draw.

  /// The halves: lime with the win's stripes, pink ([AppColors.opponent])
  /// with white stripes at [pinkStripeAlpha] the other way
  /// ([pinkStripeAngleDeg]).
  static const pinkFill = AppColors.opponent;
  static const pinkStripeAlpha = 0.28;
  static const pinkStripeAngleDeg = 65.0;

  /// The fighters stand [fighterScale] times their size with their feet on
  /// y [fighterFootY]. They hop in ([hopUp] high, one hop per [hopMs]) from
  /// [meFromX] and [opponentFromX] to [meNearX] and [opponentNearX] until
  /// [landMs], close in until [punchMs] (fists out from [attackFromMs]), keep
  /// their fists together until [springFromMs], and spring back ([springUp]
  /// high) to [meBackX] and [opponentBackX] by [guardFromMs]. Fists meet in
  /// the middle: each stands [fistReach] times its scale from it.
  static const fighterScale = 1.3;
  static const fighterFootY = 610.0;
  static const fistReach = 81.0;
  static const meFromX = -120.0;
  static const opponentFromX = 480.0;
  static const meNearX = 64.0;
  static const opponentNearX = 296.0;
  static const meBackX = 58.0;
  static const opponentBackX = 302.0;
  static const hopUp = 10.0;
  static const hopMs = 170.0;
  static const attackFromMs = 500.0;
  static const punchMs = 520.0;
  static const springFromMs = 640.0;
  static const springUp = 16.0;
  static const guardFromMs = 880.0;

  /// From [outFromMs] the opponent leaves to [opponentGoneX] over
  /// [opponentOutMs], easing in, and fades.
  static const opponentGoneX = 470.0;
  static const opponentOutMs = 300.0;

  /// The spark where the fists meet: [sparkUp] times the fighters' scale
  /// above their feet, from [punchMs] to [sparkGoneMs]. It grows from 0.3
  /// to 1.15 until [sparkPeakMs], then to 1.35 while it fades, turning 12
  /// and then 10 more degrees.
  static const sparkUp = 55.0;
  static const sparkPeakMs = 600.0;
  static const sparkGoneMs = 780.0;

  /// The shake of the characters' layer: [shakeAmp] points across, [shakeRate]
  /// radians a ms, dying out from [punchMs] over [shakeMs].
  static const shakeAmp = 6.0;
  static const shakeRate = 0.35;
  static const shakeMs = 160.0;

  /// The band 무승부 drops [drawBandDrop] from above from [drawBandFromMs]
  /// over [bandInMs], overshooting a little, turned [drawBandTurnDeg]; from
  /// [outFromMs] it rises [drawBandRise] and fades.
  static const drawBandFromMs = 700.0;
  static const drawBandDrop = 300.0;
  static const drawBandTurnDeg = -2.0;
  static const drawBandRise = 24.0;

  /// The band's words.
  static const loseWords = '패배';
  static const drawWords = '무승부';

  /// The spark's shape in its own points about its middle (the design's
  /// SVG): eight rays from [sparkRays], ink [sparkRayWidth] with round ends,
  /// and a white sixteen-point star [sparkStar] with an ink edge
  /// [sparkEdgeWidth].
  static const sparkRays = [
    (Offset(21.4, -51.7), Offset(32.1, -77.6)),
    (Offset(51.7, -21.4), Offset(77.6, -32.1)),
    (Offset(51.7, 21.4), Offset(77.6, 32.1)),
    (Offset(21.4, 51.7), Offset(32.1, 77.6)),
    (Offset(-21.4, 51.7), Offset(-32.1, 77.6)),
    (Offset(-51.7, 21.4), Offset(-77.6, 32.1)),
    (Offset(-51.7, -21.4), Offset(-77.6, -32.1)),
    (Offset(-21.4, -51.7), Offset(-32.1, -77.6)),
  ];
  static const sparkRayWidth = 4.0;
  static const sparkStar = [
    Offset(0, -46),
    Offset(7.3, -17.6),
    Offset(32.5, -32.5),
    Offset(17.6, -7.3),
    Offset(46, 0),
    Offset(17.6, 7.3),
    Offset(32.5, 32.5),
    Offset(7.3, 17.6),
    Offset(0, 46),
    Offset(-7.3, 17.6),
    Offset(-32.5, 32.5),
    Offset(-17.6, 7.3),
    Offset(-46, 0),
    Offset(-17.6, -7.3),
    Offset(-32.5, -32.5),
    Offset(-7.3, -17.6),
  ];
  static const sparkEdgeWidth = 3.0;

  /// White at [alpha], for the stripes and the rain.
  static Color white(double alpha) => AppColors.card.withValues(alpha: alpha);
}

/// A loss's and a draw's frames of a [VictoryScene].
extension VictoryDefeatScene on VictoryScene {
  bool get _draw => result == VictoryResult.draw;

  /// The scene [tMs] ms after the report opened; the end look from
  /// [VictoryDefeat.endMs] on (1.2 s later with the rank ladder's hold,
  /// whose way out reads [heldTime]).
  VictoryFrame defeatAt(double tMs) {
    if (tMs >= endMs) return end;
    final t = math.max(0.0, tMs);
    final b = heldTime(t);
    if (_draw) {
      return VictoryFrame(
        stand: _standAt(b),
        panel: b >= VictoryDefeat.outFromMs
            ? _shrink(b, _split(1, seam: true))
            : _split(
                _eo(t / VictoryDefeat.panelInMs),
                seam: t >= VictoryDefeat.seamFromMs,
              ),
        fighters: _fighters(t, b),
        spark: _spark(t),
        shake: _shake(t),
        band: _drawBand(t, b),
      );
    }
    return VictoryFrame(
      stand: _standAt(b),
      panel: b >= VictoryDefeat.outFromMs
          ? _shrink(b, const VictoryShutter())
          : _shutter(t),
      rain: _rain(t),
      figure: _falling(t, b),
      band: _loseBand(t, b),
    );
  }

  /// A draw's end look: my character alone on the seat in the guard pose,
  /// on the lime and pink stand.
  VictoryFrame get drawEnd => VictoryFrame(
    stand: defeatStand(1),
    fighters: [
      _fighter(
        characterId: character.id,
        side: BattleSide.me,
        foot: layout.nearSeat(rig.scene.seatFoot),
        scale: rig.scene.seatScale,
        pose: BattlePose.idle,
      ),
    ],
  );

  /// The stand opened [k] of the way: white for a loss, half lime and half
  /// pink for a draw.
  VictoryStand defeatStand(double k) => VictoryStand(
    rect: layout.rectNearSeat(rig.scene.stand.rect),
    color: _draw ? AppColors.accent : rig.scene.stand.lose,
    rightColor: _draw ? AppColors.opponent : null,
    scaleX: k,
    opacity: k,
  );

  VictoryStand? _standAt(double t) => t < VictoryDefeat.standFromMs
      ? null
      : defeatStand(
          _eo((t - VictoryDefeat.standFromMs) / VictoryDefeat.standMs),
        );

  /// The panels shrinking into the seat (the win's rectangle) with [inner]
  /// inside.
  VictoryShrink _shrink(double t, VictoryPanel inner) {
    final size = layout.size;
    final e = _eio((t - VictoryDefeat.outFromMs) / VictoryDefeat.panelShrinkMs);
    final last = layout.rectNearSeat(rig.scene.panel.seatRect);
    return VictoryShrink(
      e: e,
      top: last.top * e,
      right: (size.width - last.right) * e,
      bottom: (size.height - last.bottom) * e,
      left: last.left * e,
      radius: rig.scene.panel.seatRadius * e,
      opacity:
          1 -
          _clamp(
            (t - VictoryDefeat.panelFadeFromMs) / VictoryDefeat.panelFadeMs,
          ),
      inner: inner,
    );
  }

  /// The red panel coming down: above a leaning edge until it has come in,
  /// then the whole screen.
  VictoryShutter _shutter(double t) {
    if (t >= VictoryDefeat.panelInMs) return const VictoryShutter();
    final size = layout.size;
    const lean = VictoryDefeat.shutterLean;
    final y =
        (size.height + VictoryDefeat.shutterPast) *
        _eo(t / VictoryDefeat.panelInMs);
    return VictoryShutter(
      polygon: [
        Offset.zero,
        Offset(size.width, 0),
        Offset(size.width, y - lean),
        Offset(0, y + lean),
      ],
    );
  }

  /// The halves [e] of the way in: each left (lime) or right (pink) of an
  /// edge leaning the same way, meeting in the middle at 1.
  VictorySplit _split(double e, {required bool seam}) {
    final width = layout.size.width;
    final height = layout.size.height;
    const lean = VictoryDefeat.splitLean;
    final travel = width / 2 + VictoryDefeat.splitFrom;
    final left = -VictoryDefeat.splitFrom + travel * e;
    final right = width + VictoryDefeat.splitFrom - travel * e;
    return VictorySplit(
      lime: [
        Offset.zero,
        Offset(left + lean, 0),
        Offset(left - lean, height),
        Offset(0, height),
      ],
      pink: [
        Offset(right + lean, 0),
        Offset(width, 0),
        Offset(width, height),
        Offset(right - lean, height),
      ],
      seam: seam
          ? (
              top: Offset(width / 2 + lean, 0),
              bottom: Offset(width / 2 - lean, height),
            )
          : null,
    );
  }

  /// The rain at [t], in the design's points.
  List<VictoryRaindrop> _rain(double t) => [
    for (var i = 0; i < VictoryDefeat.rainCount; i++)
      () {
        final speed = 1 + _random(i, 3) * 0.5;
        final y =
            (_random(i, 2) * VictoryDefeat.rainLoop + t * speed) %
                VictoryDefeat.rainLoop +
            VictoryDefeat.rainTop;
        final x =
            _random(i, 1) * VictoryDefeat.rainSpread +
            VictoryDefeat.rainLeft -
            y * VictoryDefeat.rainSlant;
        return VictoryRaindrop(topLeft: Offset(x, y));
      }(),
  ];

  /// My character falling, frustrating big, and going to the seat ([b] the
  /// way-out time).
  VictoryFigure? _falling(double t, double b) {
    if (t < VictoryDefeat.enterFromMs) return null;
    final values = rig.scene;
    final motion = character.frustrate;
    final bigScale = values.bigScale * layout.designScale;
    if (t < VictoryDefeat.landMs) {
      final u = _clamp(
        (t - VictoryDefeat.enterFromMs) /
            (VictoryDefeat.landMs - VictoryDefeat.enterFromMs),
      );
      final y =
          VictoryDefeat.fallTop +
          (values.bigFootY - VictoryDefeat.fallTop) * _ei(u);
      return VictoryFigure(
        foot: layout.fromDesign(Offset(character.bigFootX, y)),
        scale: bigScale,
        opacity: 1,
        motion: VictoryMotionKind.frustrate,
        timeMs: 0,
        endBlend: 0,
        frame: motion.frameAt(0),
      );
    }
    final time = math
        .min(
          VictoryDefeat.frustrateStopMs,
          VictoryDefeat.frustrateFromMs + (t - VictoryDefeat.landMs),
        )
        .roundToDouble();
    final big = layout.fromDesign(Offset(character.bigFootX, values.bigFootY));
    // Big until the way out, held or not.
    if (t < outFromMs) {
      final w = t < VictoryDefeat.landMs + VictoryDefeat.thudMs
          ? math.sin(
              math.pi * (t - VictoryDefeat.landMs) / VictoryDefeat.thudMs,
            )
          : 0.0;
      return VictoryFigure(
        foot: big,
        scale: bigScale,
        stretchX: 1 + VictoryDefeat.thudWide * w,
        stretchY: 1 - VictoryDefeat.thudLow * w,
        opacity: 1,
        motion: VictoryMotionKind.frustrate,
        timeMs: time,
        endBlend: 0,
        frame: motion.frameAt(time),
      );
    }
    final e = _eio((b - VictoryDefeat.outFromMs) / VictoryDefeat.seatMs);
    return VictoryFigure(
      foot: Offset.lerp(big, layout.nearSeat(values.seatFoot), e)!,
      scale: lerpDouble(bigScale, values.seatScale, e)!,
      opacity: 1,
      motion: VictoryMotionKind.frustrate,
      timeMs: time,
      endBlend: 0,
      frame: motion.frameAt(time),
    );
  }

  VictoryBand? _loseBand(double t, double b) {
    if (t < VictoryDefeat.loseBandFromMs ||
        b >= VictoryDefeat.outFromMs + VictoryDefeat.bandOutMs) {
      return null;
    }
    final sag = _eio((t - VictoryDefeat.sagFromMs) / VictoryDefeat.sagMs);
    final out = _clamp((b - VictoryDefeat.outFromMs) / VictoryDefeat.bandOutMs);
    final lift = bandLiftAt(t);
    return VictoryBand(
      text: VictoryDefeat.loseWords,
      dx:
          -VictoryDefeat.loseBandSlide *
          (1 -
              _eo((t - VictoryDefeat.loseBandFromMs) / VictoryDefeat.bandInMs)),
      dy:
          VictoryDefeat.sagDrop * sag +
          VictoryDefeat.loseBandDrop * out -
          VictoryTimes.bandLift * lift,
      rotDeg: VictoryDefeat.loseBandTurnDeg + VictoryDefeat.sagTurnDeg * sag,
      opacity: 1 - out,
      scale: 1 - VictoryTimes.bandShrink * lift,
    );
  }

  /// The two fighters, the opponent first (mine is drawn over it); [b] is
  /// the way-out time.
  List<VictoryFighter> _fighters(double t, double b) {
    if (t < VictoryDefeat.enterFromMs) return const [];
    const s = VictoryDefeat.fighterScale;
    const middle = 180.0;
    const meClose = middle - VictoryDefeat.fistReach * s;
    const opponentClose = middle + VictoryDefeat.fistReach * s;
    double lerp(double a, double b, double u) => a + (b - a) * u;
    double meX;
    double opponentX;
    var up = 0.0;
    var pose = BattlePose.idle;
    if (t < VictoryDefeat.landMs) {
      final u = _eo(
        (t - VictoryDefeat.enterFromMs) /
            (VictoryDefeat.landMs - VictoryDefeat.enterFromMs),
      );
      meX = lerp(VictoryDefeat.meFromX, VictoryDefeat.meNearX, u);
      opponentX = lerp(
        VictoryDefeat.opponentFromX,
        VictoryDefeat.opponentNearX,
        u,
      );
      up =
          VictoryDefeat.hopUp *
          math
              .sin(
                math.pi * (t - VictoryDefeat.enterFromMs) / VictoryDefeat.hopMs,
              )
              .abs();
    } else if (t < VictoryDefeat.punchMs) {
      final u = _eio(
        (t - VictoryDefeat.landMs) /
            (VictoryDefeat.punchMs - VictoryDefeat.landMs),
      );
      meX = lerp(VictoryDefeat.meNearX, meClose, u);
      opponentX = lerp(VictoryDefeat.opponentNearX, opponentClose, u);
      if (t >= VictoryDefeat.attackFromMs) pose = BattlePose.attack;
    } else if (t < VictoryDefeat.springFromMs) {
      meX = meClose;
      opponentX = opponentClose;
      pose = BattlePose.attack;
    } else if (t < VictoryDefeat.guardFromMs) {
      final u = _clamp(
        (t - VictoryDefeat.springFromMs) /
            (VictoryDefeat.guardFromMs - VictoryDefeat.springFromMs),
      );
      meX = lerp(meClose, VictoryDefeat.meBackX, _eo(u));
      opponentX = lerp(opponentClose, VictoryDefeat.opponentBackX, _eo(u));
      up = VictoryDefeat.springUp * math.sin(math.pi * u);
    } else {
      meX = VictoryDefeat.meBackX;
      opponentX = VictoryDefeat.opponentBackX;
    }
    const footY = VictoryDefeat.fighterFootY;
    final scale = s * layout.designScale;
    var meFoot = layout.fromDesign(Offset(meX, footY - up));
    var meScale = scale;
    var opponentFoot = layout.fromDesign(Offset(opponentX, footY - up));
    var opponentOpacity = 1.0;
    if (t >= outFromMs) {
      final e = _eio((b - VictoryDefeat.outFromMs) / VictoryDefeat.seatMs);
      meFoot = Offset.lerp(
        layout.fromDesign(const Offset(VictoryDefeat.meBackX, footY)),
        layout.nearSeat(rig.scene.seatFoot),
        e,
      )!;
      meScale = lerpDouble(scale, rig.scene.seatScale, e)!;
      final q = _clamp(
        (b - VictoryDefeat.outFromMs) / VictoryDefeat.opponentOutMs,
      );
      opponentFoot = layout.fromDesign(
        Offset(
          lerp(
            VictoryDefeat.opponentBackX,
            VictoryDefeat.opponentGoneX,
            _ei(q),
          ),
          footY,
        ),
      );
      opponentOpacity = 1 - q;
    }
    // In guard after springing back, until the way out: the stage's idle
    // motion, both on one clock (the design's live ChB).
    final idleMs =
        pose == BattlePose.idle &&
            t >= VictoryDefeat.guardFromMs &&
            t < outFromMs
        ? t - VictoryDefeat.guardFromMs
        : null;
    return [
      if (opponentOpacity > 0)
        _fighter(
          characterId: opponentId,
          side: BattleSide.opponent,
          foot: opponentFoot,
          scale: scale,
          pose: pose,
          mirrored: true,
          opacity: opponentOpacity,
          idleMs: idleMs,
        ),
      _fighter(
        characterId: character.id,
        side: BattleSide.me,
        foot: meFoot,
        scale: meScale,
        pose: pose,
        idleMs: idleMs,
      ),
    ];
  }

  VictoryFighter _fighter({
    required String characterId,
    required BattleSide side,
    required Offset foot,
    required double scale,
    required BattlePose pose,
    bool mirrored = false,
    double opacity = 1,
    double? idleMs,
  }) => VictoryFighter(
    characterId: characterId,
    side: side,
    foot: foot,
    scale: scale,
    mirrored: mirrored,
    opacity: opacity,
    pose: pose,
    idle: idleMs == null
        ? IdleSample.rest
        : CharacterRig.standard.art(characterId).idleMotion.sampleAt(idleMs),
  );

  VictorySpark? _spark(double t) {
    if (t < VictoryDefeat.punchMs || t >= VictoryDefeat.sparkGoneMs) {
      return null;
    }
    final a = _clamp(
      (t - VictoryDefeat.punchMs) /
          (VictoryDefeat.sparkPeakMs - VictoryDefeat.punchMs),
    );
    final b = _clamp(
      (t - VictoryDefeat.sparkPeakMs) /
          (VictoryDefeat.sparkGoneMs - VictoryDefeat.sparkPeakMs),
    );
    return VictorySpark(
      center: const Offset(
        180,
        VictoryDefeat.fighterFootY -
            VictoryDefeat.sparkUp * VictoryDefeat.fighterScale,
      ),
      rotDeg: 12 * a + 10 * b,
      scale: t < VictoryDefeat.sparkPeakMs
          ? 0.3 + 0.85 * _eo(a)
          : 1.15 + 0.2 * b,
      opacity: 1 - b,
    );
  }

  double _shake(double t) {
    if (t < VictoryDefeat.punchMs ||
        t >= VictoryDefeat.punchMs + VictoryDefeat.shakeMs) {
      return 0;
    }
    final since = t - VictoryDefeat.punchMs;
    return VictoryDefeat.shakeAmp *
        math.sin(since * VictoryDefeat.shakeRate) *
        (1 - _clamp(since / VictoryDefeat.shakeMs));
  }

  VictoryBand? _drawBand(double t, double b) {
    if (t < VictoryDefeat.drawBandFromMs ||
        b >= VictoryDefeat.outFromMs + VictoryDefeat.bandOutMs) {
      return null;
    }
    final out = _clamp((b - VictoryDefeat.outFromMs) / VictoryDefeat.bandOutMs);
    final lift = bandLiftAt(t);
    final y =
        -VictoryDefeat.drawBandDrop *
        (1 -
            _back((t - VictoryDefeat.drawBandFromMs) / VictoryDefeat.bandInMs));
    return VictoryBand(
      text: VictoryDefeat.drawWords,
      dx: 0,
      dy: y - VictoryDefeat.drawBandRise * out - VictoryTimes.bandLift * lift,
      rotDeg: VictoryDefeat.drawBandTurnDeg,
      opacity: 1 - out,
      scale: 1 - VictoryTimes.bandShrink * lift,
    );
  }
}

/// The design's repeatable random number for streak [i], use [k] (0 to 1).
double _random(int i, int k) {
  final x = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

double _clamp(double x) => x.clamp(0.0, 1.0);

double _eo(double x) => MotionEase.eo.at(_clamp(x));

double _eio(double x) => MotionEase.eio.at(_clamp(x));

double _ei(double x) => MotionEase.ei.at(_clamp(x));

/// The overshoot: 1 + 2.70158 (x - 1)^3 + 1.70158 (x - 1)^2.
double _back(double x) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final d = _clamp(x) - 1;
  return 1 + c3 * d * d * d + c1 * d * d;
}
