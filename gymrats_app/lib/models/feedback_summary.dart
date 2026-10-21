// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
/// The one-line form feedback a history row shows for a battle.
///
/// Made on the phone from the battle's form report and stored on the server
/// next to it, so a list never has to load whole reports.
class FeedbackSummary {
  const FeedbackSummary({
    required this.validReps,
    required this.invalidReps,
    required this.issueCount,
    this.accuracy,
    this.topIssue,
  });

  final int validReps;
  final int invalidReps;

  /// Counted reps out of all judged ones, 0 to 1; null when none was judged.
  final double? accuracy;

  /// Title of the first thing to fix, e.g. "팔꿈치가 벌어져요"; null when the
  /// form had nothing to fix.
  final String? topIssue;

  /// How many things to fix the feedback screen lists.
  final int issueCount;

  /// What the row says: the top issue, or praise when there is none.
  String get line => topIssue ?? '좋은 자세';

  Map<String, Object?> toJson() => {
    'valid_reps': validReps,
    'invalid_reps': invalidReps,
    'accuracy': accuracy,
    'top_issue': topIssue,
    'issue_count': issueCount,
  };

  factory FeedbackSummary.fromJson(Map<String, Object?> json) =>
      FeedbackSummary(
        validReps: json['valid_reps']! as int,
        invalidReps: json['invalid_reps']! as int,
        accuracy: (json['accuracy'] as num?)?.toDouble(),
        topIssue: json['top_issue'] as String?,
        issueCount: json['issue_count']! as int,
      );
}
