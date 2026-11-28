import '../../models/exercise_type.dart';
import '../../shared/battle_protocol.dart';
import '../api/api_client.dart';

/// The friend code that finds [nickname]'s account: `nickname#tag`, the
/// tag being the account id padded to four digits ("쥐돌이#0042"). Nicknames
/// repeat; the id tells them apart. The server builds the same code.
String friendCode(String nickname, int id) =>
    '$nickname#${id.toString().padLeft(4, '0')}';

/// Another account, as the friends list shows it.
class FriendPerson {
  const FriendPerson({
    required this.id,
    required this.nickname,
    required this.code,
  });

  final int id;
  final String nickname;
  final String code;

  @override
  bool operator ==(Object other) =>
      other is FriendPerson &&
      other.id == id &&
      other.nickname == nickname &&
      other.code == code;

  @override
  int get hashCode => Object.hash(id, nickname, code);
}

/// An open friend request: [person] asked me (incoming) or I asked them
/// (outgoing).
class FriendRequestItem {
  const FriendRequestItem({required this.id, required this.person});

  final int id;
  final FriendPerson person;
}

enum InviteStatus { pending, accepted, declined, cancelled, expired }

/// A friend's invite to a 1v1 battle of [exercise], open until [expiresAt]
/// (a minute).
class BattleInvite {
  const BattleInvite({
    required this.id,
    required this.from,
    required this.to,
    required this.exercise,
    required this.status,
    required this.expiresAt,
    this.character = '',
  });

  final int id;
  final FriendPerson from, to;
  final ExerciseType exercise;
  final InviteStatus status;
  final DateTime expiresAt;

  /// The inviter's character id as their app sent it (A11), for the
  /// friend's alert and waiting room; "" when an older app or server sent
  /// none. Draw it through `CharacterRig.selectableOrDefault`.
  final String character;

  /// How long an invite stays open: the server's INVITE_TTL.
  static const ttl = Duration(minutes: 1);

  /// The whole seconds left at [now] until [expiresAt], rounded up and cut
  /// to 0..60: the one count the alert, the friends page and the waiting
  /// room show (A11 spec 1). [expiresAt] is the server's; a device clock
  /// off from it moves the count, never past these bounds.
  int secondsLeftAt(DateTime now) {
    final left = expiresAt.difference(now).inMilliseconds;
    if (left <= 0) return 0;
    return ((left + 999) ~/ 1000).clamp(0, ttl.inSeconds);
  }

  BattleInvite withStatus(InviteStatus status) => BattleInvite(
    id: id,
    from: from,
    to: to,
    exercise: exercise,
    status: status,
    expiresAt: expiresAt,
    character: character,
  );
}

/// Everything the friends screen shows at once.
class FriendsOverview {
  const FriendsOverview({
    required this.code,
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.invites = const [],
  });

  /// My own friend code.
  final String code;
  final List<FriendPerson> friends;
  final List<FriendRequestItem> incoming, outgoing;

  /// Open battle invites to me, newest first.
  final List<BattleInvite> invites;
}

/// What sending a friend request did.
enum FriendAddOutcome {
  /// The request waits for them.
  requested,

  /// They had asked me already: we are friends now.
  accepted,
}

/// Friends and friend battle invites (P9). Every call throws an
/// [ApiException] when the server refuses it or cannot be reached; its
/// [ApiException.code] says why (e.g. `already_requested`, `invite_expired`).
abstract interface class FriendRepository {
  Future<FriendsOverview> fetchOverview();

  /// Asks the owner of [code] ("닉네임#0042") to be friends.
  Future<FriendAddOutcome> addFriend(String code);

  Future<void> acceptRequest(int requestId);
  Future<void> declineRequest(int requestId);

  /// Invites the friend with [friendId] to a battle of [exercise]. My
  /// earlier open invite, if any, is cancelled. [character], my character
  /// id, goes along when it has the battle server's avatar id shape
  /// ([isBattleAvatarId]); otherwise the invite goes without it, as an
  /// older app's does.
  Future<BattleInvite> invite(
    int friendId,
    ExerciseType exercise, {
    String? character,
  });

