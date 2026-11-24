import 'package:flutter/foundation.dart';

import '../services/api/api_client.dart';
import '../services/auth/auth_repository.dart';
import 'auth_viewmodel.dart';
import 'help_viewmodel.dart';
import 'login_viewmodel.dart';
import 'signup_viewmodel.dart';

/// A Google account with no GymRats account yet: the provider and
/// the token it gave, sent again with the nickname.
typedef SocialSignupRequest = ({SocialProvider provider, String token});

/// What the nickname step shows besides the typed text.
class SocialSignupState {
  const SocialSignupState({
    this.nicknameError,
    this.formError,
    this.submitting = false,
  });

  /// Shown under the field; null when it is fine.
  final String? nicknameError;

  /// Shown above the button, e.g. an expired provider login or no network.
  final String? formError;

  /// The sign-up request is running: the button does nothing.
  final bool submitting;
}

/// Creates the GymRats account of a new Google account once the
/// user picks a nickname. On success the user is logged in, and the app shows
/// the body info step and the rules before home, as after sign-up.
class SocialSignupViewModel extends ChangeNotifier {
  SocialSignupViewModel({
    required this._auth,
    required this.request,
    this._help,
  });

  final AuthViewModel _auth;
  final SocialSignupRequest request;

  /// Shows the new account the battle rules before home. Null in form-only
  /// tests.
  final HelpViewModel? _help;
  SocialSignupState _state = const SocialSignupState();
  bool _disposed = false;

  SocialSignupState get state => _state;

  SocialProvider get provider => request.provider;

  /// The provider login has to start over, e.g. it expired while the user
  /// was choosing a nickname.
  String get expiredMessage =>
      '${provider.label} 로그인이 만료됐어요. 뒤로 가서 다시 시도해 주세요.';

  /// Clears the form-wide error once the user types again.
  void edited() {
    if (_state.submitting || _state.formError == null) return;
    _set(SocialSignupState(nicknameError: _state.nicknameError));
  }

  /// True when the account was created and the user is logged in.
  Future<bool> submit(String nickname) async {
    if (_state.submitting) return false;
    final error = SignupRules.nickname(nickname);
    if (error != null) {
      _set(SocialSignupState(nicknameError: error));
      return false;
    }
    _set(const SocialSignupState(submitting: true));
    try {
      final created = await _auth.signInWith(
        request.provider,
        request.token,
        nickname: nickname.trim(),
      );
      // The account may have been made meanwhile, e.g. on another phone:
      // then it already saw the rules.
      if (created) {
        if (_auth.account case final account?) {
          await _help?.signedUp(account.id);
        }
      }
      _set(const SocialSignupState());
      return true;
    } on SocialTokenRejectedException {
      _set(SocialSignupState(formError: expiredMessage));
    } on SocialLoginUnavailableException {
      _set(
        SocialSignupState(
          formError: LoginViewModel.socialUnavailableMessage(provider),
        ),
      );
    } on ApiException catch (e) {
      _set(SocialSignupState(formError: e.message));
    } on Exception {
      _set(const SocialSignupState(formError: genericErrorMessage));
    }
    return false;
  }

  void _set(SocialSignupState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
