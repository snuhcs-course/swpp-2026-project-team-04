import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/services/audio/sound_effects.dart';
import 'package:gymrats_app/services/audio/sound_settings.dart';

import '../../support/audio_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMusicPlayers players;
  late SoundSettings settings;

  SoundEffectsService newEffects() =>
      SoundEffectsService(newPlayer: players.call, settings: settings);

  // prepare makes one player per effect, in order, then the alarm's.
  FakeMusicPlayer playerOf(String asset) => asset == dangerAlarmAsset
      ? players.made.last
      : players.made[SoundEffect.values.indexWhere((e) => e.asset == asset)];

  setUp(() {
    players = FakeMusicPlayers();
    settings = SoundSettings(store: MemorySoundSettingsStore());
  });

  group('SoundEffect', () {
    test('every effect has a bundled file', () {
      for (final effect in SoundEffect.values) {
        expect(effect.asset, startsWith('assets/audio/sfx_'));
      }
      expect(dangerAlarmAsset, 'assets/audio/sfx_danger.wav');
    });

    test('a rep sounds by its grade; one that earned nothing is a miss', () {
      expect(SoundEffect.forRep(GameGrade.excellent), SoundEffect.excellent);
      expect(SoundEffect.forRep(GameGrade.good), SoundEffect.good);
      expect(SoundEffect.forRep(GameGrade.average), SoundEffect.average);
      expect(SoundEffect.forRep(null), SoundEffect.reject);
    });
  });

  test('prepare loads every effect once, ahead of the first hit', () {
    fakeAsync((async) {
      final effects = newEffects()
        ..prepare()
        ..prepare();
      async.flushMicrotasks();
      expect(players.made, hasLength(SoundEffect.values.length + 1));
      for (final effect in SoundEffect.values) {
        expect(playerOf(effect.asset).loop, isFalse);
      }
      expect(playerOf(dangerAlarmAsset).loop, isTrue);
      effects.dispose();
    });
  });

  test('a hit rewinds its loaded player and plays it, every time', () {
    fakeAsync((async) {
      final effects = newEffects()..prepare();
      async.flushMicrotasks();
      final good = playerOf(SoundEffect.good.asset);
      effects
        ..play(SoundEffect.good)
        ..play(SoundEffect.good);
      async.flushMicrotasks();
      expect(good.rewinds, 2);
      expect(good.playing, isTrue);
      expect(players.made, hasLength(SoundEffect.values.length + 1));
      effects.dispose();
    });
  });

  test('an effect asked for before prepare, or still loading, is skipped', () {
    fakeAsync((async) {
      final gate = Completer<void>();
      final effects = SoundEffectsService(
        newPlayer: () => players()..loadGate = gate,
        settings: settings,
      )..play(SoundEffect.ko);
      expect(players.made, isEmpty);
      effects
        ..prepare()
        ..play(SoundEffect.ko);
      async.flushMicrotasks();
      expect(playerOf(SoundEffect.ko.asset).playing, isFalse);
      gate.complete();
      async.flushMicrotasks();
      effects.play(SoundEffect.ko);
      async.flushMicrotasks();
      expect(playerOf(SoundEffect.ko.asset).playing, isTrue);
      effects.dispose();
    });
  });

  test('the danger alarm loops while in danger and pauses after', () {
    fakeAsync((async) {
      final effects = newEffects()..prepare();
      async.flushMicrotasks();
      final alarm = playerOf(dangerAlarmAsset);
      effects.setDanger(true);
      async.flushMicrotasks();
      expect(alarm.playing, isTrue);
      expect(effects.danger, isTrue);
      effects.setDanger(true);
      async.flushMicrotasks();
      expect(alarm.rewinds, 1, reason: 'no restart while still in danger');
      effects.setDanger(false);
      async.flushMicrotasks();
      expect(alarm.playing, isFalse);
      effects.dispose();
    });
  });

  test('danger that starts while the alarm loads sounds once it is ready', () {
    fakeAsync((async) {
      final gate = Completer<void>();
      final effects = SoundEffectsService(
        newPlayer: () => players()..loadGate = gate,
        settings: settings,
      )..prepare();
      effects.setDanger(true);
      async.flushMicrotasks();
      expect(playerOf(dangerAlarmAsset).playing, isFalse);
      gate.complete();
      async.flushMicrotasks();
      expect(playerOf(dangerAlarmAsset).playing, isTrue);
      effects.dispose();
    });
  });

  test('sound off silences the hits and pauses the alarm; on brings the '
      'alarm back while still in danger', () {
    fakeAsync((async) {
      final effects = newEffects()..prepare();
      async.flushMicrotasks();
      final alarm = playerOf(dangerAlarmAsset);
      effects.setDanger(true);
      async.flushMicrotasks();
      unawaited(settings.setEnabled(false));
      async.flushMicrotasks();
      expect(alarm.playing, isFalse);
      effects.play(SoundEffect.good);
      async.flushMicrotasks();
      expect(playerOf(SoundEffect.good.asset).playing, isFalse);
      unawaited(settings.setEnabled(true));
      async.flushMicrotasks();
      expect(alarm.playing, isTrue);
      effects
        ..setDanger(false)
        ..dispose();
    });
  });

  test('danger asked for while sound is off starts when sound is back', () {
    fakeAsync((async) {
      unawaited(settings.setEnabled(false));
      final effects = newEffects()..prepare();
      async.flushMicrotasks();
      effects.setDanger(true);
      async.flushMicrotasks();
      final alarm = playerOf(dangerAlarmAsset);
      expect(alarm.playing, isFalse);
      unawaited(settings.setEnabled(true));
      async.flushMicrotasks();
      expect(alarm.playing, isTrue);
      effects.dispose();
    });
  });

  test('the background pauses the alarm and the foreground resumes it', () {
    fakeAsync((async) {
      final effects = newEffects()..prepare();
      async.flushMicrotasks();
      final alarm = playerOf(dangerAlarmAsset);
      effects.setDanger(true);
      effects.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.flushMicrotasks();
      expect(alarm.playing, isFalse);
      effects.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.flushMicrotasks();
      expect(alarm.playing, isTrue);
      effects.dispose();
    });
  });

  test('an effect that fails to load stays silent and the rest play', () {
    fakeAsync((async) {
      players.failNext = true; // The first effect: good.
      final effects = newEffects()..prepare();
      async.flushMicrotasks();
      effects
        ..play(SoundEffect.good)
        ..play(SoundEffect.excellent);
      async.flushMicrotasks();
      expect(players.made.first.playing, isFalse);
      expect(playerOf(SoundEffect.excellent.asset).playing, isTrue);
      effects.dispose();
    });
  });

  test('dispose stops and frees every player and ignores later calls', () {
    fakeAsync((async) {
      final effects = newEffects()..prepare();
      async.flushMicrotasks();
      effects
        ..setDanger(true)
        ..dispose()
        ..dispose()
        ..play(SoundEffect.good)
        ..setDanger(false)
        ..prepare();
      async.flushMicrotasks();
      expect(players.made, hasLength(SoundEffect.values.length + 1));
      expect(players.made.every((p) => p.disposed && p.stopped), isTrue);
      unawaited(settings.setEnabled(false));
      async.flushMicrotasks();
    });
  });

  test('release frees the players and stops the alarm; the next prepare '
      'loads them again', () {
    fakeAsync((async) {
      final effects = newEffects()..prepare();
      async.flushMicrotasks();
      effects
        ..setDanger(true)
        ..release();
      async.flushMicrotasks();
      final first = [...players.made];
      expect(first.every((p) => p.stopped && p.disposed), isTrue);
      expect(effects.danger, isFalse);
      effects.play(SoundEffect.good);
      effects.prepare();
      async.flushMicrotasks();
      expect(players.made, hasLength(first.length * 2));
      effects.play(SoundEffect.good);
      async.flushMicrotasks();
      final reloadedGood = players.made[first.length + SoundEffect.good.index];
      expect(reloadedGood.asset, SoundEffect.good.asset);
      expect(reloadedGood.playing, isTrue);
      effects.dispose();
    });
  });

  test('a player released while it loads is never used', () {
    fakeAsync((async) {
      final gate = Completer<void>();
      final effects = SoundEffectsService(
        newPlayer: () => players()..loadGate = gate,
        settings: settings,
      )..prepare();
      final released = [...players.made];
      effects
        ..release()
        ..setDanger(true);
      gate.complete();
      async.flushMicrotasks();
      expect(released.any((p) => p.playing), isFalse);
      effects.dispose();
    });
  });

  test('a player that loads after dispose is never used', () {
    fakeAsync((async) {
      final gate = Completer<void>();
      final effects = SoundEffectsService(
        newPlayer: () => players()..loadGate = gate,
        settings: settings,
      )..prepare();
      effects.dispose();
      gate.complete();
      async.flushMicrotasks();
      effects.play(SoundEffect.good);
      async.flushMicrotasks();
      expect(players.made.any((p) => p.playing), isFalse);
    });
  });
}
