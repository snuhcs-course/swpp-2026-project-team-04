import 'package:flutter/material.dart';

import '../models/exercise_type.dart';
import '../theme/app_theme.dart';
import '../viewmodels/setup_viewmodel.dart';
import '../widgets/cancel_matching.dart';
import 'setup_screen.dart';

/// [SetupScreen] as the matching flow shows it, with a 매칭 취소 button on
/// top.
///
/// Back, from the system or from SetupScreen's own back button, only asks
/// whether to cancel the matching; the 매칭 취소 button goes home right
/// away. Like SetupScreen, it pops with the exercise when setup finishes.
class MatchSetupScreen extends StatefulWidget {
  const MatchSetupScreen({
    super.key,
    required this.exercise,
    this.createViewModel,
  });

  final ExerciseType exercise;

  /// Builds SetupScreen's view model; replaces the default one in tests.
  final SetupViewModel Function()? createViewModel;

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  /// SetupScreen's view model, kept so [_cancel] can stop it. SetupScreen
  /// still creates it, through [_createSetupViewModel], and disposes it.
  SetupViewModel? _setupViewModel;

  SetupViewModel _createSetupViewModel() => _setupViewModel =
      widget.createViewModel?.call() ??
      SetupViewModel(exercise: widget.exercise);

  /// Goes home. Setup stops first: SetupScreen keeps checking frames while
  /// it slides away, and finishing then would pop home itself, leaving an
  /// empty screen.
  void _cancel() {
    _setupViewModel?.pause();
    popToHome(context);
  }

  /// Asks before leaving on a back attempt.
  ///
  /// Setup goes on under the dialog. When it finishes, SetupScreen pops the
  /// top route, which is then the dialog, with the exercise. So the dialog
  /// takes any result, and the exercise is passed on as if the dialog had
  /// not been there.
  Future<void> _confirmCancel() async {
    final result = await showDialog<Object?>(
      context: context,
      builder: (_) => const CancelMatchingDialog(),
    );
    if (!mounted) return;
    if (result == true) {
      _cancel();
    } else if (result is ExerciseType) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmCancel();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          SetupScreen(
            exercise: widget.exercise,
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
                child: _CancelButton(onPressed: _cancel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "✕ 매칭 취소" on a dark pill that stays readable over the camera.
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.close_rounded, size: 18),
      label: const Text('매칭 취소'),
      style: FilledButton.styleFrom(
        // As tall as SetupScreen's round buttons.
        minimumSize: const Size(0, 40),
        backgroundColor: AppColors.background.withValues(alpha: 0.7),
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
