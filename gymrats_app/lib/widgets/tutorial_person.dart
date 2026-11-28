import 'dart:math' as math;
import 'dart:ui';

/// The tutorial's people as plain geometry (A12 spec 4): joint positions
/// worked out from a pose and how far down it is, and the outlines drawn
/// from them. No painting here; `tutorial_figure_painters.dart` fills the
/// outlines in ink.
///
/// Two views, each ported line by line from the A12 design's scripts:
/// - the side view ([TutorialSide], `figcore_c.js`, the `lib()` of
///   `TutFigSide` and `TutDraft`): units where the floor is at y 0, up is
///   negative and the person faces left; a person is about 100 tall;
/// - the camera's front view ([TutorialFront], `cam2.js` for the setup's
///   camera, `cam3.js` for the battle's), in the camera's own 290 x 387
///   box ([TutorialFront.box]).

/// The side view's poses: a push-up, a push-up with the knees on the floor,
/// and a squat with both hands held together in front of the chest.
enum TutorialSidePose { push, kneel, squat }

/// The side view's body (the design's `BODY.real`).
abstract final class TutorialBody {
  static const headRadius = 6.6;
  static const neck = 3.4;
  static const torso = 29.0;
  static const upperArm = 17.5;
  static const forearm = 15.5;
  static const hand = 5.4;
  static const thigh = 25.0;
  static const shin = 24.0;
  static const ankle = 4.0;
  static const toe = 7.2;
  static const heel = 2.6;
}

/// Where the joints of a side-view person are. The near side is drawn in
/// ink; the far side ("far…", a little behind and up) in gray.
class SideJoints {
  const SideJoints({
    required this.shoulder,
    required this.hip,
    required this.knee,
    required this.ankle,
    required this.elbow,
    required this.wrist,
    required this.fingertip,
    required this.head,
    required this.neckEnd,
    required this.toe,
    required this.heel,
    required this.farShoulder,
    required this.farElbow,
    required this.farWrist,
    required this.farFingertip,
    required this.farHip,
    required this.farKnee,
    required this.farAnkle,
    required this.farToe,
    required this.farHeel,
    required this.look,
    this.fist,
  });

  final Offset shoulder;
  final Offset hip;
  final Offset knee;
  final Offset ankle;
  final Offset elbow;
  final Offset wrist;
  final Offset fingertip;

  /// The middle of the head, and where the neck meets it.
  final Offset head;
  final Offset neckEnd;
  final Offset toe;
  final Offset heel;
  final Offset farShoulder;
  final Offset farElbow;
  final Offset farWrist;
  final Offset farFingertip;
  final Offset farHip;
  final Offset farKnee;
  final Offset farAnkle;
  final Offset farToe;
  final Offset farHeel;

  /// Which way the face looks, a unit direction; not moved by [map].
  final Offset look;

  /// The squat's hands held together in front of the chest: where the right
  /// fist is, wrapped by the left hand. Null when the hands are apart.
  final Offset? fist;

  /// Whether the hands are held together ([fist]).
  bool get clasp => fist != null;

  /// These joints with every point moved by [to]; [look] stays.
  SideJoints map(Offset Function(Offset) to) => SideJoints(
    shoulder: to(shoulder),
    hip: to(hip),
    knee: to(knee),
    ankle: to(ankle),
    elbow: to(elbow),
    wrist: to(wrist),
    fingertip: to(fingertip),
    head: to(head),
    neckEnd: to(neckEnd),
    toe: to(toe),
    heel: to(heel),
    farShoulder: to(farShoulder),
    farElbow: to(farElbow),
    farWrist: to(farWrist),
    farFingertip: to(farFingertip),
    farHip: to(farHip),
    farKnee: to(farKnee),
    farAnkle: to(farAnkle),
    farToe: to(farToe),
    farHeel: to(farHeel),
    look: look,
    fist: fist == null ? null : to(fist!),
  );
}

/// The outlines of a side-view person, each a list of pieces filled one by
/// one: the far leg and arm (gray), then the near leg, the torso, the neck,
/// the head with its nose, and the near arm in front with a thin white edge.
class SideShapes {
  const SideShapes({
    required this.farLeg,
    required this.farArm,
    required this.leg,
    required this.torso,
    required this.neck,
    required this.head,
    required this.nose,
    required this.arm,
  });

