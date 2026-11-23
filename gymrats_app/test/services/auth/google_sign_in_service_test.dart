import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/services/auth/google_sign_in_service.dart';

class _FakeGoogle implements GoogleAuthApi {
  final initialized = <String>[];
  Object? initError;
  Object? authError;
  String? token = 'id-token';
  int authenticateCalls = 0;

  @override
  Future<void> initialize({required String serverClientId}) async {
    initialized.add(serverClientId);
    if (initError case final error?) {
      initError = null;
      throw error;
    }
  }

  @override
  Future<String?> authenticate() async {
    authenticateCalls++;
    if (authError case final error?) throw error;
    return token;
  }
}

void main() {
  late _FakeGoogle google;
  late GoogleSignInService service;

  setUp(() {
    google = _FakeGoogle();
    service = GoogleSignInService(serverClientId: 'web-client', api: google);
  });

  test('is the Google provider', () {
    expect(service.provider, SocialProvider.google);
    expect(SocialProvider.google.label, 'Google');
  });

  test('returns the ID token, initializing the plugin once', () async {
    expect(await service.signIn(), 'id-token');
    expect(await service.signIn(), 'id-token');
    expect(google.initialized, ['web-client']);
    expect(google.authenticateCalls, 2);
  });

  test('without a server client id it fails before the plugin runs', () async {
    service = GoogleSignInService(serverClientId: '', api: google);
    await expectLater(
      service.signIn(),
      throwsA(isA<SocialSignInFailedException>()),
    );
    expect(google.initialized, isEmpty);
  });

  test('backing out is a cancellation', () async {
    google.authError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
    );
    await expectLater(
      service.signIn(),
      throwsA(isA<SocialSignInCancelledException>()),
    );
  });

  test('other plugin errors fail with their code', () async {
    google.authError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.clientConfigurationError,
    );
    await expectLater(
      service.signIn(),
      throwsA(
        isA<SocialSignInFailedException>().having(
          (e) => e.reason,
          'reason',
          'clientConfigurationError',
        ),
      ),
    );
  });

  test('no ID token from Google fails', () async {
    for (final token in [null, '']) {
      google.token = token;
      await expectLater(
        service.signIn(),
        throwsA(isA<SocialSignInFailedException>()),
      );
    }
  });

  test('a failed initialization is retried on the next tap', () async {
    google.initError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.unknownError,
    );
    await expectLater(
      service.signIn(),
      throwsA(isA<SocialSignInFailedException>()),
    );
    expect(await service.signIn(), 'id-token');
    expect(google.initialized, ['web-client', 'web-client']);
  });

  test('the failure keeps tokens out of its text', () {
    expect(
      const SocialSignInFailedException('canceled').toString(),
      'SocialSignInFailedException(canceled)',
    );
  });
}
