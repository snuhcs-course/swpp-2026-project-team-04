// Pure Dart contract shared by the server and Flutter. No camera/video fields.
/// Whether [value] may travel in `avatar_id`: a short id of lowercase
/// letters, digits and `_` (1 to 32). Since W3 it holds the player's
/// character id (`mouse`, `bear`, ...); older apps still send their avatar
/// id (`avatar_01`). The server checks only this shape and passes the value
/// on; each app decides what it draws for it.
bool isBattleAvatarId(Object? value) =>
    value is String && _battleAvatarId.hasMatch(value);

final _battleAvatarId = RegExp(r'^[a-z0-9_]{1,32}$');

/// Whether [value] may travel in `queue.join`'s `friend_id` (P9): the
/// player id of the friend to battle, as the server names players (the
/// account id, in digits). A join with it is paired only with that friend,
/// and only when they named this player back; one without it is a main
/// match join, as before.
bool isBattleFriendId(Object? value) =>
    value is String && _battleFriendId.hasMatch(value);

final _battleFriendId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

/// How long the two players have to finish the pose setup, counted from the
/// moment both phones have said (`match.setup`) that their setup camera is
/// on. When it runs out before both are ready, the server cancels the match
/// with [battleSetupTimeoutReason]; nobody wins or loses. The Iteration 5
/// trial (P12) started at 10 s; 20 s since A6 (2026-11-25), as getting the
/// phone set and the whole body in view took longer. The server may be given
/// another.
const battleSetupTimeout = Duration(seconds: 20);

/// `match.cancelled` reason when the setup time above ran out.
const battleSetupTimeoutReason = 'setup_timeout';

/// P10: how long a player who sent `accept_virtual` waits in the main queue
/// for a real player. Real players are paired at once; after this the
/// server finds them a match with a simulated opponent instead.
const battleVirtualWait = Duration(seconds: 10);

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
