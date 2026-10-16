import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/services/auth/in_memory_auth_repository.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';

import '../support/fakes.dart';

void main() {
  test('starts restoring', () {
    final vm = AuthViewModel(repository: InMemoryAuthRepository());
    expect(vm.status, AuthStatus.restoring);
  });

  test('restore with a saved session is signed in', () async {
    final vm = AuthViewModel(repository: signedInAuth());
    await vm.restore();
    expect(vm.status, AuthStatus.signedIn);
    expect(vm.account!.nickname, '우현');
  });

  test('restore without a session is signed out', () async {
    final vm = AuthViewModel(repository: InMemoryAuthRepository());
    await vm.restore();
    expect(vm.status, AuthStatus.signedOut);
    expect(vm.account, isNull);
    expect(vm.sessionExpired, isFalse);
  });

  test('log in, log out', () async {
    final repository = InMemoryAuthRepository()
      ..addAccount(loginId: 'woohyun', nickname: '우현', password: 'password1');
    final vm = AuthViewModel(repository: repository);
    await vm.restore();
    await vm.logIn(loginId: 'woohyun', password: 'password1');
    expect(vm.status, AuthStatus.signedIn);
    await vm.logOut();
    expect(vm.status, AuthStatus.signedOut);
    expect(vm.sessionExpired, isFalse);
    expect(await repository.restoreSession(), isNull);
  });

  test('a failed login stays signed out and rethrows', () async {
    final vm = AuthViewModel(repository: InMemoryAuthRepository());
    await vm.restore();
    await expectLater(
      vm.logIn(loginId: 'woohyun', password: 'password1'),
      throwsA(isA<InvalidCredentialsException>()),
    );
    expect(vm.status, AuthStatus.signedOut);
  });

  test('sign-up logs in', () async {
    final vm = AuthViewModel(repository: InMemoryAuthRepository());
    await vm.restore();
    await vm.signUp(nickname: '우현', loginId: 'woohyun', password: 'password1');
    expect(vm.status, AuthStatus.signedIn);
    expect(vm.account!.loginId, 'woohyun');
  });

  test(
    'an expired session signs out and says so until the next login',
    () async {
      final repository = signedInAuth()
        ..addAccount(loginId: 'woohyun', nickname: '우현', password: 'password1');
      final vm = AuthViewModel(repository: repository);
      await vm.restore();
      await repository.expireSession();
      await pumpEventQueue();
      expect(vm.status, AuthStatus.signedOut);
      expect(vm.sessionExpired, isTrue);
      await vm.logIn(loginId: 'woohyun', password: 'password1');
      expect(vm.sessionExpired, isFalse);
    },
  );
}
