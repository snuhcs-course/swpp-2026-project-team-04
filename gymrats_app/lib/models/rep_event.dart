/// Why a repetition was rejected.
enum RejectReason {
  insufficientDepth('Go lower'),
  incompleteExtension('Lock out your arms'),
  shouldersNotLevel('Keep shoulders level'),

  /// No longer produced by the rep judge. A fast descent is feedback after
  /// the battle. Kept so an older report still reads, and so the bot can
  /// still draw a rejected rep.
  tooFast('Slow down'),

  /// The knees were seen bent on the floor: a knee push-up.
  kneesDown('Knees up'),

  /// The head reached the bottom while the arms stayed straight.
  armsStraight('Bend your arms'),

  /// The hips were seen down at the hands while the head was at the bottom.
  bellyDown('Hips up'),

  /// The body was seen upright, as when pushing off a wall.
  notFloorPushUp('Floor push-up'),

  /// The phone leaned or shook after the round started.
  phoneMoved('Hold the phone still');

  const RejectReason(this.message);

  /// Short text shown to the user while the match is running.
  final String message;
}

/// One judged repetition, valid or not.
///
/// [maxDepth], [minElbowAngle], and [maxTilt] are kept so a later result
/// screen can explain the rep without the original frames.
class RepEvent {
  const RepEvent({
    required this.index,
    required this.valid,
    required this.at,
    this.reason,
    this.maxDepth,
    this.minElbowAngle,
    this.maxTilt,
    this.descent,
  });

  /// 1-based index within the current judging session.
  final int index;

  final bool valid;

  /// Null when [valid] is true.
  final RejectReason? reason;

  /// Time of the frame that closed the rep, from the injected clock.
  final Duration at;

  /// Deepest head drop of the attempt, in top-pose shoulder widths.
  final double? maxDepth;

  /// Smallest elbow angle seen during the attempt, in degrees. Null when
  /// the arms were never visible; at the bottom they usually are not.
  final double? minElbowAngle;

  /// Largest shoulder-line tilt from horizontal during the attempt, degrees.
  final double? maxTilt;

  /// Time from the start of the attempt until the head first reached the
  /// bottom. Null when the rep never got that far.
  final Duration? descent;
}