  final List<Path> farLeg;
  final List<Path> farArm;
  final List<Path> leg;
  final List<Path> torso;
  final List<Path> neck;
  final List<Path> head;
  final List<Path> nose;
  final List<Path> arm;
}

/// Outlines built of joints: tapered bars rounded at their joints, circles,
/// ellipses and smooth closed curves (the design's `limb`, `circ`, `ell`,
/// `blob`).
abstract final class TutorialOutline {
  /// A bar from [from] to [to], [fromWidth] wide at one end and [toWidth]
  /// at the other (the design's `taper`).
  static Path taper(Offset from, Offset to, double fromWidth, double toWidth) {
    final along = _unit(to - from);
    final across = Offset(-along.dy, along.dx);
    return Path()..addPolygon([
      from + across * (fromWidth / 2),
      to + across * (toWidth / 2),
      to - across * (toWidth / 2),
      from - across * (fromWidth / 2),
    ], true);
  }

  /// A limb through [points], [widths] wide at each of them: a bar between
  /// each two, a circle at each.
  static List<Path> limb(List<Offset> points, List<double> widths) => [
    for (var i = 0; i < points.length - 1; i++)
      taper(points[i], points[i + 1], widths[i], widths[i + 1]),
    for (var i = 0; i < points.length; i++) circle(points[i], widths[i] / 2),
  ];

  static Path circle(Offset center, double radius) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  static Path ellipse(Offset center, double radiusX, double radiusY) => Path()
    ..addOval(
      Rect.fromCenter(center: center, width: 2 * radiusX, height: 2 * radiusY),
    );

  /// A smooth closed curve through [points] (Catmull-Rom as cubic curves,
  /// the design's `blob`).
  static Path blob(List<Offset> points) {
    final n = points.length;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 0; i < n; i++) {
      final p0 = points[(i - 1 + n) % n];
      final p1 = points[i];
      final p2 = points[(i + 1) % n];
      final p3 = points[(i + 2) % n];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path..close();
  }

  static Offset _unit(Offset v) {
    final length = v.distance;
    return length == 0 ? v : v / length;
  }
}

/// The side view's joints and outlines (`figcore_c.js`).
abstract final class TutorialSide {
  /// Starts and stops slowly (the design's `ease`, a cubic).
  static double ease(double t) =>
      t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;

  /// How far down page 1's person is [ms] into its loop (`TutFigSide`
  /// `phase()`): a push-up takes 2000 ms, a squat 2400; each holds at the
  /// top, eases down, holds at the bottom and eases up.
  static double phase(double ms, {required bool squat}) {
    final steps = squat
        ? const [2400.0, 250.0, 1100.0, 1300.0, 2150.0]
        : const [2000.0, 200.0, 950.0, 1100.0, 1850.0];
    final u = ((ms % steps[0]) + steps[0]) % steps[0];
    if (u < steps[1]) return 0;
    if (u < steps[2]) return ease((u - steps[1]) / (steps[2] - steps[1]));
    if (u < steps[3]) return 1;
    if (u < steps[4]) return 1 - ease((u - steps[3]) / (steps[4] - steps[3]));
    return 0;
  }

  /// How long one rep of page 1's loop takes.
  static Duration loopOf({required bool squat}) =>
      Duration(milliseconds: squat ? 2400 : 2000);

  /// The joints of [pose] [k] of the way down: 0 at the top (arms straight,
  /// or standing), 1 at the bottom. The design's grades use a little past 1
  /// for an excellent squat.
  static SideJoints joints(TutorialSidePose pose, double k) => switch (pose) {
    TutorialSidePose.push => _push(k),
    TutorialSidePose.kneel => _kneel(k),
    TutorialSidePose.squat => _squat(k),
  };

  /// The middle of [joints]' width, counting the head (`side()` and
  /// `frame()`).
  static double middleOf(SideJoints joints) {
    final xs = [
      for (final p in [
        joints.shoulder,
        joints.hip,
        joints.knee,
        joints.ankle,
        joints.wrist,
        joints.fingertip,
        joints.toe,
        joints.heel,
      ])
        p.dx,
      joints.head.dx - TutorialBody.headRadius,
      joints.head.dx + TutorialBody.headRadius,
    ];
    return (xs.reduce(math.min) + xs.reduce(math.max)) / 2;
  }

