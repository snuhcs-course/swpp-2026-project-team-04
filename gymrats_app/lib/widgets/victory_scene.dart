import 'dart:math' as math;
import 'dart:ui' show Color, Offset, RRect, Radius, Rect, Size, lerpDouble;

import '../models/battle_result.dart';
import '../models/character_idle_motion.dart';
import '../models/character_rig.dart';
import '../models/game_score.dart';
import '../models/match_record.dart';
import 'battle_fx_motion.dart' show BattlePose;
import 'battle_stage_model.dart' show BattleSide;
import 'character_motion.dart';
import 'victory_defeat.dart';
import 'victory_motion.dart';

/// How the battle ended for me, as the victory scene shows it: a win by KO,
/// by time or because the opponent left gets the cut-in with its band
/// (spec 1 and 4); a loss the red cut-in with the frustration, a draw the
/// lime and pink one with the two characters in guard (A7,
/// [VictoryDefeat]).
enum VictoryResult {
  koWin('ko'),
  timeWin('time'),
  leftWin('left'),
  lose(null),
  draw(null);

  const VictoryResult(this.bandKey);

  /// The key of the band's words in the rig (`band.text`): a win's. Null for
  /// a loss and a draw, whose bands (패배, 무승부) are A7's
  /// ([VictoryDefeat.loseWords], [VictoryDefeat.drawWords]).
  final String? bandKey;

  bool get isWin => bandKey != null;

  /// The scene for [result]: a win is by KO, by time, or (online) because
  /// the opponent left, whatever the clock showed.
  static VictoryResult of(BattleResult result) => decide(
    result.outcome,
    byKo: result.end == GameEnd.ko,
    opponentLeft: result.departure == BattleDeparture.opponentLeft,
  );

  /// The scene for a battle with [outcome]: a win because the opponent
  /// left is that first, whatever ended the round; else a KO or a time-up
  /// win. A loss or a draw has one scene whatever ended it.
  static VictoryResult decide(
    MatchOutcome outcome, {
    required bool byKo,
    required bool opponentLeft,
  }) => switch (outcome) {
    MatchOutcome.win when opponentLeft => leftWin,
    MatchOutcome.win when byKo => koWin,
    MatchOutcome.win => timeWin,
    MatchOutcome.lose => lose,
    MatchOutcome.draw => draw,
  };
}

/// The scene's values (`scene.values` of the rig, spec 2 to 4), in the
/// design's 360 x 780 points. The times of the formulas are
/// [VictoryTimes].
class VictorySceneValues {
  const VictorySceneValues({
    required this.screen,
    required this.seatBox,
    required this.seatFoot,
    required this.seatScale,
    required this.bigFootY,
    required this.bigScale,
    required this.winEndMs,
    required this.loseEndMs,
    required this.band,
    required this.panel,
    required this.stand,
    required this.confetti,
  });

