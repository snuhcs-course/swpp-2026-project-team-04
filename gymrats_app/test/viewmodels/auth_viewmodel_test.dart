import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/services/auth/in_memory_auth_repository.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';

import '../support/auth_fakes.dart';
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

  group('body info step (P7)', () {
    late ScriptedAuthRepository repository;
    late AuthViewModel vm;
    var notified = 0;

    setUp(() async {
      repository = ScriptedAuthRepository();
      vm = AuthViewModel(repository: repository)..addListener(() => notified++);
      await vm.restore();
      notified = 0;
    });

    test('a new id-and-password account needs it; a login does not', () async {
      await vm.signUp(nickname: '우현', loginId: 'woohyun', password: 'pw123456');
      expect(vm.needsBodyInfo, isTrue);
      await vm.logOut();
      expect(vm.needsBodyInfo, isFalse);
      await vm.logIn(loginId: 'woohyun', password: 'pw123456');
      expect(vm.needsBodyInfo, isFalse);
    });

    test('a social sign-in needs it only for a new account', () async {
      expect(
        await vm.signInWith(SocialProvider.google, 't', nickname: '우현'),
        isTrue,
      );
      expect(repository.socialSignIns.single, (
        SocialProvider.google,
        't',
        '우현',
      ));
      expect(vm.status, AuthStatus.signedIn);
      expect(vm.account!.nickname, '우현');
      expect(vm.needsBodyInfo, isTrue);
      await vm.logOut();
      expect(await vm.signInWith(SocialProvider.google, 't'), isFalse);
      expect(vm.needsBodyInfo, isFalse);
    });

    test(
      'a new provider account without a nickname stays logged out',
      () async {
        await expectLater(
          vm.signInWith(SocialProvider.google, 't'),
          throwsA(isA<SocialSignUpRequiredException>()),
        );
        expect(vm.status, AuthStatus.signedOut);
        expect(vm.needsBodyInfo, isFalse);
      },
    );

    test('a refused social sign-in stays logged out', () async {
      repository.socialError = const SocialTokenRejectedException();
      await expectLater(
        vm.signInWith(SocialProvider.google, 't', nickname: '우현'),
        throwsA(isA<SocialTokenRejectedException>()),
      );
      expect(vm.status, AuthStatus.signedOut);
      expect(vm.needsBodyInfo, isFalse);
    });

    test('saving ends the step; a failed save keeps it', () async {
      await vm.signInWith(SocialProvider.google, 't', nickname: '우현');
      repository.bodyInfoError = const ApiException(ApiErrorKind.network);
      await expectLater(
        vm.saveBodyInfo(heightCm: 175, weightKg: 70),
        throwsA(isA<ApiException>()),
      );
      expect(vm.needsBodyInfo, isTrue);
      repository.bodyInfoError = null;
      notified = 0;
      await vm.saveBodyInfo(heightCm: 175, weightKg: 70);
      expect(repository.bodyInfos.last, (175.0, 70.0));
      expect(vm.needsBodyInfo, isFalse);
      expect(notified, 1);
    });

    test('skipping ends the step once', () async {
      await vm.signInWith(SocialProvider.google, 't', nickname: '우현');
      notified = 0;
      vm.finishBodyInfo();
      vm.finishBodyInfo();
      expect(vm.needsBodyInfo, isFalse);
      expect(notified, 1);
    });

    test('an expired session ends the step', () async {
      final memory = InMemoryAuthRepository();
      final auth = AuthViewModel(repository: memory);
      await auth.restore();
      await auth.signInWith(SocialProvider.google, 'sub', nickname: '우현');
      await memory.expireSession();
      await Future<void>.delayed(Duration.zero);
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.needsBodyInfo, isFalse);
    });

    test('finishing after dispose does nothing', () async {
      await vm.signInWith(SocialProvider.google, 't', nickname: '우현');
      vm.dispose();
      vm.finishBodyInfo();
      expect(vm.needsBodyInfo, isFalse);
    });
  });
}
