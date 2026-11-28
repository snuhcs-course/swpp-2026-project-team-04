import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/ranking_ladder.dart';
import 'package:gymrats_app/services/game/online_battle_result.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';

/// A session the server has finished by time with a win for the user;
/// [friendId] makes it a friend battle.
OnlineBattleSession _finished({String? friendId}) {
  final session = OnlineBattleSession(
    endpoint: Uri.parse('wss://example.com/ws/v1/battle'),
    accessToken: 'test-only',
    character: 'bear',
  );
  addTearDown(session.dispose);
  session
    ..friendId = friendId
    ..playerId = 'me'
    ..opponent = const OnlinePlayer('them', '진영', 'seal')
    ..rules = battleRules
    ..durationMs = 30000
    ..startAtMs = 1792400000000
    ..endAtMs = 1792400030000
    ..myScore = 120
    ..opponentScore = 20
    ..phase = OnlinePhase.finished
    ..result = {
      'reason': 'time_up',
      'ended_at_ms': 1792400030000,
      'players': [
        {'player_id': 'me', 'outcome': 'win'},
        {'player_id': 'them', 'outcome': 'loss'},
      ],
    };
  return session;
}

const _before = RankingSnapshot(
  entries: [
    (userId: 1, nickname: '펭귄짱', points: 31, rank: 1, battles: 4),
    (userId: 9, nickname: '쥐돌이', points: 19, rank: 2, battles: 3),
  ],
  me: (userId: 9, nickname: '쥐돌이', points: 19, rank: 2, battles: 3),
);

void main() {
  group('onlineBattleResult and the weekly ranking (A15)', () {
    test('a battle that is not a friend battle is ranked and carries the '
        'ranking read before it', () {
      final result = onlineBattleResult(
        _finished(),
        playerName: '우현',
        rankingBefore: _before,
      )!;
      expect(result.ranked, isTrue);
      expect(result.rankingBefore, same(_before));
    });

    test('a ranked battle without the ranking before carries none', () {
      final result = onlineBattleResult(_finished(), playerName: '우현')!;
      expect(result.ranked, isTrue);
      expect(result.rankingBefore, isNull);
    });

    test('a friend battle is not ranked', () {
      final result = onlineBattleResult(
        _finished(friendId: '7'),
        playerName: '우현',
        rankingBefore: _before,
      )!;
      expect(result.ranked, isFalse);
    });

    test('no result, no ranking: a battle that has not finished', () {
      final session = _finished()..phase = OnlinePhase.playing;
      expect(
        onlineBattleResult(session, playerName: '우현', rankingBefore: _before),
        isNull,
      );
    });
  });
}
