// Battle screen demo: no matching, no pose setup, and no push-ups.
//
// Run from gymrats_app/:
//   flutter run -t lib/demo/battle_demo.dart -d <device-id>
// For a shorter round, e.g. 20 seconds:
//   flutter run -t lib/demo/battle_demo.dart --dart-define=BATTLE_SECONDS=20
//
// The battle opens at once against BotOpponent. Touches stand in for the
// push-up judge: tap the camera for a counted rep, press and hold it for a
// rejected one, with the four reasons in turn. The camera is a stand-in
// too: it needs no camera, sends blank frames on a timer, and shows the
// design's pose as dots. Only these stand-ins differ from the app; the
// battle and result screens and their view models are the app's own.
// 다시 매칭 on the result screen opens the next battle right away.
import 'dart:async';
import 'dart:collection';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_result.dart';
import '../models/exercise_type.dart';
import '../models/matchup.dart';
import '../models/pose_frame.dart';
import '../models/rep_event.dart';
import '../screens/battle_screen.dart';
import '../screens/result_screen.dart';
import '../services/device/device_controls.dart';
import '../services/matching/bot_matchmaker.dart';
import '../services/opponent/bot_opponent.dart';
import '../services/pose/camera_service.dart';
import '../services/pose/pose_estimator.dart';
import '../services/pose/rep_judge.dart';
import '../services/user/in_memory_user_repository.dart';
import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/battle_viewmodel.dart';
import '../viewmodels/rep_counter_viewmodel.dart';
import '../widgets/grid_background.dart';
import '../widgets/pose_camera_view.dart';

/// Round length in seconds, set with `--dart-define=BATTLE_SECONDS=20`.
const _battleSeconds = int.fromEnvironment('BATTLE_SECONDS', defaultValue: 60);

const _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: BotMatchmaker.bot,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const BattleDemoApp());
}

/// Opens the battle at once, with touches for the user's reps.
class BattleDemoApp extends StatelessWidget {
  const BattleDemoApp({
    super.key,
    this.roundLength = const Duration(seconds: _battleSeconds),
  });

  final Duration roundLength;

  @override
  Widget build(BuildContext context) {
    // Battles are saved here, as in the app, for as long as the demo runs.
    return Provider<UserRepository>(
      create: (_) => InMemoryUserRepository(),
      child: MaterialApp(
        title: 'GymRats battle demo',
        theme: AppTheme.dark,
        home: _DemoHome(roundLength: roundLength),
        onGenerateRoute: (settings) => switch (settings.name) {
          GymRatsApp.resultRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                ResultScreen(result: settings.arguments! as BattleResult),
          ),
          // 다시 매칭 on the result screen skips the search here too and
          // opens the next battle.
          GymRatsApp.matchingRoute => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => _TouchBattle(roundLength: roundLength),
          ),
          _ => null,
        },
      ),
    );
  }
}

/// Where the demo comes back to when a battle ends: how to play, and a
/// button for the next battle. The first battle opens by itself.
class _DemoHome extends StatefulWidget {
  const _DemoHome({required this.roundLength});

  final Duration roundLength;

  @override
  State<_DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<_DemoHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startBattle());
  }

  void _startBattle() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _TouchBattle(roundLength: widget.roundLength),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final note = text.bodyLarge?.copyWith(color: AppColors.textSecondary);
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('배틀 데모', style: text.headlineMedium),
                  const SizedBox(height: 12),
                  Text(
                    '카메라 화면을 탭하면 인정 1회,\n길게 누르면 무효 1회예요.',
                    textAlign: TextAlign.center,
                    style: note,
                  ),
                  const SizedBox(height: 8),
                  Text('경기 시간 ${widget.roundLength.inSeconds}초', style: note),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _startBattle,
                    child: const Text('배틀 시작'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's BattleScreen, with touches on the camera for the user's reps.
///
/// Touches count only on the camera and only while the round runs, so the
/// leave dialog and the TIME UP overlay work as in the app.
class _TouchBattle extends StatefulWidget {
  const _TouchBattle({required this.roundLength});

  final Duration roundLength;

  @override
  State<_TouchBattle> createState() => _TouchBattleState();
}

class _TouchBattleState extends State<_TouchBattle> {
  final _judge = _TouchJudge();

  /// Handed to BattleScreen, which disposes it.
  late final BattleViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = BattleViewModel(
      matchup: _matchup,
      counter: RepCounterViewModel(
        camera: _StandInCamera(),
        estimator: _StandInEstimator(),
        judge: _judge,
        roundLength: widget.roundLength,
      ),
      opponent: BotOpponent(roundLength: widget.roundLength),
      repository: context.read<UserRepository>(),
      sound: const DeviceRepSound(),
    );
  }

  void _touch(Offset position, {required bool counted}) {
    if (_viewModel.counter.state.phase != CounterPhase.running) return;
    if (!(_cameraRect()?.contains(position) ?? false)) return;
    if (counted) {
      _judge.countRep();
    } else {
      _judge.rejectRep();
    }
  }

  /// Where BattleScreen shows the camera, on screen.
  Rect? _cameraRect() {
    Rect? rect;
    void search(Element element) {
      if (element.widget is PoseCameraView) {
        final box = element.renderObject! as RenderBox;
        rect = box.localToGlobal(Offset.zero) & box.size;
      } else {
        element.visitChildren(search);
      }
    }

    context.visitChildElements(search);
    return rect;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _touch(details.globalPosition, counted: true),
      onLongPressStart: (details) =>
          _touch(details.globalPosition, counted: false),
      child: BattleScreen(matchup: _matchup, createViewModel: () => _viewModel),
    );
  }
}

