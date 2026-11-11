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
}
