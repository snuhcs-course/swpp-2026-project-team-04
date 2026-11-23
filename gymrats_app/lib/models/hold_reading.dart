/// The picture in a hold stage's warning box (arcade hold spec 4). The hold
/// screen draws every one of them, for both poses, and a pose's definition
/// only names one for each of its faults (spec 3, "그림").
enum HoldIcon {
  /// Knees coming off the floor (the design's `move=plank` warning).
  knee,

  /// Sitting lower (`move=sit`, `reason=low`).
  low,

  /// Knees pushed apart (`move=sit`, `reason=spread`).
  spread,

  /// The setup cue's body icon, for "화면 밖".
  offScreen,

  /// An empty box of the same size: the setup cues have no arm or head
  /// icon to borrow (spec 4).
  blank,
}

/// The gray figure the camera box shows where the camera picture is not
/// (the design's `move=plank` and `move=sit`), and the pose's icon on the
/// briefing card.
enum HoldSilhouette { plank, sit }

/// The guide lines over the camera while holding: the push-up battle's
/// chest height lines, or the squat battle's hip and knee heights
/// (`SquatHeightOverlay`).
enum HoldGuide { chestHeight, squatHeight }

/// Why a held pose broke, and what the camera box says about it: two short
/// lines of big text and an icon (spec 4).
final class HoldFault {
  const HoldFault({required this.id, required this.cue, required this.icon});

  /// Tells faults apart: two faults with the same id are the same.
  final String id;

  /// The big text, its first line and its second, e.g. ('무릎', '떼요').
  final (String, String) cue;

  final HoldIcon icon;

  /// The cue as one line, e.g. "무릎 떼요", for a screen reader.
  String get words => '${cue.$1} ${cue.$2}';

  /// The common fault of every pose: the body could not be read for too
  /// long, or left the pose (spec 3, "화면 밖").
  static const offScreen = HoldFault(
    id: 'offScreen',
    cue: ('화면', '안으로'),
    icon: HoldIcon.offScreen,
  );

  @override
  bool operator ==(Object other) => other is HoldFault && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'HoldFault($id)';
}

/// What a pose reading made of one frame (spec 3).
enum HoldReadingKind {
  /// The pose is held.
  ok,

  /// The pose broke, for [HoldReading.fault].
  broken,

  /// The parts the pose is read from were not seen well enough. A part that
  /// is not seen never breaks the pose.
  unknown,
}

/// One frame's reading of a held pose.
final class HoldReading {
  const HoldReading._(this.kind, this.fault);

  /// A broken pose, for [fault].
  const HoldReading.broken(HoldFault this.fault)
    : kind = HoldReadingKind.broken;

  static const ok = HoldReading._(HoldReadingKind.ok, null);
  static const unknown = HoldReading._(HoldReadingKind.unknown, null);

  final HoldReadingKind kind;

  /// Why it broke; null unless [kind] is [HoldReadingKind.broken].
  final HoldFault? fault;

  @override
  bool operator ==(Object other) =>
      other is HoldReading && other.kind == kind && other.fault == fault;

  @override
  int get hashCode => Object.hash(kind, fault);

  @override
  String toString() => switch (kind) {
    HoldReadingKind.ok => 'HoldReading.ok',
    HoldReadingKind.unknown => 'HoldReading.unknown',
    HoldReadingKind.broken => 'HoldReading.broken(${fault!.id})',
  };
}
