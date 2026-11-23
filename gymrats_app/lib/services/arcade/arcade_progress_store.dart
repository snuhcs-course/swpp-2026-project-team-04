import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/arcade_progress.dart';

/// Each account's arcade progress, kept on this phone (arcade spec 7). The
/// server keeps none yet.
abstract interface class ArcadeProgressStore {
  /// [accountId]'s progress. The first state when nothing is saved or the
  /// saved value cannot be read.
  Future<ArcadeProgress> read(int accountId);

  /// Saves [progress] over [accountId]'s.
  Future<void> write(int accountId, ArcadeProgress progress);
}

/// One JSON value per account in the phone's secure storage,
/// `{"v":1,"best":[...]}` under `gymrats.arcade.<account>`.
class SecureArcadeProgressStore implements ArcadeProgressStore {
  SecureArcadeProgressStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String key(int accountId) => 'gymrats.arcade.$accountId';

  @override
  Future<ArcadeProgress> read(int accountId) async {
    try {
      final saved = await _storage.read(key: key(accountId));
      if (saved == null) return ArcadeProgress.initial();
      return ArcadeProgress.fromJson(jsonDecode(saved));
    } on Object {
      // A store that cannot be read, a broken value, another version, or a
      // value of another length starts the arcade over; the app goes on.
      return ArcadeProgress.initial();
    }
  }

  @override
  Future<void> write(int accountId, ArcadeProgress progress) =>
      _storage.write(key: key(accountId), value: jsonEncode(progress.toJson()));
}

/// Keeps the progress only while the app runs. For tests and demos.
class MemoryArcadeProgressStore implements ArcadeProgressStore {
  final saved = <int, ArcadeProgress>{};

  @override
  Future<ArcadeProgress> read(int accountId) async =>
      saved[accountId] ?? ArcadeProgress.initial();

  @override
  Future<void> write(int accountId, ArcadeProgress progress) async {
    saved[accountId] = progress;
  }
}

/// Saves that [accountId] played stage [number] for [stars], once, when the
/// stage ends: the stage keeps its most stars. Returns the saved progress.
Future<ArcadeProgress> recordArcadeStage(
  ArcadeProgressStore store,
  int accountId,
  int number,
  int stars,
) async {
  final progress = (await store.read(accountId)).withStars(number, stars);
  await store.write(accountId, progress);
  return progress;
}
