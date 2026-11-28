import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/exercise_type.dart';
import '../models/user_profile.dart';
import '../services/api/api_client.dart';
import '../services/friends/friend_repository.dart';
import '../services/user/user_repository.dart';

/// What the friends screen and the friend battle's waiting room say for a
/// refused friends call, by the server's code.
String friendErrorMessage(Object error) {
  if (error is! ApiException) return '요청을 처리하지 못했어요. 다시 시도해 주세요.';
  return switch (error.code) {
    'invalid_code' => '친구 코드는 닉네임#0000 모양이에요.',
    'user_not_found' => '그런 친구 코드가 없어요. 닉네임과 번호를 확인해 주세요.',
    'cannot_add_self' => '내 친구 코드예요. 친구의 코드를 넣어 주세요.',
    'already_friends' => '이미 친구예요.',
    'already_requested' => '이미 요청을 보냈어요. 친구가 수락하면 목록에 보여요.',
    'not_friends' => '친구에게만 대결을 신청할 수 있어요.',
    'invite_expired' => '대결 신청 시간이 지났어요.',
    'invite_closed' => '이미 끝난 대결 신청이에요.',
    // One friend battle at a time (another accept or invite is on).
    'invite_busy' => '이미 진행 중인 친구 대결이 있어요.',
    'request_not_found' || 'invite_not_found' => '이미 처리된 요청이에요.',
    _ => error.message,
  };
}

/// The friends screen (P9): my friend code, adding a friend by code, open
/// requests both ways, battle invites to me, and my friends.
///
/// While invites to me are listed, it ticks every [tickEvery] so their
/// time left ([secondsLeft], from the server's `expires_at`) counts down,
/// and an invite whose time runs out here leaves the list for good (A11
/// spec 4; one at 0 from the first sight stays: [_LocalExpiry]).
/// It also holds the profile the exercise sheet shows the bests from
/// ([useProfile], [refreshProfile]).
class FriendsViewModel extends ChangeNotifier {
  FriendsViewModel({
    required this._repository,
    DateTime Function()? now,
    this.tickEvery = const Duration(seconds: 1),
  }) : _now = now ?? DateTime.now;

  final FriendRepository _repository;
  final DateTime Function() _now;
  final Duration tickEvery;

  FriendsOverview? overview;
  bool loading = false;

  /// Invites whose time ran out here ([_LocalExpiry]): never listed again,
  /// even when a read still has them (the device clock may run ahead of
  /// the server's).
  final _expired = <int>{};
  final _expiry = _LocalExpiry();
  Timer? _tick;

  /// The profile for the exercise sheet's bests; null until one is given
  /// or read.
  UserProfile? profile;
  UserRepository? _users;
  Future<UserProfile?>? _readingProfile;

  /// Why the last profile read failed; null after one that worked.
  Object? _profileError;

  /// Why the last load failed; null after one that worked.
  String? loadError;

  /// The answer to the last friend request sent: [addError] when refused,
  /// [addNotice] when sent or accepted.
  String? addError, addNotice;
  bool adding = false;

  /// Why the last answer to a request or an invite failed.
  String? actionError;

