import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../../../server/lib/battle_server.dart';
// ignore: avoid_relative_lib_imports
import '../../../../server/lib/result_store.dart';
// ignore: avoid_relative_lib_imports
import '../../../../server/lib/skill_matchmaker.dart';

/// P10 on the battle server: real players are paired at once; a player who
/// accepts it gets a simulated opponent after the wait, copying the account
/// whose estimate is closest to theirs.

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

  bool has(String type) => events.any((e) => e['type'] == type);
  int count(String type) => events.where((e) => e['type'] == type).length;
  Map<String, dynamic> last(String type) =>
      events.lastWhere((e) => e['type'] == type);

  void send(String type, Map<String, dynamic> payload) => socket.add(
    jsonEncode({
      'v': 1,
      'type': type,
      'request_id': '$hashCode-${++_sequence}',
      'payload': payload,
    }),
  );

  void join({
    String exercise = 'push_up',
    bool? virtual = true,
    String? friend,
  }) => send('queue.join', {
    'exercise': exercise,
    'avatar_id': 'mouse',
    'friend_id': ?friend,
    'accept_virtual': ?virtual,
  });
}

/// Recent battles the server reads; [records] may change between reads.
class _Skills implements SkillSource {
  _Skills(this.records);
  List<SkillRecord> records;
  int reads = 0;
  bool fail = false;

  @override
  Future<List<SkillRecord>> loadSkills() async {
    reads++;
    if (fail) throw const SocketException('down');
    return records;
  }
}

/// A source whose first read answers only when [answer] does.
class _Slow implements SkillSource {
  _Slow(this.answer);
  final Future<List<SkillRecord>> answer;

  @override
  Future<List<SkillRecord>> loadSkills() => answer;
}

SkillRecord _record(String id, String name, List<int> pushUps) =>
    SkillRecord(id, name, {'push_up': pushUps});

