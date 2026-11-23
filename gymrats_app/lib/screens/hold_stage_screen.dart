import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/arcade_catalog.dart';
import '../models/arcade_stage.dart';
import '../models/character_rig.dart';
import '../models/setup_silhouette_alignment.dart';
import '../services/arcade/arcade_progress_store.dart';
import '../services/audio/sound_effects.dart';
import '../services/audio/sound_services.dart';
import '../services/device/device_controls.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/hold_stage_viewmodel.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/grid_background.dart';
import 'hold_stage_brief.dart';
import 'hold_stage_play.dart';
import 'hold_stage_result.dart';

/// What the user chose when a hold stage screen closes (arcade hold spec
/// 7). The arcade (P16) takes it from there.
enum HoldStageExit {
  /// Back to the arcade: the briefing's back, or 아케이드로.
  arcade,

  /// 다음 스테이지, after a clear.
  nextStage,

  /// Left mid-stage through the leave dialog: no star, nothing kept.
  left,
}

/// One hold stage, opened by its number (spec 7): the briefing, the pose
/// setup, the hold, and its result, in one screen. 다시 하기 and 다시 도전
/// start again from the briefing here; the screen pops a [HoldStageExit]
/// for the rest. Opening a stage that is not a hold stage is stopped by an
/// assert.
///
/// The stars are kept in [progressStore] (or the app's, or the phone's
/// secure store) for [accountId] (or the signed-in account); without an
/// account none are kept. A warning plays the battle's reject sound,
/// following the sound settings (spec 12, user 2026-11-23), and a screen
/// reader hears the warnings, the time running again, each star and the
/// end (spec 8).
class HoldStageScreen extends StatefulWidget {
  const HoldStageScreen({
    super.key,
    required this.stage,
    this.myCharacter = CharacterRig.defaultId,
    this.progressStore,
    this.accountId,
    this.sounds,
    this.createViewModel,
  });

  /// The stage's number, 1 to 24; a hold stage's.
  final int stage;

  /// The user's character: on the bar and cheering on a clear.
  final String myCharacter;

  final ArcadeProgressStore? progressStore;
  final int? accountId;

  /// The sound set; [SoundServices.shared] by default.
  final SoundServices? sounds;

  /// Builds the view model; replaces the default one in tests.
  final HoldStageViewModel Function()? createViewModel;

  @override
  State<HoldStageScreen> createState() => _HoldStageScreenState();
}

