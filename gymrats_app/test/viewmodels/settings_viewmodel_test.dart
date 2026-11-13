import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/user/settings_store.dart';
import 'package:gymrats_app/viewmodels/settings_viewmodel.dart';

/// A store whose read waits for [gate], and that can fail.
class _ScriptedStore extends MemorySettingsStore {
  Completer<void>? gate;
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<SavedSettings> read() async {
    await gate?.future;
    if (failRead) throw Exception('storage');
    return super.read();
  }

  @override
  Future<void> writeSoundEffects(bool on) async {
    if (failWrite) throw Exception('storage');
    await super.writeSoundEffects(on);
  }
}

void main() {
  test('sound effects on and voice guidance off, as designed', () {
    final vm = SettingsViewModel();
    expect(vm.state.soundEffectsOn, isTrue);
    expect(vm.state.voiceGuidanceOn, isFalse);
  });

  test('starts from the switch values it is given', () {
    final vm = SettingsViewModel(soundEffectsOn: false, voiceGuidanceOn: true);
    expect(vm.state.soundEffectsOn, isFalse);
    expect(vm.state.voiceGuidanceOn, isTrue);
  });

  test('each switch changes alone and tells the listeners', () {
    final vm = SettingsViewModel();
    var notified = 0;
    vm.addListener(() => notified++);

    vm.setSoundEffects(false);
    expect(vm.state.soundEffectsOn, isFalse);
    expect(vm.state.voiceGuidanceOn, isFalse);

    vm.setVoiceGuidance(true);
    expect(vm.state.soundEffectsOn, isFalse);
    expect(vm.state.voiceGuidanceOn, isTrue);
    expect(notified, 2);
  });

  test('a switch after dispose is dropped', () {
    final vm = SettingsViewModel()..dispose();
    // Notifying a disposed view model would throw here.
    vm.setSoundEffects(false);
    expect(vm.state.soundEffectsOn, isTrue);
  });

  group('kept across restarts', () {
    test('each switch turned is saved', () async {
      final store = MemorySettingsStore();
      SettingsViewModel(store: store)
        ..setSoundEffects(false)
        ..setVoiceGuidance(true);
      await pumpEventQueue();
      expect(store.soundEffectsOn, isFalse);
      expect(store.voiceGuidanceOn, isTrue);
    });

    test(
      'load shows what a previous run saved, and tells the listeners',
      () async {
        final store = MemorySettingsStore()
          ..soundEffectsOn = false
          ..voiceGuidanceOn = true;
        final vm = SettingsViewModel(store: store);
        var notified = 0;
        vm.addListener(() => notified++);
        await vm.load();
        expect(vm.state.soundEffectsOn, isFalse);
        expect(vm.state.voiceGuidanceOn, isTrue);
        expect(notified, 1);
      },
    );

    test('a switch never saved keeps its default', () async {
      final vm = SettingsViewModel(
        store: MemorySettingsStore()..voiceGuidanceOn = true,
      );
      await vm.load();
      expect(vm.state.soundEffectsOn, isTrue);
      expect(vm.state.voiceGuidanceOn, isTrue);
    });

    test('a switch turned while loading keeps the user\'s value', () async {
      final store = _ScriptedStore()
        ..soundEffectsOn = true
        ..voiceGuidanceOn = true
        ..gate = Completer();
      final vm = SettingsViewModel(store: store);
      final loading = vm.load();
      vm.setSoundEffects(false);
      store.gate!.complete();
      await loading;
      expect(vm.state.soundEffectsOn, isFalse);
      // The other switch still comes from the store.
      expect(vm.state.voiceGuidanceOn, isTrue);
    });

    test('a failed read keeps the defaults', () async {
      final vm = SettingsViewModel(store: _ScriptedStore()..failRead = true);
      await expectLater(vm.load(), completes);
      expect(vm.state.soundEffectsOn, isTrue);
      expect(vm.state.voiceGuidanceOn, isFalse);
    });

    test(
      'a failed save keeps the switch for this run, with no error',
      () async {
        final vm = SettingsViewModel(store: _ScriptedStore()..failWrite = true);
        vm.setSoundEffects(false);
        await pumpEventQueue();
        expect(vm.state.soundEffectsOn, isFalse);
      },
    );

    test('values read after dispose are dropped', () async {
      final store = _ScriptedStore()
        ..soundEffectsOn = false
        ..gate = Completer();
      final vm = SettingsViewModel(store: store);
      final loading = vm.load();
      vm.dispose();
      store.gate!.complete();
      // Notifying a disposed view model would throw here.
      await expectLater(loading, completes);
      expect(vm.state.soundEffectsOn, isTrue);
    });
  });

  group("the safety notice ('매 경기 안전 안내')", () {
    test('on and not seen at first: the notice shows', () {
      final notice = SettingsViewModel().safetyNotice;
      expect(notice.everyMatch, isTrue);
      expect(notice.seen, isFalse);
      expect(notice.showsBeforeMatch, isTrue);
    });

    test('on, it shows before every match; off, only until it was seen', () {
      for (final (everyMatch, seen, shows) in const [
        (true, false, true),
        (true, true, true),
        (false, false, true),
        (false, true, false),
      ]) {
        expect(
          SafetyNoticeSetting(
            everyMatch: everyMatch,
            seen: seen,
          ).showsBeforeMatch,
          shows,
          reason: 'every match $everyMatch, seen $seen',
        );
      }
    });

    test('the switch turns, is saved and tells the listeners; the sound '
        'switches stay', () async {
      final store = MemorySettingsStore();
      final vm = SettingsViewModel(store: store);
      var notified = 0;
      vm.addListener(() => notified++);
      vm.setSafetyNoticeEveryMatch(false);
      expect(vm.safetyNotice.everyMatch, isFalse);
      expect(vm.safetyNotice.seen, isFalse);
      expect(notified, 1);
      await pumpEventQueue();
      expect(store.safetyNoticeEveryMatch, isFalse);
      expect(store.safetyNoticeSeen, isNull);
      expect(vm.state.soundEffectsOn, isTrue);
      expect(vm.state.voiceGuidanceOn, isFalse);
      expect((store.soundEffectsOn, store.voiceGuidanceOn), (null, null));
    });

    test(
      'seen once is saved once; with the switch off it no longer shows',
      () async {
        final store = MemorySettingsStore();
        final vm = SettingsViewModel(store: store)
          ..setSafetyNoticeEveryMatch(false);
        var notified = 0;
        vm.addListener(() => notified++);
        vm.markSafetyNoticeSeen();
        expect(vm.safetyNotice.seen, isTrue);
        expect(vm.safetyNotice.showsBeforeMatch, isFalse);
        vm.markSafetyNoticeSeen();
        expect(notified, 1);
        await pumpEventQueue();
        expect(store.safetyNoticeSeen, isTrue);
        // Turned on again, it shows before every match, seen or not.
        vm.setSafetyNoticeEveryMatch(true);
        expect(vm.safetyNotice.showsBeforeMatch, isTrue);
        expect(vm.safetyNotice.seen, isTrue);
      },
    );

    test('kept across a restart: a new view model on the same store loads '
        'the switch and the seen mark', () async {
      final store = MemorySettingsStore();
      SettingsViewModel(store: store)
        ..setSafetyNoticeEveryMatch(false)
        ..markSafetyNoticeSeen();
      await pumpEventQueue();

      final restarted = SettingsViewModel(store: store);
      expect(restarted.safetyNotice.showsBeforeMatch, isTrue);
      var notified = 0;
      restarted.addListener(() => notified++);
      await restarted.load();
      expect(restarted.safetyNotice.everyMatch, isFalse);
      expect(restarted.safetyNotice.seen, isTrue);
      expect(restarted.safetyNotice.showsBeforeMatch, isFalse);
      // One notice for the sound switches and the safety notice together.
      expect(notified, 1);
    });

    test('never saved, load keeps the defaults', () async {
      final vm = SettingsViewModel(
        store: MemorySettingsStore()..soundEffectsOn = false,
      );
      await vm.load();
      expect(vm.safetyNotice.everyMatch, isTrue);
      expect(vm.safetyNotice.seen, isFalse);
      expect(vm.state.soundEffectsOn, isFalse);
    });

    test('the switch turned or the notice seen while loading keep the '
        "user's", () async {
      final store = _SafetyGatedStore()
        ..safetyNoticeEveryMatch = true
        ..safetyNoticeSeen = null
        ..gate = Completer();
      final vm = SettingsViewModel(store: store);
      final loading = vm.load();
      vm
        ..setSafetyNoticeEveryMatch(false)
        ..markSafetyNoticeSeen();
      store.gate!.complete();
      await loading;
      expect(vm.safetyNotice.everyMatch, isFalse);
      expect(vm.safetyNotice.seen, isTrue);
    });

    test('a failed read of the safety notice keeps its defaults and still '
        'loads the sound switches', () async {
      final vm = SettingsViewModel(
        store: _SafetyGatedStore()
          ..failSafetyRead = true
          ..safetyNoticeEveryMatch = false
          ..voiceGuidanceOn = true,
      );
      await expectLater(vm.load(), completes);
      expect(vm.safetyNotice.everyMatch, isTrue);
      expect(vm.state.voiceGuidanceOn, isTrue);
    });

    test('a failed read of the sound switches still shows the saved safety '
        'notice, and tells the listeners', () async {
      final vm = SettingsViewModel(
        store: _ScriptedStore()
          ..failRead = true
          ..safetyNoticeEveryMatch = false
          ..safetyNoticeSeen = true,
      );
      var notified = 0;
      vm.addListener(() => notified++);
      await vm.load();
      expect(vm.safetyNotice.showsBeforeMatch, isFalse);
      expect(vm.state.soundEffectsOn, isTrue);
      expect(notified, 1);
    });

    test(
      'a failed save keeps the switch for this run, with no error',
      () async {
        final vm = SettingsViewModel(
          store: _SafetyGatedStore()..failSafetyWrite = true,
        );
        vm
          ..setSafetyNoticeEveryMatch(false)
          ..markSafetyNoticeSeen();
        await pumpEventQueue();
        expect(vm.safetyNotice.everyMatch, isFalse);
        expect(vm.safetyNotice.seen, isTrue);
      },
    );

    test('after dispose the switch, the seen mark and a late read are '
        'dropped', () async {
      final store = _SafetyGatedStore()
        ..safetyNoticeEveryMatch = false
        ..gate = Completer();
      final vm = SettingsViewModel(store: store);
      final loading = vm.load();
      vm.dispose();
      store.gate!.complete();
      // Notifying a disposed view model would throw here.
      await expectLater(loading, completes);
      vm
        ..setSafetyNoticeEveryMatch(false)
        ..markSafetyNoticeSeen();
      expect(vm.safetyNotice.everyMatch, isTrue);
      expect(vm.safetyNotice.seen, isFalse);
      await pumpEventQueue();
      expect(store.safetyNoticeSeen, isNull);
    });
  });
}

/// A store whose safety-notice read waits for [gate], and whose safety
/// reads and writes can fail. The read takes the values when it starts, as
/// a real read in flight does: writes made while it waits are not in it.
class _SafetyGatedStore extends MemorySettingsStore {
  Completer<void>? gate;
  bool failSafetyRead = false;
  bool failSafetyWrite = false;

  @override
  Future<SavedSafetyNotice> readSafetyNotice() async {
    final saved = await super.readSafetyNotice();
    await gate?.future;
    if (failSafetyRead) throw Exception('storage');
    return saved;
  }

  @override
  Future<void> writeSafetyNoticeEveryMatch(bool on) async {
    if (failSafetyWrite) throw Exception('storage');
    await super.writeSafetyNoticeEveryMatch(on);
  }

  @override
  Future<void> writeSafetyNoticeSeen() async {
    if (failSafetyWrite) throw Exception('storage');
    await super.writeSafetyNoticeSeen();
  }
}
