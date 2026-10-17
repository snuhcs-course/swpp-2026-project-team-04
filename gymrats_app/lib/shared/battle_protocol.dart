// Pure Dart contract shared by the server and Flutter. No camera/video fields.
const battleAvatarIds = {'avatar_01', 'avatar_02', 'avatar_03', 'avatar_04'};
const battleReasons = {
  'insufficient_depth',
  'incomplete_extension',
  'shoulders_not_level',
  'too_fast',
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
