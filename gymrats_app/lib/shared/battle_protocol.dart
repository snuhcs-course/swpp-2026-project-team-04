// Pure Dart contract shared by the server and Flutter. No camera/video fields.
/// Whether [value] may travel in `avatar_id`: a short id of lowercase
/// letters, digits and `_` (1 to 32). Since W3 it holds the player's
/// character id (`mouse`, `bear`, ...); older apps still send their avatar
/// id (`avatar_01`). The server checks only this shape and passes the value
/// on; each app decides what it draws for it.
bool isBattleAvatarId(Object? value) =>
    value is String && _battleAvatarId.hasMatch(value);

final _battleAvatarId = RegExp(r'^[a-z0-9_]{1,32}$');

const battleReasons = {
  'insufficient_depth',
  'incomplete_extension',
  'shoulders_not_level',
  'shallow_squat',
  'stand_up_fully',
  'too_fast',
  'knees_down',
  'arms_straight',
  'belly_down',
  'not_floor_push_up',
  'phone_moved',
};

class BattleProtocolError implements Exception {
  const BattleProtocolError(this.code);
  final String code;
}

Never invalid([String code = 'INVALID_PAYLOAD']) =>
    throw BattleProtocolError(code);
Map<String, dynamic> object(dynamic value) =>
    value is Map<String, dynamic> ? value : invalid();
int integer(dynamic value, int min, int max) =>
    value is int && value >= min && value <= max ? value : invalid();
double number(dynamic value, double min, double max) =>
    value is num && value.isFinite && value >= min && value <= max
    ? value.toDouble()
    : invalid();
void fields(Map<String, dynamic> value, Set<String> allowed) {
  if (value.keys.any((key) => !allowed.contains(key))) invalid();
}

Map<String, dynamic> checkedPose(dynamic value, {int durationMs = 60000}) {
  final p = object(value);
  fields(p, {
    'frame_seq',
    'elapsed_ms',
    'aspect_ratio',
    'has_person',
    'joints',
  });
  final seq = integer(p['frame_seq'], 1, 0x7fffffff),
      elapsed = integer(p['elapsed_ms'], 0, durationMs - 1);
  final aspect = number(p['aspect_ratio'], .01, 10);
  if (p['has_person'] is! bool || p['joints'] is! List) invalid();
  final source = p['joints'] as List;
  if (source.length > 33) invalid();
  if ((p['has_person'] == false && source.isNotEmpty) ||
      (p['has_person'] == true && source.isEmpty)) {
    invalid();
  }
  final ids = <int>{}, joints = <List<num>>[];
  for (final row in source) {
    if (row is! List || row.length != 5) invalid();
    final id = integer(row[0], 0, 32);
    if (!ids.add(id)) invalid();
    joints.add([
      id,
      number(row[1], -2, 3),
      number(row[2], -2, 3),
      number(row[3], -10, 10),
      number(row[4], 0, 1),
    ]);
  }
  return {
    'frame_seq': seq,
    'elapsed_ms': elapsed,
    'aspect_ratio': aspect,
    'has_person': p['has_person'],
    'joints': joints,
  };
}