  /// The invite as it stands now, for the waiting rooms.
  Future<BattleInvite> fetchInvite(int inviteId);
  Future<BattleInvite> acceptInvite(int inviteId);
  Future<void> declineInvite(int inviteId);

  /// Takes back an open or accepted invite, by either player leaving the
  /// waiting room. With [ifPending], only an invite still open: an accepted
  /// one stays (and the call is refused with `invite_closed`).
  Future<void> cancelInvite(int inviteId, {bool ifPending = false});
}

/// [FriendRepository] over the GymRats API (`/friends`).
class ServerFriendRepository implements FriendRepository {
  ServerFriendRepository({required this._api});

  final ApiClient _api;

  @override
  Future<FriendsOverview> fetchOverview() async {
    final json = await _api.get('/friends');
    return _read(() {
      final body = json! as Map<String, Object?>;
      List<Map<String, Object?>> rows(String key) =>
          (body[key]! as List).cast<Map<String, Object?>>();
      return FriendsOverview(
        code: body['code']! as String,
        friends: rows('friends').map(_person).toList(),
        incoming: [
          for (final r in rows('incoming'))
            FriendRequestItem(
              id: r['request_id']! as int,
              person: _person(r['from']),
            ),
        ],
        outgoing: [
          for (final r in rows('outgoing'))
            FriendRequestItem(
              id: r['request_id']! as int,
              person: _person(r['to']),
            ),
        ],
        invites: rows('invites').map(_invite).toList(),
      );
    });
  }

  @override
  Future<FriendAddOutcome> addFriend(String code) async {
    final json = await _api.post('/friends/requests', {'code': code.trim()});
    return _read(
      () => switch ((json! as Map)['status']) {
        'accepted' => FriendAddOutcome.accepted,
        'requested' => FriendAddOutcome.requested,
        _ => throw const FormatException('status'),
      },
    );
  }

  @override
  Future<void> acceptRequest(int requestId) =>
      _api.post('/friends/requests/$requestId/accept', const {});

  @override
  Future<void> declineRequest(int requestId) =>
      _api.post('/friends/requests/$requestId/decline', const {});

  @override
  Future<BattleInvite> invite(
    int friendId,
    ExerciseType exercise, {
    String? character,
  }) async {
    final json = await _api.post('/friends/invites', {
      'friend_id': friendId,
      'exercise': _exerciseName(exercise),
      if (isBattleAvatarId(character)) 'character': character,
    });
    return _read(() => _invite(json));
  }

  @override
  Future<BattleInvite> fetchInvite(int inviteId) async {
    final json = await _api.get('/friends/invites/$inviteId');
    return _read(() => _invite(json));
  }

  @override
  Future<BattleInvite> acceptInvite(int inviteId) async {
    final json = await _api.post('/friends/invites/$inviteId/accept', const {});
    return _read(() => _invite(json));
  }

  @override
  Future<void> declineInvite(int inviteId) =>
      _api.post('/friends/invites/$inviteId/decline', const {});

  @override
  Future<void> cancelInvite(int inviteId, {bool ifPending = false}) =>
      _api.post('/friends/invites/$inviteId/cancel', {
        if (ifPending) 'if_pending': true,
      });

  static FriendPerson _person(Object? json) {
    final p = json! as Map<String, Object?>;
    return FriendPerson(
      id: p['id']! as int,
      nickname: p['nickname']! as String,
      code: p['code']! as String,
    );
  }

  static BattleInvite _invite(Object? json) {
    final i = json! as Map<String, Object?>;
    return BattleInvite(
      id: i['invite_id']! as int,
      from: _person(i['from']),
      to: _person(i['to']),
      exercise: switch (i['exercise']) {
        'push_up' => ExerciseType.pushUp,
        'squat' => ExerciseType.squat,
        _ => throw const FormatException('exercise'),
      },
      status: InviteStatus.values.byName(i['status']! as String),
      expiresAt: DateTime.parse(i['expires_at']! as String),
      // A server from before A11 sends no character: "" draws the default.
      character: switch (i['character']) {
        final String id => id,
        _ => '',
      },
    );
  }