void main() {
  const wait = 300;

  Future<BattleServer> server(
    _Skills skills, {
    SkillSource? source,
    int virtualAfterMs = wait,
    int skillRefreshMs = 300000,
  }) async {
    final s = BattleServer(
      authenticate: (token) => switch (token) {
        'a' => const BattleIdentity('1', '쥐돌이'),
        'b' => const BattleIdentity('2', '헬창'),
        'c' => const BattleIdentity('3', '근육'),
        _ => null,
      },
      tickMs: 20,
      readyTimeoutMs: 5000,
      skills: source ?? skills,
      virtualAfterMs: virtualAfterMs,
      skillRefreshMs: skillRefreshMs,
    );
    await s.start();
    addTearDown(s.close);
    return s;
  }

  Future<_Wire> open(BattleServer s, String token) async {
    final wire = _Wire(
      await WebSocket.connect(
        'ws://127.0.0.1:${s.port}/ws/v1/battle',
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    addTearDown(wire.socket.close);
    await _until(() => wire.has('session.welcome'));
    return wire;
  }

  final skills = [
    _record('1', '쥐돌이', [5, 5, 6]),
    _record('2', '헬창', [20, 21, 22]),
    _record('7', '근손실', [6, 7, 7]),
    _record('8', '고수', [14, 15, 15]),
  ];

  test('two real players are paired at once, whatever their skill', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a'), b = await open(s, 'b');
    a.join();
    b.join();
    await _until(() => a.has('match.found') && b.has('match.found'));
    await Future<void>.delayed(const Duration(milliseconds: wait + 100));
    expect(a.has('match.virtual'), isFalse);
    expect(b.has('match.virtual'), isFalse);
  });

  test('a real player joining within the wait is taken first', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    a.join();
    await _until(() => a.has('queue.joined'));
    await Future<void>.delayed(const Duration(milliseconds: wait ~/ 2));
    final b = await open(s, 'b');
    b.join();
    await _until(() => a.has('match.found'));
    expect(a.has('match.virtual'), isFalse);
  });

  test('after the wait the player gets the closest account by name', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    final joined = Stopwatch()..start();
    a.join();
    await _until(() => a.has('match.virtual'));
    expect(joined.elapsedMilliseconds, greaterThanOrEqualTo(wait - 20));
    // 쥐돌이's estimate is 5: 근손실 (7) is closest, not 쥐돌이 themself.
    expect(a.last('match.virtual')['payload'], {
      'exercise': 'push_up',
      'opponent': {'display_name': '근손실', 'expected_reps': 7},
    });
    expect(a.last('match.virtual').containsKey('match_id'), isFalse);
    expect(a.has('match.found'), isFalse);
  });

  test('a simulated opponent is assigned once, then never paired', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    a.join();
    await _until(() => a.has('match.virtual'));
    final b = await open(s, 'b');
    b.join();
    await Future<void>.delayed(const Duration(milliseconds: wait ~/ 2));
    expect(a.has('match.found'), isFalse);
    expect(b.has('match.found'), isFalse);
    await _until(() => b.has('match.virtual'));
    await Future<void>.delayed(const Duration(milliseconds: wait));
    expect(a.count('match.virtual'), 1);
    expect(b.count('match.virtual'), 1);
    // 헬창 (21) is closest to 고수 (15).
    expect(
      b.last('match.virtual')['payload']['opponent']['display_name'],
      '고수',
    );
  });

  test('a player may join again after a simulated opponent', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    a.join();
    await _until(() => a.has('match.virtual'));
    a.join();
    await _until(() => a.count('queue.joined') == 2);
    await _until(() => a.count('match.virtual') == 2);
    expect(a.has('error'), isFalse);
  });

  test('a cancelled search gets no simulated opponent', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    a.join();
    await _until(() => a.has('queue.joined'));
    a.send('queue.cancel', {'queue_id': '1'});
    await _until(() => a.has('queue.cancelled'));
    await Future<void>.delayed(const Duration(milliseconds: wait + 150));
    expect(a.has('match.virtual'), isFalse);
  });

  test('a player who disconnects while waiting gets none', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    a.join();
    await _until(() => a.has('queue.joined'));
    await a.socket.close();
    await Future<void>.delayed(const Duration(milliseconds: wait + 150));
    expect(a.has('match.virtual'), isFalse);
  });

  test('an app that does not accept one keeps waiting (older app)', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    a.join(virtual: null);
    await _until(() => a.has('queue.joined'));
    await Future<void>.delayed(const Duration(milliseconds: wait + 150));
    expect(a.has('match.virtual'), isFalse);
    final b = await open(s, 'b');
    b.join(virtual: false);
    await _until(() => a.has('match.found') && b.has('match.found'));
  });

  test('a friend battle is never given a simulated opponent', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    a.join(virtual: false, friend: '2');
    await _until(() => a.has('queue.joined'));
    await Future<void>.delayed(const Duration(milliseconds: wait + 150));
    expect(a.has('match.virtual'), isFalse);
  });

  test('accepting one in a friend battle is refused', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    a.join(friend: '2');
    await _until(() => a.has('error'));
    expect(a.last('error')['payload']['code'], 'INVALID_PAYLOAD');
    expect(a.has('queue.joined'), isFalse);
  });

  test('accept_virtual must be true or false', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    a.send('queue.join', {'exercise': 'push_up', 'accept_virtual': 'yes'});
    await _until(() => a.has('error'));
    expect(a.has('queue.joined'), isFalse);
  });

  test('the estimates are read at start and again after a while', () async {
    final source = _Skills([
      _record('2', '헬창', [10]),
    ]);
    final s = await server(source, skillRefreshMs: 200);
    await _until(() => s.skills.estimateOf('2', 'push_up') == 10);
    expect(source.reads, 1);
    source.records = [
      _record('2', '헬창', [30, 30, 30]),
    ];
    await _until(() => s.skills.estimateOf('2', 'push_up') == 30);
    expect(source.reads, greaterThanOrEqualTo(2));
  });

  test('a failed read keeps the estimates there were', () async {
    final source = _Skills([
      _record('2', '헬창', [10]),
    ]);
    final s = await server(source, skillRefreshMs: 100);
    await _until(() => s.skills.estimateOf('2', 'push_up') == 10);
    source.fail = true;
    final reads = source.reads;
    await _until(() => source.reads > reads);
    expect(s.skills.estimateOf('2', 'push_up'), 10);
  });

  test('a slow read does not hold up the start', () async {
    final slow = Completer<List<SkillRecord>>();
    final source = _Slow(slow.future);
    final clock = Stopwatch()..start();
    final s = await server(_Skills([]), source: source);
    expect(clock.elapsedMilliseconds, lessThan(1000));
    expect(s.skills.count('push_up'), 0);
    slow.complete([
      _record('2', '헬창', [10]),
    ]);
    await _until(() => s.skills.count('push_up') == 1);
  });

  test('without any estimate it is RepBot at the default skill', () async {
    final source = _Skills([])..fail = true;
    final s = await server(source);
    final a = await open(s, 'a');
    a.join(exercise: 'squat');
    await _until(() => a.has('match.virtual'));
    expect(a.last('match.virtual')['payload'], {
      'exercise': 'squat',
      'opponent': {'display_name': 'RepBot', 'expected_reps': 9},
    });
  });

  group('HttpResultStore.loadSkills', () {
    const secret = 'test-results-secret-not-used-anywhere-else';
    late HttpServer api;
    late Object? reply;
    final calls = <(String, String?, Object?)>[];

    setUp(() async {
      calls.clear();
      reply = {'players': []};
      api = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      api.listen((request) async {
        final body = jsonDecode(await utf8.decodeStream(request));
        calls.add((
          request.uri.path,
          request.headers.value('X-Results-Secret'),
          body,
        ));
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(reply));
        await request.response.close();
      });
    });
    tearDown(() => api.close(force: true));

    HttpResultStore store() => HttpResultStore(
      Uri.parse('http://127.0.0.1:${api.port}/internal'),
      secret,
      retryDelays: const [],
      log: (_) {},
    );

    test('asks for the latest five battles with the secret', () async {
      reply = {
        'players': [
          {
            'player_id': '1',
            'display_name': '쥐돌이',
            'recent': {
              'push_up': [9, 8],
            },
          },
        ],
      };
      final records = await store().loadSkills();
      expect(calls.single.$1, '/internal/skills');
      expect(calls.single.$2, secret);
      expect(calls.single.$3, {'limit': 5});
      expect(records.single.name, '쥐돌이');
      expect(records.single.recent['push_up'], [9, 8]);
    });

    test('leaves out malformed records', () async {
      reply = {
        'players': [
          {'player_id': '1'},
          {
            'player_id': '2',
            'display_name': '헬창',
            'recent': {
              'squat': [3],
            },
          },
        ],
      };
      final records = await store().loadSkills();
      expect(records.map((r) => r.id), ['2']);
    });

    test('an answer without players is an error', () async {
      reply = {'detail': 'forbidden'};
      await expectLater(store().loadSkills(), throwsStateError);
    });
  });
}
