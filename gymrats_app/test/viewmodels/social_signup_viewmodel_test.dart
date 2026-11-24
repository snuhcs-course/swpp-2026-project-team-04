import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/viewmodels/auth_viewmodel.dart';
import 'package:gymrats_app/viewmodels/help_viewmodel.dart';
import 'package:gymrats_app/viewmodels/login_viewmodel.dart';
import 'package:gymrats_app/viewmodels/social_signup_viewmodel.dart';

import '../support/auth_fakes.dart';
import '../support/help_fakes.dart';

void main() {
  late ScriptedAuthRepository repository;
  late AuthViewModel auth;
  late HelpViewModel help;
  late SocialSignupViewModel vm;

  setUp(() async {
    repository = ScriptedAuthRepository();
    auth = AuthViewModel(repository: repository);
    await auth.restore();
    help = HelpViewModel(store: ScriptedRulesSeenStore());
    vm = SocialSignupViewModel(
      auth: auth,
      help: help,
      request: (provider: SocialProvider.google, token: 'id-token'),
    );
  });

  test('knows its provider', () {
    expect(vm.provider, SocialProvider.google);
    expect(vm.expiredMessage, contains('Google'));
  });

  test('creates the account with the trimmed nickname', () async {
    expect(await vm.submit(' 현우 '), isTrue);
    expect(repository.socialSignIns.single, (
      SocialProvider.google,
      'id-token',
      '현우',
    ));
    expect(auth.status, AuthStatus.signedIn);
    expect(auth.account!.nickname, '현우');
    expect(auth.needsBodyInfo, isTrue);
    expect(help.gateFor(1), HelpGate.rules);
    expect(vm.state.submitting, isFalse);
  });

  test('the nickname follows the sign-up rule; nothing is sent', () async {
    expect(await vm.submit('  '), isFalse);
    expect(vm.state.nicknameError, '닉네임을 입력해 주세요.');
    expect(await vm.submit('가나다라마바사아자차카타파'), isFalse);
    expect(vm.state.nicknameError, contains('12자'));
    expect(repository.socialSignIns, isEmpty);
  });

  test('each failure has its message and stays logged out', () async {
    final cases = <(Exception, String)>[
      (const SocialTokenRejectedException(), vm.expiredMessage),
      (
        const SocialLoginUnavailableException(),
        LoginViewModel.socialUnavailableMessage(SocialProvider.google),
      ),
      (
        const ApiException(ApiErrorKind.network),
        const ApiException(ApiErrorKind.network).message,
      ),
      (Exception('?'), genericErrorMessage),
    ];
    for (final (error, message) in cases) {
      repository.socialError = error;
      expect(await vm.submit('현우'), isFalse);
      expect(vm.state.formError, message);
      expect(auth.status, AuthStatus.signedOut);
    }
  });

  test('typing clears the form error but keeps the field error', () async {
    repository.socialError = const ApiException(ApiErrorKind.network);
    await vm.submit('현우');
    vm.edited();
    expect(vm.state.formError, isNull);
    await vm.submit('');
    vm.edited();
    expect(vm.state.nicknameError, isNotNull);
  });

  test('a second tap while sending does nothing', () async {
    final first = vm.submit('현우');
    expect(vm.state.submitting, isTrue);
    expect(await vm.submit('현우'), isFalse);
    vm.edited();
    expect(await first, isTrue);
    expect(repository.socialSignIns, hasLength(1));
  });

  test(
    'an account made meanwhile logs in without showing the rules again',
    () async {
      repository.socialIsNew = false;
      expect(await vm.submit('현우'), isTrue);
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.needsBodyInfo, isFalse);
      expect(help.gateFor(1), isNot(HelpGate.rules));
    },
  );

  test('without a help view model it still signs up', () async {
    vm = SocialSignupViewModel(
      auth: auth,
      request: (provider: SocialProvider.google, token: 't'),
    );
    expect(await vm.submit('우현'), isTrue);
  });

  test('a result after dispose changes nothing', () async {
    final pending = vm.submit('현우');
    vm.dispose();
    expect(await pending, isTrue);
  });
}