  /// Requests and invites being answered, so their buttons wait.
  final busy = <int>{};
  bool _disposed = false;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    _notify();
    try {
      overview = _withoutExpired(await _repository.fetchOverview());
      loadError = null;
    } on Object catch (error) {
      loadError = friendErrorMessage(error);
    } finally {
      loading = false;
      _syncTick();
      _notify();
    }
  }

  /// The whole seconds [invite] has left, as the alert and the waiting room
  /// count them ([BattleInvite.secondsLeftAt]).
  int secondsLeft(BattleInvite invite) => invite.secondsLeftAt(_now());

  /// [read] without the invites whose time is up here ([_LocalExpiry]).
  FriendsOverview _withoutExpired(FriendsOverview read) {
    final now = _now();
    for (final invite in read.invites) {
      if (_expiry.isOver(invite, now)) _expired.add(invite.id);
    }
    if (!read.invites.any((i) => _expired.contains(i.id))) return read;
    return FriendsOverview(
      code: read.code,
      friends: read.friends,
      incoming: read.incoming,
      outgoing: read.outgoing,
      invites: [
        for (final invite in read.invites)
          if (!_expired.contains(invite.id)) invite,
      ],
    );
  }

  /// Ticks only while an invite to me is listed.
  void _syncTick() {
    final counting = !_disposed && (overview?.invites.isNotEmpty ?? false);
    if (!counting) {
      _tick?.cancel();
      _tick = null;
    } else {
      _tick ??= Timer.periodic(tickEvery, (_) => _onTick());
    }
  }

  void _onTick() {
    final shown = overview;
    if (shown == null) return;
    overview = _withoutExpired(shown);
    _syncTick();
    _notify();
  }

  /// Takes the profile 게임 시작 passed ([given]), and [users] to read it
  /// with: now when none was given, and on [refreshProfile].
  /// Nothing on the page shows the profile, so taking one tells no one.
  void useProfile(UserProfile? given, {UserRepository? users}) {
    _users = users;
    if (given != null) {
      profile = given;
    } else {
      unawaited(refreshProfile());
    }
  }

  /// Reads the profile again (after a battle opened from here, the bests
  /// may be new). A failed read keeps the one held. One read at a time.
  Future<UserProfile?> refreshProfile() {
    final users = _users;
    if (users == null) return Future.value(profile);
    return _readingProfile ??= () async {
      try {
        profile = await users.fetchProfile();
        _profileError = null;
        _notify();
      } on Object catch (error) {
        // Keep the profile held, if any.
        _profileError = error;
      } finally {
        _readingProfile = null;
      }
      return profile;
    }();
  }

  /// The profile for the exercise sheet: the one held, or a read when there
  /// is none yet. Null when none can be had; [actionError] then says why.
  Future<UserProfile?> profileForSheet() async {
    final found = profile ?? await refreshProfile();
    if (found == null) {
      actionError = friendErrorMessage(_profileError ?? StateError('profile'));
      _notify();
    }
    return found;
  }

  /// Sends a friend request to [code]; true when it went through.
  Future<bool> addFriend(String code) async {
    if (adding) return false;
    final wanted = code.trim();
    addNotice = null;
    if (wanted.isEmpty) {
      addError = '친구 코드를 넣어 주세요.';
      _notify();
      return false;
    }
    adding = true;
    addError = null;
    _notify();
    try {
      final outcome = await _repository.addFriend(wanted);
      addNotice = switch (outcome) {
        FriendAddOutcome.requested => '친구 요청을 보냈어요.',
        FriendAddOutcome.accepted => '이미 나에게 요청한 친구라 바로 친구가 됐어요.',
      };
      adding = false;
      await load();
      return true;
    } on Object catch (error) {
      addError = friendErrorMessage(error);
      adding = false;
      _notify();
      return false;
    }
  }

  Future<void> acceptRequest(int requestId) =>
      _answer(requestId, () => _repository.acceptRequest(requestId));

  Future<void> declineRequest(int requestId) =>
      _answer(requestId, () => _repository.declineRequest(requestId));

  Future<void> declineInvite(int inviteId) =>
      _answer(inviteId, () => _repository.declineInvite(inviteId));

  /// Accepts [invite]; the accepted invite to battle with, or null when it
  /// can no longer be accepted ([actionError] says why).
  Future<BattleInvite?> acceptInvite(BattleInvite invite) async {
    BattleInvite? accepted;
    await _answer(invite.id, () async {
      accepted = await _repository.acceptInvite(invite.id);
    });
    return accepted;
  }

  /// Takes back an invite I accepted but will not play (another battle
  /// opened meanwhile), so the friend's waiting room ends and both are free.
  /// Quiet: the friend's room ends on its own if this fails.
  Future<void> takeBack(BattleInvite accepted) async {
    try {
      await _repository.cancelInvite(accepted.id);
    } on Object {
      // Nothing to show: the page has moved on.
    }
  }

  /// Runs [call] for the request or invite [id], then reloads: a refused
  /// one may have expired or been answered elsewhere.
  Future<void> _answer(int id, Future<void> Function() call) async {
    if (!busy.add(id)) return;
    actionError = null;
    _notify();
    try {
      await call();
    } on Object catch (error) {
      actionError = friendErrorMessage(error);
    } finally {
      busy.remove(id);
    }
    await load();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
    super.dispose();
  }
}

