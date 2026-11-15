import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/voice_cue.dart';
import 'package:gymrats_app/services/audio/background_music.dart';
import 'package:gymrats_app/services/audio/sound_services.dart';
import 'package:gymrats_app/widgets/sound_cues.dart';

import '../support/audio_fakes.dart';

SoundServices _fakes() => fakeSoundServices();

FakeBackgroundMusic _music(SoundServices s) => s.music as FakeBackgroundMusic;
FakeVoiceGuidance _voice(SoundServices s) => s.voice as FakeVoiceGuidance;

void main() {
  tearDown(() => SoundServices.shared = null);

  testWidgets('shows its child and passes the cues on every build', (
    tester,
  ) async {
    final services = _fakes();
    await tester.pumpWidget(
      SoundCues(
        services: services,
        music: MusicCue.battle,
        voice: VoiceCue.countdownThree,
        child: const Text('battle', textDirection: TextDirection.ltr),
      ),
    );
    expect(find.text('battle'), findsOneWidget);
    expect(_music(services).played, [MusicCue.battle]);
    expect(_voice(services).said, [VoiceCue.countdownThree]);

    await tester.pumpWidget(
      SoundCues(
        services: services,
        music: MusicCue.fever,
        voice: VoiceCue.countdownTwo,
        child: const SizedBox(),
      ),
    );
    expect(_music(services).played, [MusicCue.battle, MusicCue.fever]);
    expect(_voice(services).said, [
      VoiceCue.countdownThree,
      VoiceCue.countdownTwo,
    ]);
  });

  testWidgets('null cues keep what is playing and say nothing', (tester) async {
    final services = _fakes();
    await tester.pumpWidget(
      SoundCues(services: services, child: const SizedBox()),
    );
    expect(_music(services).played, isEmpty);
    expect(_music(services).stops, 0);
    expect(_voice(services).said, isEmpty);
  });

  testWidgets('leaving the screen stops nothing', (tester) async {
    final services = _fakes();
    await tester.pumpWidget(
      SoundCues(
        services: services,
        music: MusicCue.win,
        voice: VoiceCue.win,
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    expect(_music(services).stops, 0);
    expect(_voice(services).stops, 0);
  });

  testWidgets('without a set it uses the shared one', (tester) async {
    final shared = _fakes();
    SoundServices.shared = shared;
    await tester.pumpWidget(
      const SoundCues(music: MusicCue.menu, child: SizedBox()),
    );
    expect(_music(shared).played, [MusicCue.menu]);
  });

  testWidgets('a screen tested without a sound set reaches no plugin and '
      'leaves no timers', (tester) async {
    await tester.pumpWidget(
      const SoundCues(
        music: MusicCue.battle,
        voice: VoiceCue.countdownThree,
        child: SizedBox(),
      ),
    );
    await tester.pumpWidget(
      const SoundCues(
        music: MusicCue.fever,
        voice: VoiceCue.fever,
        child: SizedBox(),
      ),
    );
    expect(SoundServices.shared.music, isA<SilentBackgroundMusic>());
  });

  testWidgets('a new set cuts the old voice off and gets the cues', (
    tester,
  ) async {
    final first = _fakes(), second = _fakes();
    await tester.pumpWidget(
      SoundCues(
        services: first,
        music: MusicCue.setup,
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(
      SoundCues(
        services: second,
        music: MusicCue.setup,
        child: const SizedBox(),
      ),
    );
    expect(_voice(first).stops, 1);
    expect(_music(second).played, [MusicCue.setup]);
  });

  testWidgets('the screen\'s music comes back when the screen pushed over '
      'it closes (home after a battle)', (tester) async {
    final s = _fakes();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: SoundCues(
          services: s,
          music: MusicCue.menu,
          child: const SizedBox(),
        ),
      ),
    );
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => SoundCues(
            services: s,
            music: MusicCue.win,
            child: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_music(s).played, [MusicCue.menu, MusicCue.win]);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_music(s).played, [MusicCue.menu, MusicCue.win, MusicCue.menu]);
  });

  testWidgets('outside a route, and with no music, nothing comes back', (
    tester,
  ) async {
    final s = _fakes();
    await tester.pumpWidget(
      MaterialApp(
        home: SoundCues(
          services: s,
          voice: VoiceCue.ready,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpWidget(
      SoundCues(services: s, voice: VoiceCue.ready, child: const SizedBox()),
    );
    expect(_music(s).played, isEmpty);
  });
}
