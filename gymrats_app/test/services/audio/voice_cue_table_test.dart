import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/models/voice_cue.dart';
import 'package:gymrats_app/services/audio/voice_cue_table.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';

SetupStatus _status(SetupReason reason, {bool isReady = false}) =>
    SetupStatus(reason: reason, isReady: isReady, readyProgress: 0);

void main() {
  group('forSetup', () {
    test('every setup reason has a "what to fix" line', () {
      const expected = {
        SetupReason.noPerson: VoiceCue.noPerson,
        SetupReason.tooClose: VoiceCue.tooClose,
        SetupReason.tooFar: VoiceCue.tooFar,
        SetupReason.notFacingForward: VoiceCue.notFacingForward,
        SetupReason.missingParts: VoiceCue.missingParts,
        SetupReason.notInPushUp: VoiceCue.notInPushUp,
        SetupReason.notStanding: VoiceCue.notStanding,
        SetupReason.phoneTooFlat: VoiceCue.phoneTooFlat,
        SetupReason.phoneShaky: VoiceCue.phoneShaky,
        SetupReason.ready: VoiceCue.holdStill,
      };
      expect(expected.keys, containsAll(SetupReason.values));
      for (final entry in expected.entries) {
        expect(VoiceCueTable.forSetup(_status(entry.key)), entry.value);
      }
    });

    test('a stably ready status says ready, whatever the frame reason', () {
      expect(
        VoiceCueTable.forSetup(_status(SetupReason.ready, isReady: true)),
        VoiceCue.ready,
      );
      expect(
        VoiceCueTable.forSetup(_status(SetupReason.tooFar, isReady: true)),
        VoiceCue.ready,
      );
    });
  });

  group('forCountdown', () {
    test('counts three, two, one as the screen rounds the seconds up', () {
      expect(
        VoiceCueTable.forCountdown(const Duration(seconds: 3)),
        VoiceCue.countdownThree,
      );
      expect(
        VoiceCueTable.forCountdown(const Duration(milliseconds: 2400)),
        VoiceCueTable.forCountdown(const Duration(seconds: 3)),
      );
      expect(
        VoiceCueTable.forCountdown(const Duration(seconds: 2)),
        VoiceCue.countdownTwo,
      );
      expect(
        VoiceCueTable.forCountdown(const Duration(milliseconds: 1001)),
        VoiceCue.countdownTwo,
      );
      expect(
        VoiceCueTable.forCountdown(const Duration(milliseconds: 1000)),
        VoiceCue.countdownOne,
      );
      expect(
        VoiceCueTable.forCountdown(const Duration(milliseconds: 200)),
        VoiceCue.countdownOne,
      );
    });

    test('no countdown, or more than three seconds, has no line', () {
      expect(VoiceCueTable.forCountdown(null), isNull);
      expect(VoiceCueTable.forCountdown(const Duration(seconds: 4)), isNull);
      expect(
        VoiceCueTable.forCountdown(const Duration(milliseconds: 3001)),
        isNull,
      );
      expect(VoiceCueTable.forCountdown(Duration.zero), isNull);
    });
  });

  test('forEnd says KO or time up', () {
    expect(VoiceCueTable.forEnd(GameEnd.ko), VoiceCue.ko);
    expect(VoiceCueTable.forEnd(GameEnd.timeUp), VoiceCue.timeUp);
  });

  test('forOutcome says win, lose, or draw', () {
    expect(VoiceCueTable.forOutcome(MatchOutcome.win), VoiceCue.win);
    expect(VoiceCueTable.forOutcome(MatchOutcome.lose), VoiceCue.lose);
    expect(VoiceCueTable.forOutcome(MatchOutcome.draw), VoiceCue.draw);
  });
}
