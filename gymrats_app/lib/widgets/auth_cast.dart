import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/character_rig.dart';
import '../theme/app_theme.dart';
import 'auth_cast_data.dart';
import 'battle_stage_model.dart';
import 'character_draw_patch.dart';
import 'character_figure.dart';
import 'character_motion.dart';
import 'victory_motion.dart';

/// The login screens' group photo (P8 SPEC 3 and 4), read once from
/// [authCastJson]: six characters on a three-step podium, each holding a
/// pose for 6 s and changing one after another, one a second.
///
/// The poses are the home rig's form (W4 spec 5), so a frame is a
/// [RigPoseTable] that [CharacterFigurePainter] draws. What the design's
/// loops add to the engine is read here: hops and rocks that run only in a
/// part of the loop, flags that change with time, and sparks and hearts.
class AuthCast {
  const AuthCast({
    required this.stage,
    required this.members,
    required this.label,
    required this.expressionTags,
    required this.heart,
    required this.spark,
    required this.characters,
  });

  /// Reads a cast in the `p8-auth-cast-1` form; anything malformed throws a
  /// [FormatException].
  factory AuthCast.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('the cast is not a JSON object');
    }
    final Map<String, dynamic> json = decoded;
    return _read('cast', () {
      final characters = json['characters'] as Map<String, dynamic>;
      final shapes = json['fxShapes'] as Map<String, dynamic>;
      final cast = AuthCast(
        stage: AuthStage._fromJson(json['stage'] as Map<String, dynamic>),
        members: [
          for (final m in json['cast'] as List)
            AuthCastMember._fromJson(m as Map<String, dynamic>),
        ],
        label: json['castLabel'] as String,
        expressionTags: readExpressionTags(
          (json['expressions'] as Map<String, dynamic>)['map']
              as Map<String, dynamic>,
        ),
        heart: AuthFxShape._fromJson(shapes['heart'] as Map<String, dynamic>),
        spark: AuthFxShape._fromJson(shapes['spark'] as Map<String, dynamic>),
        characters: {
          for (final MapEntry(:key, :value) in characters.entries)
            key: AuthCastCharacter._fromJson(
              key,
              value as Map<String, dynamic>,
            ),
        },
      );
      for (final member in cast.members) {
        if (!cast.characters.containsKey(member.id)) {
          throw FormatException('no loop for "${member.id}"');
        }
      }
      for (final character in cast.characters.values) {
        for (final e in character.motion.expressions) {
          if (!cast.expressionTags.containsKey(e.expression)) {
            throw FormatException('no tags for "${e.expression}"');
          }
        }
      }
      return cast;
    });
  }

  /// The app's group photo, read from [authCastJson] on first use.
  static final standard = AuthCast.parse(authCastJson);

  final AuthStage stage;

  /// Who stands where, listed back to front (the drawing order).
  final List<AuthCastMember> members;

  /// What a screen reader says for the whole picture (LoginB `castLabel`).
  final String label;

  /// Expression -> character id (or `default`) -> the `show` tags it draws.
  final Map<String, Map<String, List<String>>> expressionTags;

  final AuthFxShape heart;
  final AuthFxShape spark;
  final Map<String, AuthCastCharacter> characters;

  /// The `show` tags [expression] draws on [characterId].
  Set<String> tagsOf(String expression, String characterId) {
    final byCharacter =
        expressionTags[expression] ??
        (throw ArgumentError.value(expression, 'expression'));
    return (byCharacter[characterId] ?? byCharacter['default'])!.toSet();
  }

  /// [member]'s frame when the photo has run [nowMs], or its one still
  /// picture (LoginB `ft`) when motion is off.
  AuthCastFrame frameOf(
    AuthCastMember member, {
    required double nowMs,
    bool still = false,
  }) {
    final character = characters[member.id]!;
    return character.frameAt(still ? member.ftMs : nowMs + member.phMs, this);
  }
}

/// The podium and the light behind it, in the design's 360 x 780 frame.
class AuthStage {
  const AuthStage({
    required this.width,
    required this.height,
    required this.dyLogin,
    required this.dySignup,
    required this.planes,
    required this.podiumShadow,
    required this.steps,
    required this.stepStroke,
    required this.castShadow,
    required this.footX,
    required this.footY,
  });

