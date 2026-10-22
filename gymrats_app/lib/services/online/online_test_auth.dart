import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Temporary UI adapter until the teammate's AuthRepository is merged.
/// No credentials are stored, logged or embedded in the APK.
Future<String> onlineLogin(Uri battle, String loginId, String password) =>
    _requestToken(battle, 'login', {'login_id': loginId, 'password': password});

Future<String> createOnlineTestAccount(Uri battle, {required bool synthetic}) {
  if (kReleaseMode) throw StateError('Test accounts are debug-only');
  final random = Random.secure();
  final suffix = List.generate(
    12,
    (_) => random.nextInt(16).toRadixString(16),
  ).join();
  final password = base64UrlEncode(
    List.generate(32, (_) => random.nextInt(256)),
  );
  return _requestToken(battle, 'signup', {
    'login_id': 'test_$suffix',
    'nickname': synthetic ? '가상상대 TEST' : '휴대폰 TEST',
    'password': password,
  });
}

Future<String> _requestToken(
  Uri battle,
  String action,
  Map<String, String> body,
) async {
  if (battle.scheme != 'wss' || battle.userInfo.isNotEmpty || battle.hasQuery) {
    throw const FormatException('HTTPS 서버 주소가 필요해요.');
  }
  final api = battle.replace(scheme: 'https', path: '/api/auth/$action');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client
        .postUrl(api)
        .timeout(const Duration(seconds: 10));
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close().timeout(const Duration(seconds: 10));
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 10))) {
      bytes.addAll(chunk);
      if (bytes.length > 65536) throw const FormatException('응답이 너무 커요.');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw const FormatException('로그인 또는 테스트 계정 생성에 실패했어요.');
    }
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map ||
        value['token'] is! String ||
        (value['token'] as String).isEmpty) {
      throw const FormatException('로그인 토큰을 받지 못했어요.');
    }
    return value['token'] as String;
  } finally {
    client.close(force: true);
  }
}
