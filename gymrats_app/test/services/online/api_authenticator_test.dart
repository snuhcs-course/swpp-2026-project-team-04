import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../../../server/lib/api_authenticator.dart';

void main() {
  test('API adapter rejects non-loopback URLs', () {
    for (final url in [
      'http://example.com/users/me',
      'https://127.0.0.1/users/me',
    ]) {
      expect(() => ApiAuthenticator(Uri.parse(url)), throwsArgumentError);
    }
  });

  test(
    'existing API verifies Bearer token and supplies identity; fails closed',
    () async {
      final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => http.close(force: true));
      http.listen((request) async {
        final token = request.headers.value(HttpHeaders.authorizationHeader);
        if (token == 'Bearer valid') {
          request.response.write(jsonEncode({'id': 42, 'nickname': 'Tester'}));
        } else if (token == 'Bearer malformed') {
          request.response.write(
            '{"id": "client-chosen", "nickname":"Tester"}',
          );
        } else if (token == 'Bearer redirect') {
          request.response.statusCode = 302;
          request.response.headers.set('location', 'http://example.com');
        } else {
          request.response.statusCode = 401;
        }
        await request.response.close();
      });
      final auth = ApiAuthenticator(
        Uri.parse('http://127.0.0.1:${http.port}/users/me'),
      );
      final identity = await auth.authenticate('valid');
      expect(identity?.id, '42');
      expect(identity?.name, 'Tester');
      for (final token in ['', 'invalid', 'malformed', 'redirect']) {
        expect(await auth.authenticate(token), isNull);
      }
    },
  );
}
