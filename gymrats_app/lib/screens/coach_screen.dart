import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/coach_viewmodel.dart';
import '../widgets/coach_stage.dart';
import '../widgets/grid_background.dart';

/// The character's talk about a battle (A10 spec 3): one line at a time in
/// a dialog box, typed out letter by letter, a card for its numbers above
/// the character, and at the goal question the two goals and '사양할래'.
///
/// It draws [viewModel], which the result screen owns and has [started]
/// (from the first line or at the question), and only forwards taps. Back,
/// like 돌아가기, returns to the battle's result; 상세 리포트로 calls
/// [onReport] (P15); a goal not picked is not saved.
///
/// [started]: CoachViewModel.start
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, required this.viewModel, this.onReport});

  final CoachViewModel viewModel;

  /// Opens the battle's report in the talk's place; without it 상세
  /// 리포트로 only leaves, as 돌아가기 does.
  final VoidCallback? onReport;

  /// One letter every 32 ms, as the design types.
  static const letterTime = Duration(milliseconds: 32);

  /// The "next" mark blinks every 15 letters' time, about half a second.
  static const blinkTicks = 15;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  late final Timer _timer;
  int _ticks = 0;
  bool _arrowOn = true;
  bool _reducedMotion = false;

  CoachViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(CoachScreen.letterTime, (_) => _tick());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reducedMotion) return;
    _reducedMotion = reduced;
    // Not while this screen builds: the view model tells its listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewModel.setInstant(_reducedMotion);
    });
  }

  void _tick() {
    if (!mounted || _reducedMotion) return;
    _viewModel.tick();
    _ticks++;
    if (_ticks % CoachScreen.blinkTicks == 0 && _viewModel.state.fullyShown) {
      setState(() => _arrowOn = !_arrowOn);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GridBackground(
        child: SafeArea(
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: CoachStage.maxTextScale,
            child: ChangeNotifierProvider<CoachViewModel>.value(
              value: _viewModel,
              child: Consumer<CoachViewModel>(
                builder: (context, viewModel, _) => CoachStage(
                  state: viewModel.state,
                  voice: viewModel.voice,
                  summary: viewModel.summary,
                  onTap: viewModel.tap,
                  onSkip: viewModel.skip,
                  onChoose: viewModel.choose,
                  onReport:
                      widget.onReport ?? () => Navigator.maybePop(context),
                  onLeave: () => Navigator.maybePop(context),
                  arrowOn: _arrowOn,
                  reducedMotion: _reducedMotion,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
