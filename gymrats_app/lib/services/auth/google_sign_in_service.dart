import 'package:google_sign_in/google_sign_in.dart';

import 'auth_repository.dart';

/// The calls [GoogleSignInService] makes to the google_sign_in plugin, so
/// tests can replace the plugin.
abstract interface class GoogleAuthApi {
  Future<void> initialize({required String serverClientId});

  /// The ID token of the account the user picked; null if Google sent none.
  /// Throws [GoogleSignInException].
  Future<String?> authenticate();
}

/// [GoogleAuthApi] on the real plugin (Android Credential Manager).
class PluginGoogleAuthApi implements GoogleAuthApi {
  const PluginGoogleAuthApi();

  @override
  Future<void> initialize({required String serverClientId}) =>
      GoogleSignIn.instance.initialize(serverClientId: serverClientId);

  @override
  Future<String?> authenticate() async =>
      (await GoogleSignIn.instance.authenticate()).authentication.idToken;
}

/// Google sign-in on the device. The ID token it returns is issued for
/// [serverClientId], the OAuth *web* client id the server accepts
/// (GOOGLE_CLIENT_IDS there). It comes from
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` at build time, never the repo.
class GoogleSignInService implements SocialSignInService {
  GoogleSignInService({
    this.serverClientId = const String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
    ),
    this._api = const PluginGoogleAuthApi(),
  });

  final String serverClientId;
  final GoogleAuthApi _api;
  Future<void>? _initialized;

  @override
  SocialProvider get provider => SocialProvider.google;

  @override
  Future<String> signIn() async {
    if (serverClientId.isEmpty) {
      throw const SocialSignInFailedException('no GOOGLE_SERVER_CLIENT_ID');
    }
    try {
      await _initialize();
      final token = await _api.authenticate();
      if (token == null || token.isEmpty) {
        throw const SocialSignInFailedException('no id token');
      }
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialSignInCancelledException();
      }
      throw SocialSignInFailedException(e.code.name);
    }
  }

  /// The plugin is initialized once per app run; a failed try is retried on
  /// the next tap.
  Future<void> _initialize() async {
    final initialized = _initialized ??= _api.initialize(
      serverClientId: serverClientId,
    );
    try {
      await initialized;
    } on Object {
      _initialized = null;
      rethrow;
    }
  }
}