class _HoldStageScreenState extends State<HoldStageScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final HoldStageViewModel _viewModel;
  late final SoundServices _sounds;
  late final StreamSubscription<HoldStageCue> _cues;

  /// The GO! band's clock.
  late final AnimationController _go = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  HoldStagePhase _shownPhase = HoldStagePhase.brief;
  bool _askingToLeave = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    assert(
      ArcadeCatalog.stage(widget.stage) is ArcadeHoldStage,
      'Stage ${widget.stage} is not a hold stage.',
    );
    _sounds = widget.sounds ?? SoundServices.shared;
    _sounds.effects.prepare();
    _viewModel = widget.createViewModel?.call() ?? _defaultViewModel();
    _viewModel.addListener(_onChanged);
    _cues = _viewModel.cues.listen(_onCue);
    _go.addListener(() => setState(() {}));
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  HoldStageViewModel _defaultViewModel() {
    final account =
        widget.accountId ??
        Provider.of<AuthViewModel?>(context, listen: false)?.account?.id;
    final store =
        widget.progressStore ??
        Provider.of<ArcadeProgressStore?>(context, listen: false) ??
        (account == null ? null : SecureArcadeProgressStore());
    return HoldStageViewModel(
      stage: widget.stage,
      store: store,
      accountId: account,
    );
  }

  void _onChanged() {
    final phase = _viewModel.state.phase;
    if (phase == _shownPhase) return;
    final was = _shownPhase;
    _shownPhase = phase;
    // The camera runs from the setup to the end: keep the screen on.
    if (was == HoldStagePhase.brief) unawaited(keepScreenOn(true));
    if (phase == HoldStagePhase.result || phase == HoldStagePhase.brief) {
      unawaited(keepScreenOn(false));
    }
    if (phase == HoldStagePhase.hold) {
      _go.forward(from: 0);
    }
    if (_askingToLeave && phase == HoldStagePhase.result) {
      // The hold ended while asking: the question no longer applies.
      _askingToLeave = false;
      Navigator.pop(context);
    }
  }

  void _onCue(HoldStageCue cue) {
    if (!mounted) return;
    if (cue.kind == HoldStageCueKind.warning) {
      _sounds.effects.play(SoundEffect.reject);
    }
    SemanticsService.sendAnnouncement(
      View.of(context),
      holdAnnouncement(cue),
      Directionality.of(context),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        unawaited(_viewModel.pause());
      case AppLifecycleState.resumed:
        unawaited(_viewModel.resume());
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _close(HoldStageExit exit) {
    if (_closed) return;
    _closed = true;
    _viewModel.leave();
    Navigator.pop(context, exit);
  }

  /// Back: to the arcade before and after the hold, the leave dialog in it.
  void _back() {
    switch (_viewModel.state.phase) {
      case HoldStagePhase.brief || HoldStagePhase.result:
        _close(HoldStageExit.arcade);
      case HoldStagePhase.setup ||
          HoldStagePhase.countdown ||
          HoldStagePhase.hold:
        unawaited(_askToLeave());
    }
  }

  /// The battle's leave dialog (spec 5): leaving keeps no star.
  Future<void> _askToLeave() async {
    if (_askingToLeave) return;
    _askingToLeave = true;
    final leave = await confirmExit(
      context,
      ExitDialog.game(opponentName: _viewModel.floor.ownerName),
    );
    if (!_askingToLeave) return;
    _askingToLeave = false;
    if (!mounted || !leave) return;
    if (_viewModel.state.phase == HoldStagePhase.result) return;
    _close(HoldStageExit.left);
  }

  @override
  void dispose() {
    unawaited(keepScreenOn(false));
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cues.cancel());
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    _go.dispose();
    _sounds.effects.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HoldStageViewModel>.value(
      value: _viewModel,
      child: Consumer<HoldStageViewModel>(
        builder: (context, viewModel, _) {
          final setup = viewModel.setup;
          final body = setup == null
              ? _body(viewModel)
              : ListenableBuilder(
                  listenable: setup,
                  builder: (context, _) => _body(viewModel),
                );
          return PopScope<Object?>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _back();
            },
            child: Scaffold(backgroundColor: AppColors.background, body: body),
          );
        },
      ),
    );
  }

  Widget _body(HoldStageViewModel viewModel) {
    final state = viewModel.state;
    switch (state.phase) {
      case HoldStagePhase.brief:
        return GridBackground(
          child: HoldStageBrief(
            stage: viewModel.stage,
            floor: viewModel.floor,
            definition: viewModel.definition,
            onBack: () => _close(HoldStageExit.arcade),
            onStart: () => unawaited(viewModel.startPose()),
          ),
        );
      case HoldStagePhase.result:
        return GridBackground(
          child: HoldStageResult(
            stage: viewModel.stage,
            floor: viewModel.floor,
            held: state.progress.held,
            litStars: state.stars.lit,
            myCharacter: widget.myCharacter,
            onPlayAgain: viewModel.playAgain,
            onNextStage: () => _close(HoldStageExit.nextStage),
            onArcade: () => _close(HoldStageExit.arcade),
          ),
        );
      case HoldStagePhase.setup ||
          HoldStagePhase.countdown ||
          HoldStagePhase.hold:
        return HoldStagePlay(
          stage: viewModel.stage,
          floor: viewModel.floor,
          definition: viewModel.definition,
          state: state,
          setup: viewModel.setup,
          frame: viewModel.lastFrame,
          myCharacter: widget.myCharacter,
          goAge: state.phase == HoldStagePhase.hold && _go.isAnimating
              ? _go.value * 700
              : null,
          onLeave: () => unawaited(_askToLeave()),
          onGuideCrop: (SetupCameraCrop crop) => viewModel.setGuideCrop(crop),
          onCameraBox: viewModel.setGuideViewport,
        );
    }
  }
}

/// What a screen reader hears for [cue] (spec 8): short, and never the
/// clock each second.
String holdAnnouncement(HoldStageCue cue) => switch (cue.kind) {
  HoldStageCueKind.warning => '경고 ${cue.count}번, ${cue.fault!.words}',
  HoldStageCueKind.resumed => '시간이 다시 흘러요',
  HoldStageCueKind.star => '${cue.seconds}초, 별 ${_count(cue.count)}',
  HoldStageCueKind.ended =>
    cue.count == 0 ? '실패' : '클리어, 별 ${_count(cue.count)}',
};

String _count(int n) => switch (n) {
  1 => '하나',
  2 => '둘',
  3 => '셋',
  _ => '$n개',
};