  factory VictorySceneValues.fromJson(Map<String, dynamic> json) {
    final values = json['values'] as Map<String, dynamic>;
    final screen = values['screen'] as List;
    final seat = values['seat'] as Map<String, dynamic>;
    final box = seat['box'] as Map<String, dynamic>;
    final big = values['big'] as Map<String, dynamic>;
    final band = values['band'] as Map<String, dynamic>;
    final panel = values['panel'] as Map<String, dynamic>;
    final stripes = panel['stripes'] as Map<String, dynamic>;
    final inset = panel['seatInset'] as Map<String, dynamic>;
    final platform = values['platform'] as Map<String, dynamic>;
    final confetti = values['confetti'] as Map<String, dynamic>;
    final pieces = json['confettiPieces'] as List;
    final count = _number(confetti['count']).toInt();
    if (pieces.length != count) {
      throw FormatException('${pieces.length} confetti for $count');
    }
    final screenSize = Size(_number(screen[0]), _number(screen[1]));
    return VictorySceneValues(
      screen: screenSize,
      seatBox: Rect.fromLTWH(
        _number(box['x']),
        _number(box['y']),
        _number(box['w']),
        _number(box['h']),
      ),
      seatFoot: _point(seat['foot']),
      seatScale: _number(seat['scale']),
      bigFootY: _number(big['footY']),
      bigScale: _number(big['scale']),
      winEndMs: _number(values['winEndMs']),
      loseEndMs: {
        for (final MapEntry(:key, :value)
            in (values['loseEndMs'] as Map<String, dynamic>).entries)
          key: _number(value),
      },
      band: VictoryBandValues(
        top: _number(band['top']),
        height: _number(band['height']),
        rotateDeg: _number(band['rotateDeg']),
        skewXDeg: _number(band['skewXDeg']),
        padX: _number(band['padX']),
        fill: parseVictoryColor(band['fill'] as String),
        border: _number(band['border']),
        textSize: _number(band['size']),
        text: Map<String, String>.from(band['text'] as Map),
      ),
      panel: VictoryPanelValues(
        fill: parseVictoryColor(panel['fill'] as String),
        stripeAngleDeg: _number(stripes['angleDeg']),
        stripeOn: _number(stripes['on']),
        stripePeriod: _number(stripes['period']),
        stripeColor: parseVictoryColor(stripes['color'] as String),
        // The inset rule's box, read as the rectangle it leaves on the
        // design's screen (240, 56) - (338, 180).
        seatRect: Rect.fromLTRB(
          _number(inset['left']),
          _number(inset['top']),
          screenSize.width - _number(inset['right']),
          screenSize.height - _number(inset['bottom']),
        ),
        seatRadius: _number(inset['radius']),
      ),
      stand: VictoryStandValues(
        rect: Rect.fromLTWH(
          _number(platform['x']),
          _number(platform['y']),
          _number(platform['w']),
          _number(platform['h']),
        ),
        radius: _number(platform['radius']),
        border: _number(platform['border']),
        win: parseVictoryColor(platform['win'] as String),
        lose: parseVictoryColor(platform['lose'] as String),
      ),
      confetti: VictoryConfettiValues(
        origin: _point(confetti['origin']),
        gravity: _number(confetti['gravity']),
        border: _number(confetti['border']),
        radius: _number(confetti['radius']),
        pieces: [
          for (final piece in pieces)
            VictoryConfettoValues.fromJson(piece as Map<String, dynamic>),
        ],
      ),
    );
  }

  /// The design's screen, 360 x 780.
  final Size screen;

  /// The seat on the design's screen: the 144 x 148 cell right of the
  /// win/lose title (spec 2), where the character ends.
  final Rect seatBox;

  /// The feet's place on the seat and the character's scale there.
  final Offset seatFoot;
  final double seatScale;

  /// The big scene's feet line and scale (spec 2 "큰 장면"); the feet's x
  /// is each character's [VictoryCharacter.bigFootX].
  final double bigFootY;
  final double bigScale;

  final double winEndMs;

  /// A frustration's end by character id: the W5 loss's end. A7's loss and
  /// draw end at [VictoryDefeat.endMs] instead.
  final Map<String, double> loseEndMs;

  final VictoryBandValues band;
  final VictoryPanelValues panel;
  final VictoryStandValues stand;
  final VictoryConfettiValues confetti;
}

/// The band (spec 4): across the middle, [top] and [height], turned
/// [rotateDeg], its white ground slanted [skewXDeg] with an ink edge
/// [border] inside, the words [textSize] high with [padX] on each side.
class VictoryBandValues {
  const VictoryBandValues({
    required this.top,
    required this.height,
    required this.rotateDeg,
    required this.skewXDeg,
    required this.padX,
    required this.fill,
    required this.border,
    required this.textSize,
    required this.text,
  });

  final double top;
  final double height;
  final double rotateDeg;
  final double skewXDeg;
  final double padX;
  final Color fill;
  final double border;
  final double textSize;

  /// The words by [VictoryResult.bandKey].
  final Map<String, String> text;
}