  factory AuthStage._fromJson(Map<String, dynamic> json) {
    final dy = json['dy'] as Map<String, dynamic>;
    final shadow = json['podiumShadow'] as Map<String, dynamic>;
    final cast = json['castShadow'] as Map<String, dynamic>;
    final box = json['box'] as Map<String, dynamic>;
    return AuthStage(
      width: _number(json['width']),
      height: _number(json['height']),
      dyLogin: _number(dy['login']),
      dySignup: _number(dy['signup']),
      planes: [
        for (final p in json['planes'] as List)
          (
            fill: _color((p as Map<String, dynamic>)['fill']),
            points: [
              for (final xy in p['points'] as List)
                Offset(_number((xy as List)[0]), _number(xy[1])),
            ],
          ),
      ],
      podiumShadow: (
        oval: Rect.fromCenter(
          center: Offset(_number(shadow['cx']), _number(shadow['cy'])),
          width: _number(shadow['rx']) * 2,
          height: _number(shadow['ry']) * 2,
        ),
        opacity: _number(shadow['opacity']),
      ),
      steps: [
        for (final s in json['steps'] as List)
          (
            rect: RRect.fromRectXY(
              Rect.fromLTWH(
                _number((s as Map<String, dynamic>)['x']),
                _number(s['y']),
                _number(s['w']),
                _number(s['h']),
              ),
              _number(s['r']),
              _number(s['r']),
            ),
            fill: _color(s['fill']),
          ),
      ],
      stepStroke: _number(json['stepStroke']),
      castShadow: (
        rx: _number(cast['rx']),
        ry: _number(cast['ry']),
        dy: _number(cast['dy']),
        opacity: _number(cast['opacity']),
      ),
      footX: _number(box['footX']),
      footY: _number(box['footY']),
    );
  }

  final double width;
  final double height;

  /// How far the podium and the cast sit lower on login than on sign-up.
  final double dyLogin;
  final double dySignup;

  /// The two light planes behind, in screen coordinates (not moved by dy).
  final List<({Color fill, List<Offset> points})> planes;
  final ({Rect oval, double opacity}) podiumShadow;

  /// Top, middle and bottom step, drawn in that order.
  final List<({RRect rect, Color fill})> steps;
  final double stepStroke;

  /// A character's shadow: [rx] x [ry] times its scale, [dy] below its feet.
  final ({double rx, double ry, double dy, double opacity}) castShadow;

  /// The feet in a character's 140 x 160 box.
  final double footX;
  final double footY;
}

/// One place of the photo: [id]'s feet at ([x], [y]) on login before dy,
/// [scale] times the box, mirrored when [flip]; its clock runs [phMs] from
/// the photo's, and [ftMs] is its still picture.
class AuthCastMember {
  const AuthCastMember({
    required this.id,
    required this.x,
    required this.y,
    required this.scale,
    required this.flip,
    required this.side,
    required this.phMs,
    required this.ftMs,
  });

  factory AuthCastMember._fromJson(Map<String, dynamic> json) {
    return AuthCastMember(
      id: json['id'] as String,
      x: _number(json['x']),
      y: _number(json['y']),
      scale: _number(json['s']),
      flip: json['flip'] as bool? ?? false,
      side: switch (json['team'] as String? ?? 'me') {
        'me' => BattleSide.me,
        'op' => BattleSide.opponent,
        final other => throw FormatException('unknown team "$other"'),
      },
      phMs: _number(json['phMs']),
      ftMs: _number(json['ftMs']),
    );
  }

  final String id;
  final double x;
  final double y;
  final double scale;
  final bool flip;

  /// Lime for the five, pink for RepBot.
  final BattleSide side;
  final double phMs;
  final double ftMs;
}

/// One character's loop: the home rig's timetable and key poses, and what
/// the loop adds to them.
class AuthCastCharacter {
  AuthCastCharacter({
    required this.id,
    required this.motion,
    required this.keyPoses,
    required this.global,
    required this.flagTimes,
    required this.effects,
    required this.ownPatch,
  });

