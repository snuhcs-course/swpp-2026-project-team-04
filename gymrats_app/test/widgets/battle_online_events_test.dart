import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/widgets/battle_online_events.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';

OnlineBattleSession _session({BattleRules? rules = battleRules}) {
  final session = OnlineBattleSession(
    endpoint: Uri.parse('wss://example.com/ws/v1/battle'),
    accessToken: 'test-only',
    character: 'bear',
  );
  addTearDown(session.dispose);
  return session
    ..playerId = 'me'
    ..opponent = const OnlinePlayer('them', '진영', 'seal')
    ..connected = true
    ..rules = rules
    ..phase = OnlinePhase.preparing;
}

/// [session]'s round, running for [elapsedMs] with [leftMs] left.
void _play(
  OnlineBattleSession session, {
  int elapsedMs = 1000,
  int leftMs = 20000,
}) {
  session
    ..startAtMs = session.serverNow - elapsedMs
    ..endAtMs = session.serverNow + leftMs
    ..phase = OnlinePhase.playing;
}

RepEvent _rep({double? depth, RejectReason? reason, double? elbow}) => RepEvent(
  index: 1,
  valid: reason == null,
  reason: reason,
  maxDepth: depth ?? 1.4,
  minElbowAngle: elbow ?? 70,
  at: Duration.zero,
);

const _good = GameRepScore(
  grade: GameGrade.good,
  combo: 2,
  fever: true,
  points: 30,
);

