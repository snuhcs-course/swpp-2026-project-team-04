import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_result.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/services/game/online_battle_result.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';

/// A session the server has finished with [reason], [outcome] for the user,
/// 23.4 s into a 30 s round, on the game's rules unless [rules] is null.
OnlineBattleSession _finished(
  String reason, {
  String outcome = 'win',
  BattleRules? rules = battleRules,
  ExerciseType exercise = ExerciseType.pushUp,
  OnlinePhase phase = OnlinePhase.finished,
}) {
  final session = OnlineBattleSession(
    endpoint: Uri.parse('wss://example.com/ws/v1/battle'),
    accessToken: 'test-only',
    character: 'bear',
    exercise: exercise,
  );
  addTearDown(session.dispose);
  session
    ..playerId = 'me'
    ..opponent = const OnlinePlayer('them', '진영', 'seal')
    ..rules = rules
    ..durationMs = 30000
    ..startAtMs = 1792400000000
    ..endAtMs = 1792400030000
    ..myReps = 6
    ..myInvalidReps = 2
    ..opponentReps = 4
    ..myScore = 120
    ..opponentScore = 20
    ..phase = phase
    ..result = {
      'reason': reason,
      'ended_at_ms': 1792400023400,
      'players': [
        {'player_id': 'me', 'outcome': outcome},
        {'player_id': 'them', 'outcome': 'other'},
      ],
    };
  return session;
}

void main() {
  group('onlineBattleResult', () {
    test('takes the server\'s numbers, outcome and end time, with the '
        'user\'s name and report', () {
      final report = FormReport(
        endedAt: DateTime(2026, 11, 12),
        opponentName: '진영',
        roundLength: const Duration(seconds: 30),
        reps: const [],
        samples: const [],
      );
      final result = onlineBattleResult(
        _finished('time_up'),
        playerName: '우현',
        report: report,
      )!;
      expect(result.matchup.exercise, ExerciseType.pushUp);
      expect(result.matchup.playerName, '우현');
      expect(result.matchup.opponent.name, '진영');
      expect(result.matchup.opponent.isBot, isFalse);
      expect(
        (result.myReps, result.myInvalidReps, result.opponentReps),
        (6, 2, 4),
      );
      expect((result.myScore, result.opponentScore), (120, 20));
      expect(result.end, GameEnd.timeUp);
      expect(result.decidedOutcome, MatchOutcome.win);
      expect(result.outcome, MatchOutcome.win);
      expect(
        result.endedAt,
        DateTime.fromMillisecondsSinceEpoch(1792400023400),
      );
      expect(result.roundLength, const Duration(seconds: 30));
      expect(result.form, same(report));
      expect(result.departure, BattleDeparture.none);
    });

    test('a KO keeps the time played, rounded up to the second', () {
      final result = onlineBattleResult(_finished('ko'), playerName: '우현')!;
      expect(result.end, GameEnd.ko);
      expect(result.roundLength, const Duration(seconds: 24));
    });

    test('the server\'s outcome decides, whatever the scores say', () {
      for (final (outcome, want) in [
        ('win', MatchOutcome.win),
        ('loss', MatchOutcome.lose),
        ('draw', MatchOutcome.draw),
      ]) {
        final result = onlineBattleResult(
          _finished('time_up', outcome: outcome),
          playerName: '우현',
        )!;
        expect(result.outcome, want, reason: outcome);
      }
    });

    test('the opponent leaving is a win by their leaving; my connection '
        'lost too long is a loss by it', () {
      for (final reason in ['forfeit', 'disconnect_timeout']) {
        final won = onlineBattleResult(_finished(reason), playerName: '우현')!;
        expect(won.departure, BattleDeparture.opponentLeft, reason: reason);
        expect(won.end, GameEnd.timeUp);
      }
      final lost = onlineBattleResult(
        _finished('disconnect_timeout', outcome: 'loss'),
        playerName: '우현',
      )!;
      expect(lost.departure, BattleDeparture.myConnectionLost);
      expect(lost.outcome, MatchOutcome.lose);
    });

    test(
      'an older server has no game: the reps decide, as the record does',
      () {
        final result = onlineBattleResult(
          _finished('time_up', rules: null),
          playerName: '우현',
        )!;
        expect(result.hasGame, isFalse);
        expect(result.decidedOutcome, isNull);
        expect(result.outcome, MatchOutcome.win);
        // The valid reps are the score, as on the stage.
        expect((result.myScore, result.opponentScore), (6, 4));
      },
    );

    test('an older server: a player leaving decides the outcome, whatever '
        'the reps', () {
      // 6 : 4 valid reps, yet the user lost by a lost connection.
      final lost = onlineBattleResult(
        _finished('disconnect_timeout', outcome: 'loss', rules: null),
        playerName: '우현',
      )!;
      expect(lost.outcome, MatchOutcome.lose);
      expect(lost.departure, BattleDeparture.myConnectionLost);
      expect((lost.myScore, lost.opponentScore), (6, 4));
      final won = onlineBattleResult(
        _finished('forfeit', rules: null),
        playerName: '우현',
      )!;
      expect(won.outcome, MatchOutcome.win);
      expect(won.departure, BattleDeparture.opponentLeft);
    });

    test('none before the end, for an end without a result, or without an '
        'outcome for the user', () {
      expect(
        onlineBattleResult(
          _finished('time_up', phase: OnlinePhase.playing),
          playerName: '우현',
        ),
        isNull,
      );
      for (final phase in [
        OnlinePhase.cancelled,
        OnlinePhase.voided,
        OnlinePhase.failed,
      ]) {
        expect(
          onlineBattleResult(
            _finished('time_up', phase: phase),
            playerName: '우현',
          ),
          isNull,
          reason: '$phase',
        );
      }
      final unknown = _finished('time_up', outcome: 'other');
      expect(onlineBattleResult(unknown, playerName: '우현'), isNull);
      unknown.result = {'reason': 'time_up'};
      expect(onlineBattleResult(unknown, playerName: '우현'), isNull);
    });

    test('a squat battle stays a squat battle', () {
      final result = onlineBattleResult(
        _finished('time_up', exercise: ExerciseType.squat),
        playerName: '우현',
      )!;
      expect(result.matchup.exercise, ExerciseType.squat);
      expect(result.record.exercise, ExerciseType.squat);
    });
  });
}
