import 'dart:async';

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
    // Not a Google failure (P8: shown in the id sheet, not above Google).
    expect(vm.state.failedWith, isNull);
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
    expect(login.state.failedWith, isNull);
    expect(login.state.cancelledWith, isNull);
  });

  group('Google (P7)', () {
    late FakeSocialSignIn google;

    setUp(() {
      google = FakeSocialSignIn(SocialProvider.google, token: 'id-token');
      vm = LoginViewModel(auth: auth, google: google);
      // An existing provider account unless a test says otherwise.
      repository.socialIsNew = false;
    });

    test('keeps the services it was given', () {
      expect(vm.google, same(google));
      expect(vm.takeSignupRequest(), isNull);
    });

    test(
      'a new provider account creates nothing and asks for a nickname',
      () async {
        repository.socialIsNew = true;
        expect(await vm.signInWith(google), isFalse);
        expect(repository.socialSignIns.single, (
          SocialProvider.google,
          'id-token',
          null,
        ));
        expect(auth.status, AuthStatus.signedOut);
        expect(vm.state.busy, isFalse);
        expect(vm.state.formError, isNull);
        expect(vm.takeSignupRequest(), (
          provider: SocialProvider.google,
          token: 'id-token',
        ));
        // Taken once.
        expect(vm.takeSignupRequest(), isNull);
      },
    );

    test('an existing account logs straight in', () async {
      expect(await vm.signInWith(google), isTrue);
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.needsBodyInfo, isFalse);
      expect(vm.takeSignupRequest(), isNull);
    });

    test('shows which provider is running and ignores other taps', () async {
      final gate = google.gate = Completer<void>();
      final first = vm.signInWith(google);
      expect(vm.state.signingInWith, SocialProvider.google);
      expect(vm.state.busy, isTrue);
      expect(await vm.signInWith(google), isFalse);
      expect(await vm.submit(loginId: 'a', password: 'b'), isFalse);
      vm.edited();
      expect(vm.state.signingInWith, SocialProvider.google);
      gate.complete();
      expect(await first, isTrue);
      expect(google.calls, 1);
      expect(repository.logIns, isEmpty);
    });

    test('backing out shows nothing and sends nothing', () async {
      google.error = const SocialSignInCancelledException();
      expect(await vm.signInWith(google), isFalse);
      expect(vm.state.formError, isNull);
      expect(vm.state.busy, isFalse);
      expect(repository.socialSignIns, isEmpty);
      expect(auth.status, AuthStatus.signedOut);
    });

    test(
      'backing out is told apart from nothing (P8), until the next try',
      () async {
        google.error = const SocialSignInCancelledException();
        await vm.signInWith(google);
        expect(vm.state.cancelledWith, SocialProvider.google);
        expect(vm.state.failedWith, isNull);
        google.error = null;
        final gate = google.gate = Completer<void>();
        final again = vm.signInWith(google);
        expect(vm.state.cancelledWith, isNull);
        expect(vm.state.signingInWith, SocialProvider.google);
        gate.complete();
        expect(await again, isTrue);
        expect(vm.state.cancelledWith, isNull);
      },
    );

    test('turning to the id form clears the cancel note (P8)', () async {
      google.error = const SocialSignInCancelledException();
      await vm.signInWith(google);
      var notified = 0;
      vm.addListener(() => notified++);
      vm.edited();
      expect(vm.state.cancelledWith, isNull);
      expect(notified, 1);
      vm.edited();
      expect(notified, 1);
    });

    test('each failure has its message', () async {
      final cases = <(FakeSocialSignIn, Exception?, Exception?, String)>[
        (
          google,
          const SocialSignInFailedException('x'),
          null,
          'Google 로그인에 실패했어요. 다시 시도해 주세요.',
        ),
        (
          google,
          null,
          const SocialTokenRejectedException(),
          'Google 로그인에 실패했어요. 다시 시도해 주세요.',
        ),
        (
          google,
          null,
          const SocialLoginUnavailableException(),
          '지금은 Google 로그인을 쓸 수 없어요. 잠시 후 다시 시도해 주세요.',
        ),
        (
          google,
          null,
          const ApiException(ApiErrorKind.network),
          const ApiException(ApiErrorKind.network).message,
        ),
        (google, null, Exception('?'), genericErrorMessage),
      ];
      for (final (service, deviceError, serverError, message) in cases) {
        service.error = deviceError;
        repository.socialError = serverError;
        expect(await vm.signInWith(service), isFalse);
        expect(vm.state.formError, message);
        // P8: every one of them is a Google failure (F1 above the button).
        expect(vm.state.failedWith, SocialProvider.google);
        expect(vm.state.cancelledWith, isNull);
        expect(auth.status, AuthStatus.signedOut);
      }
      vm.edited();
      expect(vm.state.formError, isNull);
      expect(vm.state.failedWith, isNull);
    });

    test('a failure can be retried', () async {
      google.error = const SocialSignInFailedException('x');
      await vm.signInWith(google);
      google.error = null;
      expect(await vm.signInWith(google), isTrue);
      expect(vm.state.formError, isNull);
      expect(vm.state.failedWith, isNull);
    });
  });
}
