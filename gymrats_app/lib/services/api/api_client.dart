import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/server_config.dart';

/// Why a request to the server failed.
enum ApiErrorKind {
  /// No connection, or the server could not be reached.
  network,

  /// The server did not answer in time.
  timeout,

  /// The token is missing, expired, or rejected (401).
  unauthorized,

  /// The request was refused, e.g. a login id that is taken (4xx).
  rejected,

  /// The server failed (5xx) or sent something the app cannot read.
  server,
}

/// A failed request. [code] is the server's `detail` when it sent one,
/// e.g. "login_id_taken".
class ApiException implements Exception {
  const ApiException(this.kind, {this.statusCode, this.code});

  final ApiErrorKind kind;
  final int? statusCode;
  final String? code;

  /// What the screens show for this failure.
  String get message => switch (kind) {
    ApiErrorKind.network => '서버에 연결하지 못했어요. 인터넷 연결을 확인해 주세요.',
    ApiErrorKind.timeout => '서버 응답이 늦어요. 잠시 후 다시 시도해 주세요.',
    ApiErrorKind.unauthorized => '로그인이 만료됐어요. 다시 로그인해 주세요.',
    ApiErrorKind.rejected => '요청을 처리하지 못했어요. 다시 시도해 주세요.',
    ApiErrorKind.server => '서버에 문제가 생겼어요. 잠시 후 다시 시도해 주세요.',
  };

  @override
  String toString() => 'ApiException($kind, $statusCode, $code)';
}

/// Talks JSON to the GymRats API.
///
/// Production uses the fixed HTTPS team endpoint. Tests may inject [baseUrl].
class ApiClient {
  ApiClient({http.Client? httpClient, Uri? baseUrl, this.timeout = _timeout})
    : _http = httpClient ?? http.Client(),
      baseUrl = baseUrl ?? defaultBaseUrl;

  static final defaultBaseUrl = Uri.parse(gymratsApiBaseUrl);

  static const _timeout = Duration(seconds: 10);

  final http.Client _http;
  final Uri baseUrl;
  final Duration timeout;

  /// Sent with every request that needs a login. Set by the auth
  /// repository; null while logged out.
  String? token;

  final _unauthorized = StreamController<void>.broadcast(sync: true);

  /// Fires when the server rejects [token] (401 on a request that needed
  /// it), so the app can log the user out.
  Stream<void> get unauthorized => _unauthorized.stream;

  Future<Object?> get(
    String path, {
    Map<String, String>? query,
    bool authorized = true,
  }) => _send('GET', path, query: query, authorized: authorized);

  Future<Object?> post(String path, Object body, {bool authorized = true}) =>
      _send('POST', path, body: body, authorized: authorized);

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  Future<Object?> put(String path, Object body, {bool authorized = true}) =>
      _send('PUT', path, body: body, authorized: authorized);

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    required bool authorized,
  }) async {
    final uri = baseUrl.replace(
      path: '${baseUrl.path}$path',
      queryParameters: query,
    );
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    final token = this.token;
    if (authorized && token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(ApiErrorKind.timeout);
    } on SocketException {
      throw const ApiException(ApiErrorKind.network);
    } on http.ClientException {
      throw const ApiException(ApiErrorKind.network);
    }

    final status = response.statusCode;
    final ok = status >= 200 && status < 300;
    Object? json;
    try {
      json = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      if (ok) throw ApiException(ApiErrorKind.server, statusCode: status);
      // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
      // An error page from the proxy, e.g. nginx's HTML 413 for a body over
      // its limit: the status still decides the kind below.
      json = null;
    }
    if (ok) return json;

    final detail = json is Map && json['detail'] is String
        ? json['detail'] as String
        : null;
    if (status == HttpStatus.unauthorized) {
      if (authorized) _unauthorized.add(null);
      throw ApiException(
        ApiErrorKind.unauthorized,
        statusCode: status,
        code: detail,
      );
    }
    throw ApiException(
      status >= 500 ? ApiErrorKind.server : ApiErrorKind.rejected,
      statusCode: status,
      code: detail,
    );
  }
}
