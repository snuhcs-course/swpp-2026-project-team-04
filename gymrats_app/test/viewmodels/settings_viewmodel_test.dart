import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/viewmodels/settings_viewmodel.dart';

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
}
