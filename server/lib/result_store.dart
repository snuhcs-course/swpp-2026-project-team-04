// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Where the battle server keeps what must outlive it (P11, protocol §8):
/// battles that started, their final results, and battles that ended void.
abstract interface class BattleResultStore {
  /// A battle's start time is fixed; recorded so a restart can void it.
  Future<void> started(String matchId, int startAtMs, List<String> playerIds);

  /// The final result, once per `result_id`. Retrying is safe.
  Future<void> finished(Map<String, dynamic> result);

  /// A battle that ended without a result (e.g. both players lost).
  Future<void> voided(String matchId, String reason);

  /// Called once at start-up: voids every battle a previous process left
  /// running (started before [bootedAtMs]) and returns their match ids with
  /// the player ids in each.
  Future<Map<String, Set<String>>> recover(int bootedAtMs);
}

/// Calls the Django P11 saver (`/internal/...`) over loopback HTTP with the
/// shared secret. Bodies and the secret are never logged.
class HttpResultStore implements BattleResultStore {
  HttpResultStore(
    Uri base,
    this._secret, {
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ],
    void Function(String line)? log,
  }) : base = base.path.endsWith('/')
           ? base
           : base.replace(path: '${base.path}/'),
       _log = log ?? stderr.writeln {
    if (base.scheme != 'http' ||
        !{'127.0.0.1', '::1', 'localhost'}.contains(base.host) ||
        base.hasQuery ||
        base.userInfo.isNotEmpty) {
      throw ArgumentError('Result store must use a loopback HTTP URL.');
    }
    if (_secret.length < 32) {
      throw ArgumentError('Result store secret must be 32+ characters.');
    }
  }

  final Uri base;
  final String _secret;
  final List<Duration> retryDelays;
  final void Function(String line) _log;

  @override
  Future<void> started(String matchId, int startAtMs, List<String> playerIds) =>
      _post('battles/start', {
        'match_id': matchId,
        'started_at_ms': startAtMs,
        'player_ids': playerIds,
      });

  @override
  Future<void> finished(Map<String, dynamic> result) =>
      _post('results', result);

  @override
  Future<void> voided(String matchId, String reason) =>
      _post('battles/void', {'match_id': matchId, 'reason': reason});

  @override
  Future<Map<String, Set<String>>> recover(int bootedAtMs) async {
    final body = await _post('battles/recover', {'booted_at_ms': bootedAtMs});
    final lost = <String, Set<String>>{};
    final voided = body?['voided'];
    if (voided is! List) return lost;
    for (final battle in voided) {
      if (battle is Map &&
          battle['match_id'] is String &&
          battle['player_ids'] is List) {
        lost[battle['match_id'] as String] = {
          for (final id in battle['player_ids'] as List)
            if (id is String) id,
        };
      }
    }
    return lost;
  }

  /// Posts [body], retrying network errors and 5xx answers. Every call is
  /// idempotent on the Django side, so a retry never stores twice.
  Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = base.resolve(path);
    for (var attempt = 0; ; attempt++) {
      int? status;
      try {
        final (code, reply) = await _send(
          uri,
          body,
        ).timeout(const Duration(seconds: 5));
        status = code;
        if (code < 300) return reply;
        // 4xx is final: invalid, forbidden, or a conflict with stored state.
        if (code < 500) {
          _log('P11 $path refused: HTTP $code');
          return null;
        }
      } catch (_) {
        // Network error or timeout: retry below.
      }
      if (attempt >= retryDelays.length) {
        _log(
          'P11 $path failed after ${attempt + 1} tries (HTTP ${status ?? '-'})',
        );
        return null;
      }
      await Future<void>.delayed(retryDelays[attempt]);
    }
  }

  Future<(int, Map<String, dynamic>?)> _send(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.postUrl(uri);
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set('X-Results-Secret', _secret);
      // Django reads only up to Content-Length, so never send it chunked.
      final bytes = utf8.encode(jsonEncode(body));
      request.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close();
      final received = <int>[];
      await for (final chunk in response) {
        received.addAll(chunk);
        if (received.length > 65536) break;
      }
      Map<String, dynamic>? reply;
      try {
        final data = jsonDecode(utf8.decode(received));
        if (data is Map<String, dynamic>) reply = data;
      } catch (_) {}
      return (response.statusCode, reply);
    } finally {
      client.close(force: true);
    }
  }
}

// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
/// The value of [key] in a `KEY=value` env file, or null. Lets the battle
/// server read only RESULTS_SECRET from the team .env instead of loading
/// every team secret into its environment.
String? readEnvValue(String content, String key) {
  for (final line in const LineSplitter().convert(content)) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('$key=')) continue;
    var value = trimmed.substring(key.length + 1).trim();
    if (value.length >= 2 &&
        (value.startsWith('"') && value.endsWith('"') ||
            value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    return value;
  }
  return null;
}
