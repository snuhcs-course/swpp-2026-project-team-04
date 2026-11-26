import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';

// ignore: avoid_relative_lib_imports
import '../../../../server/lib/battle_server.dart';
// ignore: avoid_relative_lib_imports
import '../../../../server/lib/result_store.dart';
// ignore: avoid_relative_lib_imports
import '../../../../server/lib/simulated_player.dart';
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

  /// The match the next messages are about, once found.
  String? match;

  /// The players of the latest match found.
  List<Map<String, dynamic>> get roster => [
    for (final p in last('match.found')['payload']['players'] as List)
      Map<String, dynamic>.from(p as Map),
  ];

  bool has(String type) => events.any((e) => e['type'] == type);
  int count(String type) => events.where((e) => e['type'] == type).length;
  Map<String, dynamic> last(String type) =>
      events.lastWhere((e) => e['type'] == type);

  void send(String type, Map<String, dynamic> payload) => socket.add(
    jsonEncode({
      'v': 1,
      'type': type,
      'request_id': '$hashCode-${++_sequence}',
      'match_id': ?match,
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

/// What the battle server stores, kept in memory.
class _Store implements BattleResultStore {
  @override
  Future<void> started(String matchId, int startAtMs, List<String> ids) async =>
      startedIds.add(ids);
  final startedIds = <List<String>>[];

  @override
  Future<void> finished(Map<String, dynamic> result) async =>
      finishedResults.add(result);
  final finishedResults = <Map<String, dynamic>>[];

  @override
  Future<void> voided(String matchId, String reason) async {}

  @override
  Future<Map<String, Set<String>>> recover(int bootedAtMs) async => {};
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
    BattleResultStore? store,
    int durationMs = 3000,
    int setupTimeoutMs = 3000,
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
      countdownMs: 50,
      durationMs: durationMs,
      setupTimeoutMs: setupTimeoutMs,
      results: store,
      skills: source ?? skills,
      virtualAfterMs: virtualAfterMs,
      skillRefreshMs: skillRefreshMs,
      simulationRandom: Random(4),
      simulatedSetupMs: (0, 0),
      simulatedReadyMs: (100, 100),
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

  bool simulated(Map<String, dynamic> player) =>
      SimulatedPlayer.isSimulatedId(player['player_id'] as String);

  test('two real players are paired at once, whatever their skill', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a'), b = await open(s, 'b');
    a.join();
    b.join();
    await _until(() => a.has('match.found') && b.has('match.found'));
    expect(a.roster.map((p) => p['player_id']).toSet(), {'1', '2'});
    await Future<void>.delayed(const Duration(milliseconds: wait + 100));
    expect(a.count('match.found'), 1);
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
    expect(a.roster.any(simulated), isFalse);
  });

  test('after the wait the match is found with the closest account, as a '
      'real one', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    final joined = Stopwatch()..start();
    a.join();
    await _until(() => a.has('match.found'));
    expect(joined.elapsedMilliseconds, greaterThanOrEqualTo(wait - 20));
    // 쥐돌이's estimate is 5: 근손실 (7) is closest, not 쥐돌이 themself.
    final opponent = a.roster.singleWhere(simulated);
    expect(opponent['display_name'], '근손실');
    // The copied account's id never reaches the phone.
    expect(a.events.toString(), isNot(contains("'7'")));
    expect(a.last('match.found')['payload']['duration_ms'], 3000);
  });

  test(
    'the simulated player opens its setup and gets ready by itself',
    () async {
      final s = await server(_Skills(skills));
      final a = await open(s, 'a');
      a.join();
      await _until(() => a.has('match.found'));
      final id = a.roster.singleWhere(simulated)['player_id'];
      await _until(
        () => a.events.any(
          (e) =>
              e['type'] == 'match.ready_state' &&
              (e['payload']['ready_player_ids'] as List).contains(id),
        ),
      );
      expect(
        a.events.any(
          (e) =>
              e['type'] == 'match.setup_state' &&
              (e['payload']['setup_player_ids'] as List).contains(id),
        ),
        isTrue,
      );
      expect(a.has('match.start'), isFalse);
    },
  );

  test('a simulated battle plays and ends as a real one; only the player '
      'keeps it', () async {
    final store = _Store();
    final s = await server(_Skills(skills), store: store);
    final a = await open(s, 'a');
    a.join();
    await _until(() => a.has('match.found'));
    a.match = a.last('match.found')['match_id'] as String;
    a.send('match.setup', {});
    a.send('match.ready', {'ready': true});
    await _until(() => a.has('match.start'));
    a.send('rep.submit', {
      'rep_seq': 1,
      'elapsed_ms': 0,
      'valid': true,
      'reason': null,
      'grade': 'good',
    });
    await _until(() => a.has('match.finished'));
    final id = a.roster.singleWhere(simulated)['player_id'];
    final reps = a.events.where((e) => e['type'] == 'rep.updated').toList();
    expect(reps, isNotEmpty);
    expect(reps.every((e) => e['payload']['player_id'] == id), isTrue);
    expect(
      [for (final e in reps) e['payload']['rep_seq']],
      [for (var i = 1; i <= reps.length; i++) i],
    );
    final result = a.last('match.finished')['payload'];
    expect(result['reason'], anyOf('time_up', 'ko'));
    expect(
      (result['players'] as List).map((p) => p['player_id']),
      contains(id),
    );
    await _until(() => store.finishedResults.isNotEmpty);
    final players = store.finishedResults.single['players'] as List;
    expect([
      for (final p in players) (p['player_id'], p['simulated'] ?? false),
    ], unorderedEquals([('1', false), (id, true)]));
    expect(
      players.singleWhere((p) => p['simulated'] == true)['display_name'],
      '근손실',
    );
    expect(store.startedIds.single, containsAll(['1', id]));
  });

  /// [a] in its simulated match's round: set up, ready, started.
  Future<void> startRound(_Wire a) async {
    a.join();
    await _until(() => a.has('match.found'));
    a.match = a.last('match.found')['match_id'] as String;
    a.send('match.setup', {});
    a.send('match.ready', {'ready': true});
    await _until(() => a.has('match.start'));
  }

  test(
    'a strong simulated player can KO, and no rep counts after it',
    () async {
      final s = await server(
        _Skills([
          _record('1', '쥐돌이', [60, 60, 60]),
          _record('9', '괴물', [60, 60, 60]),
        ]),
      );
      final a = await open(s, 'a');
      await startRound(a);
      await _until(() => a.has('match.finished'));
      final result = a.last('match.finished')['payload'];
      expect(result['reason'], 'ko');
      final id = a.roster.singleWhere(simulated)['player_id'];
      expect(result['winner_id'], id);
      final finishedAt = a.events.indexOf(a.last('match.finished'));
      final reps = [
        for (final e in a.events)
          if (e['type'] == 'rep.updated') e,
      ];
      // Every rep it made came before the end, and the result counts them all.
      expect(reps.every((e) => a.events.indexOf(e) < finishedAt), isTrue);
      final sim = (result['players'] as List).singleWhere(
        (p) => p['player_id'] == id,
      );
      expect(sim['valid_reps'] + sim['invalid_reps'], reps.length);
      // It stopped short of its whole plan of about 60.
      expect(reps.length, lessThan(55));
      // The rep that made the KO lead was its last: none came after it.
      final scores = [for (final e in reps) e['payload']['game_score'] as int];
      expect(scores.last, greaterThanOrEqualTo(100));
      expect(scores[scores.length - 2], lessThan(100));
    },
  );

  test('the player can KO the simulated player', () async {
    final s = await server(
      _Skills([
        _record('1', '쥐돌이', [5]),
        _record('9', '약골', [1]),
      ]),
      durationMs: 20000,
    );
    final a = await open(s, 'a');
    await startRound(a);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    for (var seq = 1; !a.has('match.finished') && seq <= 12; seq++) {
      a.send('rep.submit', {
        'rep_seq': seq,
        'elapsed_ms': seq * 2,
        'valid': true,
        'reason': null,
        'grade': 'excellent',
      });
      await _until(() => a.count('rep.accepted') == seq);
    }
    await _until(() => a.has('match.finished'));
    final result = a.last('match.finished')['payload'];
    expect(result['reason'], 'ko');
    expect(result['winner_id'], '1');
  });

  test('a player who reconnects mid-round resumes against the simulated '
      'player', () async {
    // A weak copy, so no KO ends the round before the reconnect.
    final s = await server(
      _Skills([
        _record('1', '쥐돌이', [2]),
        _record('9', '약골', [2]),
      ]),
      durationMs: 4000,
    );
    final a = await open(s, 'a');
    await startRound(a);
    final id = a.roster.singleWhere(simulated)['player_id'];
    final match = a.match;
    // Past the countdown: leaving before it would cancel the match.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await a.socket.close();
    final back = await open(s, 'a');
    expect(back.last('session.welcome')['payload']['active_match_id'], match);
    back.match = match;
    back.send('match.resume', {});
    await _until(() => back.has('match.snapshot'));
    final snapshot = back.last('match.snapshot')['payload'];
    expect(
      (snapshot['players'] as List).map((p) => p['player_id']),
      contains(id),
    );
    expect((snapshot['scores'] as Map).keys, containsAll(['1', id]));
    expect(snapshot['disconnected_player_ids'], isEmpty);
    // The round goes on to its end, as against a person.
    await _until(() => back.has('match.finished'));
    expect(back.last('match.finished')['payload']['reason'], 'time_up');
  });

  test('a setup past the setup time is cancelled as a real one', () async {
    final s = await server(_Skills(skills), setupTimeoutMs: 400);
    final a = await open(s, 'a');
    a.join();
    await _until(() => a.has('match.found'));
    a.match = a.last('match.found')['match_id'] as String;
    a.send('match.setup', {});
    await _until(() => a.has('match.cancelled'));
    expect(a.last('match.cancelled')['payload']['reason'], 'setup_timeout');
    expect(a.has('match.start'), isFalse);
  });

  test(
    'leaving after the start is a forfeit the simulated player wins',
    () async {
      final s = await server(_Skills(skills), durationMs: 20000);
      final a = await open(s, 'a');
      a.join();
      await _until(() => a.has('match.found'));
      a.match = a.last('match.found')['match_id'] as String;
      a.send('match.setup', {});
      a.send('match.ready', {'ready': true});
      await _until(() => a.has('match.start'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      a.send('match.leave', {'reason': 'user_exit'});
      await _until(() => a.has('match.finished'));
      final result = a.last('match.finished')['payload'];
      expect(result['reason'], 'forfeit');
      expect(result['winner_id'], a.roster.singleWhere(simulated)['player_id']);
    },
  );

  test('each waiting player gets their own simulated match, once', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    a.join();
    await _until(() => a.has('match.found'));
    final b = await open(s, 'b');
    b.join();
    await _until(() => b.has('match.found'));
    expect(b.roster.any((p) => p['player_id'] == '1'), isFalse);
    // 헬창 (21) is closest to 고수 (15).
    expect(b.roster.singleWhere(simulated)['display_name'], '고수');
    expect(
      a.last('match.found')['match_id'],
      isNot(b.last('match.found')['match_id']),
    );
    await Future<void>.delayed(const Duration(milliseconds: wait));
    expect(a.count('match.found'), 1);
    expect(b.count('match.found'), 1);
  });

  test('the app plays a simulated opponent as any online opponent', () async {
    final s = await server(_Skills(skills));
    final session = OnlineBattleSession(
      endpoint: Uri.parse('ws://127.0.0.1:${s.port}/ws/v1/battle'),
      accessToken: 'a',
      allowInsecureLoopback: true,
    );
    addTearDown(session.dispose);
    await session.connect();
    await _until(() => session.phase == OnlinePhase.preparing);
    expect(session.opponent!.name, '근손실');
    session.setupOpened();
    session.ready(true);
    await _until(() => session.opponentReps > 0);
    await _until(() => session.phase == OnlinePhase.finished);
    expect(session.opponentScore, greaterThan(0));
    expect(session.outcome, 'loss');
  });

  test('a cancelled search gets no simulated opponent', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    a.join();
    await _until(() => a.has('queue.joined'));
    a.send('queue.cancel', {'queue_id': '1'});
    await _until(() => a.has('queue.cancelled'));
    await Future<void>.delayed(const Duration(milliseconds: wait + 150));
    expect(a.has('match.found'), isFalse);
  });

  test('a player who disconnects while waiting gets none', () async {
    final store = _Store();
    final s = await server(_Skills(skills), store: store);
    final a = await open(s, 'a');
    a.join();
    await _until(() => a.has('queue.joined'));
    await a.socket.close();
    await Future<void>.delayed(const Duration(milliseconds: wait + 150));
    expect(a.has('match.found'), isFalse);
    expect(store.startedIds, isEmpty);
  });

  test('an app that does not accept one keeps waiting (older app)', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    a.join(virtual: null);
    await _until(() => a.has('queue.joined'));
    await Future<void>.delayed(const Duration(milliseconds: wait + 150));
    expect(a.has('match.found'), isFalse);
    final b = await open(s, 'b');
    b.join(virtual: false);
    await _until(() => a.has('match.found') && b.has('match.found'));
    expect(a.roster.any(simulated), isFalse);
  });

  test('a friend battle is never given a simulated opponent', () async {
    final s = await server(_Skills(skills));
    final a = await open(s, 'a');
    a.join(virtual: false, friend: '2');
    await _until(() => a.has('queue.joined'));
    await Future<void>.delayed(const Duration(milliseconds: wait + 150));
    expect(a.has('match.found'), isFalse);
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

  test('without any estimate it is RepBot', () async {
    final source = _Skills([])..fail = true;
    final s = await server(source);
    final a = await open(s, 'a');
    a.join(exercise: 'squat');
    await _until(() => a.has('match.found'));
    expect(a.roster.singleWhere(simulated)['display_name'], 'RepBot');
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