  factory AuthCastCharacter._fromJson(String id, Map<String, dynamic> json) {
    return _read('character "$id"', () {
      final motion = CharacterMotion.fromJson(
        json['motion'] as Map<String, dynamic>,
      );
      final keyPoses = readKeyPoses(json['keyposes'] as Map<String, dynamic>);
      motion.checkKeyPoses(keyPoses);
      if (!motion.loop) throw const FormatException('a loop that ends');
      final flagTimes = [
        for (final f in json['flagT'] as List)
          (
            atMs: _number((f as Map<String, dynamic>)['atMs']),
            flags: Set<String>.unmodifiable(
              List<String>.from(f['flags'] as List),
            ),
          ),
      ];
      return AuthCastCharacter(
        id: id,
        motion: motion,
        keyPoses: keyPoses,
        global: [
          for (final g in json['glob'] as List)
            AuthGlobalPart._fromJson(g as Map<String, dynamic>),
        ],
        flagTimes: flagTimes,
        effects: [
          for (final f in json['fx'] as List)
            AuthEffect._fromJson(f as Map<String, dynamic>),
        ],
        ownPatch: List.unmodifiable([
          for (final p in json['drawPatch'] as List)
            CharacterDrawPatch.fromJson(p as Map<String, dynamic>),
        ]),
      );
    });
  }

  final String id;
  final CharacterMotion motion;
  final Map<String, RigPoseTable> keyPoses;

  /// The whole picture's hops and rocks, each in its part of the loop.
  final List<AuthGlobalPart> global;

  /// From [atMs] on, the flags that are on (gBack, th2).
  final List<({double atMs, Set<String> flags})> flagTimes;

  /// Sparks and hearts, each in its part of the loop.
  final List<AuthEffect> effects;

  /// The shapes the loop shows that the W3, W4 and W5 drawings lack.
  final List<CharacterDrawPatch> ownPatch;

  /// What [CharacterFigurePainter] applies to the W3 drawing list: the home
  /// rig's patch, the victory rig's faces, then [ownPatch].
  late final List<CharacterDrawPatch> drawPatch = List.unmodifiable([
    ...?CharacterMotionRig.standard.characters[id]?.drawPatch,
    ...?VictoryRig.standard.characters[id]?.ownPatch,
    ...ownPatch,
  ]);

  /// The frame [tMs] into the loop (any time; the loop wraps it).
  AuthCastFrame frameAt(double tMs, AuthCast cast) {
    final frame = motion.frameAt(tMs, keyPoses);
    final t = motion.wrap(tMs);
    return AuthCastFrame(
      pose: frame.pose,
      expression: frame.expression,
      tags: cast.tagsOf(frame.expression, id),
      flags: flagsAt(t),
      global: globalAt(t),
      effects: [for (final effect in effects) ?effect.at(t)],
    );
  }

  /// The flags of the last change begun by the wrapped time [t].
  Set<String> flagsAt(double t) {
    var flags = const <String>{};
    for (final f in flagTimes) {
      if (t >= f.atMs) flags = f.flags;
    }
    return flags;
  }

  /// Every part of [global] that runs at the wrapped time [t], added.
  MotionGlobal globalAt(double t) {
    var up = 0.0;
    var rotDeg = 0.0;
    for (final g in global) {
      if (t < g.fromMs || t > g.toMs) continue;
      switch (g.kind) {
        case AuthGlobalKind.hop:
          up += g.amount * math.sin(math.pi * (t - g.phaseMs) / g.ms).abs();
        case AuthGlobalKind.rock:
          rotDeg += g.amount * math.sin(2 * math.pi * (t - g.phaseMs) / g.ms);
      }
    }
    return MotionGlobal(up: up, rotDeg: rotDeg, sx: 1, sy: 1);
  }
}

enum AuthGlobalKind { hop, rock }

/// A hop ([amount] px up, one per [ms]) or a rock ([amount] degrees either
/// way per [ms]) from [fromMs] to [toMs] of the loop, [phaseMs] later.
class AuthGlobalPart {
  const AuthGlobalPart({
    required this.kind,
    required this.amount,
    required this.ms,
    required this.phaseMs,
    required this.fromMs,
    required this.toMs,
  });

