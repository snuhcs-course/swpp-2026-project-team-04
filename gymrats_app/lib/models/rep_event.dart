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
/// [minElbowAngle], [minSpanRatio], and [maxTilt] are kept so a later
/// result screen can explain the rep without the original frames.
class RepEvent {
  const RepEvent({
    required this.index,
    required this.valid,
    required this.at,
    this.reason,
    this.minElbowAngle,
    this.minSpanRatio,
    this.maxTilt,
  });

  /// 1-based index within the current judging session.
  final int index;

  final bool valid;

  /// Null when [valid] is true.
  final RejectReason? reason;

  /// Time of the frame that closed the rep, from the injected clock.
  final Duration at;

  /// Smallest elbow angle seen during the attempt, in degrees.
  final double? minElbowAngle;

  /// Smallest shoulder-to-wrist span, relative to the top pose (1 = top).
  final double? minSpanRatio;

  /// Largest shoulder-line tilt from horizontal during the attempt, degrees.
  final double? maxTilt;
}
