import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/body_info_viewmodel.dart';
import 'package:gymrats_app/viewmodels/login_viewmodel.dart';

import '../support/auth_fakes.dart';

void main() {
  late ScriptedAuthRepository repository;
  late AuthViewModel auth;
  late BodyInfoViewModel vm;

  setUp(() async {
    repository = ScriptedAuthRepository();
    auth = AuthViewModel(repository: repository);
    await auth.restore();
    await auth.signInWith(SocialProvider.google, 't', nickname: '우현');
    vm = BodyInfoViewModel(auth: auth);
  });

  Future<bool> submit({
    String height = '175',
    String weight = '70.5',
    bool consent = true,
  }) => vm.submit(height: height, weight: weight, consent: consent);

  group('BodyInfoRules', () {
    test('parses whole and decimal numbers, also with a comma', () {
      expect(BodyInfoRules.parse(' 175 '), 175);
      expect(BodyInfoRules.parse('72.5'), 72.5);
      expect(BodyInfoRules.parse('72,5'), 72.5);
      expect(BodyInfoRules.parse('abc'), isNull);
      expect(BodyInfoRules.parse('NaN'), isNull);
      expect(BodyInfoRules.parse('Infinity'), isNull);
    });

    test('height and weight have the server ranges', () {
      expect(BodyInfoRules.height(''), '키를 입력해 주세요.');
      expect(BodyInfoRules.height('99.9'), '키는 100~250cm로 입력해 주세요.');
      expect(BodyInfoRules.height('250.1'), isNotNull);
      expect(BodyInfoRules.height('100'), isNull);
      expect(BodyInfoRules.height('250'), isNull);
      expect(BodyInfoRules.weight(' '), '몸무게를 입력해 주세요.');
      expect(BodyInfoRules.weight('19'), '몸무게는 20~300kg으로 입력해 주세요.');
      expect(BodyInfoRules.weight('301'), isNotNull);
      expect(BodyInfoRules.weight('20'), isNull);
      expect(BodyInfoRules.weight('300'), isNull);
    });

    test('consent is required to save', () {
      expect(BodyInfoRules.consent(true), isNull);
      expect(BodyInfoRules.consent(false), contains('동의'));
    });
  });

  test('saves both values with consent and ends the step', () async {
    expect(await submit(), isTrue);
    expect(repository.bodyInfos.single, (175.0, 70.5));
    expect(auth.needsBodyInfo, isFalse);
    expect(vm.state.submitting, isFalse);
  });

  test('without consent nothing is sent', () async {
    expect(await submit(consent: false), isFalse);
    expect(vm.state.consentError, isNotNull);
    expect(vm.state.hasFieldError, isTrue);
    expect(repository.bodyInfos, isEmpty);
    expect(auth.needsBodyInfo, isTrue);
  });

  test('values out of range show under their field', () async {
    expect(await submit(height: '90', weight: 'x'), isFalse);
    expect(vm.state.heightError, isNotNull);
    expect(vm.state.weightError, isNotNull);
    expect(vm.state.consentError, isNull);
    expect(repository.bodyInfos, isEmpty);
  });

  test('skip sends nothing and ends the step', () {
    vm.skip();
    expect(repository.bodyInfos, isEmpty);
    expect(auth.needsBodyInfo, isFalse);
  });

  test('while saving, other taps do nothing', () async {
    final gate = repository.holdBodyInfo();
    final first = submit();
    expect(vm.state.submitting, isTrue);
    expect(await submit(), isFalse);
    vm.skip();
    vm.edited();
    expect(auth.needsBodyInfo, isTrue);
    gate.complete();
    expect(await first, isTrue);
    expect(repository.bodyInfos, hasLength(1));
  });

  test('a failed save shows its message; editing clears only that', () async {
    repository.bodyInfoError = const ApiException(ApiErrorKind.network);
    expect(await submit(), isFalse);
    expect(
      vm.state.formError,
      const ApiException(ApiErrorKind.network).message,
    );
    expect(auth.needsBodyInfo, isTrue);
    vm.edited();
    expect(vm.state.formError, isNull);

    repository.bodyInfoError = Exception('?');
    expect(await submit(), isFalse);
    expect(vm.state.formError, genericErrorMessage);
  });

  test('editing keeps field errors so the user sees what to fix', () async {
    await submit(height: '');
    vm.edited();
    expect(vm.state.heightError, isNotNull);
  });

  test('after dispose a finished save changes nothing', () async {
    final gate = repository.holdBodyInfo();
    final pending = submit();
    vm.dispose();
    gate.complete();
    expect(await pending, isTrue);
  });
}