  /// A reply the app cannot read is the server's fault.
  static T _read<T>(T Function() read) {
    try {
      return read();
    } on Object {
      throw const ApiException(ApiErrorKind.server);
    }
  }
}

String _exerciseName(ExerciseType exercise) =>
    exercise == ExerciseType.squat ? 'squat' : 'push_up';

/// [FriendRepository] kept in memory: the app's stand-in without a server
/// (tests, demos). [me] is the signed-in account; [people] are the other
/// accounts a code can find. It follows the server's rules.
class InMemoryFriendRepository implements FriendRepository {
  InMemoryFriendRepository({
    this.me = const FriendPerson(id: 1, nickname: '나', code: '나#0001'),
    List<FriendPerson> people = const [],
    DateTime Function()? now,
  }) : _people = [...people],
       _now = now ?? DateTime.now;

  final FriendPerson me;
  final List<FriendPerson> _people;
  final DateTime Function() _now;
  final friends = <FriendPerson>[];
  final incoming = <FriendRequestItem>[];
  final outgoing = <FriendRequestItem>[];

  /// Every invite, to me or from me.
  final invites = <BattleInvite>[];
  int _nextId = 1;

  static const ttl = Duration(minutes: 1);

  /// How long an accept holds both players: one friend battle at a time,
  /// as the server's ACCEPT_HOLD.
  static const acceptHold = Duration(minutes: 2);

  /// When I accepted each invite.
  final _acceptedAt = <int, DateTime>{};

  static Never _refuse(String code) =>
      throw ApiException(ApiErrorKind.rejected, statusCode: 400, code: code);

  BattleInvite _current(BattleInvite invite) =>
      invite.status == InviteStatus.pending &&
          !_now().isBefore(invite.expiresAt)
      ? invite.withStatus(InviteStatus.expired)
      : invite;

  /// [from] invites me to a battle of [exercise], as a friend's app would,
  /// with their [character] ("" as an older app's).
  BattleInvite receiveInvite(
    FriendPerson from,
    ExerciseType exercise, {
    String character = '',
  }) {
    final invite = BattleInvite(
      id: _nextId++,
      from: from,
      to: me,
      exercise: exercise,
      status: InviteStatus.pending,
      expiresAt: _now().add(ttl),
      character: character,
    );
    invites.add(invite);
    return invite;
  }

  /// Sets the invite with [inviteId] to [status], as the friend's answer.
  void answer(int inviteId, InviteStatus status) {
    final index = invites.indexWhere((i) => i.id == inviteId);
    invites[index] = invites[index].withStatus(status);
  }

  @override
  Future<FriendsOverview> fetchOverview() async => FriendsOverview(
    code: me.code,
    friends: [...friends]..sort((a, b) => a.nickname.compareTo(b.nickname)),
    incoming: [...incoming],
    outgoing: [...outgoing],
    invites: invites
        .map(_current)
        .where((i) => i.to == me && i.status == InviteStatus.pending)
        .toList()
        .reversed
        .toList(),
  );

  @override
  Future<FriendAddOutcome> addFriend(String code) async {
    final wanted = code.trim();
    if (!RegExp(r'^.{1,12}#[0-9]{4,10}$', dotAll: true).hasMatch(wanted)) {
      _refuse('invalid_code');
    }
    if (wanted == me.code) _refuse('cannot_add_self');
    final person = _people.where((p) => p.code == wanted).firstOrNull;
    if (person == null) _refuse('user_not_found');
    if (friends.contains(person)) _refuse('already_friends');
    if (outgoing.any((r) => r.person == person)) _refuse('already_requested');
    final asked = incoming.where((r) => r.person == person).firstOrNull;
    if (asked != null) {
      incoming.remove(asked);
      friends.add(person);
      return FriendAddOutcome.accepted;
    }
    outgoing.add(FriendRequestItem(id: _nextId++, person: person));
    return FriendAddOutcome.requested;
  }