/// The lime panel with white stripes (spec 2), and the rectangle around
/// the seat it shrinks into ([seatRect] on the design's screen, corners
/// [seatRadius]).
class VictoryPanelValues {
  const VictoryPanelValues({
    required this.fill,
    required this.stripeAngleDeg,
    required this.stripeOn,
    required this.stripePeriod,
    required this.stripeColor,
    required this.seatRect,
    required this.seatRadius,
  });

  final Color fill;
  final double stripeAngleDeg;

  /// Each stripe's width, and the width of a stripe and the gap after it.
  final double stripeOn;
  final double stripePeriod;
  final Color stripeColor;
  final Rect seatRect;
  final double seatRadius;
}

/// The stand under the seated character (spec 2): [rect] on the design's
/// screen, corners [radius], an ink edge [border] inside; lime for a win,
/// white for a loss (a draw's is half lime and half pink, A7).
class VictoryStandValues {
  const VictoryStandValues({
    required this.rect,
    required this.radius,
    required this.border,
    required this.win,
    required this.lose,
  });

  final Rect rect;
  final double radius;
  final double border;
  final Color win;
  final Color lose;
}

/// The confetti (spec 3 "색종이"): [pieces] burst from [origin] and fall
/// with [gravity]; each has an ink edge [border] inside and corners
/// [radius].
class VictoryConfettiValues {
  const VictoryConfettiValues({
    required this.origin,
    required this.gravity,
    required this.border,
    required this.radius,
    required this.pieces,
  });

  final Offset origin;
  final double gravity;
  final double border;
  final double radius;
  final List<VictoryConfettoValues> pieces;
}

/// One piece of confetti: when it leaves, how fast (points per ms), how it
/// turns (degrees, degrees per ms), its size and its color.
class VictoryConfettoValues {
  const VictoryConfettoValues({
    required this.delayMs,
    required this.vx,
    required this.vy,
    required this.rot0,
    required this.spin,
    required this.size,
    required this.color,
  });

  factory VictoryConfettoValues.fromJson(Map<String, dynamic> json) =>
      VictoryConfettoValues(
        delayMs: _number(json['delayMs']),
        vx: _number(json['vx']),
        vy: _number(json['vy']),
        rot0: _number(json['rot0']),
        spin: _number(json['spin']),
        size: Size(_number(json['w']), _number(json['h'])),
        color: parseVictoryColor(json['color'] as String),
      );

  final double delayMs;
  final double vx;
  final double vy;
  final double rot0;
  final double spin;
  final Size size;
  final Color color;
}

/// The times of the win's formulas (spec 3, written out in the rig's
/// `scene.win`), in ms from the moment the report opens. A loss's and a
/// draw's are A7's, in [VictoryDefeat].
abstract final class VictoryTimes {
  /// The panel sweeps in from the left over 0 to [wipeMs]; its edge leans
  /// [wipeLean] either way and ends [wipeLean] * 2 past the right side.
  static const wipeMs = 300.0;
  static const wipeLean = 100.0;

  /// The character jumps up from [riseFromMs] for [riseMs], from
  /// [riseDrop] below its feet line, showing within [riseFadeMs].
  static const riseFromMs = 140.0;
  static const riseMs = 380.0;
  static const riseDrop = 340.0;
  static const riseFadeMs = 60.0;

  /// The band slides in from [bandSlide] to the right, from [bandFromMs]
  /// for [bandInMs].
  static const bandFromMs = 260.0;
  static const bandInMs = 300.0;
  static const bandSlide = 440.0;

  /// The confetti burst.
  static const confettiFromMs = 300.0;

  /// The celebration's clock starts.
  static const celebrateFromMs = 520.0;

  /// The way out: the band rises [bandRise] and fades over [bandOutMs]; the
  /// character goes to its seat over [seatMs] and into its end pose over
  /// [endBlendMs]; the panel shrinks over [panelShrinkMs] and fades from
  /// [panelFadeFromMs] for [panelFadeMs].
  static const outFromMs = 1600.0;
  static const bandOutMs = 180.0;
  static const bandRise = 24.0;
  static const seatMs = 500.0;
  static const endBlendMs = 250.0;
  static const panelShrinkMs = 420.0;
  static const panelFadeFromMs = 1880.0;
  static const panelFadeMs = 220.0;

