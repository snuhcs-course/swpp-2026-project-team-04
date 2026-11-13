import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/battle_screen.dart';
import 'package:gymrats_app/services/audio/background_music.dart';
import 'package:gymrats_app/services/audio/sound_effects.dart';
import 'package:gymrats_app/services/audio/sound_services.dart';
import 'package:gymrats_app/services/pose/rep_judge.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/battle_viewmodel.dart';
import 'package:gymrats_app/viewmodels/rep_counter_viewmodel.dart';

import '../support/audio_fakes.dart';
import '../support/fakes.dart';
import '../support/placed_phone.dart';
import '../support/pose_fixtures.dart';

/// The bot battle screen with nothing hooked in from outside: its own sound
/// (J2's `BattleSounds`) plays through the shared sound set.
void main() {
  const matchup = Matchup(
    exercise: ExerciseType.pushUp,
    playerName: '진영',
    opponent: Opponent(name: 'RepBot', isBot: true),
  );

  late SoundServices sound;
  late FakeCameraService camera;
  late FakePoseEstimator estimator;
  late FakeRepJudge judge;
  late Duration now;

  FakeBackgroundMusic music() => sound.music as FakeBackgroundMusic;
  FakeSoundEffects effects() => sound.effects as FakeSoundEffects;
  FakeVoiceGuidance voice() => sound.voice as FakeVoiceGuidance;

  Future<void> pass(WidgetTester tester, int ms) async {
    for (var left = ms; left > 0; left -= 50) {
      await tester.pump(Duration(milliseconds: left < 50 ? left : 50));
    }
  }

  Future<void> frame(WidgetTester tester, double seconds) async {
    now = Duration(milliseconds: (seconds * 1000).round());
    estimator.frames.add(standingFrame());
    camera.emit();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    sound = fakeSoundServices();
    SoundServices.shared = sound;
    addTearDown(() => SoundServices.shared = null);
    camera = FakeCameraService();
    estimator = FakePoseEstimator();
    judge = FakeRepJudge();
    now = Duration.zero;
    final viewModel = BattleViewModel(
      matchup: matchup,
      counter: RepCounterViewModel(
        camera: camera,
        estimator: estimator,
        judge: judge,
        exercise: matchup.exercise,
        phoneTilt: placedPhone(),
        clock: () => now,
        roundLength: const Duration(days: 1),
      ),
      opponent: FakeOpponentSource(),
      repository: FakeUserRepository(),
      sound: FakeRepSound(),
      setup: SetupChecker(
        exercise: matchup.exercise,
        config: const SetupConfig(
          readyDelay: Duration.zero,
          dropDelay: Duration.zero,
        ),
        clock: () => now,
      ),
      clock: () => now,
      now: () => DateTime(2026, 11, 13, 14),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BattleScreen(matchup: matchup, createViewModel: () => viewModel),
      ),
    );
    await pass(tester, 400);
  }

  testWidgets('setup music through the setup and 3-2-1, then the battle '
      'music; my counted rep hits; no voice at all; leaving frees the '
      'effects', (tester) async {
    await open(tester);
    expect(effects().prepares, 1);
    expect(music().played.toSet(), {MusicCue.setup});

    await frame(tester, 1);
    await frame(tester, 2.5);
    await frame(tester, 4);
    await pass(tester, 800);
    expect(music().played.last, MusicCue.battle);

    judge.snapshot = const JudgeSnapshot(
      phase: RepPhase.descending,
      shoulderDrop: .5,
      topShoulderY: 200,
    );
    judge.closeRep();
    await frame(tester, 6);
    await pass(tester, 500);
    expect(effects().played, contains(SoundEffect.good));
    expect(voice().said, isEmpty, reason: 'the battle has no voice');

    await tester.pumpWidget(const SizedBox());
    expect(effects().releases, 1);
  });
}
