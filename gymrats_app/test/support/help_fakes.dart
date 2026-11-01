import 'dart:async';

import 'package:gymrats_app/services/user/rules_seen_store.dart';

/// Rules flags in a map that fail or wait on request, like a broken or
/// slow keystore. An account without a flag counts as seen.
class ScriptedRulesSeenStore implements RulesSeenStore {
  final values = <int, bool>{};

  /// Account ids read, and (account id, seen) written, in order.
  final reads = <int>[];
  final writes = <(int, bool)>[];

  /// Thrown by every read / write while set.
  Exception? readError;
  Exception? writeError;

  Completer<void>? _readGate;
  Completer<void>? _writeGate;

  /// Makes reads wait until the returned completer completes.
  Completer<void> holdRead() => _readGate = Completer();

  /// Makes writes wait until the returned completer completes.
  Completer<void> holdWrite() => _writeGate = Completer();

  @override
  Future<bool> read(int accountId) async {
    reads.add(accountId);
    await _readGate?.future;
    if (readError case final error?) throw error;
    return values[accountId] ?? true;
  }

  @override
  Future<void> write(int accountId, {required bool seen}) async {
    writes.add((accountId, seen));
    await _writeGate?.future;
    if (writeError case final error?) throw error;
    values[accountId] = seen;
  }
}