  /// The confetti fade from [confettiFadeFromMs] for [confettiFadeMs]; a
  /// piece more than [confettiGoneBelow] below the screen is gone (y 800
  /// on the design's 780).
  static const confettiFadeFromMs = 1780.0;
  static const confettiFadeMs = 320.0;
  static const confettiGoneBelow = 20.0;

  /// The win's lime stand opens from [standFromMs] for [standMs].
  static const standFromMs = 1900.0;
  static const standMs = 200.0;

  /// The rank ladder's hold (A15, the design `SpScene` E): with a ladder to
  /// play, the big moment is held [holdMs] longer from when the way out was
  /// due ([outFromMs] for a win, `VictoryDefeat.outFromMs` for a loss and a
  /// draw), and the way-out formulas run [holdMs] later
  /// ([VictoryScene.heldTime]).
  static const holdMs = 1200.0;

  /// Meanwhile the band makes room for the ladder: from [bandLiftFromMs]
  /// over [bandLiftMs] it rises [bandLift] and shrinks by [bandShrink].
  static const bandLiftFromMs = 880.0;
  static const bandLiftMs = 240.0;
  static const bandLift = 124.0;
  static const bandShrink = 0.28;
}

/// Where the scene is on a real screen: the overlay's [size] and the
/// seat's top left [seat] in it (the 144 x 148 cell, spec 11.2).
///
/// The seat, the stand and the panel's last rectangle follow [seat]. The
/// big scene (the jumping character, the band, the confetti) is drawn on
/// the design's 360 x 780 screen scaled the same both ways to fit [size]
/// and centred ([designScale], [designOrigin]); on 360 x 780 it is the
/// design's place exactly.
class VictoryLayout {
  VictoryLayout({required this.size, required this.seat, required this.values})
    : designScale = math.min(
        size.width / values.screen.width,
        size.height / values.screen.height,
      ) {
    designOrigin = Offset(
      (size.width - values.screen.width * designScale) / 2,
      (size.height - values.screen.height * designScale) / 2,
    );
  }

  final Size size;
  final Offset seat;
  final VictorySceneValues values;

  /// How large the design's screen is drawn, and where its top left goes.
  final double designScale;
  late final Offset designOrigin;

  /// A point of the big scene (on the design's screen) on this screen.
  Offset fromDesign(Offset point) => designOrigin + point * designScale;

  /// A point near the seat (on the design's screen) on this screen: it
  /// keeps its place to the seat.
  Offset nearSeat(Offset point) => seat + (point - values.seatBox.topLeft);

  /// A rectangle near the seat on this screen.
  Rect rectNearSeat(Rect rect) => rect.shift(seat - values.seatBox.topLeft);
}

/// The victory scene of one result and one character on one layout: what
/// each layer shows at a time (spec 3 and 6; a loss and a draw in
/// [VictoryDefeatScene]), and the end look (spec 8).
class VictoryScene {
  VictoryScene({
    required this.rig,
    required this.character,
    required this.result,
    required this.layout,
    this.opponentId = CharacterRig.defaultId,
    this.hold = false,
  });

  final VictoryRig rig;
  final VictoryCharacter character;
  final VictoryResult result;
  final VictoryLayout layout;

  /// The opponent's character in a draw, drawn as the battle stage draws
  /// it (a `CharacterRig` id; an unknown one draws the default).
  final String opponentId;

  /// Whether the big moment is held for the rank ladder (A15,
  /// [VictoryTimes.holdMs]); without it the scene is W5's and A7's.
  final bool hold;

  VictorySceneValues get _values => rig.scene;

  /// When it ends: 2100 ms for a win, 2000 ms for a loss or a draw; 1.2 s
  /// later with [hold].
  double get endMs => endMsOf(rig, result, hold: hold);

