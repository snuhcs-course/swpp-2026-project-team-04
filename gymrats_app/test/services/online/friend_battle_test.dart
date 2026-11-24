import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/shared/battle_protocol.dart';

// ignore: avoid_relative_lib_imports
import '../../../../server/lib/battle_server.dart';

/// Friend battles on the battle server (P9): a `queue.join` with
/// `friend_id` is paired only with that friend, and only when they named
/// this player back; the main queue never takes them.

Future<void> _until(bool Function() condition) async {
  final clock = Stopwatch()..start();
  while (!condition()) {
    if (clock.elapsedMilliseconds > 5000) {
      throw TimeoutException('state not reached');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _Wire {
  _Wire(this.socket) {
    socket.listen(
      (raw) => events.add(
        Map<String, dynamic>.from(jsonDecode(raw as String) as Map),
      ),
    );
  }

  final WebSocket socket;
  final events = <Map<String, dynamic>>[];
  int _sequence = 0;
  String? match;

  static Future<_Wire> open(BattleServer server, String token) async {
    final wire = _Wire(
      await WebSocket.connect(
        'ws://127.0.0.1:${server.port}/ws/v1/battle',
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    await _until(() => wire.has('session.welcome'));
    return wire;
  }

  void send(String type, Map<String, dynamic> payload) => socket.add(
    jsonEncode({
      'v': 1,
      'type': type,
      'request_id': '$token-${++_sequence}',
      'match_id': ?match,
      'payload': payload,
    }),
  );

  String get token => hashCode.toString();

  bool has(String type) => events.any((e) => e['type'] == type);

  Map<String, dynamic> last(String type) =>
      events.lastWhere((e) => e['type'] == type);

  void join({String exercise = 'push_up', String? friend}) => send(
    'queue.join',
    {'exercise': exercise, 'avatar_id': 'mouse', 'friend_id': ?friend},
  );

  List<String> get opponents => [
    for (final found in events.where((e) => e['type'] == 'match.found'))
      for (final p in (found['payload']['players'] as List))
        p['player_id'] as String,
  ];
}

void main() {
  Future<BattleServer> server() async {
    final s = BattleServer(
      authenticate: (token) => switch (token) {
        'a' => const BattleIdentity('1', '쥐돌이'),
        'b' => const BattleIdentity('2', '헬창'),
        'c' => const BattleIdentity('3', '근육'),
        'd' => const BattleIdentity('4', '근손실'),
        _ => null,
      },
      countdownMs: 80,
      readyTimeoutMs: 1000,
      reconnectMs: 300,
    );
    await s.start();
    addTearDown(s.close);
    return s;
  }

  Future<_Wire> open(BattleServer s, String token) async {
    final wire = await _Wire.open(s, token);
    addTearDown(wire.socket.close);
    return wire;
  }

  /// Lets the server pair whoever it would.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  test('two friends who name each other share one room', () async {
    final s = await server();
    final a = await open(s, 'a'), b = await open(s, 'b');
    a.join(friend: '2');
    b.join(friend: '1');
    await _until(() => a.has('match.found') && b.has('match.found'));
    expect(
      a.last('match.found')['match_id'],
      b.last('match.found')['match_id'],
    );
    expect(a.opponents.toSet(), {'1', '2'});
  });

  test('the friend joining later still finds the one waiting', () async {
    final s = await server();
    final a = await open(s, 'a');
    a.join(friend: '2');
    await _until(() => a.has('queue.joined'));
    await settle();
    expect(a.has('match.found'), isFalse);
    final b = await open(s, 'b');
    b.join(friend: '1');
    await _until(() => a.has('match.found') && b.has('match.found'));
  });

  test('a friend waiting is never paired with the main queue', () async {
    final s = await server();
    final a = await open(s, 'a'), c = await open(s, 'c');
    a.join(friend: '2');
    c.join();
    await settle();
    expect(a.has('match.found'), isFalse);
    expect(c.has('match.found'), isFalse);
    // The main queue still pairs the next one in it.
    final d = await open(s, 'd');
    d.join();
    await _until(() => c.has('match.found') && d.has('match.found'));
    expect(c.opponents.toSet(), {'3', '4'});
    expect(a.has('match.found'), isFalse);
  });

  test('only the named friend: someone naming me while I name another '
      'waits', () async {
    final s = await server();
    final a = await open(s, 'a'), c = await open(s, 'c');
    a.join(friend: '2'); // a waits for b
    c.join(friend: '1'); // c wants a
    await settle();
    expect(a.has('match.found') || c.has('match.found'), isFalse);
    final b = await open(s, 'b');
    b.join(friend: '1');
    await _until(() => a.has('match.found') && b.has('match.found'));
    expect(a.opponents.toSet(), {'1', '2'});
    expect(c.has('match.found'), isFalse);
  });

  test('friends who pick different exercises are not paired', () async {
    final s = await server();
    final a = await open(s, 'a'), b = await open(s, 'b');
    a.join(friend: '2');
    b.join(friend: '1', exercise: 'squat');
    await settle();
    expect(a.has('match.found') || b.has('match.found'), isFalse);
  });

  test('the friend leaving the queue leaves the other waiting, with no '
      'match', () async {
    final s = await server();
    final a = await open(s, 'a'), b = await open(s, 'b');
    a.join(friend: '2');
    await _until(() => a.has('queue.joined'));
    await b.socket.close();
    await settle();
    expect(a.has('match.found'), isFalse);
    // And a cancelled wait no longer pairs with the friend's later join.
    a.send('queue.cancel', {'queue_id': '1'});
    await _until(() => a.has('queue.cancelled'));
    final b2 = await open(s, 'b');
    b2.join(friend: '1');
    await settle();
    expect(b2.has('match.found'), isFalse);
  });

  test('a friend leaving the room before the start cancels it for both, '
      'as in the main match', () async {
    final s = await server();
    final a = await open(s, 'a'), b = await open(s, 'b');
    a.join(friend: '2');
    b.join(friend: '1');
    await _until(() => a.has('match.found') && b.has('match.found'));
    a.match = b.match = a.last('match.found')['match_id'] as String;
    b.send('match.leave', {'reason': 'user_exit'});
    await _until(() => a.has('match.cancelled'));
    expect(a.last('match.cancelled')['payload']['reason'], 'user_exit');
  });

  for (final (label, friend) in [
    ('myself', '1'),
    ('an empty id', ''),
    ('a number', 2),
    ('spaces', '2 3'),
    ('a too long id', 'x' * 65),
  ]) {
    test('friend_id naming $label is refused', () async {
      final s = await server();
      final a = await open(s, 'a');
      a.send('queue.join', {'exercise': 'push_up', 'friend_id': friend});
      await _until(() => a.has('error'));
      expect(a.last('error')['payload']['code'], 'INVALID_FRIEND');
      expect(a.has('queue.joined'), isFalse);
    });
  }

  test('the friend joining twice still makes one room', () async {
    final s = await server();
    final a = await open(s, 'a'), b = await open(s, 'b');
    a.join(friend: '2');
    b.join(friend: '1');
    await _until(() => a.has('match.found') && b.has('match.found'));
    // A second join (a double tap on 수락) is refused: one match per player.
    b.join(friend: '1');
    await _until(() => b.has('error'));
    expect(b.last('error')['payload']['code'], 'ALREADY_IN_MATCH');
    await settle();
    expect(a.events.where((e) => e['type'] == 'match.found'), hasLength(1));
    expect(b.events.where((e) => e['type'] == 'match.found'), hasLength(1));
  });

  test('the friend accepting on a second phone makes one room', () async {
    final s = await server();
    final a = await open(s, 'a');
    a.join(friend: '2');
    await _until(() => a.has('queue.joined'));
    final first = await open(s, 'b');
    first.join(friend: '1');
    await _until(() => a.has('match.found'));
    // The same account again: it takes over the session, no second room.
    final second = await open(s, 'b');
    second.join(friend: '1');
    await _until(() => second.has('error'));
    expect(second.last('error')['payload']['code'], 'ALREADY_IN_MATCH');
    expect(
      second.events.first['payload']['active_match_id'],
      a.last('match.found')['match_id'],
    );
    await settle();
    expect(a.events.where((e) => e['type'] == 'match.found'), hasLength(1));
  });

  test('isBattleFriendId takes server player ids only', () {
    expect(isBattleFriendId('42'), isTrue);
    expect(isBattleFriendId('a_b-C9'), isTrue);
    expect(isBattleFriendId('x' * 64), isTrue);
    for (final bad in [null, 42, '', 'x' * 65, '4 2', '쥐돌이', '1#2']) {
      expect(isBattleFriendId(bad), isFalse, reason: '$bad');
    }
  });

  test('two app sessions with friendId meet on the real server', () async {
    final s = await server();
    OnlineBattleSession session(String token, String friend) =>
        OnlineBattleSession(
          endpoint: Uri.parse('ws://127.0.0.1:${s.port}/ws/v1/battle'),
          accessToken: token,
          allowInsecureLoopback: true,
        )..friendId = friend;
    final a = session('a', '2'), b = session('b', '1');
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await a.connect();
    await b.connect();
    await _until(() => a.opponent != null && b.opponent != null);
    expect(a.opponent!.id, '2');
    expect(a.opponent!.name, '헬창');
    expect(b.opponent!.id, '1');
    expect(a.matchId, b.matchId);
  });
}
