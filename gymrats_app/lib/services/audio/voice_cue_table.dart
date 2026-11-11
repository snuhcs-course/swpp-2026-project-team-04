import '../../models/game_score.dart';
import '../../models/match_record.dart';
import '../../models/voice_cue.dart';
import '../pose/setup_checker.dart';

/// Maps setup hints and battle events to voice lines, so the sound widget
/// only has to forward state. Pure functions; no plugin, no state.
abstract final class VoiceCueTable {
  /// The line for the setup screen's current hint: "what to fix", "hold
  /// still", or "ready" once the status is stably ready.
  static VoiceCue forSetup(SetupStatus status) {
    if (status.isReady) return VoiceCue.ready;
    return switch (status.reason) {
      SetupReason.noPerson => VoiceCue.noPerson,
      SetupReason.tooClose => VoiceCue.tooClose,
      SetupReason.tooFar => VoiceCue.tooFar,
      SetupReason.notFacingForward => VoiceCue.notFacingForward,
      SetupReason.missingParts => VoiceCue.missingParts,
      SetupReason.notInPushUp => VoiceCue.notInPushUp,
      SetupReason.notStanding => VoiceCue.notStanding,
      SetupReason.phoneTooFlat => VoiceCue.phoneTooFlat,
      SetupReason.phoneShaky => VoiceCue.phoneShaky,
      SetupReason.ready => VoiceCue.holdStill,
    };
  }

  /// The countdown line for the seconds left before an auto start (3, 2, 1,
  /// as the setup screen shows them: milliseconds rounded up). Null when
  /// there is no countdown or it is longer than three seconds.
  static VoiceCue? forCountdown(Duration? autoStartIn) {
    if (autoStartIn == null) return null;
    final seconds = (autoStartIn.inMilliseconds / 1000).ceil();
    return switch (seconds) {
      3 => VoiceCue.countdownThree,
      2 => VoiceCue.countdownTwo,
      1 => VoiceCue.countdownOne,
      _ => null,
    };
  }

  /// The line when the round ends: "KO" or "time up".
  static VoiceCue forEnd(GameEnd end) => switch (end) {
    GameEnd.ko => VoiceCue.ko,
    GameEnd.timeUp => VoiceCue.timeUp,
  };

  /// The line for the result.
  static VoiceCue forOutcome(MatchOutcome outcome) => switch (outcome) {
    MatchOutcome.win => VoiceCue.win,
    MatchOutcome.lose => VoiceCue.lose,
    MatchOutcome.draw => VoiceCue.draw,
  };
}
