/// Why a repetition was rejected.
enum RejectReason {
  insufficientDepth('Go lower'),
  incompleteExtension('Lock out your arms'),
  shouldersNotLevel('Keep shoulders level'),
  tooFast('Slow down');

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
}