  factory AuthGlobalPart._fromJson(Map<String, dynamic> json) {
    final kind = switch (json['k']) {
      'hop' => AuthGlobalKind.hop,
      'rock' => AuthGlobalKind.rock,
      final other => throw FormatException('unknown move "$other"'),
    };
    final part = AuthGlobalPart(
      kind: kind,
      amount: _number(json[kind == AuthGlobalKind.hop ? 'amp' : 'deg']),
      ms: _number(json['ms']),
      phaseMs: _number(json['ph'] ?? 0),
      fromMs: _number(json['from']),
      toMs: _number(json['to']),
    );
    if (part.ms <= 0) throw const FormatException('a move of no time');
    return part;
  }

  final AuthGlobalKind kind;
  final double amount;
  final double ms;
  final double phaseMs;
  final double fromMs;
  final double toMs;
}

enum AuthEffectKind { heart, spark }

/// A spark or heart from [fromMs] to [toMs] of the loop at ([x], [y]) of the
/// box, rising [rise] px over its time, [scale] times its size.
class AuthEffect {
  const AuthEffect({
    required this.kind,
    required this.x,
    required this.y,
    required this.rise,
    required this.scale,
    required this.fromMs,
    required this.toMs,
  });

  factory AuthEffect._fromJson(Map<String, dynamic> json) {
    if (json['follow'] == true) {
      throw const FormatException('an effect that follows the body');
    }
    final effect = AuthEffect(
      kind: switch (json['k']) {
        'heart' => AuthEffectKind.heart,
        'spark' => AuthEffectKind.spark,
        final other => throw FormatException('unknown effect "$other"'),
      },
      x: _number(json['x']),
      y: _number(json['y']),
      rise: _number(json['rise'] ?? 0),
      scale: _number(json['s'] ?? 1),
      fromMs: _number(json['from']),
      toMs: _number(json['to']),
    );
    if (effect.toMs <= effect.fromMs) {
      throw const FormatException('an effect of no time');
    }
    return effect;
  }

  final AuthEffectKind kind;
  final double x;
  final double y;
  final double rise;
  final double scale;
  final double fromMs;
  final double toMs;

  /// Where and how strong it is at the wrapped time [t]; null outside its
  /// time. It fades in over the first 15 % and out over the last 30 %; a
  /// spark grows from 0.75 to 1.1 of its size over the first third.
  AuthEffectFrame? at(double t) {
    if (t < fromMs || t > toMs) return null;
    final u = (t - fromMs) / (toMs - fromMs);
    final opacity = u < 0.15 ? u / 0.15 : (u > 0.7 ? (1 - u) / 0.3 : 1.0);
    final grow = kind == AuthEffectKind.spark
        ? 0.75 + 0.35 * math.min(1, u * 3)
        : 1.0;
    return AuthEffectFrame(
      kind: kind,
      center: Offset(x, y - rise * u),
      scale: scale * grow,
      opacity: opacity.clamp(0.0, 1.0),
    );
  }
}

/// An effect as drawn in one frame.
class AuthEffectFrame {
  const AuthEffectFrame({
    required this.kind,
    required this.center,
    required this.scale,
    required this.opacity,
  });

  final AuthEffectKind kind;
  final Offset center;
  final double scale;
  final double opacity;
}

/// The path of a spark or a heart, centred on (0, 0).
class AuthFxShape {
  AuthFxShape({required this.path, required this.filled, required this.width});

  factory AuthFxShape._fromJson(Map<String, dynamic> json) {
    final path = Path();
    for (final step in json['d'] as List) {
      final s = step as List;
      final v = [for (final n in s.skip(1)) _number(n)];
      switch (s.first) {
        case 'M':
          path.moveTo(v[0], v[1]);
        case 'L':
          path.lineTo(v[0], v[1]);
        case 'C':
          path.cubicTo(v[0], v[1], v[2], v[3], v[4], v[5]);
        case 'Z':
          path.close();
        default:
          throw FormatException('unknown path step "${s.first}"');
      }
    }
    return AuthFxShape(
      path: path,
      filled: json['fill'] != null,
      width: _number(json['strokeWidth']),
    );
  }

  final Path path;

  /// The heart is filled pink; the spark is lines only.
  final bool filled;

  /// Its ink outline's width.
  final double width;
}

/// One character's frame: its pose, face, flags, whole-picture move and
/// effects.
class AuthCastFrame {
  const AuthCastFrame({
    required this.pose,
    required this.expression,
    required this.tags,
    required this.flags,
    required this.global,
    required this.effects,
  });

