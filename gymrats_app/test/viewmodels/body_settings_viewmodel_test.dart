import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/body_settings_viewmodel.dart';
import 'package:gymrats_app/viewmodels/login_viewmodel.dart';

import '../support/auth_fakes.dart';
import '../support/fakes.dart';

void main() {
  late FakeUserRepository profiles;
  late ScriptedAuthRepository authRepository;
  late AuthViewModel auth;
  late BodySettingsViewModel vm;

  setUp(() {
    profiles = FakeUserRepository()
      ..profile = const UserProfile(name: '우현', heightCm: 175, weightKg: 72.5);
    authRepository = ScriptedAuthRepository();
    auth = AuthViewModel(repository: authRepository);
    vm = BodySettingsViewModel(profiles: profiles, auth: auth);
  });

  tearDown(() {
    vm.dispose();
    auth.dispose();
  });

  test('loads the saved height and weight from the profile', () async {
    expect(vm.state.loading, isTrue);
    await vm.load();
    expect(vm.state.loading, isFalse);
    expect(vm.state.heightCm, 175);
    expect(vm.state.weightKg, 72.5);
    expect(vm.state.hasValues, isTrue);
  });

  test('a user who gave none starts empty', () async {
    profiles.profile = const UserProfile(name: '우현');
    await vm.load();
    expect(vm.state.hasValues, isFalse);
    expect(vm.state.loadFailed, isFalse);
  });

  test('a profile that cannot be read says so, saves nothing, and 다시 시도 '
      'reads it again', () async {
    profiles.error = Exception('offline');
    await vm.load();
    expect(vm.state.loading, isFalse);
    expect(vm.state.loadFailed, isTrue);
    expect(await vm.save(height: '176', weight: '70', consent: true), isFalse);
    expect(authRepository.bodyInfos, isEmpty);
    profiles.error = null;
    final reading = vm.load();
    expect(vm.state.loading, isTrue);
    expect(vm.state.loadFailed, isFalse);
    await reading;
    expect(vm.state.heightCm, 175);
  });

  test('the fields show whole numbers without a point', () {
    expect(BodySettingsViewModel.textOf(175), '175');
    expect(BodySettingsViewModel.textOf(72.5), '72.5');
    expect(BodySettingsViewModel.textOf(null), '');
  });

  test('saves new values in range with consent, through the sign-up '
      'call', () async {
    await vm.load();
    expect(await vm.save(height: '176.5', weight: '70', consent: true), isTrue);
    expect(authRepository.bodyInfos, [(176.5, 70.0)]);
    expect(vm.state.saved, isTrue);
    expect(vm.state.heightCm, 176.5);
    expect(vm.state.weightKg, 70);
  });

  test('out of range or without consent: the errors, nothing sent', () async {
    await vm.load();
    expect(await vm.save(height: '99', weight: '19', consent: false), isFalse);
    expect(vm.state.heightError, isNotNull);
    expect(vm.state.weightError, isNotNull);
    expect(vm.state.consentError, isNotNull);
    expect(authRepository.bodyInfos, isEmpty);
    vm.edited();
    expect(vm.state.heightError, isNull);
    expect(vm.state.consentError, isNull);
    // The saved values stay.
    expect(vm.state.heightCm, 175);
  });

  test('a server error or no network shows above the button', () async {
    await vm.load();
    authRepository.bodyInfoError = const ApiException(ApiErrorKind.network);
    expect(await vm.save(height: '176', weight: '70', consent: true), isFalse);
    expect(
      vm.state.formError,
      const ApiException(ApiErrorKind.network).message,
    );
    authRepository.bodyInfoError = Exception('boom');
    expect(await vm.save(height: '176', weight: '70', consent: true), isFalse);
    expect(vm.state.formError, genericErrorMessage);
    expect(vm.state.heightCm, 175);
  });

  test('a second save while one runs, or a save while loading, does '
      'nothing', () async {
    expect(await vm.save(height: '176', weight: '70', consent: true), isFalse);
    await vm.load();
    final gate = authRepository.holdBodyInfo();
    final first = vm.save(height: '176', weight: '70', consent: true);
    expect(vm.state.saving, isTrue);
    expect(await vm.save(height: '177', weight: '71', consent: true), isFalse);
    gate.complete();
    expect(await first, isTrue);
    expect(authRepository.bodyInfos, [(176.0, 70.0)]);
  });

  test('nothing changes after dispose', () async {
    final late = BodySettingsViewModel(profiles: profiles, auth: auth);
    late.dispose();
    await late.load();
    expect(late.state.loading, isTrue);
  });
}