  /// [endMs] without a layout.
  static double endMsOf(
    VictoryRig rig,
    VictoryResult result, {
    bool hold = false,
  }) =>
      (result.isWin ? rig.scene.winEndMs : VictoryDefeat.endMs) +
      (hold ? VictoryTimes.holdMs : 0);

  /// How long the big moment is held: [VictoryTimes.holdMs] with [hold].
  double get holdMs => hold ? VictoryTimes.holdMs : 0;

  /// When the way out starts: 1600 ms for a win, 1500 ms for a loss or a
  /// draw, [holdMs] later.
  double get outFromMs =>
      (result.isWin ? VictoryTimes.outFromMs : VictoryDefeat.outFromMs) +
      holdMs;

  /// The time the way-out formulas read at [t] (the design's `bt`): [t]
  /// until the way out was due, that time through the hold, then [t] less
  /// the hold. The coming in, the band's slide and sag, the rain, the
  /// confetti's flight and the motions' clocks read [t] itself. Without
  /// [hold] it is [t].
  double heldTime(double t) {
    final due = outFromMs - holdMs;
    if (t < due) return t;
    return t < outFromMs ? due : t - holdMs;
  }

  /// How far the band has risen and shrunk for the ladder at [t], 0 to 1;
  /// 0 without [hold].
  double bandLiftAt(double t) => hold
      ? _eio((t - VictoryTimes.bandLiftFromMs) / VictoryTimes.bandLiftMs)
      : 0;

  /// The scene [tMs] ms after the report opened; its end look from [endMs]
  /// on.
  VictoryFrame at(double tMs) => result.isWin ? _win(tMs) : defeatAt(tMs);

  /// The end look: the stand and the end pose on the seat, nothing else
  /// (after the scene, after a tap, with reduced motion, for a past report).
  /// A draw's is my character in guard ([VictoryDefeatScene.drawEnd]).
  VictoryFrame get end {
    if (result == VictoryResult.draw) return drawEnd;
    final motion = result.isWin ? character.celebrate : character.frustrate;
    return VictoryFrame(
      stand: _stand(1),
      figure: VictoryFigure(
        foot: layout.nearSeat(_values.seatFoot),
        scale: _values.seatScale,
        opacity: 1,
        motion: result.isWin
            ? VictoryMotionKind.celebrate
            : VictoryMotionKind.frustrate,
        timeMs: null,
        endBlend: 0,
        frame: motion.rest,
      ),
    );
  }

  VictoryFrame _win(double t) {
    if (t >= endMs) return end;
    final b = heldTime(t);
    return VictoryFrame(
      panel: _panel(t, b),
      band: _band(t, b),
      stand: b >= VictoryTimes.standFromMs
          ? _stand(_eo((b - VictoryTimes.standFromMs) / VictoryTimes.standMs))
          : null,
      figure: _celebrating(t, b),
      confetti: t >= VictoryTimes.confettiFromMs ? _confetti(t, b) : const [],
    );
  }

  /// The panel at [t], [b] its way-out time ([heldTime]).
  VictoryPanel _panel(double t, double b) {
    final size = layout.size;
    if (b < VictoryTimes.outFromMs) {
      const lean = VictoryTimes.wipeLean;
      final x = (size.width + lean * 2) * _eo(t / VictoryTimes.wipeMs);
      return VictoryWipe(
        x: x,
        polygon: [
          Offset.zero,
          Offset(x + lean, 0),
          Offset(x - lean, size.height),
          Offset(0, size.height),
        ],
      );
    }
    final e = _eio((b - VictoryTimes.outFromMs) / VictoryTimes.panelShrinkMs);
    final last = layout.rectNearSeat(_values.panel.seatRect);
    return VictoryShrink(
      e: e,
      top: last.top * e,
      right: (size.width - last.right) * e,
      bottom: (size.height - last.bottom) * e,
      left: last.left * e,
      radius: _values.panel.seatRadius * e,
      opacity:
          1 -
          _clamp((b - VictoryTimes.panelFadeFromMs) / VictoryTimes.panelFadeMs),
    );
  }