void main() {
  group('myRep', () {
    test('a rep that earns: its grade, with the preview\'s points, combo and '
        'fever; never the knockout', () {
      final session = _session();
      _play(session);
      session.myScore = 200;
      session.submitRep(_rep(depth: 1.9), passDepth: 1);
      final event = OnlineStageEvents.myRep(
        session,
        _rep(depth: 1.9),
        passDepth: 1,
      );
      expect(event.side, BattleSide.me);
      expect(event.grade, GameGrade.excellent);
      expect(event.points, session.myLastScore!.points);
      expect(event.combo, session.myLastScore!.combo);
      expect(event.fever, session.myLastScore!.fever);
      expect(event.reason, isNull);
      expect(event.knockout, isFalse);
    });

    test('a rejected rep misses, with its reason', () {
      final session = _session();
      _play(session);
      final rep = _rep(reason: RejectReason.kneesDown, elbow: 90);
      session.submitRep(rep, passDepth: 1);
      final event = OnlineStageEvents.myRep(session, rep, passDepth: 1);
      expect((event.grade, event.points, event.combo), (null, 0, 0));
      expect(event.reason, RejectReason.kneesDown);
    });

    test('an average rep lands weakly with its points and keeps its reason; '
        'it breaks the combo', () {
      final session = _session();
      _play(session);
      final rep = _rep(reason: RejectReason.insufficientDepth, elbow: 120);
      session.submitRep(rep, passDepth: 1);
      final event = OnlineStageEvents.myRep(session, rep, passDepth: 1);
      expect(event.grade, GameGrade.average);
      expect(event.points, battleRules.averagePoints);
      expect(event.combo, 0);
      expect(event.reason, RejectReason.insufficientDepth);
    });

    test('the grade goes by the judge\'s pass depth', () {
      final session = _session();
      _play(session);
      final rep = _rep(depth: 1.2);
      session.submitRep(rep, passDepth: .75);
      expect(
        OnlineStageEvents.myRep(session, rep, passDepth: .75).grade,
        GameGrade.excellent,
      );
      expect(
        OnlineStageEvents.myRep(session, rep, passDepth: 1).grade,
        GameGrade.good,
      );
    });

    test(
      'an older server: a counted rep lands for one point, the rest miss',
      () {
        final session = _session(rules: null);
        final counted = OnlineStageEvents.myRep(session, _rep(), passDepth: 1);
        expect(
          (counted.grade, counted.points, counted.combo),
          (GameGrade.good, 1, 1),
        );
        final missed = OnlineStageEvents.myRep(
          session,
          _rep(reason: RejectReason.tooFast),
          passDepth: 1,
        );
        expect((missed.grade, missed.points), (null, 0));
        expect(missed.reason, RejectReason.tooFast);
      },
    );
  });

  group('opponentRep', () {
    test('a new latest score is a blow of its grade, once', () {
      final session = _session();
      final before = OnlineStageEvents.opponentSeen(session);
      expect(OnlineStageEvents.opponentRep(before, session), isNull);
      session
        ..opponentLastScore = _good
        ..opponentScore = 30
        ..opponentReps = 2;
      final event = OnlineStageEvents.opponentRep(before, session)!;
      expect(event.side, BattleSide.opponent);
      expect(
        (event.grade, event.points, event.combo, event.fever),
        (GameGrade.good, 30, 2, true),
      );
      expect(event.reason, isNull);
      expect(event.knockout, isFalse);
      expect(
        OnlineStageEvents.opponentRep(
          OnlineStageEvents.opponentSeen(session),
          session,
        ),
        isNull,
      );
    });

    test('the same numbers in a new score object are a new rep; the same '
        'object is not', () {
      final session = _session()..opponentLastScore = _good;
      final seen = OnlineStageEvents.opponentSeen(session);
      session.opponentScore = 60;
      expect(OnlineStageEvents.opponentRep(seen, session), isNull);
      // A new rep with the same numbers: the session makes a new object.
      session.opponentLastScore = GameRepScore(
        grade: _good.grade,
        combo: _good.combo,
        fever: _good.fever,
        points: _good.points,
      );
      expect(OnlineStageEvents.opponentRep(seen, session), isNotNull);
    });

    test('the blow that brings a KO lead is the knockout blow', () {
      final session = _session();
      final before = OnlineStageEvents.opponentSeen(session);
      session
        ..opponentLastScore = _good
        ..myScore = 10
        ..opponentScore = 10 + battleRules.koLead - 1;
      expect(OnlineStageEvents.opponentRep(before, session)!.knockout, isFalse);
      session.opponentScore = 10 + battleRules.koLead;
      expect(OnlineStageEvents.opponentRep(before, session)!.knockout, isTrue);
    });

    test('an older server: one more valid rep is a one-point blow', () {
      final session = _session(rules: null);
      final before = OnlineStageEvents.opponentSeen(session);
      expect(OnlineStageEvents.opponentRep(before, session), isNull);
      session.opponentReps = 1;
      final event = OnlineStageEvents.opponentRep(before, session)!;
      expect((event.grade, event.points), (GameGrade.good, 1));
      expect(event.knockout, isFalse);
    });

    test('a rep that earned nothing is a miss, once, in fever as the round '
        'is', () {
      final session = _session();
      _play(session, elapsedMs: 21000, leftMs: 8000);
      final before = OnlineStageEvents.opponentSeen(session);
      expect(before.misses, 0);
      session.opponentMisses = 1;
      final event = OnlineStageEvents.opponentRep(before, session)!;
      expect(event.side, BattleSide.opponent);
      expect((event.grade, event.points, event.combo), (null, 0, 0));
      expect(event.counted, isFalse);
      expect(event.knockout, isFalse);
      expect(event.reason, isNull);
      expect(event.fever, session.fever);
      expect(event.fever, isTrue);
      expect(
        OnlineStageEvents.opponentRep(
          OnlineStageEvents.opponentSeen(session),
          session,
        ),
        isNull,
      );
    });

    test('a blow wins over a miss count left as it was', () {
      final session = _session()..opponentMisses = 2;
      final before = OnlineStageEvents.opponentSeen(session);
      session.opponentLastScore = const GameRepScore(
        grade: GameGrade.average,
        combo: 0,
        fever: false,
        points: 5,
      );
      final event = OnlineStageEvents.opponentRep(before, session)!;
      expect(event.grade, GameGrade.average);
      expect(event.points, 5);
    });

    test('an older server: a rejected rep is a miss', () {
      final session = _session(rules: null);
      final before = OnlineStageEvents.opponentSeen(session);
      session.opponentMisses = 1;
      final event = OnlineStageEvents.opponentRep(before, session)!;
      expect(event.grade, isNull);
      expect(event.points, 0);
    });
  });

  group('endOf', () {
    OnlineBattleSession finished(String reason, String outcome) => _session()
      ..phase = OnlinePhase.finished
      ..result = {
        'reason': reason,
        'players': [
          {'player_id': 'me', 'outcome': outcome},
        ],
      };

    test('none while it runs', () {
      final session = _session();
      expect(OnlineStageEvents.endOf(session), isNull);
      _play(session);
      expect(OnlineStageEvents.endOf(session), isNull);
    });

    test('the clock run out before the server\'s result: an undecided '
        'time-up', () {
      final session = _session();
      _play(session, elapsedMs: 30000, leftMs: 0);
      session.phase = OnlinePhase.awaitingResult;
      final end = OnlineStageEvents.endOf(session)!;
      expect(
        (end.kind, end.winner, end.decided),
        (BattleEndKind.timeUp, null, false),
      );
    });

    test('the server\'s result: a time-up, a KO or a player leaving, won, '
        'lost or drawn', () {
      for (final (reason, outcome, kind, winner) in [
        ('time_up', 'win', BattleEndKind.timeUp, BattleSide.me),
        ('time_up', 'loss', BattleEndKind.timeUp, BattleSide.opponent),
        ('time_up', 'draw', BattleEndKind.timeUp, null),
        ('ko', 'win', BattleEndKind.knockout, BattleSide.me),
        ('ko', 'loss', BattleEndKind.knockout, BattleSide.opponent),
        ('forfeit', 'win', BattleEndKind.playerLeft, BattleSide.me),
        (
          'disconnect_timeout',
          'loss',
          BattleEndKind.playerLeft,
          BattleSide.opponent,
        ),
      ]) {
        final end = OnlineStageEvents.endOf(finished(reason, outcome))!;
        expect(
          (end.kind, end.winner, end.decided),
          (kind, winner, true),
          reason: '$reason $outcome',
        );
      }
    });

    test('a result without an outcome for the user stays undecided', () {
      final end = OnlineStageEvents.endOf(finished('time_up', 'unknown'))!;
      expect((end.kind, end.decided), (BattleEndKind.timeUp, false));
    });

    test('no stage ending without a result: cancelled, void, error, or a '
        'battle the server lost', () {
      for (final phase in [
        OnlinePhase.cancelled,
        OnlinePhase.voided,
        OnlinePhase.failed,
      ]) {
        final session = _session()..phase = phase;
        expect(OnlineStageEvents.endOf(session), isNull, reason: '$phase');
      }
      final restarted = _session()
        ..phase = OnlinePhase.voided
        ..result = {'reason': 'server_restarted'};
      expect(OnlineStageEvents.endOf(restarted), isNull);
    });
  });

  group('stateOf', () {
    test('setting up: who is ready, the names, no countdown', () {
      final session = _session()..readyPlayers = {'them'};
      final state = OnlineStageEvents.stateOf(session, myName: '우현');
      expect(state.phase, BattleStagePhase.setup);
      expect((state.myName, state.opponentName), ('우현', '진영'));
      expect((state.meReady, state.opponentReady), (false, true));
      expect(state.countdown, isNull);
      expect(state.end, isNull);
    });

    test('scheduled: the countdown to the server\'s start, to the '
        'millisecond', () {
      final session = _session()
        ..phase = OnlinePhase.scheduled
        ..readyPlayers = {'me', 'them'};
      session.startAtMs = session.serverNow + 2500;
      final state = OnlineStageEvents.stateOf(session, myName: '우현');
      expect(state.phase, BattleStagePhase.countdown);
      expect(state.countdown!.inMilliseconds, inInclusiveRange(2400, 2500));
      session.startAtMs = session.serverNow - 10;
      expect(
        OnlineStageEvents.stateOf(session, myName: '우현').countdown,
        Duration.zero,
      );
    });

    test('playing: the server\'s scores, reps, bar, fever, danger and the '
        'connections', () {
      final session = _session();
      _play(session, elapsedMs: 21000, leftMs: 9000);
      session
        ..myScore = 20
        ..opponentScore = 90
        ..myReps = 2
        ..opponentReps = 7
        ..connected = false
        ..opponentConnected = false;
      final state = OnlineStageEvents.stateOf(session, myName: '우현');
      expect(state.phase, BattleStagePhase.playing);
      expect((state.myScore, state.opponentScore), (20, 90));
      expect((state.myReps, state.opponentReps), (2, 7));
      expect(state.barShare, session.myBarShare);
      expect(state.fever, isTrue);
      expect(state.feverMultiplier, battleRules.feverMultiplier);
      expect(state.danger, isTrue);
      expect(state.reconnecting, isTrue);
      expect(state.opponentDisconnected, isTrue);
      expect(state.remaining.inMilliseconds, inInclusiveRange(8900, 9000));
      expect(state.roundLength, Duration(milliseconds: session.durationMs));
    });

    test('no danger while the camera has failed', () {
      final session = _session();
      _play(session);
      session.opponentScore = 90;
      expect(OnlineStageEvents.stateOf(session, myName: '우현').danger, isTrue);
      expect(
        OnlineStageEvents.stateOf(
          session,
          myName: '우현',
          cameraFailed: true,
        ).danger,
        isFalse,
      );
    });

    test('an older server: the valid reps are the score', () {
      final session = _session(rules: null);
      _play(session);
      session
        ..myReps = 4
        ..opponentReps = 3;
      final state = OnlineStageEvents.stateOf(session, myName: '우현');
      expect((state.myScore, state.opponentScore), (4, 3));
      expect(state.feverMultiplier, 2);
    });

    test('ended once the end is known, before the server\'s result too', () {
      final session = _session();
      _play(session, elapsedMs: 30000, leftMs: 0);
      expect(
        OnlineStageEvents.stateOf(session, myName: '우현').phase,
        BattleStagePhase.ended,
      );
    });
  });
}