  /// [joints] sized by [scale] with the middle of their width ([middle],
  /// theirs unless given) at [centerX] and the floor at [floorY].
  static SideJoints place(
    SideJoints joints, {
    required double scale,
    required double centerX,
    required double floorY,
    double? middle,
  }) {
    final mid = middle ?? middleOf(joints);
    return joints.map(
      (p) => Offset(centerX + (p.dx - mid) * scale, floorY + p.dy * scale),
    );
  }

  /// The torso's thickness along it, from the shoulder (0) to the hip (1):
  /// (where, chest side, back side), in body units.
  static const _profile = [
    (-0.12, 2.0, 2.4),
    (-0.03, 5.4, 4.6),
    (0.1, 7.6, 5.0),
    (0.28, 7.4, 4.4),
    (0.5, 6.0, 3.8),
    (0.7, 5.6, 4.4),
    (0.88, 5.9, 6.3),
    (1.02, 4.6, 6.0),
    (1.12, 1.6, 3.0),
  ];

  /// The outlines of placed [joints] drawn [scale] times the body's units
  /// (the design's `lookC`, the ink silhouette).
  static SideShapes shapes(SideJoints joints, double scale) {
    final s = scale;
    final p = joints;
    final limb = TutorialOutline.limb;
    final circle = TutorialOutline.circle;
    final fist = p.fist;
    final gaze = Offset(p.look.dy, -p.look.dx);
    const headRadius = TutorialBody.headRadius;
    return SideShapes(
      farLeg: [
        ...limb([p.farHip, p.farKnee, p.farAnkle], [9 * s, 5.4 * s, 3.3 * s]),
        ...limb([p.farHeel, p.farToe], [3.8 * s, 2.6 * s]),
      ],
      farArm: [
        ...limb(
          [p.farShoulder, p.farElbow, p.farWrist],
          [5.4 * s, 4.2 * s, 3.1 * s],
        ),
        if (fist == null)
          ...limb([p.farWrist, p.farFingertip], [3 * s, 2.2 * s]),
      ],
      leg: [
        ...limb([p.hip, p.knee, p.ankle], [10 * s, 5.8 * s, 3.4 * s]),
        ...limb([p.heel, p.toe], [4 * s, 2.7 * s]),
      ],
      torso: [TutorialOutline.blob(_torso(p, s))],
      neck: limb([p.shoulder, p.neckEnd], [5.2 * s, 4.4 * s]),
      head: [circle(p.head, headRadius * s)],
      nose: [
        circle(
          p.head +
              gaze * (headRadius * s * 0.9) +
              p.look * (-0.12 * headRadius * s),
          1.5 * s,
        ),
      ],
      arm: [
        ...limb([p.shoulder, p.elbow, p.wrist], [6 * s, 4.5 * s, 3.2 * s]),
        if (fist != null)
          circle(fist, 3 * s)
        else
          ...limb([p.wrist, p.fingertip], [3.2 * s, 2.3 * s]),
        circle(Offset.lerp(p.shoulder, p.elbow, 0.12)!, 3.7 * s),
      ],
    );
  }

