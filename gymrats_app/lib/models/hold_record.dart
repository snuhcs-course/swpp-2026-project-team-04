import 'arcade_stage.dart';

/// One warning of a hold: when it came, counted from GO, and its fault.
class HoldRecordWarning {
  const HoldRecordWarning({
    required this.at,
    required this.faultId,
    required this.words,
  });

  /// From GO, paused time included.
  final Duration at;

  /// The fault's id, e.g. "plank.kneeDown".
  final String faultId;

  /// The fault's words, e.g. "무릎 떼요".
  final String words;

  Map<String, Object?> toJson() => {
    'at_ms': at.inMilliseconds,
    'fault': faultId,
    'words': words,
  };

  static HoldRecordWarning fromJson(Map<String, Object?> json) =>
      HoldRecordWarning(
        at: Duration(milliseconds: (json['at_ms']! as num).toInt()),
        faultId: json['fault']! as String,
        words: json['words']! as String,
      );
}

/// A time the hold's clock stood, counted from GO: a warning until the
/// pose was held again.
class HoldRecordPause {
  const HoldRecordPause({required this.start, required this.end});

  final Duration start;
  final Duration end;

  Duration get length => end - start;

  Map<String, Object?> toJson() => {
    'start_ms': start.inMilliseconds,
    'end_ms': end.inMilliseconds,
  };

  static HoldRecordPause fromJson(Map<String, Object?> json) => HoldRecordPause(
    start: Duration(milliseconds: (json['start_ms']! as num).toInt()),
    end: Duration(milliseconds: (json['end_ms']! as num).toInt()),
  );
}

/// One played hold stage, kept on the phone for its report and the archive
/// (P13): the pose, the time held and the time from GO to the end, the
/// warnings and pauses, and the stars against the stage's star seconds.
/// No frames, video or joints: only these numbers.
class HoldRecord {
  const HoldRecord({
    required this.endedAt,
    required this.pose,
    required this.stage,
    required this.held,
    required this.elapsed,
    required this.stars,
    required this.starSeconds,
    this.warnings = const [],
    this.pauses = const [],
    this.endedByWarnings = false,
    this.accountId,
  });

  /// When the hold ended, local time.
  final DateTime endedAt;
  final HoldPose pose;

  /// The arcade stage's number.
  final int stage;

  /// The time really held.
  final Duration held;

  /// From GO to the end, paused time included.
  final Duration elapsed;

  /// Stars earned, 0 to 3.
  final int stars;

  /// The seconds each star asks for, in order.
  final List<int> starSeconds;
  final List<HoldRecordWarning> warnings;
  final List<HoldRecordPause> pauses;

  /// Whether a second warning ended it before the last star.
  final bool endedByWarnings;

  /// The account that played it; null in a record kept before accounts
  /// were (2026-11-26). The phone keeps every account's holds in one place.
  final int? accountId;

  /// Whether the signed-in [account] may see it: its own, or a record with
  /// no account; everything when no one is known to be signed in.
  bool isOf(int? account) =>
      account == null || accountId == null || accountId == account;

  /// Tells records apart, and names the record's file.
  String get id => endedAt.microsecondsSinceEpoch.toString();

  Map<String, Object?> toJson() => {
    'ended_at': endedAt.toUtc().toIso8601String(),
    'pose': pose.name,
    'stage': stage,
    'held_ms': held.inMilliseconds,
    'elapsed_ms': elapsed.inMilliseconds,
    'stars': stars,
    'star_seconds': starSeconds,
    'warnings': [for (final w in warnings) w.toJson()],
    'pauses': [for (final p in pauses) p.toJson()],
    'ended_by_warnings': endedByWarnings,
    'account_id': ?accountId,
  };

  /// Reads [toJson]'s map; throws on a map it did not write.
  static HoldRecord fromJson(Map<String, Object?> json) => HoldRecord(
    endedAt: DateTime.parse(json['ended_at']! as String).toLocal(),
    pose: HoldPose.values.byName(json['pose']! as String),
    stage: (json['stage']! as num).toInt(),
    held: Duration(milliseconds: (json['held_ms']! as num).toInt()),
    elapsed: Duration(milliseconds: (json['elapsed_ms']! as num).toInt()),
    stars: (json['stars']! as num).toInt(),
    starSeconds: [
      for (final s in json['star_seconds']! as List) (s as num).toInt(),
    ],
    warnings: [
      for (final w in json['warnings']! as List)
        HoldRecordWarning.fromJson(Map<String, Object?>.from(w as Map)),
    ],
    pauses: [
      for (final p in json['pauses']! as List)
        HoldRecordPause.fromJson(Map<String, Object?>.from(p as Map)),
    ],
    endedByWarnings: json['ended_by_warnings']! as bool,
    accountId: (json['account_id'] as num?)?.toInt(),
  );
}
