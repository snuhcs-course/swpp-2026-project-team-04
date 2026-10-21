import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _base = Uri.parse('http://server.test/api');

http.Response _json(Object? body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

ApiClient _client(MockClientHandler handler) =>
    ApiClient(httpClient: MockClient(handler), baseUrl: _base);

Matcher _apiError(ApiErrorKind kind, {int? status, String? code}) =>
    isA<ApiException>()
        .having((e) => e.kind, 'kind', kind)
        .having((e) => e.statusCode, 'statusCode', status)
        .having((e) => e.code, 'code', code);

void main() {
  test('sends JSON under the base path and decodes the answer', () async {
    late http.Request sent;
    final api = _client((request) async {
      sent = request;
      return _json({'ok': true}, 201);
    });
    final result = await api.post('/auth/signup', {'a': 1}, authorized: false);
    expect(result, {'ok': true});
    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://server.test/api/auth/signup');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), {'a': 1});
  });

  test('adds query parameters', () async {
    late Uri url;
    final api = _client((request) async {
      url = request.url;
      return _json({}, 200);
    });
    await api.get('/matches', query: {'limit': '20', 'before': '7'});
    expect(url.path, '/api/matches');
    expect(url.queryParameters, {'limit': '20', 'before': '7'});
  });

  test('sends the token only on requests that need a login', () async {
    final headers = <Map<String, String>>[];
    final api = _client((request) async {
      headers.add(request.headers);
      return _json({}, 200);
    })..token = 'secret-token';
    await api.get('/users/me');
    await api.post('/auth/login', {}, authorized: false);
    expect(headers[0]['Authorization'], 'Bearer secret-token');
    expect(headers[1].containsKey('Authorization'), isFalse);
  });

  test('no token: no Authorization header', () async {
    late http.Request sent;
    final api = _client((request) async {
      sent = request;
      return _json({}, 200);
    });
    await api.get('/users/me');
    expect(sent.headers.containsKey('Authorization'), isFalse);
  });

  test(
    'a 401 on a logged-in request is unauthorized and is announced',
    () async {
      final api = _client((_) async => _json({'detail': 'invalid_token'}, 401))
        ..token = 'old';
      var announced = 0;
      api.unauthorized.listen((_) => announced++);
      await expectLater(
        api.get('/users/me'),
        throwsA(
          _apiError(
            ApiErrorKind.unauthorized,
            status: 401,
            code: 'invalid_token',
          ),
        ),
      );
      expect(announced, 1);
    },
  );

  test('a 401 on login is not announced as an expired session', () async {
    final api = _client(
      (_) async => _json({'detail': 'invalid_credentials'}, 401),
    );
    var announced = 0;
    api.unauthorized.listen((_) => announced++);
    await expectLater(
      api.post('/auth/login', {}, authorized: false),
      throwsA(
        _apiError(
          ApiErrorKind.unauthorized,
          status: 401,
          code: 'invalid_credentials',
        ),
      ),
    );
    expect(announced, 0);
  });

  test('maps 4xx to rejected and 5xx to server', () async {
    await expectLater(
      _client((_) async => _json({'detail': 'login_id_taken'}, 409))
          .post('/x', {}),
      throwsA(
        _apiError(ApiErrorKind.rejected, status: 409, code: 'login_id_taken'),
      ),
    );
    await expectLater(
      _client((_) async => http.Response('Bad Gateway', 502)).get('/x'),
      throwsA(_apiError(ApiErrorKind.server, status: 502)),
    );
  });

  test('a body that is not JSON is a server error', () async {
    await expectLater(
      _client((_) async => http.Response('<html>', 200)).get('/x'),
      throwsA(_apiError(ApiErrorKind.server, status: 200)),
    );
  });

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  test('a proxy error page is classed by its status', () async {
    await expectLater(
      _client((_) async => http.Response('<html>413</html>', 413)).get('/x'),
      throwsA(_apiError(ApiErrorKind.rejected, status: 413)),
    );
    await expectLater(
      _client((_) async => http.Response('<html>502</html>', 502)).get('/x'),
      throwsA(_apiError(ApiErrorKind.server, status: 502)),
    );
  });

  test('no connection is a network error', () async {
    await expectLater(
      _client((_) async => throw const SocketException('down')).get('/x'),
      throwsA(_apiError(ApiErrorKind.network)),
    );
    await expectLater(
      _client((_) async => throw http.ClientException('reset')).get('/x'),
      throwsA(_apiError(ApiErrorKind.network)),
    );
  });

  test('a slow server times out', () async {
    final never = Completer<http.Response>();
    final api = ApiClient(
      httpClient: MockClient((_) => never.future),
      baseUrl: _base,
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(api.get('/x'), throwsA(_apiError(ApiErrorKind.timeout)));
  });

  test('every error kind has a Korean message', () {
    for (final kind in ApiErrorKind.values) {
      expect(ApiException(kind).message, isNotEmpty);
    }
  });

  test('the default server is the team server under /api', () {
    expect(ApiClient.defaultBaseUrl.toString(), 'https://52.78.38.225/api');
  });
}
