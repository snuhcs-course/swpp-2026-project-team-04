import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../models/matchup.dart';
import '../viewmodels/setup_viewmodel.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/exit_game_button.dart';
import 'setup_screen.dart';

/// [SetupScreen] as the matching flow shows it, with a 게임 나가기 button on
/// top.
///
/// Back, from the system or from SetupScreen's own back button, and the
/// 게임 나가기 button all ask before going home. Like SetupScreen, it pops
/// with the exercise when setup finishes.
class MatchSetupScreen extends StatefulWidget {
  const MatchSetupScreen({
    super.key,
    required this.matchup,
    this.createViewModel,
  });

  /// The battle being set up: setup is for its exercise, and the exit
  /// dialog names its opponent.
  final Matchup matchup;

  /// Builds SetupScreen's view model; replaces the default one in tests.
  final SetupViewModel Function()? createViewModel;

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  /// SetupScreen's view model, kept so [_leave] can stop it. SetupScreen
  /// still creates it, through [_createSetupViewModel], and disposes it.
  SetupViewModel? _setupViewModel;

  SetupViewModel _createSetupViewModel() {
    final viewModel =
        widget.createViewModel?.call() ??
        SetupViewModel(exercise: widget.matchup.exercise);
    _setupViewModel = viewModel;
    return viewModel;
  }

  /// Goes home. Setup stops first: SetupScreen keeps checking frames while
  /// it slides away, and finishing then would pop home itself, leaving an
  /// empty screen.
  void _leave() {
    _setupViewModel?.pause();
    popToHome(context);
  }

  /// Asks before leaving, on a back attempt or the 게임 나가기 button.
  ///
  /// Setup goes on under the dialog. When it finishes, SetupScreen pops the
  /// top route, which is then the dialog, with the exercise. So the dialog
  /// takes any result, and the exercise is passed on as if the dialog had
  /// not been there.
  Future<void> _askToLeave() async {
    final result = await showDialog<Object?>(
      context: context,
      builder: (_) =>
          ExitDialog.game(opponentName: widget.matchup.opponent.name),
    );
    if (!mounted) return;
    if (result == true) {
      _leave();
    } else if (result is ExerciseType) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askToLeave();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          SetupScreen(
            exercise: widget.matchup.exercise,
            createViewModel: _createSetupViewModel,
          ),
          // Nothing here may paint or take taps outside the button, so
          // SetupScreen's back and camera switch buttons keep working.
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                // As around SetupScreen's top buttons, so all three line up.
                padding: const EdgeInsets.all(8),
                child: ExitGameButton(onPressed: _askToLeave),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