/// Judges by touch instead of by pose: each frame closes the next rep the
/// user touched for, if any.
class _TouchJudge extends RepJudge {
  final Queue<RejectReason?> _touches = Queue();
  final Stopwatch _sinceStart = Stopwatch()..start();
  int _index = 0;
  int _rejected = 0;

  /// A counted rep, closed on the next frame.
  void countRep() => _touches.add(null);

  /// A rejected rep, closed on the next frame. The reasons take turns.
  void rejectRep() => _touches.add(
    RejectReason.values[_rejected++ % RejectReason.values.length],
  );

  @override
  RepUpdate update(PoseFrame frame) {
    if (_touches.isEmpty) {
      return const RepUpdate(snapshot: JudgeSnapshot.initial);
    }
    final reason = _touches.removeFirst();
    return RepUpdate(
      snapshot: JudgeSnapshot.initial,
      event: RepEvent(
        index: ++_index,
        valid: reason == null,
        reason: reason,
        at: _sinceStart.elapsed,
      ),
    );
  }
}

/// A camera without a camera: it opens at once and sends a blank frame 15
/// times a second, so the round clock and the judge keep running.
class _StandInCamera implements CameraService {
  Timer? _frames;

  @override
  CameraLensDirection get preferredLens => CameraLensDirection.front;

  @override
  CameraController? get controller => null;

  @override
  bool get isFrontCamera => true;

  @override
  bool get canSwitchCamera => false;

  @override
  int get rotationDegrees => 0;

  @override
  Future<CameraPermission> requestPermission() async =>
      CameraPermission.granted;

  @override
  Future<bool> openSettings() async => false;

  @override
  void selectNextCamera() {}

  @override
  Future<void> start(void Function(CameraImage image) onImage) async {
    _frames?.cancel();
    _frames = Timer.periodic(
      const Duration(milliseconds: 66),
      (_) => onImage(const _BlankImage()),
    );
  }

  @override
  Future<void> stop() async {
    _frames?.cancel();
    _frames = null;
  }
}

/// A frame with no pixels. The stand-in estimator never looks at it.
class _BlankImage implements CameraImage {
  const _BlankImage();

  @override
  Never noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('The demo camera sends no pixels.');
}

/// Finds the same pose in every frame: the design's user at the top of a
/// push-up.
class _StandInEstimator implements PoseEstimator {
  @override
  bool get isBusy => false;

  @override
  Future<PoseFrame?> process(CameraImage image, int rotationDegrees) async =>
      _designPose;

  @override
  Future<void> close() async {}
}

/// The design's pose in its 390 × 520 picture: seen clearly from the hips
/// up, with the legs hidden behind the body.
final _designPose = PoseFrame(
  imageWidth: 390,
  imageHeight: 520,
  keypoints: {
    for (final (landmark, x, y, likelihood) in const [
      (BodyLandmark.nose, 195.0, 232.5, 0.95),
      (BodyLandmark.leftEye, 208.5, 221.4, 0.95),
      (BodyLandmark.rightEye, 181.5, 221.4, 0.95),
      (BodyLandmark.leftEar, 221.5, 248.4, 0.95),
      (BodyLandmark.rightEar, 168.5, 248.4, 0.95),
      (BodyLandmark.leftShoulder, 251.1, 319.1, 0.95),
      (BodyLandmark.rightShoulder, 138.9, 319.1, 0.95),
      (BodyLandmark.leftElbow, 263.4, 404.1, 0.95),
      (BodyLandmark.rightElbow, 126.6, 404.1, 0.95),
      (BodyLandmark.leftWrist, 268.1, 486.5, 0.95),
      (BodyLandmark.rightWrist, 121.9, 486.5, 0.95),
      (BodyLandmark.leftHip, 221.0, 395.2, 0.7),
      (BodyLandmark.rightHip, 169.0, 395.2, 0.7),
      (BodyLandmark.leftKnee, 212.6, 435.1, 0.3),
      (BodyLandmark.rightKnee, 177.4, 435.1, 0.3),
      (BodyLandmark.leftAnkle, 208.3, 461.7, 0.3),
      (BodyLandmark.rightAnkle, 181.7, 461.7, 0.3),
    ])
      landmark: Keypoint(
        landmark: landmark,
        x: x,
        y: y,
        likelihood: likelihood,
      ),
  },
);