  /// The torso's outline: chest side down from the shoulder, back side up.
  static List<Offset> _torso(SideJoints p, double scale) {
    final along = p.hip - p.shoulder;
    final length = along.distance;
    final u = TutorialOutline._unit(along);
    final n = Offset(-u.dy, u.dx);
    final front = <Offset>[];
    final back = <Offset>[];
    for (final (t, chest, spine) in _profile) {
      final c = p.shoulder + u * (t * length);
      front.add(c + n * (chest * scale));
      back.add(c - n * (spine * scale));
    }
    return [...front, ...back.reversed];
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static Offset _rotate(Offset v, double degrees) {
    final r = degrees * math.pi / 180;
    final c = math.cos(r);
    final s = math.sin(r);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  /// The elbow (or knee) between [from] and [to], [first] and [second]
  /// long, on the side [pick] chooses of the two that fit.
  static Offset _bend(
    Offset from,
    Offset to,
    double first,
    double second,
    Offset Function(Offset a, Offset b) pick,
  ) {
    final d = to - from;
    var reach = d.distance;
    if (reach >= first + second - 0.01) {
      return Offset.lerp(from, to, first / (first + second))!;
    }
    reach = math.max(reach, 0.5);
    final a = math.atan2(d.dy, d.dx);
    final c =
        ((first * first + reach * reach - second * second) /
                (2 * first * reach))
            .clamp(-1.0, 1.0);
    final b = math.acos(c);
    return pick(
      Offset(
        from.dx + first * math.cos(a + b),
        from.dy + first * math.sin(a + b),
      ),
      Offset(
        from.dx + first * math.cos(a - b),
        from.dy + first * math.sin(a - b),
      ),
    );
  }

  static Offset _rightmost(Offset a, Offset b) => a.dx > b.dx ? a : b;
  static Offset _lowest(Offset a, Offset b) => a.dy > b.dy ? a : b;

  /// A push-up seen from the side (`pushPose`).
  static SideJoints _push(double k) {
    const wrist = Offset(0, -1.3);
    const top = TutorialBody.upperArm + TutorialBody.forearm + 0.2;
    const low = 10.5;
    final h = _lerp(top, low, k);
    const start = Offset(0.4, -top);
    const body = TutorialBody.torso + TutorialBody.thigh + TutorialBody.shin;
    const ankleY = -(TutorialBody.ankle + 1.8);
    final dx0 = math.sqrt(body * body - math.pow(start.dy - ankleY, 2));
    final ankle = Offset(start.dx + dx0, ankleY);
    final shoulder = Offset(
      ankle.dx - math.sqrt(body * body - math.pow(-h - ankleY, 2)),
      -h,
    );
    final u = TutorialOutline._unit(ankle - shoulder);
    final hip = shoulder + u * TutorialBody.torso;
    final knee = shoulder + u * (TutorialBody.torso + TutorialBody.thigh);
    return _plank(
      shoulder,
      hip,
      knee,
      ankle,
      wrist,
      u,
      (ankle) {
        final toe = Offset(ankle.dx - TutorialBody.toe * 0.55, -0.2);
        final heel = Offset(ankle.dx + TutorialBody.heel * 0.9, ankleY - 1.4);
        return (toe, heel);
      },
      kneeShift: const Offset(2.2, -0.6),
      ankleShift: const Offset(2.4, -0.2),
      toeShift: const Offset(2.4, 0),
      heelShift: const Offset(2.4, -0.2),
    );
  }

  /// A push-up with the knees on the floor (`kneePose`): the shins and feet
  /// lift behind.
  static SideJoints _kneel(double k) {
    const wrist = Offset(0, -1.3);
    const top = TutorialBody.upperArm + TutorialBody.forearm + 0.2;
    const low = 12.5;
    final h = _lerp(top, low, k);
    const body = TutorialBody.torso + TutorialBody.thigh;
    const kneeY = -2.4;
    const start = Offset(0.4, -top);
    final knee = Offset(
      start.dx + math.sqrt(body * body - math.pow(start.dy - kneeY, 2)),
      kneeY,
    );
    final shoulder = Offset(
      knee.dx - math.sqrt(body * body - math.pow(-h - kneeY, 2)),
      -h,
    );
    final u = TutorialOutline._unit(knee - shoulder);
    final hip = shoulder + u * TutorialBody.torso;
    final shinDirection = TutorialOutline._unit(
      Offset(math.cos(38 * math.pi / 180), -math.sin(38 * math.pi / 180)),
    );
    final ankle = knee + shinDirection * TutorialBody.shin;
    final foot = _rotate(shinDirection, -80);
    return _plank(
      shoulder,
      hip,
      knee,
      ankle,
      wrist,
      u,
      (ankle) {
        final toe = ankle + foot * (-TutorialBody.toe * 0.7);
        final heel = ankle + foot * (TutorialBody.heel * 0.6);
        return (toe, heel);
      },
      kneeShift: const Offset(2.2, -0.4),
      ankleShift: const Offset(2.4, -0.6),
      toeShift: const Offset(2.4, -0.4),
      heelShift: const Offset(2.4, -0.4),
    );
  }

  /// What a push-up and a knee push-up share: the arm to the planted hand,
  /// the head ahead of the shoulder, and the far side's small offsets.
  static SideJoints _plank(
    Offset shoulder,
    Offset hip,
    Offset knee,
    Offset ankle,
    Offset wrist,
    Offset u,
    (Offset, Offset) Function(Offset ankle) feet, {
    required Offset kneeShift,
    required Offset ankleShift,
    required Offset toeShift,
    required Offset heelShift,
  }) {
    final elbow = _bend(
      shoulder,
      wrist,
      TutorialBody.upperArm,
      TutorialBody.forearm,
      _rightmost,
    );
    final fingertip = Offset(wrist.dx - TutorialBody.hand, -0.25);
    final forward = -u;
    final look = TutorialOutline._unit(_rotate(forward, 9));
    final head =
        shoulder + look * (TutorialBody.neck + TutorialBody.headRadius * 0.92);
    final neckEnd =
        shoulder + look * (TutorialBody.neck + TutorialBody.headRadius * 0.4);
    final (toe, heel) = feet(ankle);
    const off = Offset(2.6, -0.9);
    return SideJoints(
      shoulder: shoulder,
      hip: hip,
      knee: knee,
      ankle: ankle,
      elbow: elbow,
      wrist: wrist,
      fingertip: fingertip,
      head: head,
      neckEnd: neckEnd,
      toe: toe,
      heel: heel,
      farShoulder: shoulder + off,
      farElbow: elbow + const Offset(2.2, -0.9),
      farWrist: wrist + const Offset(2.4, -0.3),
      farFingertip: fingertip + const Offset(2.4, -0.1),
      farHip: hip + off,
      farKnee: knee + kneeShift,
      farAnkle: ankle + ankleShift,
      farToe: toe + toeShift,
      farHeel: heel + heelShift,
      look: look,
    );
  }

  /// A squat seen from the side (`squatPose`), both hands held together in
  /// front of the chest: the right fist wrapped by the left hand.
  static SideJoints _squat(double k) {
    const ankle = Offset(0, -TutorialBody.ankle);
    Offset towards(double degrees, double length, {bool forward = true}) {
      final r = degrees * math.pi / 180;
      return Offset((forward ? -1 : 1) * math.sin(r), -math.cos(r)) * length;
    }

    final knee = ankle + towards(_lerp(3, 33, k), TutorialBody.shin);
    final hip =
        knee + towards(_lerp(2, 84, k), TutorialBody.thigh, forward: false);
    final lean = _lerp(3, 41, k);
    final shoulder = hip + towards(lean, TutorialBody.torso);
    final look = towards(lean * 0.62, 1);
    final head =
        shoulder + look * (TutorialBody.neck + TutorialBody.headRadius * 0.92);
    final neckEnd =
        shoulder + look * (TutorialBody.neck + TutorialBody.headRadius * 0.4);
    // The hands held 19 in front of the shoulder and 8 below it, along the
    // torso.
    final up = TutorialOutline._unit(shoulder - hip);
    final ahead = Offset(up.dy, -up.dx);
    final wrist = shoulder + ahead * 19 + up * -8;
    final elbow = _bend(
      shoulder,
      wrist,
      TutorialBody.upperArm,
      TutorialBody.forearm,
      _lowest,
    );
    final fingertip = wrist + ahead * 1.6;
    const toe = Offset(-TutorialBody.toe, -0.2);
    const heel = Offset(TutorialBody.heel, -0.6);
    final farShoulder = shoulder + const Offset(1.6, -1.2);
    final farWrist = wrist + const Offset(0.9, -1.1);
    const off = Offset(1.4, -1.0);
    return SideJoints(
      shoulder: shoulder,
      hip: hip,
      knee: knee,
      ankle: ankle,
      elbow: elbow,
      wrist: wrist,
      fingertip: fingertip,
      head: head,
      neckEnd: neckEnd,
      toe: toe,
      heel: heel,
      farShoulder: farShoulder,
      farElbow: _bend(
        farShoulder,
        farWrist,
        TutorialBody.upperArm,
        TutorialBody.forearm,
        _lowest,
      ),
      farWrist: farWrist,
      farFingertip: fingertip + const Offset(0.9, -1.1),
      farHip: hip + off,
      farKnee: knee + const Offset(2.6, -1.1),
      farAnkle: ankle + const Offset(2.8, -0.4),
      farToe: toe + const Offset(3.2, 0),
      farHeel: heel + const Offset(3.0, -0.1),
      look: look,
      fist: wrist + ahead * 1.2,
    );
  }
}

/// A front-view person on the camera: its pieces by fill, and the heights
/// the battle's lines are drawn at.
class FrontFigure {
  const FrontFigure({
    this.far = const [],
    this.belly = const [],
    required this.body,
    this.arms = const [],
    this.clasp,
    this.lineY,
    this.kneeY,
  });

  /// The legs behind, in the darker gray; the belly in the near-ink.
  final List<Path> far;
  final List<Path> belly;

  /// The rest, in ink.
  final List<Path> body;

  /// Arms held in front of the body: ink with a white edge.
  final List<Path> arms;

  /// The fingers' line over the held hands, in gray.
  final Path? clasp;

  /// The push-up's shoulder height, or the squat's hip height, where the
  /// battle draws its line; null on the setup's camera.
  final double? lineY;

  /// The squat's knee height (its other line); null for a push-up.
  final double? kneeY;
}

/// The camera's front-view people (`cam2.js`, `cam3.js`), in the camera's
/// [box].
abstract final class TutorialFront {
  static const box = Size(290, 387);

  static Offset _lerpP(Offset a, Offset b, double k) => Offset.lerp(a, b, k)!;
  static List<Offset> _lerpAll(List<Offset> a, List<Offset> b, double k) => [
    for (var i = 0; i < a.length; i++) _lerpP(a[i], b[i], k),
  ];
  static List<Offset> _mirror(List<Offset> points) => [
    for (final p in points) Offset(box.width - p.dx, p.dy),
  ];
  static double _lerp(double a, double b, double k) => a + (b - a) * k;

  /// The push-up as the setup's camera sees it, arms straight, filling its
  /// guide (`cam2.js` `pushFront`).
  static FrontFigure setupPush() {
    final limb = TutorialOutline.limb;
    final ellipse = TutorialOutline.ellipse;
    const armL = [Offset(86, 124), Offset(76, 220), Offset(62, 328)];
    const chest = [
      Offset(80, 104),
      Offset(110, 94),
      Offset(145, 92),
      Offset(180, 94),
      Offset(210, 104),
      Offset(206, 124),
      Offset(194, 170),
      Offset(178, 196),
      Offset(145, 204),
      Offset(112, 196),
      Offset(96, 170),
      Offset(84, 124),
    ];
    const belly = [
      Offset(112, 194),
      Offset(178, 194),
      Offset(172, 234),
      Offset(145, 244),
      Offset(118, 234),
    ];
    const legL = [Offset(131, 238), Offset(135, 304)];
    return FrontFigure(
      far: [
        ...limb(legL, [18, 10]),
        ...limb(_mirror(legL), [18, 10]),
        ellipse(const Offset(134, 312), 7, 5),
        ellipse(const Offset(156, 312), 7, 5),
      ],
      belly: [TutorialOutline.blob(belly)],
      body: [
        TutorialOutline.blob(chest),
        ...limb(armL, [28, 22, 16]),
        ...limb(_mirror(armL), [28, 22, 16]),
        ...limb(const [Offset(62, 328), Offset(58, 352)], [16, 15]),
        ...limb(const [Offset(228, 328), Offset(232, 352)], [16, 15]),
        ellipse(const Offset(56, 364), 25, 13),
        ellipse(const Offset(234, 364), 25, 13),
        TutorialOutline.circle(const Offset(88, 114), 17),
        TutorialOutline.circle(const Offset(202, 114), 17),
        ...limb(const [Offset(145, 70), Offset(145, 96)], [34, 42]),
        ellipse(const Offset(145, 46), 32, 33),
      ],
    );
  }

  /// Standing for a squat, both hands held together in front of the chest
  /// (`cam2.js` `standFront`).
  static FrontFigure setupStand() {
    final limb = TutorialOutline.limb;
    final ellipse = TutorialOutline.ellipse;
    const torso = [
      Offset(93, 100),
      Offset(118, 92),
      Offset(145, 90),
      Offset(172, 92),
      Offset(197, 100),
      Offset(200, 116),
      Offset(184, 150),
      Offset(179, 190),
      Offset(181, 212),
      Offset(145, 222),
      Offset(109, 212),
      Offset(111, 190),
      Offset(106, 150),
      Offset(90, 116),
    ];
    const armL = [Offset(99, 104), Offset(83, 148), Offset(134, 124)];
    const legL = [Offset(127, 208), Offset(119, 275), Offset(114, 334)];
    return FrontFigure(
      body: [
        TutorialOutline.blob(torso),
        ...limb(const [Offset(145, 74), Offset(145, 94)], [20, 24]),
        ...limb(legL, [30, 20, 14]),
        ...limb(_mirror(legL), [30, 20, 14]),
        ellipse(const Offset(106, 343), 15, 7),
        ellipse(const Offset(184, 343), 15, 7),
        ellipse(const Offset(145, 52), 24, 25),
      ],
      arms: [
        ...limb(armL, [20, 16, 12]),
        ...limb(_mirror(armL), [20, 16, 12]),
        ellipse(const Offset(145, 123), 14, 11),
      ],
      clasp: Path()
        ..moveTo(136, 119)
        ..quadraticBezierTo(145, 113, 156, 120),
    );
  }

  /// A push-up on the battle's camera [k] of the way down (0 arms straight,
  /// 1 at the bottom); [knee] puts the knees on the floor, the shins and
  /// feet lifting behind the hips (`cam3.js` `push`). [FrontFigure.lineY]
  /// is the shoulders' height.
  static FrontFigure push(double k, {bool knee = false}) {
    final limb = TutorialOutline.limb;
    final ellipse = TutorialOutline.ellipse;
    final armL = _lerpAll(
      const [Offset(107, 160), Offset(88, 236), Offset(68, 304)],
      const [Offset(100, 242), Offset(54, 260), Offset(68, 304)],
      k,
    );
    final chest = _lerpAll(
      const [
        Offset(104, 150),
        Offset(124, 140),
        Offset(145, 138),
        Offset(166, 140),
        Offset(186, 150),
        Offset(186, 166),
        Offset(172, 194),
        Offset(145, 206),
        Offset(118, 194),
        Offset(104, 166),
      ],
      const [
        Offset(98, 232),
        Offset(120, 224),
        Offset(145, 222),
        Offset(170, 224),
        Offset(192, 232),
        Offset(190, 246),
        Offset(176, 266),
        Offset(145, 274),
        Offset(114, 266),
        Offset(100, 246),
      ],
      k,
    );
    final belly = _lerpAll(
      const [
        Offset(120, 194),
        Offset(170, 194),
        Offset(165, 222),
        Offset(145, 230),
        Offset(125, 222),
      ],
      const [
        Offset(120, 264),
        Offset(170, 264),
        Offset(166, 280),
        Offset(145, 286),
        Offset(124, 280),
      ],
      k,
    );
    final hips = _lerpAll(
      const [
        Offset(125, 216),
        Offset(165, 216),
        Offset(162, 238),
        Offset(145, 242),
        Offset(128, 238),
      ],
      const [
        Offset(127, 276),
        Offset(163, 276),
        Offset(160, 286),
        Offset(145, 289),
        Offset(130, 286),
      ],
      k,
    );
    final legTop = _lerp(236, 282, k);
    final head = _lerpP(const Offset(145, 96), const Offset(145, 184), k);
    final neck = [
      _lerpP(const Offset(145, 118), const Offset(145, 206), k),
      _lerpP(const Offset(145, 146), const Offset(145, 232), k),
    ];
    final shoulders = [
      _lerpP(const Offset(106, 158), const Offset(100, 240), k),
      _lerpP(const Offset(184, 158), const Offset(190, 240), k),
    ];
    return FrontFigure(
      far: [
        TutorialOutline.blob(hips),
        if (knee) ...[
          ...limb([Offset(136, legTop), const Offset(137, 292)], [13, 11]),
          ...limb([Offset(154, legTop), const Offset(153, 292)], [13, 11]),
          ...limb(const [Offset(134, 268), Offset(122, 236)], [9, 7]),
          ...limb(const [Offset(156, 268), Offset(168, 236)], [9, 7]),
          ellipse(const Offset(120, 231), 6, 4.5),
          ellipse(const Offset(170, 231), 6, 4.5),
        ] else ...[
          ...limb([Offset(136, legTop), const Offset(139, 272)], [12, 7]),
          ...limb([Offset(154, legTop), const Offset(151, 272)], [12, 7]),
          ellipse(const Offset(139, 277), 5, 3.5),
          ellipse(const Offset(151, 277), 5, 3.5),
        ],
      ],
      belly: [TutorialOutline.blob(belly)],
      body: [
        TutorialOutline.blob(chest),
        ...limb(armL, [26, 20, 16]),
        ...limb(_mirror(armL), [26, 20, 16]),
        ...limb(const [Offset(68, 304), Offset(64, 314)], [16, 14]),
        ...limb(const [Offset(222, 304), Offset(226, 314)], [16, 14]),
        ellipse(const Offset(64, 318), 20, 9),
        ellipse(const Offset(226, 318), 20, 9),
        TutorialOutline.circle(shoulders[0], 15),
        TutorialOutline.circle(shoulders[1], 15),
        ...limb(neck, [22, 26]),
        ellipse(head, _lerp(25, 27, k), _lerp(28, 29, k)),
      ],
      lineY: _lerp(156, 238, k),
    );
  }

  /// A squat on the battle's camera [k] of the way down (0 standing, 1
  /// sitting), both hands held together in front of the chest: seen from
  /// the front the thighs grow short and the knees part (`cam3.js`
  /// `squat`). [FrontFigure.lineY] is the hips' height, [FrontFigure.kneeY]
  /// the knees'.
  static FrontFigure squat(double k) {
    final limb = TutorialOutline.limb;
    final ellipse = TutorialOutline.ellipse;
    final dy = _lerp(0, 74, k);
    Offset up(Offset p) => Offset(p.dx, p.dy + dy);
    const torsoPoints = [
      Offset(113, 94),
      Offset(128, 88),
      Offset(145, 87),
      Offset(162, 88),
      Offset(177, 94),
      Offset(179, 108),
      Offset(171, 140),
      Offset(167, 166),
      Offset(171, 190),
      Offset(145, 198),
      Offset(119, 190),
      Offset(123, 166),
      Offset(119, 140),
      Offset(111, 108),
    ];
    final torso = [
      for (final p in torsoPoints)
        Offset(
          145 + (p.dx - 145) * _lerp(1, 1.06, k),
          p.dy * _lerp(1, 0.92, k) + dy + _lerp(0, 8, k),
        ),
    ];
    final hipL = Offset(_lerp(132, 126, k), _lerp(190, 250, k));
    final kneeL = Offset(_lerp(130, 98, k), _lerp(258, 284, k));
    final ankleL = Offset(_lerp(131, 110, k), 326);
    final legL = [hipL, kneeL, ankleL];
    final head = up(const Offset(145, 58));
    final fist = up(const Offset(145, 132));
    final armL = [
      up(const Offset(116, 98)),
      Offset(_lerp(104, 98, k), _lerp(144, 144, k) + dy),
      Offset(fist.dx - 9, fist.dy + 2),
    ];
    final legWidths = [_lerp(25, 30, k), _lerp(15, 19, k), 11.0];
    return FrontFigure(
      body: [
        TutorialOutline.blob(torso),
        ...limb(
          [up(const Offset(145, 72)), up(const Offset(145, 90))],
          [14, 16],
        ),
        ...limb(legL, legWidths),
        ...limb(_mirror(legL), legWidths),
        ellipse(Offset(ankleL.dx - 4, 332), 12, 6),
        ellipse(Offset(box.width - ankleL.dx + 4, 332), 12, 6),
        ellipse(head, 17, 19),
      ],
      arms: [
        ...limb(armL, [16, 13, 10]),
        ...limb(_mirror(armL), [16, 13, 10]),
        ellipse(fist, 13, 11),
      ],
      clasp: Path()
        ..moveTo(fist.dx - 9, fist.dy - 4)
        ..quadraticBezierTo(fist.dx, fist.dy - 10, fist.dx + 11, fist.dy - 3),
      lineY: hipL.dy,
      kneeY: kneeL.dy,
    );
  }
}
