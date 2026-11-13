import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/audio/background_music.dart';
import 'package:gymrats_app/services/audio/sound_settings.dart';

import '../../support/audio_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fade = Duration(milliseconds: 600);
  late FakeMusicPlayers players;
  late SoundSettings settings;

  BackgroundMusicService newMusic() => BackgroundMusicService(
    newPlayer: players.call,
    settings: settings,
    fade: fade,
  );

  setUp(() {
    players = FakeMusicPlayers();
    settings = SoundSettings(store: MemorySoundSettingsStore());
  });

  group('MusicCue', () {
    test('every cue has a bundled track; only the jingles play once', () {
      for (final cue in MusicCue.values) {
        expect(cue.asset, startsWith('assets/audio/bgm_'));
      }
      expect(MusicCue.values.where((c) => !c.loop), [
        MusicCue.win,
        MusicCue.lose,
      ]);
    });

    test('fever is the battle track played faster', () {
      expect(MusicCue.fever.asset, MusicCue.battle.asset);
      expect(MusicCue.fever.rate, feverRate);
      expect(feverRate, 1.25);
      expect(MusicCue.battle.rate, 1);
    });

    test('the battle track starts at its first beat and fades in fast; the '
        'others start at the top', () {
      expect(MusicCue.battle.start, battleStart);
      expect(MusicCue.fever.start, battleStart);
      expect(battleStart, greaterThan(Duration.zero));
      expect(MusicCue.battle.fadeIn, lessThan(fade));
      for (final cue in [MusicCue.menu, MusicCue.setup, MusicCue.win]) {
        expect(cue.start, Duration.zero);
        expect(cue.fadeIn, isNull);
        expect(cue.volume, 1);
      }
      expect(MusicCue.battle.volume, battleVolume);
      expect(MusicCue.fever.volume, battleVolume);
      expect(battleVolume, lessThan(1), reason: 'the hits must stand out');
    });
  });

  group('changing the music', () {
    test('a cue loads its track silent, starts it and fades it in', () {
      fakeAsync((async) {
        final music = newMusic();
        music.play(MusicCue.menu);
        async.flushMicrotasks();
        final p = players.last;
        expect(p.asset, MusicCue.menu.asset);
        expect(p.loop, isTrue);
        expect(p.playing, isTrue);
        expect(p.volumes.first, 0);
        async.elapse(fade);
        expect(p.volume, closeTo(1, 1e-9));
        expect(p.volumes, orderedEquals([...p.volumes]..sort()));
        expect(music.cue, MusicCue.menu);
        music.dispose();
      });
    });

    test('the battle track loads from its first beat and is at full volume '
        'after its short fade-in', () {
      fakeAsync((async) {
        final music = newMusic()..play(MusicCue.setup);
        async.elapse(fade);
        final setup = players.last;
        music.play(MusicCue.battle);
        async.flushMicrotasks();
        final battle = players.last;
        expect(battle.start, battleStart);
        async.elapse(MusicCue.battle.fadeIn!);
        expect(battle.volume, closeTo(battleVolume, 1e-9));
        expect(
          setup.volume,
          greaterThan(0),
          reason:
              'the old one fades out '
              'over the normal fade',
        );
        async.elapse(fade);
        expect(setup.disposed, isTrue);
        music.dispose();
      });
    });

    test('the same cue on every state update plays the track once', () {
      fakeAsync((async) {
        final music = newMusic();
        for (var i = 0; i < 30; i++) {
          music.play(MusicCue.battle);
          async.elapse(const Duration(milliseconds: 33));
        }
        expect(players.made, hasLength(1));
        music.dispose();
      });
    });

    test('a new track fades in while the old one fades out and is freed', () {
      fakeAsync((async) {
        final music = newMusic()..play(MusicCue.menu);
        async.elapse(fade);
        final menu = players.last;
        music.play(MusicCue.setup);
        async.flushMicrotasks();
        final setup = players.last;
        expect(setup, isNot(same(menu)));
        async.elapse(fade ~/ 2);
        expect(menu.volume, closeTo(0.5, 1e-9));
        expect(setup.volume, closeTo(0.5, 1e-9));
        expect(menu.disposed, isFalse);
        async.elapse(fade ~/ 2);
        expect(menu.volume, closeTo(0, 1e-9));
        expect(menu.stopped && menu.disposed, isTrue);
        expect(setup.volume, closeTo(1, 1e-9));
        expect(setup.playing, isTrue);
        music.dispose();
      });
    });

    test('fever keeps the battle track and only raises its rate; back to '
        'battle lowers it', () {
      fakeAsync((async) {
        final music = newMusic()..play(MusicCue.battle);
        async.elapse(fade);
        final battle = players.last;
        music.play(MusicCue.fever);
        async.flushMicrotasks();
        expect(players.made, hasLength(1), reason: 'no restart at fever');
        expect(battle.rate, feverRate);
        expect(battle.playing, isTrue);
        music.play(MusicCue.battle);
        async.flushMicrotasks();
        expect(battle.rate, 1);
        music.dispose();
      });
    });

    test('fever asked for while the battle track still loads plays fast', () {
      fakeAsync((async) {
        final gate = Completer<void>();
        final music = BackgroundMusicService(
          newPlayer: () => players()..loadGate = gate,
          settings: settings,
          fade: fade,
        )..play(MusicCue.battle);
        music.play(MusicCue.fever);
        gate.complete();
        async.elapse(fade);
        expect(players.made, hasLength(1));
        expect(players.last.rate, feverRate);
        music.dispose();
      });
    });

    test('a result jingle plays once', () {
      fakeAsync((async) {
        final music = newMusic()..play(MusicCue.fever);
        async.elapse(fade);
        music.play(MusicCue.win);
        async.elapse(fade);
        expect(players.last.asset, MusicCue.win.asset);
        expect(players.last.loop, isFalse);
        music.play(MusicCue.lose);
        async.elapse(fade);
        expect(players.last.asset, MusicCue.lose.asset);
        expect(players.last.loop, isFalse);
        music.dispose();
      });
    });

    test('a track replaced while it loads is freed and never plays', () {
      fakeAsync((async) {
        final gate = Completer<void>();
        var first = true;
        final music = BackgroundMusicService(
          newPlayer: () {
            final p = players();
            if (first) p.loadGate = gate;
            first = false;
            return p;
          },
          settings: settings,
          fade: fade,
        )..play(MusicCue.setup);
        final slow = players.last;
        music.play(MusicCue.battle);
        gate.complete();
        async.elapse(fade);
        expect(slow.playing, isFalse);
        expect(slow.disposed, isTrue);
        expect(players.last.asset, MusicCue.battle.asset);
        expect(players.last.playing, isTrue);
        music.dispose();
      });
    });

    test('stop fades out, frees the player and forgets the cue', () {
      fakeAsync((async) {
        final music = newMusic()..play(MusicCue.menu);
        async.elapse(fade);
        final p = players.last;
        music.stop();
        expect(music.cue, isNull);
        async.elapse(fade);
        expect(p.volume, closeTo(0, 1e-9));
        expect(p.disposed, isTrue);
        music.play(MusicCue.menu);
        async.elapse(fade);
        expect(players.made, hasLength(2), reason: 'the same cue after stop');
        music.dispose();
      });
    });
  });

  group('sound off', () {
    test('turning sound off fades the music out and pauses it; on resumes '
        'the same track', () {
      fakeAsync((async) {
        final music = newMusic()..play(MusicCue.setup);
        async.elapse(fade);
        final p = players.last;
        unawaited(settings.setEnabled(false));
        async.elapse(fade);
        expect(p.volume, closeTo(0, 1e-9));
        expect(p.playing, isFalse);
        expect(p.disposed, isFalse);
        unawaited(settings.setEnabled(true));
        async.elapse(fade);
        expect(players.made, hasLength(1));
        expect(p.playing, isTrue);
        expect(p.volume, closeTo(1, 1e-9));
        music.dispose();
      });
    });

    test('nothing plays while sound is off; the last looping cue starts '
        'when it is back', () {
      fakeAsync((async) {
        unawaited(settings.setEnabled(false));
        final music = newMusic()
          ..play(MusicCue.setup)
          ..play(MusicCue.battle);
        async.elapse(fade);
        expect(players.made, isEmpty);
        unawaited(settings.setEnabled(true));
        async.elapse(fade);
        expect(players.made, hasLength(1));
        expect(players.last.asset, MusicCue.battle.asset);
        expect(players.last.playing, isTrue);
        music.dispose();
      });
    });

    test('a jingle asked for while sound is off is not played later', () {
      fakeAsync((async) {
        unawaited(settings.setEnabled(false));
        final music = newMusic()..play(MusicCue.win);
        unawaited(settings.setEnabled(true));
        async.elapse(fade);
        expect(players.made, isEmpty);
        music.dispose();
      });
    });

    test('a jingle cut off by sound off is freed, not replayed', () {
      fakeAsync((async) {
        final music = newMusic()..play(MusicCue.lose);
        async.elapse(fade);
        final p = players.last;
        unawaited(settings.setEnabled(false));
        async.elapse(fade);
        expect(p.disposed, isTrue);
        unawaited(settings.setEnabled(true));
        async.elapse(fade);
        expect(players.made, hasLength(1));
        music.dispose();
      });
    });

    test('a jingle still loading when sound goes off is dropped, not played '
        'when sound is back', () {
      fakeAsync((async) {
        final gate = Completer<void>();
        final music = BackgroundMusicService(
          newPlayer: () => players()..loadGate = gate,
          settings: settings,
          fade: fade,
        )..play(MusicCue.win);
        final p = players.last;
        unawaited(settings.setEnabled(false));
        async.flushMicrotasks();
        expect(p.disposed, isTrue);
        gate.complete();
        async.elapse(fade);
        unawaited(settings.setEnabled(true));
        async.elapse(fade);
        expect(p.playing, isFalse);
        expect(players.made, hasLength(1));
        music.dispose();
      });
    });

    test('sound off while the track loads keeps it paused until sound is '
        'back', () {
      fakeAsync((async) {
        final gate = Completer<void>();
        final music = BackgroundMusicService(
          newPlayer: () => players()..loadGate = gate,
          settings: settings,
          fade: fade,
        )..play(MusicCue.menu);
        unawaited(settings.setEnabled(false));
        gate.complete();
        async.elapse(fade);
        expect(players.last.playing, isFalse);
        unawaited(settings.setEnabled(true));
        async.elapse(fade);
        expect(players.last.playing, isTrue);
        music.dispose();
      });
    });
  });

  test('sound back on brings the battle track in over its quick fade', () {
    fakeAsync((async) {
      final music = newMusic()..play(MusicCue.battle);
      async.elapse(fade);
      final p = players.last;
      unawaited(settings.setEnabled(false));
      async.elapse(fade);
      expect(p.playing, isFalse);
      unawaited(settings.setEnabled(true));
      async.elapse(MusicCue.battle.fadeIn!);
      expect(p.playing, isTrue);
      expect(p.volume, closeTo(battleVolume, 1e-9));
      music.dispose();
    });
  });

  group('background', () {
    test('a paused app fades the music out and resumes it in the '
        'foreground', () {
      fakeAsync((async) {
        final music = newMusic()..play(MusicCue.menu);
        async.elapse(fade);
        final p = players.last;
        music.didChangeAppLifecycleState(AppLifecycleState.paused);
        async.elapse(fade);
        expect(p.playing, isFalse);
        music.didChangeAppLifecycleState(AppLifecycleState.inactive);
        async.elapse(fade);
        expect(p.playing, isFalse);
        music.didChangeAppLifecycleState(AppLifecycleState.resumed);
        async.elapse(fade);
        expect(p.playing, isTrue);
        expect(p.volume, closeTo(1, 1e-9));
        music.dispose();
      });
    });

    testWidgets('the service hears the lifecycle from the binding, and one '
        'made in the background starts silent', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final music = newMusic()..play(MusicCue.menu);
      await tester.pump(fade);
      expect(players.made, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(fade);
      expect(players.last.playing, isTrue);
      music.dispose();
      await tester.pump(fade);
    });
  });

  group('robustness', () {
    test('a track that fails to load is freed and the music goes on with '
        'the next cue', () {
      fakeAsync((async) {
        final music = newMusic();
        players.failNext = true;
        music.play(MusicCue.menu);
        async.elapse(fade);
        expect(players.last.disposed, isTrue);
        music.play(MusicCue.setup);
        async.elapse(fade);
        expect(players.last.playing, isTrue);
        music.dispose();
      });
    });

    test(
      'dispose in the middle of a change frees the old fading track too',
      () {
        fakeAsync((async) {
          final music = newMusic()..play(MusicCue.setup);
          async.elapse(fade);
          final setup = players.last;
          music.play(MusicCue.battle);
          async.elapse(fade ~/ 3);
          music.dispose();
          expect(setup.disposed, isTrue);
          expect(setup.playing, isFalse);
          expect(players.last.disposed, isTrue);
          expect(async.pendingTimers, isEmpty);
        });
      },
    );

    test('a set that starts silent plays the last cue once the saved switch '
        'says on', () {
      fakeAsync((async) {
        settings = SoundSettings(
          store: MemorySoundSettingsStore(),
          enabled: false,
        );
        final music = newMusic()..play(MusicCue.menu);
        async.elapse(fade);
        expect(players.made, isEmpty, reason: 'not before the switch is read');
        unawaited(settings.load());
        async.elapse(fade);
        expect(players.last.playing, isTrue);
        music.dispose();
      });
    });

    test('a set that starts silent stays silent when the saved switch says '
        'off', () {
      fakeAsync((async) {
        settings = SoundSettings(
          store: MemorySoundSettingsStore(enabled: false),
          enabled: false,
        );
        final music = newMusic()..play(MusicCue.menu);
        unawaited(settings.load());
        async.elapse(fade);
        expect(players.made, isEmpty);
        music.dispose();
      });
    });

    test('dispose cuts the music, ignores later cues, and is safe twice', () {
      fakeAsync((async) {
        final music = newMusic()..play(MusicCue.menu);
        async.elapse(fade);
        final p = players.last;
        music.dispose();
        expect(p.disposed, isTrue);
        music
          ..play(MusicCue.battle)
          ..dispose();
        unawaited(settings.setEnabled(false));
        async.elapse(fade);
        expect(players.made, hasLength(1));
        expect(async.pendingTimers, isEmpty);
      });
    });
  });
}