  @override
  Future<void> acceptRequest(int requestId) async {
    final found = incoming.where((r) => r.id == requestId).firstOrNull;
    if (found == null) _refuse('request_not_found');
    incoming.remove(found);
    friends.add(found.person);
  }

  @override
  Future<void> declineRequest(int requestId) async {
    final before = incoming.length;
    incoming.removeWhere((r) => r.id == requestId);
    if (incoming.length == before) _refuse('request_not_found');
  }

  @override
  Future<BattleInvite> invite(
    int friendId,
    ExerciseType exercise, {
    String? character,
  }) async {
    final friend = friends.where((f) => f.id == friendId).firstOrNull;
    if (friend == null) _refuse('not_friends');
    for (var n = 0; n < invites.length; n++) {
      if (invites[n].from == me && invites[n].status == InviteStatus.pending) {
        invites[n] = invites[n].withStatus(InviteStatus.cancelled);
      }
    }
    final invite = BattleInvite(
      id: _nextId++,
      from: me,
      to: friend,
      exercise: exercise,
      status: InviteStatus.pending,
      expiresAt: _now().add(ttl),
      // As the server keeps it: "" when none or a malformed one was sent.
      character: isBattleAvatarId(character) ? character! : '',
    );
    invites.add(invite);
    return invite;
  }

  BattleInvite _find(int inviteId) => _current(
    invites.where((i) => i.id == inviteId).firstOrNull ??
        _refuse('invite_not_found'),
  );

  @override
  Future<BattleInvite> fetchInvite(int inviteId) async => _find(inviteId);

  Future<BattleInvite> _close(
    int inviteId,
    InviteStatus to, {
    bool ifPending = false,
  }) async {
    final invite = _find(inviteId);
    final open =
        invite.status == InviteStatus.pending ||
        (to == InviteStatus.cancelled &&
            !ifPending &&
            invite.status == InviteStatus.accepted);
    if (invite.status == InviteStatus.expired) _refuse('invite_expired');
    if (!open) _refuse('invite_closed');
    answer(inviteId, to);
    return invite.withStatus(to);
  }

  @override
  Future<BattleInvite> acceptInvite(int inviteId) async {
    // As the server: neither player may be in another friend battle. This
    // fake holds only invites involving me, so the inviter's own battles
    // with others cannot occur here; the server test covers them.
    final inviter = invites.where((i) => i.id == inviteId).firstOrNull?.from;
    bool involves(BattleInvite i, FriendPerson? p) =>
        p != null && (i.to == p || i.from == p);
    final held = invites.any(
      (i) =>
          i.id != inviteId &&
          (involves(i, me) || involves(i, inviter)) &&
          i.status == InviteStatus.accepted &&
          _now().difference(_acceptedAt[i.id] ?? DateTime(0)) < acceptHold,
    );
    if (held) {
      final invite = _find(inviteId);
      if (invite.status == InviteStatus.pending) {
        answer(inviteId, InviteStatus.cancelled);
      }
      _refuse('invite_busy');
    }
    final accepted = await _close(inviteId, InviteStatus.accepted);
    _acceptedAt[inviteId] = _now();
    // The others, to me or from me, cannot be paired now: take them back.
    for (final i in [...invites]) {
      if (i.id != inviteId &&
          (i.to == me || i.from == me) &&
          i.status == InviteStatus.pending) {
        answer(i.id, InviteStatus.cancelled);
      }
    }
    return accepted;
  }

  @override
  Future<void> declineInvite(int inviteId) =>
      _close(inviteId, InviteStatus.declined);

  @override
  Future<void> cancelInvite(int inviteId, {bool ifPending = false}) =>
      _close(inviteId, InviteStatus.cancelled, ifPending: ifPending);
}