/// Which invites are over on this phone by its own clock (A11; user,
/// 2026-11-27): one whose count reaches 0 after it was first seen here with
/// time left. One first seen at 0 (the device clock runs over a minute
/// ahead of the server's) is not over here: it shows 0:00 until the server
/// stops listing it, at the latest on the next read, and an accept is the
/// server's to judge.
class _LocalExpiry {
  final _seen = <int>{}, _live = <int>{};

  /// Notes [invite] as seen at [now]; whether its time ran out here.
  bool isOver(BattleInvite invite, DateTime now) {
    final left = invite.secondsLeftAt(now);
    if (_seen.add(invite.id) && left > 0) _live.add(invite.id);
    return left == 0 && _live.contains(invite.id);
  }

  /// Forget what was seen (another account).
  void clear() {
    _seen.clear();
    _live.clear();
  }
}

/// A friend battle to open the online lobby with: against [friend], of
/// [exercise]. [accepted] is the invite I accepted when I was invited; null
/// when I invite, and the lobby's [FriendInviteWaitViewModel] sends it.
class FriendBattle {
  const FriendBattle({
    required this.friend,
    required this.exercise,
    this.accepted,
  });

  final FriendPerson friend;
  final ExerciseType exercise;
  final BattleInvite? accepted;

  /// Whether I invite (and wait for the friend to accept).
  bool get inviting => accepted == null;
}

/// How a friend battle's wait ended before the friend came (A11): it picks
/// the waiting room's band, title and circle.
enum FriendWaitEnd {
  /// The friend declined my invite (DECLINED).
  declined,

  /// My invite's minute ran out: by the server's status, or by the device's
  /// clock when the server was not reached (TIME OUT).
  expired,

  /// Anything else: cancelled, not paired in time, or the invite could not
  /// be sent (CLOSED).
  other,
}

