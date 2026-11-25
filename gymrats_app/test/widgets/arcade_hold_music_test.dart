import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/audio/background_music.dart';
import 'package:gymrats_app/services/audio/sound_services.dart';
import 'package:gymrats_app/services/audio/sound_settings.dart';
import 'package:gymrats_app/widgets/arcade_hold_music.dart';

import '../support/audio_fakes.dart';

void main() {
  late FakeBackgroundMusic app;
  late ArcadeHoldMusic music;

  setUp(() {
    app = FakeBackgroundMusic();
    music = ArcadeHoldMusic(app);
  });

  void playAll(List<MusicCue> cues) => cues.forEach(music.play);

  test('passes the hold screen\'s cues on: the setup, the hold, the '
      'jingle', () {
    playAll([MusicCue.setup, MusicCue.setup, MusicCue.battle, MusicCue.win]);
    expect(app.played, [
      MusicCue.setup,
      MusicCue.setup,
      MusicCue.battle,
      MusicCue.win,
    ]);
  });

  test('left in the setup, the 3·2·1 or the hold, the menu comes back, as '
      'when a battle is left before its result', () {
    for (final last in [MusicCue.setup, MusicCue.battle]) {
      final app = FakeBackgroundMusic();
      final music = ArcadeHoldMusic(app);
      music
        ..play(MusicCue.setup)
        ..play(last)
        ..play(MusicCue.menu);
      expect(app.played.last, MusicCue.menu, reason: 'left after $last');
    }
  });

  test('closed on its briefing before anything started: what plays goes on, '
      'as a fight\'s sheet and versus screen play nothing', () {
    music.play(MusicCue.menu);
    expect(app.played, isEmpty);
  });

  test('closed on its briefing after a jingle (다시 하기, then back): the '
      'silence after the jingle stays, as after a fight', () {
    playAll([MusicCue.setup, MusicCue.battle, MusicCue.lose, MusicCue.menu]);
    expect(app.played, [MusicCue.setup, MusicCue.battle, MusicCue.lose]);
  });

  test('left in the second warning\'s moment, after its jingle started: the '
      'jingle goes on', () {
    playAll([MusicCue.setup, MusicCue.battle, MusicCue.win, MusicCue.menu]);
    expect(app.played.last, MusicCue.win);
  });

  test('played again after a jingle, then left mid-stage: the menu comes '
      'back', () {
    playAll([
      MusicCue.setup,
      MusicCue.battle,
      MusicCue.win,
      MusicCue.setup,
      MusicCue.menu,
    ]);
    expect(app.played.last, MusicCue.menu);
  });

  test('stop goes to the app\'s music; dispose leaves the app\'s music '
      'alone', () {
    music
      ..stop()
      ..dispose();
    expect(app.stops, 1);
    expect(app.disposed, isFalse);
  });

  test('around keeps the set\'s switches, voice and effects and wraps its '
      'music', () {
    final effects = FakeSoundEffects();
    final voice = FakeVoiceGuidance();
    final settings = SoundSettings(store: MemorySoundSettingsStore());
    final set = SoundServices(
      settings: settings,
      voice: voice,
      music: app,
      effects: effects,
    );
    final wrapped = ArcadeHoldMusic.around(set);
    expect(wrapped.settings, same(settings));
    expect(wrapped.voice, same(voice));
    expect(wrapped.effects, same(effects));
    expect(wrapped.music, isA<ArcadeHoldMusic>());
    wrapped.music
      ..play(MusicCue.setup)
      ..play(MusicCue.menu);
    expect(app.played, [MusicCue.setup, MusicCue.menu]);
  });
}