  final RigPoseTable pose;
  final String expression;
  final Set<String> tags;
  final Set<String> flags;
  final MotionGlobal global;
  final List<AuthEffectFrame> effects;
}

/// Which screen the photo stands on: login has it [AuthStage.dyLogin]
/// lower. [top] and [bottom] are the band of the 360 x 780 design between
/// the screen's top part and its bottom part, and [feet] the lowest row's
/// feet, below which a message may cover the podium.
enum AuthCastPlace {
  /// LoginB step login: the logo ends at 50 + 50 + 10 + 18 = 128; the
  /// Google button and the link start at 780 - 24 - 44 - 10 - 54 = 648.
  login(top: 128, bottom: 648, feet: 542),

  /// LoginB step signup: the title row ends at 32 + 44 = 76; the nickname
  /// form starts at 780 - 24 - 58 - 8 - 8 - 18 - 8 - 56 - 8 - 18 = 574.
  signup(top: 76, bottom: 574, feet: 502);

  const AuthCastPlace({
    required this.top,
    required this.bottom,
    required this.feet,
  });

  final double top;
  final double bottom;
  final double feet;

  double get height => bottom - top;

  double dyIn(AuthStage stage) =>
      this == login ? stage.dyLogin : stage.dySignup;
}

/// The two light planes behind the login screens, the design's 360 wide
/// frame scaled to the screen's width from its top left.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, this.cast});

  /// Defaults to [AuthCast.standard].
  final AuthCast? cast;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackdropPainter((cast ?? AuthCast.standard).stage),
      child: const SizedBox.expand(),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.stage);

  final AuthStage stage;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);
    canvas.save();
    canvas.scale(size.width / stage.width);
    for (final plane in stage.planes) {
      canvas.drawPath(
        Path()..addPolygon(plane.points, true),
        Paint()..color = plane.fill,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) =>
      oldDelegate.stage != stage;
}

/// The podium and the six characters, moving (SPEC 4).
///
/// It draws [place]'s band of the design as large as fits its box, centred,
/// never larger than the screen's width allows ([maxScale]). Its clock
/// starts at 0, runs only while the photo can be seen (no opaque screen on
/// top, app in front) and goes on from where it stopped. With the device's
/// animations off it draws each character's still picture and never ticks.
/// A screen reader reads the whole photo as one picture.
class AuthCastStage extends StatefulWidget {
  const AuthCastStage({
    super.key,
    required this.place,
    this.maxScale = double.infinity,
    this.cast,
  });

  final AuthCastPlace place;

  /// The largest scale (the screen's width over the design's).
  final double maxScale;

  /// Defaults to [AuthCast.standard].
  final AuthCast? cast;

  @override
  State<AuthCastStage> createState() => AuthCastStageState();
}

