import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/services/audio/background_music.dart';
import 'package:gymrats_app/services/audio/sound_effects.dart';
import 'package:gymrats_app/services/audio/sound_services.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/sound_battle.dart';

import '../support/audio_fakes.dart';

FakeBackgroundMusic _music(SoundServices s) => s.music as FakeBackgroundMusic;
FakeSoundEffects _effects(SoundServices s) => s.effects as FakeSoundEffects;
FakeVoiceGuidance _voice(SoundServices s) => s.voice as FakeVoiceGuidance;

BattleStageState _stage(
  BattleStagePhase phase, {
  bool fever = false,
  bool danger = false,
  BattleStageEnd? end,
}) => BattleStageState(
  phase: phase,
  myName: '나',
  opponentName: 'BOT',
  remaining: const Duration(seconds: 10),
  roundLength: const Duration(seconds: 30),
  fever: fever,
  danger: danger,
  end: end,
);

BattleStageEnd _end(BattleSide? winner, {bool decided = true}) =>
    BattleStageEnd(
      kind: BattleEndKind.timeUp,
      winner: winner,
      decided: decided,
    );

void main() {
  tearDown(() => SoundServices.shared = null);

  group('musicFor', () {
    test('setup music through the setup and the countdown; battle, then '
        'fever; the jingle for the winner', () {
      expect(
        BattleSounds.musicFor(_stage(BattleStagePhase.setup)),
        MusicCue.setup,
      );
      expect(
        BattleSounds.musicFor(_stage(BattleStagePhase.countdown)),
        MusicCue.setup,
      );
      expect(
        BattleSounds.musicFor(_stage(BattleStagePhase.playing)),
        MusicCue.battle,
      );
      expect(
        BattleSounds.musicFor(_stage(BattleStagePhase.playing, fever: true)),
        MusicCue.fever,
      );
      expect(
        BattleSounds.musicFor(
          _stage(BattleStagePhase.ended, end: _end(BattleSide.me)),
        ),
        MusicCue.win,
      );
      expect(
        BattleSounds.musicFor(
          _stage(BattleStagePhase.ended, end: _end(BattleSide.opponent)),
        ),
        MusicCue.lose,
      );
      expect(
        BattleSounds.musicFor(_stage(BattleStagePhase.ended, end: _end(null))),
        isNull,
      );
    });
  });

  test('a whole round: prepares the effects, setup, battle, fever, the alarm '
      'on and off, the win jingle, no voice; leaving frees the effects', () {
    final s = fakeSoundServices();
    final sounds = BattleSounds(services: s);
    expect(_effects(s).prepares, 1);
    sounds
      ..show(_stage(BattleStagePhase.setup))
      ..show(_stage(BattleStagePhase.countdown))
      ..show(_stage(BattleStagePhase.playing))
      ..show(_stage(BattleStagePhase.playing, danger: true))
      ..show(_stage(BattleStagePhase.playing, fever: true, danger: true))
      ..show(_stage(BattleStagePhase.playing, fever: true))
      ..show(_stage(BattleStagePhase.ended, end: _end(BattleSide.me)));
    expect(_music(s).played, [
      MusicCue.setup,
      MusicCue.setup,
      MusicCue.battle,
      MusicCue.battle,
      MusicCue.fever,
      MusicCue.fever,
      MusicCue.win,
    ]);
    expect(_effects(s).dangers, [true, false]);
    sounds
      ..dispose()
      ..dispose()
      ..show(_stage(BattleStagePhase.playing))
      ..cue(const BattleStageCue(BattleCueKind.knockout));
    expect(_effects(s).releases, 1);
    expect(_music(s).played, hasLength(7));
    expect(_effects(s).played, isEmpty);
    expect(_voice(s).said, isEmpty);
  });

  test('the alarm sounds only while the round is on', () {
    final s = fakeSoundServices();
    final sounds = BattleSounds(services: s)
      ..show(_stage(BattleStagePhase.setup, danger: true));
    expect(_effects(s).danger, isFalse);
    sounds.show(_stage(BattleStagePhase.playing, danger: true));
    expect(_effects(s).danger, isTrue);
    sounds.show(
      _stage(
        BattleStagePhase.ended,
        danger: true,
        end: _end(BattleSide.opponent),
      ),
    );
    expect(_effects(s).danger, isFalse);
    expect(_music(s).played.last, MusicCue.lose);
  });

  test('waiting for the server\'s result keeps the music; a draw fades it '
      'out', () {
    final s = fakeSoundServices();
    BattleSounds(services: s)
      ..show(_stage(BattleStagePhase.playing, fever: true))
      ..show(_stage(BattleStagePhase.ended, end: _end(null, decided: false)));
    expect(_music(s).stops, 0);
    expect(_music(s).played, [MusicCue.fever]);
    BattleSounds(services: s)
        .show(_stage(BattleStagePhase.ended, end: _end(null)));
    expect(_music(s).stops, 1);
  });

  test('the stage moments: my hit by grade, my miss, the KO; the '
      'opponent\'s reps and the other moments are silent', () {
    final s = fakeSoundServices();
    BattleSounds(services: s)
      ..cue(
        const BattleStageCue(
          BattleCueKind.hit,
          side: BattleSide.me,
          grade: GameGrade.excellent,
        ),
      )
      ..cue(
        const BattleStageCue(
          BattleCueKind.hit,
          side: BattleSide.me,
          grade: GameGrade.good,
        ),
      )
      ..cue(
        const BattleStageCue(
          BattleCueKind.hit,
          side: BattleSide.me,
          grade: GameGrade.average,
        ),
      )
      ..cue(const BattleStageCue(BattleCueKind.miss, side: BattleSide.me))
      ..cue(
        const BattleStageCue(
          BattleCueKind.hit,
          side: BattleSide.opponent,
          grade: GameGrade.excellent,
        ),
      )
      ..cue(const BattleStageCue(BattleCueKind.miss, side: BattleSide.opponent))
      ..cue(const BattleStageCue(BattleCueKind.countdown, number: 3))
      ..cue(const BattleStageCue(BattleCueKind.go))
      ..cue(const BattleStageCue(BattleCueKind.timeUp))
      ..cue(
        const BattleStageCue(
          BattleCueKind.knockout,
          side: BattleSide.opponent,
          grade: GameGrade.good,
        ),
      );
    expect(_effects(s).played, [
      SoundEffect.excellent,
      SoundEffect.good,
      SoundEffect.average,
      SoundEffect.reject,
      SoundEffect.ko,
    ]);
  });

  test('a battle that ends without a result stops the alarm and the '
      'music', () {
    final s = fakeSoundServices();
    BattleSounds(services: s)
      ..show(_stage(BattleStagePhase.playing, danger: true))
      ..ended()
      ..ended();
    expect(_effects(s).danger, isFalse);
    expect(_music(s).stops, 2);
    final gone = BattleSounds(services: s)..dispose();
    gone.ended();
    expect(_music(s).stops, 2);
  });

  test('leaving before a result brings the menu music back; after a result '
      'its jingle, or a draw\'s silence, goes on', () {
    final s = fakeSoundServices();
    BattleSounds(services: s)
      ..show(_stage(BattleStagePhase.playing, fever: true))
      ..dispose();
    expect(_music(s).played.last, MusicCue.menu);

    BattleSounds(services: s)
      ..show(_stage(BattleStagePhase.ended, end: _end(null, decided: false)))
      ..dispose();
    expect(_music(s).played.last, MusicCue.menu, reason: 'no result yet');

    BattleSounds(services: s)
      ..show(_stage(BattleStagePhase.playing))
      ..ended()
      ..dispose();
    expect(_music(s).played.last, MusicCue.menu, reason: 'ended without one');

    BattleSounds(services: s)
      ..show(_stage(BattleStagePhase.ended, end: _end(BattleSide.me)))
      ..dispose();
    expect(_music(s).played.last, MusicCue.win);

    final played = _music(s).played.length;
    BattleSounds(services: s)
      ..show(_stage(BattleStagePhase.ended, end: _end(null)))
      ..dispose();
    expect(_music(s).played, hasLength(played), reason: 'a draw stays quiet');
  });

  test('without a set it uses the shared one', () {
    final shared = fakeSoundServices();
    SoundServices.shared = shared;
    BattleSounds().show(_stage(BattleStagePhase.playing));
    expect(_music(shared).played, [MusicCue.battle]);
  });

  test('the battle\'s rep beep stays quiet', () {
    const NoRepBeep().playRepCounted();
  });
}
