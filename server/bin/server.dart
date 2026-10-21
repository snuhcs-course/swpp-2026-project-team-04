import 'dart:convert';
import 'dart:io';

import '../lib/battle_server.dart';
import '../lib/api_authenticator.dart';
import '../lib/result_store.dart';

Future<void> main() async {
  final env = Platform.environment, host = env['BATTLE_HOST'] ?? '127.0.0.1';
  final dev = env['BATTLE_DEV_AUTH'] == '1';
  if (dev && host != '127.0.0.1') {
    stderr.writeln('Development authentication is loopback-only.');
    exitCode = 1;
    return;
  }
  final file = env['BATTLE_AUTH_FILE'];
  final apiUrl = env['BATTLE_AUTH_URL'];
  if ([dev, file != null, apiUrl != null].where((enabled) => enabled).length !=
      1) {
    stderr.writeln(
      'Select exactly one authentication adapter: BATTLE_AUTH_URL, BATTLE_AUTH_FILE or loopback BATTLE_DEV_AUTH=1.',
    );
    exitCode = 1;
    return;
  }
  ApiAuthenticator? api;
  try {
    if (apiUrl != null) api = ApiAuthenticator(Uri.parse(apiUrl));
  } catch (_) {
    stderr.writeln('Invalid authentication API configuration.');
    exitCode = 1;
    return;
  }
  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  // P11: with BATTLE_RESULTS_URL set, results go to the Django saver using
  // only RESULTS_SECRET from the env file in BATTLE_RESULTS_ENV_FILE
  // (/srv/gymrats/.env); without it they stay in memory.
  HttpResultStore? results;
  final resultsUrl = env['BATTLE_RESULTS_URL'];
  try {
    if (resultsUrl != null) {
      final secretFile = env['BATTLE_RESULTS_ENV_FILE'];
      final secret = secretFile == null
          ? null
          : readEnvValue(
              await File(secretFile).readAsString(),
              'RESULTS_SECRET',
            );
      results = HttpResultStore(Uri.parse(resultsUrl), secret ?? '');
    }
  } catch (_) {
    stderr.writeln('Invalid result storage configuration (secret redacted).');
    exitCode = 1;
    return;
  }
  // Temporary trusted-token adapter. Real team login/JWT verification is a
  // separate integration; never put this file or its tokens in the repository.
  Map<String, dynamic> tokens = {};
  try {
    if (file != null)
      tokens =
          jsonDecode(await File(file).readAsString()) as Map<String, dynamic>;
    for (final entry in tokens.entries) {
      final value = entry.value;
      if (entry.key.isEmpty ||
          value is! Map ||
          value['player_id'] is! String ||
          value['display_name'] is! String)
        throw const FormatException();
    }
  } catch (_) {
    stderr.writeln('Invalid authentication configuration (contents redacted).');
    exitCode = 1;
    return;
  }
  final server = BattleServer(
    results: results,
    authenticate: (token) async {
      if (api != null) return api.authenticate(token);
      if (dev &&
          RegExp(r'^dev:[a-zA-Z0-9_-]{3,64}:[^:]{1,40}$').hasMatch(token)) {
        final parts = token.split(':');
        return BattleIdentity(parts[1], parts[2]);
      }
      final identity = tokens[token];
      return identity is Map
          ? BattleIdentity(
              identity['player_id'] as String,
              identity['display_name'] as String,
            )
          : null;
    },
  );
  await server.start(
    address: InternetAddress(host),
    port: int.parse(env['BATTLE_PORT'] ?? '8080'),
  );
  stdout.writeln(
    'GymRats battle v1 listening on $host:${server.port} (no pose/token logging, '
    'results ${results == null ? 'in memory only' : 'stored'})',
  );
  ProcessSignal.sigint.watch().listen((_) async {
    await server.close();
    exit(0);
  });
  ProcessSignal.sigterm.watch().listen((_) async {
    await server.close();
    exit(0);
  });
}