  VictoryBand? _band(double t, double b) {
    if (t < VictoryTimes.bandFromMs ||
        b >= VictoryTimes.outFromMs + VictoryTimes.bandOutMs) {
      return null;
    }
    final out = _clamp((b - VictoryTimes.outFromMs) / VictoryTimes.bandOutMs);
    final lift = bandLiftAt(t);
    return VictoryBand(
      text: _values.band.text[result.bandKey]!,
      dx:
          VictoryTimes.bandSlide *
          (1 - _eo((t - VictoryTimes.bandFromMs) / VictoryTimes.bandInMs)),
      dy: -VictoryTimes.bandRise * out - VictoryTimes.bandLift * lift,
      rotDeg: _values.band.rotateDeg,
      opacity: 1 - out,
      scale: 1 - VictoryTimes.bandShrink * lift,
    );
  }

  VictoryFigure? _celebrating(double t, double b) {
    if (t < VictoryTimes.riseFromMs) return null;
    final bigFoot = layout.fromDesign(
      Offset(character.bigFootX, _values.bigFootY),
    );
    final bigScale = _values.bigScale * layout.designScale;
    final motion = character.celebrate;
    if (t < VictoryTimes.celebrateFromMs) {
      final r = _back((t - VictoryTimes.riseFromMs) / VictoryTimes.riseMs);
      return VictoryFigure(
        foot: bigFoot.translate(
          0,
          VictoryTimes.riseDrop * (1 - r) * layout.designScale,
        ),
        scale: bigScale,
        opacity: _clamp(
          (t - VictoryTimes.riseFromMs) / VictoryTimes.riseFadeMs,
        ),
        motion: VictoryMotionKind.celebrate,
        timeMs: 0,
        endBlend: 0,
        frame: motion.frameAt(0),
      );
    }
    final time = (t - VictoryTimes.celebrateFromMs).roundToDouble();
    // Big until the way out, held or not.
    if (t < outFromMs) {
      return VictoryFigure(
        foot: bigFoot,
        scale: bigScale,
        opacity: 1,
        motion: VictoryMotionKind.celebrate,
        timeMs: time,
        endBlend: 0,
        frame: motion.frameAt(time),
      );
    }
    final e = _eio((b - VictoryTimes.outFromMs) / VictoryTimes.seatMs);
    final endBlend = _eio(
      (b - VictoryTimes.outFromMs) / VictoryTimes.endBlendMs,
    );
    return VictoryFigure(
      foot: Offset.lerp(bigFoot, layout.nearSeat(_values.seatFoot), e)!,
      scale: lerpDouble(bigScale, _values.seatScale, e)!,
      opacity: 1,
      motion: VictoryMotionKind.celebrate,
      timeMs: time,
      endBlend: endBlend,
      frame: motion.frameAt(time, endBlend: endBlend),
    );
  }

  List<VictoryConfetto> _confetti(double t, double b) {
    final values = _values.confetti;
    final tc = t - VictoryTimes.confettiFromMs;
    final fade =
        1 -
        _clamp(
          (b - VictoryTimes.confettiFadeFromMs) / VictoryTimes.confettiFadeMs,
        );
    final gone =
        layout.size.height +
        VictoryTimes.confettiGoneBelow * layout.designScale;
    return [
      for (final piece in values.pieces)
        () {
          final tt = math.max(0.0, tc - piece.delayMs);
          final x = values.origin.dx + piece.vx * tt;
          final y =
              values.origin.dy + piece.vy * tt + 0.5 * values.gravity * tt * tt;
          final shown =
              tc >= piece.delayMs && layout.fromDesign(Offset(x, y)).dy < gone;
          return VictoryConfetto(
            topLeft: Offset(x, y),
            size: piece.size,
            rotDeg: piece.rot0 + piece.spin * tt,
            color: piece.color,
            opacity: shown ? fade : 0,
          );
        }(),
    ];
  }

