import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/signup_viewmodel.dart';

import '../support/auth_fakes.dart';

void main() {
  late ScriptedAuthRepository repository;
  late AuthViewModel auth;
  late SignupViewModel vm;

  setUp(() async {
    repository = ScriptedAuthRepository();
    auth = AuthViewModel(repository: repository);
    await auth.restore();
    vm = SignupViewModel(auth: auth);
  });

  Future<bool> submit({
    String nickname = '우현',
    String loginId = 'woohyun',
    String password = 'password1',
    String? confirm,
  }) => vm.submit(
    nickname: nickname,
    loginId: loginId,
    password: password,
    confirm: confirm ?? password,
  );

  group('rules', () {
    test('nickname', () {
      expect(SignupRules.nickname(''), isNotNull);
      expect(SignupRules.nickname('   '), isNotNull);
      expect(SignupRules.nickname('우' * 12), isNull);
      expect(SignupRules.nickname('우' * 13), isNotNull);
      expect(SignupRules.nickname(' 우현 '), isNull);
    });

    test('login id', () {
      expect(SignupRules.loginId(''), '아이디를 입력해 주세요.');
      for (final bad in [
        'abc',
        'Woohyun',
        'woo hyun',
        'woo-hyun',
        '우현우현',
        'a' * 21,
      ]) {
        expect(SignupRules.loginId(bad), isNotNull, reason: bad);
      }
      for (final good in ['abcd', 'woo_hyun9', 'a' * 20]) {
        expect(SignupRules.loginId(good), isNull, reason: good);
      }
    });

    test('password', () {
      expect(SignupRules.password(''), isNotNull);
      expect(SignupRules.password('1234567'), '비밀번호는 8자 이상이어야 해요.');
      expect(SignupRules.password('12345678'), isNull);
      expect(SignupRules.password('a' * 64), isNull);
      expect(SignupRules.password('a' * 65), isNotNull);
      expect(SignupRules.password('가' * 30), isNull);
      // Emoji are one character each, as on the server.
      expect(SignupRules.password('😀' * 4), isNotNull);
      expect(SignupRules.password('😀' * 8), isNull);
      expect(SignupRules.password('😀' * 64), isNull);
      expect(SignupRules.password('😀' * 65), isNotNull);
    });

    test('confirmation', () {
      expect(SignupRules.confirm('password1', ''), isNotNull);
      expect(SignupRules.confirm('password1', 'password2'), '비밀번호가 일치하지 않아요.');
      expect(SignupRules.confirm('password1', 'password1'), isNull);
    });
  });

  test('every invalid field shows its error and nothing is sent', () async {
    expect(
      await submit(nickname: '', loginId: 'A', password: 'short', confirm: 'x'),
      isFalse,
    );
    expect(vm.state.nicknameError, isNotNull);
    expect(vm.state.loginIdError, isNotNull);
    expect(vm.state.passwordError, isNotNull);
    expect(vm.state.confirmError, isNotNull);
    expect(repository.signUps, isEmpty);
  });

  test('valid fields create the account and log in', () async {
    expect(await submit(nickname: ' 우현 '), isTrue);
    expect(repository.signUps.single, ('우현', 'woohyun', 'password1'));
    expect(auth.status, AuthStatus.signedIn);
  });

  test('a taken login id shows under the id field', () async {
    repository.signUpError = const LoginIdTakenException();
    expect(await submit(), isFalse);
    expect(vm.state.loginIdError, '이미 사용 중인 아이디예요.');
    expect(vm.state.formError, isNull);
    expect(auth.status, AuthStatus.signedOut);
  });

  test('server problems show above the button and clear on typing', () async {
    repository.signUpError = const ApiException(ApiErrorKind.timeout);
    await submit();
    expect(
      vm.state.formError,
      const ApiException(ApiErrorKind.timeout).message,
    );
    vm.edited();
    expect(vm.state.formError, isNull);
  });

  test('ignores a second submit while one runs', () async {
    final gate = repository.holdSignUp();
    final first = submit();
    expect(vm.state.submitting, isTrue);
    expect(await submit(), isFalse);
    gate.complete();
    expect(await first, isTrue);
    expect(repository.signUps, hasLength(1));
  });
}
