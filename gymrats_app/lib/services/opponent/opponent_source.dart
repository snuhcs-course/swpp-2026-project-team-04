import '../../models/rep_event.dart';

/// The other side of a battle: reports the opponent's reps as they happen.
///
/// BattleViewModel starts it when the user's camera starts running and stops
/// it when the round ends. Iteration 1 battles only the AI and uses
/// BotOpponent; a server implementation can replace it later.
abstract interface class OpponentSource {
  /// The opponent's reps, valid and rejected, as they are made.
  Stream<RepEvent> get reps;

  /// Starts a new round from zero.
  void start();

  /// Holds the round while the user's round clock is held.
  void pause();

  /// Continues a held round. Does nothing while it runs or after [stop].
  void resume();

  /// Ends the round: no more reps until the next [start].
  void stop();

  /// Releases [reps]. The source cannot be used afterwards.
  void dispose();
}