  VictoryStand _stand(double k) => VictoryStand(
    rect: layout.rectNearSeat(_values.stand.rect),
    color: result.isWin ? _values.stand.win : _values.stand.lose,
    scaleX: k,
    opacity: k,
  );
}

/// What every layer shows at one time; a null layer is not drawn.
class VictoryFrame {
  const VictoryFrame({
    this.panel,
    this.rain = const [],
    this.band,
    this.stand,
    this.figure,
    this.fighters = const [],
    this.spark,
    this.shake = 0,
    this.confetti = const [],
  });

  final VictoryPanel? panel;

  /// A loss's rain on the red panel, inside the panel's shape.
  final List<VictoryRaindrop> rain;
  final VictoryBand? band;
  final VictoryStand? stand;

  /// My character in a motion: celebrating (a win) or frustrating (a loss).
  final VictoryFigure? figure;

  /// The characters as the battle stage draws them (a draw), in drawing
  /// order: the opponent, then mine.
  final List<VictoryFighter> fighters;

  /// The spark where a draw's fists meet.
  final VictorySpark? spark;

  /// How far the characters' layer (figure, fighters, spark) is moved
  /// across, in the design's points.
  final double shake;
  final List<VictoryConfetto> confetti;
}

/// A panel's shape on the screen, at [opacity].
sealed class VictoryPanel {
  const VictoryPanel({required this.opacity});

  final double opacity;
}

/// The win's lime panel sweeping in: the polygon left of a leaning edge at
/// [x].
class VictoryWipe extends VictoryPanel {
  const VictoryWipe({required this.x, required this.polygon})
    : super(opacity: 1);

  final double x;
  final List<Offset> polygon;
}

/// A loss's red panel with its rain: the [polygon] above a leaning edge
/// while it comes down, the whole screen when [polygon] is null.
class VictoryShutter extends VictoryPanel {
  const VictoryShutter({this.polygon}) : super(opacity: 1);

  final List<Offset>? polygon;
}

/// A draw's two halves: the [lime] polygon on the left, the [pink] one on
/// the right, and the ink [seam] between them once they meet.
class VictorySplit extends VictoryPanel {
  const VictorySplit({required this.lime, required this.pink, this.seam})
    : super(opacity: 1);

  final List<Offset> lime;
  final List<Offset> pink;
  final ({Offset top, Offset bottom})? seam;
}

/// The panel shrinking into the seat: the screen less these insets, with
/// round corners; [e] is how far (0 to 1). It shows [inner] inside: the
/// win's lime panel when null.
class VictoryShrink extends VictoryPanel {
  const VictoryShrink({
    required this.e,
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
    required this.radius,
    required super.opacity,
    this.inner,
  });

  final double e;
  final double top;
  final double right;
  final double bottom;
  final double left;
  final double radius;

  /// The panel inside the shrinking shape, its whole look at the end of
  /// coming in: a loss's [VictoryShutter], a draw's [VictorySplit].
  final VictoryPanel? inner;

  /// The panel on a screen of [size].
  RRect rectIn(Size size) => RRect.fromLTRBR(
    left,
    top,
    size.width - right,
    size.height - bottom,
    Radius.circular(radius),
  );
}

/// The band's words and where it is: moved ([dx], [dy]) from its place, in
/// the design's points, [scale] times its size, and turned [rotDeg].
class VictoryBand {
  const VictoryBand({
    required this.text,
    required this.dx,
    required this.dy,
    required this.rotDeg,
    required this.opacity,
    this.scale = 1,
  });

  final String text;
  final double dx;
  final double dy;
  final double rotDeg;
  final double opacity;

  /// How large it is about its middle: smaller while it makes room for the
  /// rank ladder (A15), else 1.
  final double scale;
}

/// The stand on the screen, opened [scaleX] of its width about its middle:
/// [color], or [color] on its left half and [rightColor] on its right.
class VictoryStand {
  const VictoryStand({
    required this.rect,
    required this.color,
    this.rightColor,
    required this.scaleX,
    required this.opacity,
  });