/// The friend battle's side of the waiting room, for both players.
/// Inviting, it sends the invite (with my [character]); invited, it holds
/// the one I accepted. Then it reads the invite every [pollEvery] until
/// [stop] (the battle server paired us): a declined, cancelled or expired
/// invite [ended] the wait, and so does an accepted one whose players are
/// not paired within [pairWithin] (the other phone went away without a
/// word). [leave] cancels the invite, so the other waiting room learns it.
class FriendInviteWaitViewModel extends ChangeNotifier {
  FriendInviteWaitViewModel({
    required this._repository,
    required this.battle,
    this.character,
    this.pollEvery = const Duration(seconds: 2),
    this.pairWithin = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final FriendRepository _repository;
  final FriendBattle battle;

  /// My character id, sent with my invite for the friend's screens (A11).
  final String? character;
  final Duration pollEvery, pairWithin;
  final DateTime Function() _now;

  /// The invite as last read; null before mine is made.
  BattleInvite? invite;

  /// Why the wait is over before the friend came; null while it goes on.
  String? ended;

  /// How it ended ([ended]'s kind); null while it goes on.
  FriendWaitEnd? endedBy;

  /// The whole seconds my invite has left, from the server's `expires_at`
  /// ([BattleInvite.secondsLeftAt]): the full minute before it is made.
  int get secondsLeft =>
      invite?.secondsLeftAt(_now()) ?? BattleInvite.ttl.inSeconds;
  Timer? _poll;
  DateTime? _acceptedAt;
  bool _stopped = false, _disposed = false, _checking = false, _paired = false;
  bool _finished = false;

  String get _friend => battle.friend.nickname;

  /// Sends the invite when inviting, then starts reading it.
  Future<void> start() async {
    if (_stopped || _poll != null) return;
    final accepted = battle.accepted;
    if (accepted != null) {
      invite = accepted;
      _acceptedAt = _now();
    } else {
      try {
        final sent = await _repository.invite(
          battle.friend.id,
          battle.exercise,
          character: character,
        );
        if (_stopped) {
          // Paired before this answer came: the friend may have accepted
          // the invite already, so take it back only if still open. Left
          // instead: take it back in any case.
          // Once the battle is over too, take it back in any case, so the
          // hold ends now.
          unawaited(_cancelQuietly(sent.id, ifPending: _paired && !_finished));
          return;
        }
        invite = sent;
      } on Object catch (error) {
        _end(friendErrorMessage(error), FriendWaitEnd.other);
        return;
      }
    }
    _poll = Timer.periodic(pollEvery, (_) => unawaited(check()));
  }

  /// Reads the invite once and ends the wait when the friend can no longer
  /// come. Past the invite's expiry, or [pairWithin] after it was accepted,
  /// the wait ends even when the server is not reached.
  Future<void> check() async {
    final last = invite;
    if (last == null || _stopped || _checking) return;
    _checking = true;
    try {
      final read = await _repository.fetchInvite(last.id);
      if (_stopped) return;
      invite = read;
      switch (read.status) {
        case InviteStatus.declined:
          _end('$_friend님이 대결 신청을 거절했어요.', FriendWaitEnd.declined);
        case InviteStatus.cancelled:
          _end('$_friend님이 대결을 취소했어요.', FriendWaitEnd.other);
        case InviteStatus.expired:
          _end('$_friend님이 1분 안에 수락하지 않았어요.', FriendWaitEnd.expired);
        case InviteStatus.accepted:
          _acceptedAt ??= _now();
        case InviteStatus.pending:
          break;
      }
    } on Object {
      // Not reached this time: the clocks below still end the wait.
      if (!_stopped &&
          last.status == InviteStatus.pending &&
          !_now().isBefore(last.expiresAt)) {
        _end('$_friend님이 1분 안에 수락하지 않았어요.', FriendWaitEnd.expired);
      }
    } finally {
      _checking = false;
    }
    final acceptedAt = _acceptedAt;
    if (!_stopped &&
        acceptedAt != null &&
        _now().difference(acceptedAt) >= pairWithin) {
      unawaited(_cancelQuietly(last.id));
      _end('$_friend님과 연결하지 못했어요. 다시 신청해 주세요.', FriendWaitEnd.other);
    }
  }

  /// The battle server paired us with the friend: stop reading, and take
  /// back my invite if it is still open. That happens when both invited
  /// each other at once and met in the queue with neither invite accepted;
  /// left open, it would come back as an alert after the battle. The server
  /// decides "still open" (my last read may not have seen the friend's
  /// accept yet), so an accepted invite stays and the friend's waiting room
  /// is not told that I cancelled.
  Future<void> paired() async {
    if (_paired) return;
    _paired = true;
    final mine = battle.inviting ? invite : null;
    stop();
    if (mine != null && mine.status != InviteStatus.accepted) {
      try {
        await _repository.cancelInvite(mine.id, ifPending: true);
      } on Object {
        // Accepted meanwhile (or closed): nothing to take back.
      }
    }
  }

  /// The friend battle is over (the waiting room closed after the pairing):
  /// take the accepted invite back, so the server lets both players into
  /// another friend battle at once rather than after its hold. Once.
  Future<void> finished() async {
    if (_finished) return;
    _finished = true;
    final played = invite;
    stop();
    if (played != null) await _cancelQuietly(played.id);
  }

  /// Stop reading.
  void stop() {
    _stopped = true;
    _poll?.cancel();
  }

  /// I left the waiting room: stop, and take back an invite still open or
  /// accepted.
  Future<void> leave() async {
    final open = !_stopped ? invite : null;
    stop();
    if (open != null &&
        (open.status == InviteStatus.pending ||
            open.status == InviteStatus.accepted)) {
      await _cancelQuietly(open.id);
    }
  }

  Future<void> _cancelQuietly(int inviteId, {bool ifPending = false}) async {
    try {
      await _repository.cancelInvite(inviteId, ifPending: ifPending);
    } on Object {
      // An open invite expires on its own within the minute.
    }
  }

  void _end(String why, FriendWaitEnd kind) {
    stop();
    ended = why;
    endedBy = kind;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}

/// The app-wide alert for a friend's battle invite (P9): while signed in and
/// in front, it reads the invites to me every [pollEvery] and offers the
/// newest one not yet answered here. [hidden] (a battle, its setup or the
/// friends page is open) stops the reading and the alert. While it offers
/// one, it ticks every [tickEvery] so the time left ([secondsLeft], from the
/// server's `expires_at`) counts down; at 0 the invite is over here and the
/// alert goes (A11 spec 6), unless it was at 0 from the first sight
/// ([_LocalExpiry]): then it shows 0:00 until the server stops listing it.
class FriendInviteAlertViewModel extends ChangeNotifier {
  FriendInviteAlertViewModel({
    required this._repository,
    this.pollEvery = const Duration(seconds: 5),
    this.tickEvery = const Duration(seconds: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final FriendRepository _repository;
  final Duration pollEvery, tickEvery;
  final DateTime Function() _now;
  Timer? _tick;

  /// The invite to show; null when there is none.
  BattleInvite? current;

  /// The whole seconds [current] has left ([BattleInvite.secondsLeftAt]);
  /// 0 without one.
  int get secondsLeft => current?.secondsLeftAt(_now()) ?? 0;

  /// Why the last answer failed, e.g. the invite ran out; cleared by the
  /// next invite or [clearError].
  String? error;

  /// An answer is on its way.
  bool answering = false;

  /// Invites answered or found closed here, never offered again.
  final _done = <int>{};
  final _expiry = _LocalExpiry();

  /// Counts sign-ins and sign-outs, so an answer that comes back after one
  /// is dropped: it belongs to the account that sent it.
  int _account = 0;
  Timer? _poll;
  bool _running = false, _hidden = false, _foreground = true;
  bool _reading = false, _disposed = false;

  bool get _active => _running && !_hidden && _foreground;

  /// Signed in: start reading. Signed out: stop and forget.
  void setSignedIn(bool signedIn) {
    if (signedIn == _running) return;
    _running = signedIn;
    _account++;
    if (!signedIn) {
      _done.clear();
      _expiry.clear();
      current = null;
      error = null;
    }
    _sync();
  }

  /// A battle or the friends page is open (or no longer).
  void setHidden(bool hidden) {
    if (hidden == _hidden) return;
    _hidden = hidden;
    if (hidden) _hiddenTimes++;
    _sync();
  }

  /// Counts the times the alert was hidden, so a 수락 that comes back after
  /// a battle (or the friends page) was opened meanwhile opens nothing.
  int _hiddenTimes = 0;

  /// The app went to the background (or came back).
  void setForeground(bool foreground) {
    if (foreground == _foreground) return;
    _foreground = foreground;
    // Going to the background hides the alert too: a 수락 on its way then
    // opens nothing (accept()).
    if (!foreground) _hiddenTimes++;
    _sync();
    _notify();
  }

  /// Whether the alert shows now.
  bool get visible => _active && (current != null || error != null);

  void _sync() {
    _poll?.cancel();
    _poll = null;
    if (_active) {
      _poll = Timer.periodic(pollEvery, (_) => unawaited(check()));
      unawaited(check());
    }
    _notify();
  }

  /// Ticks only while an invite shows.
  void _syncTick() {
    if (_disposed || !visible || current == null) {
      _tick?.cancel();
      _tick = null;
    } else {
      _tick ??= Timer.periodic(tickEvery, (_) => _onTick());
    }
  }

  void _onTick() {
    final invite = current;
    // An answer on its way decides it; the server says whether it was late.
    if (invite == null || answering) return;
    if (_expiry.isOver(invite, _now())) {
      _done.add(invite.id);
      current = null;
    }
    _notify();
  }

  /// Reads the invites once. A read that comes back after a sign-in change
  /// belongs to the account that sent it and is dropped.
  Future<void> check() async {
    if (!_active || _reading || answering) return;
    final account = _account;
    var dropped = false;
    _reading = true;
    try {
      final overview = await _repository.fetchOverview();
      if (account != _account) {
        dropped = true;
        return;
      }
      if (!_active || answering) return;
      // One whose time ran out here is over here, whatever the read says
      // (not one at 0 from the first sight: [_LocalExpiry]).
      final now = _now();
      for (final i in overview.invites) {
        if (_expiry.isOver(i, now)) _done.add(i.id);
      }
      final next = overview.invites
          .where((i) => !_done.contains(i.id))
          .firstOrNull;
      if (next?.id != current?.id) {
        current = next;
        if (next != null) error = null;
        _notify();
      }
    } on Object {
      // Not reached this time; the next read tries again.
    } finally {
      _reading = false;
      // The new account's first read was skipped while this one ran: read
      // for it now rather than at the next tick.
      if (dropped) unawaited(check());
    }
  }

  /// Accepts [current]; the accepted invite to open the waiting room with,
  /// or null when it can no longer be accepted ([error] says why), or when
  /// the account signed out meanwhile: then nobody will come for the friend,
  /// so it tries to take the accepted invite back (after a sign-out the
  /// request may lack a login and fail; the friend's waiting room then ends
  /// on its own within 30 s). The same when the alert was hidden meanwhile
  /// (another battle or the friends page opened): the friend battle must
  /// not open over it.
  Future<BattleInvite?> accept() async {
    final invite = current;
    if (invite == null || answering) return null;
    final account = _account, hiddenTimes = _hiddenTimes;
    var settled = true;
    answering = true;
    _notify();
    try {
      final accepted = await _repository.acceptInvite(invite.id);
      if (account != _account ||
          hiddenTimes != _hiddenTimes ||
          _hidden ||
          !_foreground) {
        unawaited(_cancelQuietly(invite.id));
        if (account == _account) current = null;
        return null;
      }
      current = null;
      return accepted;
    } on Object catch (e) {
      // An answer for an account that signed out meanwhile says nothing.
      if (account != _account) return null;
      current = null;
      error = friendErrorMessage(e);
      // Refused by the server (closed, expired, busy): final. No answer
      // (network, timeout, a server failure): offer it again on the next
      // read, while it is still open.
      settled = e is ApiException && e.kind == ApiErrorKind.rejected;
      return null;
    } finally {
      if (settled) _done.add(invite.id);
      answering = false;
      _notify();
    }
  }

  Future<void> _cancelQuietly(int inviteId) async {
    try {
      await _repository.cancelInvite(inviteId);
    } on Object {
      // The friend's waiting room ends on its own within 30 s.
    }
  }

  /// Declines [current]; the alert goes at once, whatever the server says.
  Future<void> decline() async {
    final invite = current;
    if (invite == null || answering) return;
    _done.add(invite.id);
    current = null;
    _notify();
    try {
      await _repository.declineInvite(invite.id);
    } on Object {
      // It runs out within the minute anyway.
    }
  }

  void clearError() {
    if (error == null) return;
    error = null;
    _notify();
  }

  void _notify() {
    _syncTick();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }
}