/// The stage's clock; public so tests can read [nowMs].
class AuthCastStageState extends State<AuthCastStage>
    with SingleTickerProviderStateMixin {
  late final _ticker = createTicker(_tick);
  late final AppLifecycleListener _lifecycle;

  /// Milliseconds the photo has run: earlier runs plus the current one.
  final _now = ValueNotifier<double>(0);
  double _carried = 0;
  double _running = 0;
  bool _still = false;
  bool _shown = true;
  bool _appInFront = true;

  /// How long the photo has run, in ms.
  double get nowMs => _now.value;

  /// Whether it shows the still pictures (animations off).
  bool get still => _still;

  @override
  void initState() {
    super.initState();
    _appInFront = _inFront(WidgetsBinding.instance.lifecycleState);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _appInFront = _inFront(state);
        _sync();
      },
    );
  }

  static bool _inFront(AppLifecycleState? state) =>
      state == null ||
      state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _shown = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  void _tick(Duration elapsed) {
    _running = elapsed.inMicroseconds / 1000;
    _now.value = _carried + _running;
  }

  void _sync() {
    final run = !_still && _shown && _appInFront;
    if (run && !_ticker.isActive) {
      _running = 0;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _carried += _running;
      _running = 0;
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _ticker.dispose();
    _now.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cast = widget.cast ?? AuthCast.standard;
    return Semantics(
      image: true,
      label: cast.label,
      excludeSemantics: true,
      child: CustomPaint(
        painter: AuthCastPainter(
          cast: cast,
          place: widget.place,
          maxScale: widget.maxScale,
          now: _now,
          still: _still,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Paints [place]'s band: the podium's shadow and steps, then each
/// character back to front with its own shadow, its frame at [now] and its
/// sparks and hearts.
class AuthCastPainter extends CustomPainter {
  AuthCastPainter({
    required this.cast,
    required this.place,
    required this.now,
    required this.still,
    this.maxScale = double.infinity,
  }) : super(repaint: now);

  final AuthCast cast;
  final AuthCastPlace place;
  final ValueListenable<double> now;
  final bool still;
  final double maxScale;

  /// The scale [place]'s band is drawn at in a box of [size].
  double scaleIn(Size size) => [
    maxScale,
    size.width / cast.stage.width,
    size.height / place.height,
  ].reduce(math.min);

  @override
  void paint(Canvas canvas, Size size) {
    final stage = cast.stage;
    final scale = scaleIn(size);
    if (scale <= 0) return;
    final dy = place.dyIn(stage);
    canvas.save();
    canvas.translate(
      (size.width - stage.width * scale) / 2,
      (size.height - place.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.translate(0, dy - place.top);

    final ink = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = stage.stepStroke;
    canvas.drawOval(
      stage.podiumShadow.oval,
      Paint()
        ..color = AppColors.ink.withValues(alpha: stage.podiumShadow.opacity),
    );
    for (final step in stage.steps) {
      canvas.drawRRect(step.rect, Paint()..color = step.fill);
      canvas.drawRRect(step.rect, ink);
    }

    final rig = CharacterRig.standard;
    final effects = CharacterMotionRig.standard.effects;
    final shadow = stage.castShadow;
    final shadowPaint = Paint()
      ..color = AppColors.ink.withValues(alpha: shadow.opacity);
    for (final member in cast.members) {
      final s = member.scale;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(member.x, member.y + shadow.dy),
          width: 2 * shadow.rx * s,
          height: 2 * shadow.ry * s,
        ),
        shadowPaint,
      );
      final character = cast.characters[member.id]!;
      final frame = cast.frameOf(member, nowMs: now.value, still: still);
      canvas.save();
      canvas.translate(member.x, member.y);
      canvas.scale(member.flip ? -s : s, s);
      canvas.translate(-stage.footX, -stage.footY);
      frame.global.applyTo(canvas, stage.footX, stage.footY);
      CharacterFigurePainter(
        rig: rig,
        art: rig.art(member.id),
        teamColor: member.side == BattleSide.me
            ? AppColors.accent
            : AppColors.opponent,
        values: frame.pose,
        tags: frame.tags,
        patches: character.drawPatch,
        flags: frame.flags,
        effects: effects,
      ).paint(canvas, Size(rig.boxWidth, rig.boxHeight));
      for (final effect in frame.effects) {
        _paintEffect(canvas, effect);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintEffect(Canvas canvas, AuthEffectFrame effect) {
    final shape = effect.kind == AuthEffectKind.heart ? cast.heart : cast.spark;
    // The design fades the effect as one group: fill and outline together.
    canvas.saveLayer(
      null,
      Paint()..color = AppColors.ink.withValues(alpha: effect.opacity),
    );
    canvas.translate(effect.center.dx, effect.center.dy);
    canvas.scale(effect.scale);
    if (shape.filled) {
      canvas.drawPath(shape.path, Paint()..color = AppColors.opponent);
    }
    canvas.drawPath(
      shape.path,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = shape.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(AuthCastPainter oldDelegate) =>
      oldDelegate.cast != cast ||
      oldDelegate.place != place ||
      oldDelegate.now != now ||
      oldDelegate.still != still ||
      oldDelegate.maxScale != maxScale;
}

/// The token behind a color name of the data.
Color _color(Object? name) => switch (name) {
  'accent' => AppColors.accent,
  'card' => AppColors.card,
  'facetLight' => AppColors.facetLight,
  'facetDark' => AppColors.facetDark,
  final other => throw FormatException('unknown color "$other"'),
};

double _number(Object? value) {
  if (value is num) return value.toDouble();
  throw FormatException('not a number: $value');
}

T _read<T>(String where, T Function() read) {
  try {
    return read();
  } on TypeError catch (error) {
    throw FormatException('$where: $error');
  } on ArgumentError catch (error) {
    throw FormatException('$where: ${error.message}');
  }
}
