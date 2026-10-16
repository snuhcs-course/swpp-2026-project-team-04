import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/services/auth/in_memory_auth_repository.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/login_viewmodel.dart';

import '../support/auth_fakes.dart';

void main() {
  late ScriptedAuthRepository repository;
  late AuthViewModel auth;
  late LoginViewModel vm;

  setUp(() async {
    repository = ScriptedAuthRepository();
    auth = AuthViewModel(repository: repository);
    await auth.restore();
    vm = LoginViewModel(auth: auth);
  });

  test('empty fields are required and nothing is sent', () async {
    expect(await vm.submit(loginId: '  ', password: ''), isFalse);
    expect(vm.state.loginIdError, '아이디를 입력해 주세요.');
    expect(vm.state.passwordError, '비밀번호를 입력해 주세요.');
    expect(repository.logIns, isEmpty);
  });

  test('a correct login signs in; the id is trimmed', () async {
    expect(
      await vm.submit(loginId: ' woohyun ', password: 'password1'),
      isTrue,
    );
    expect(repository.logIns.single, ('woohyun', 'password1'));
    expect(auth.status, AuthStatus.signedIn);
    expect(vm.state.formError, isNull);
    expect(vm.state.submitting, isFalse);
  });

  test('wrong credentials show one generic message', () async {
    repository.logInError = const InvalidCredentialsException();
    expect(await vm.submit(loginId: 'woohyun', password: 'nope1234'), isFalse);
    expect(vm.state.formError, LoginViewModel.wrongCredentialsMessage);
    expect(vm.state.loginIdError, isNull);
    expect(vm.state.passwordError, isNull);
    expect(auth.status, AuthStatus.signedOut);
  });

  test('network problems show their message', () async {
    repository.logInError = const ApiException(ApiErrorKind.network);
    await vm.submit(loginId: 'woohyun', password: 'password1');
    expect(
      vm.state.formError,
      const ApiException(ApiErrorKind.network).message,
    );
  });

  test('other failures show the generic error', () async {
    repository.logInError = Exception('boom');
    await vm.submit(loginId: 'woohyun', password: 'password1');
    expect(vm.state.formError, genericErrorMessage);
  });

  test(
    'is submitting while the request runs and ignores a second submit',
    () async {
      final gate = repository.holdLogIn();
      final first = vm.submit(loginId: 'woohyun', password: 'password1');
      expect(vm.state.submitting, isTrue);
      expect(
        await vm.submit(loginId: 'woohyun', password: 'password1'),
        isFalse,
      );
      gate.complete();
      expect(await first, isTrue);
      expect(repository.logIns, hasLength(1));
    },
  );

  test('typing clears the errors', () async {
    await vm.submit(loginId: '', password: '');
    vm.edited();
    expect(vm.state.loginIdError, isNull);
    expect(vm.state.passwordError, isNull);
  });

  test('says when the session expired', () async {
    final memory = InMemoryAuthRepository();
    final expiredAuth = AuthViewModel(repository: memory);
    await memory.signUp(
      nickname: '우현',
      loginId: 'woohyun',
      password: 'password1',
    );
    await expiredAuth.restore();
    await memory.expireSession();
    await pumpEventQueue();
    final login = LoginViewModel(auth: expiredAuth);
    expect(login.state.formError, LoginViewModel.expiredMessage);
  });
}
