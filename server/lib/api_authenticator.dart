import 'dart:convert';
import 'dart:io';

import 'battle_server.dart';

/// Delegates JWT verification to the existing Django API over loopback only.
/// Tokens and response bodies must never be written to logs.
class ApiAuthenticator {
  ApiAuthenticator(this.endpoint) {
    if (endpoint.scheme != 'http' ||
        !{'127.0.0.1', '::1', 'localhost'}.contains(endpoint.host) ||
        endpoint.hasQuery ||
        endpoint.userInfo.isNotEmpty) {
      throw ArgumentError('Authentication API must use a loopback HTTP URL.');
    }
  }

  final Uri endpoint;

  Future<BattleIdentity?> authenticate(String token) async {
    if (token.isEmpty || token.length > 8192) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      return await _verify(client, token).timeout(const Duration(seconds: 4));
    } catch (_) {
      return null; // Fail closed on API failure, malformed response or timeout.
    } finally {
      client.close(force: true);
    }
  }

  Future<BattleIdentity?> _verify(HttpClient client, String token) async {
    final request = await client.getUrl(endpoint);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final response = await request.close();
    if (response.statusCode != 200) return null;
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > 65536) return null;
    }
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map) return null;
    final id = data['id'], name = data['nickname'];
    if (id is! int ||
        id <= 0 ||
        name is! String ||
        name.isEmpty ||
        name.length > 80) {
      return null;
    }
    return BattleIdentity(id.toString(), name);
  }
}
