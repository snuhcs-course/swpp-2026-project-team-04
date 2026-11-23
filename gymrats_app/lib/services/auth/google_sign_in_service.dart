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

/// The OAuth *web* client id of the GymMouse Google Cloud project, the one
/// the server accepts (GOOGLE_CLIENT_IDS there). Not a secret: every ID
/// token names it as its audience, and it ships inside the app. Kept here so
/// plain `flutter run` / `flutter build` builds have Google sign-in; a build
/// may swap it with `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.
const googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '569497763915-es3rao2rsnqku8sip59vvhtgmhfvsgs0.apps.googleusercontent.com',
);

/// Google sign-in on the device. The ID token it returns is issued for
/// [serverClientId].
class GoogleSignInService implements SocialSignInService {
  GoogleSignInService({
    this.serverClientId = googleServerClientId,
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
