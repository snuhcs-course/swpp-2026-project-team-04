import 'package:gymrats_app/models/rep_event.dart';

/// The declared plan of the frozen push-up evaluation set (P6/P7/P17).
///
/// Committed on 2026-10-30, before any evaluation run. The thresholds and
/// the expected labels below must not change once results exist; a change
/// is a new plan with its own date in `README.md`.

/// Minimum share for each metric to pass.
const m1CountAccuracyThreshold = 0.90;
const m2RejectionRateThreshold = 0.90;
const m3RightReasonThreshold = 0.80;

/// Phone positions of the recording standard (기준서 §2).
enum PhonePosition {
  a('A', 50, '60–65°'),
  b('B', 50, '75–80°'),
  c('C', 100, '60–65°'),
  d('D', 100, '75–80°');

  const PhonePosition(this.code, this.distanceCm, this.angle);

  final String code;
  final int distanceCm;
  final String angle;
}

/// One of the eight sets each person records (기준서 §3–§4, revised
/// 2026-10-30 for set 8).
enum EvalSet {
  normalA(1, PhonePosition.a, null, 'Normal push-ups'),
  kneelingBow(2, PhonePosition.a, RejectReason.kneesDown, 'Kneeling bow'),
  halfRepHeadNod(
    3,
    PhonePosition.b,
    RejectReason.insufficientDepth,
    'Half rep + head nod',
  ),
  noLockout(
    4,
    PhonePosition.b,
    RejectReason.incompleteExtension,
    'No lockout until the last rep',
  ),
  kneePushUp(5, PhonePosition.c, RejectReason.kneesDown, 'Knee push-ups'),
  bellyDown(6, PhonePosition.c, RejectReason.bellyDown, 'Belly on the floor'),
  normalD(7, PhonePosition.d, null, 'Normal push-ups'),
  kneelingStraightArms(
    8,
    PhonePosition.d,
    RejectReason.armsStraight,
    'Kneeling, arms straight, head down',
  );

  const EvalSet(this.number, this.position, this.reason, this.motion);

  /// The set's number in the recording standard, 1 to 8.
  final int number;
  final PhonePosition position;

  /// The reason every incorrect rep of the set should be rejected with;
  /// null for a normal set.
  final RejectReason? reason;
  final String motion;

  static EvalSet byNumber(int number) =>
      values.firstWhere((s) => s.number == number);

  /// The expected verdict of each rep, in order, for a set done as written
  /// with [reps] reps: null for a rep that should be counted.
  ///
  /// Set 4 comes up short [reps] - 1 times and locks out only at the end,
  /// so the judge rejects the first [reps] - 1 descents and counts the last
  /// (Hyunwoo, 2026-10-30).
  List<RejectReason?> expectedPerRep(int reps) => [
    for (var i = 0; i < reps; i++)
      this == noLockout && i == reps - 1 ? null : reason,
  ];
}