  final Rect rect;
  final Color color;
  final Color? rightColor;
  final double scaleX;
  final double opacity;
}

/// The character on the screen: its feet (70, 150 of its box) at [foot],
/// [scale] times its size (and [stretchX] by [stretchY] more, a landing's
/// squash), in [frame]. [timeMs] is the motion's clock and [endBlend] how
/// far it has blended into its end pose; a still picture (the end look) has
/// no clock.
class VictoryFigure {
  const VictoryFigure({
    required this.foot,
    required this.scale,
    this.stretchX = 1,
    this.stretchY = 1,
    required this.opacity,
    required this.motion,
    required this.timeMs,
    required this.endBlend,
    required this.frame,
  });

  final Offset foot;
  final double scale;
  final double stretchX;
  final double stretchY;
  final double opacity;
  final VictoryMotionKind motion;
  final double? timeMs;
  final double endBlend;
  final CharacterMotionFrame frame;

  bool get still => timeMs == null;
}

/// A character as the battle stage draws it (W3): [characterId] in [pose]
/// and [side]'s team color, its feet (70, 150 of its box) at [foot], [scale]
/// times its size, facing left when [mirrored], moved about its feet by
/// [idle] (the stage's idle motion).
class VictoryFighter {
  const VictoryFighter({
    required this.characterId,
    required this.side,
    required this.pose,
    required this.foot,
    required this.scale,
    required this.mirrored,
    required this.opacity,
    required this.idle,
  });

  final String characterId;
  final BattleSide side;
  final BattlePose pose;
  final Offset foot;
  final double scale;
  final bool mirrored;
  final double opacity;
  final IdleSample idle;
}

/// The spark of a draw's fists at [center] (the design's points), turned
/// [rotDeg] and [scale] times its size.
class VictorySpark {
  const VictorySpark({
    required this.center,
    required this.rotDeg,
    required this.scale,
    required this.opacity,
  });

  final Offset center;
  final double rotDeg;
  final double scale;
  final double opacity;
}

/// One streak of a loss's rain: its unturned top left in the design's
/// points ([VictoryDefeat] has its size and turn).
class VictoryRaindrop {
  const VictoryRaindrop({required this.topLeft});

  final Offset topLeft;
}

/// One piece of confetti: its unturned top left in the design's points,
/// turned [rotDeg] about its middle.
class VictoryConfetto {
  const VictoryConfetto({
    required this.topLeft,
    required this.size,
    required this.rotDeg,
    required this.color,
    required this.opacity,
  });

  final Offset topLeft;
  final Size size;
  final double rotDeg;
  final Color color;
  final double opacity;
}

/// Reads `#RRGGBB` or `rgba(r, g, b, a)` as the rig writes its colors.
Color parseVictoryColor(String text) {
  final hex = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(text);
  if (hex != null) {
    const opaque = 0xFF000000;
    return Color(opaque | int.parse(hex[1]!, radix: 16));
  }
  final rgba = RegExp(
    r'^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)$',
  ).firstMatch(text);
  if (rgba != null) {
    return Color.fromRGBO(
      int.parse(rgba[1]!),
      int.parse(rgba[2]!),
      int.parse(rgba[3]!),
      double.parse(rgba[4]!),
    );
  }
  throw FormatException('not a color: $text');
}

double _clamp(double x) => x.clamp(0.0, 1.0);

double _eo(double x) => MotionEase.eo.at(_clamp(x));

double _eio(double x) => MotionEase.eio.at(_clamp(x));

/// The rise's overshoot: 1 + 2.70158 (x - 1)^3 + 1.70158 (x - 1)^2.
double _back(double x) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final d = _clamp(x) - 1;
  return 1 + c3 * d * d * d + c1 * d * d;
}

Offset _point(Object? json) {
  final list = json as List;
  return Offset(_number(list[0]), _number(list[1]));
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  throw FormatException('not a number: $value');
}
