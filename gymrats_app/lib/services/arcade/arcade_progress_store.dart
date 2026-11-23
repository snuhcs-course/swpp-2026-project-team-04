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

  /// Saves that [accountId] played stage [number] for [stars], once, when
  /// the stage ends: the stage keeps its most stars (arcade spec 6, 7).
  /// Returns the progress after the play.
  ///
  /// When the store itself fails to read, nothing is written, so a passing
  /// failure never wipes the saved progress; the play's stars are then
  /// counted over the first state. A missing or broken value is replaced.
  Future<ArcadeProgress> recordStage(int accountId, int number, int stars);
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
      return _parse(await _storage.read(key: key(accountId)));
    } on Object {
      // A store that cannot be read starts the arcade over; the app goes on.
      return ArcadeProgress.initial();
    }
  }

  @override
  Future<void> write(int accountId, ArcadeProgress progress) =>
      _storage.write(key: key(accountId), value: jsonEncode(progress.toJson()));

  @override
  Future<ArcadeProgress> recordStage(
    int accountId,
    int number,
    int stars,
  ) async {
    final String? saved;
    try {
      saved = await _storage.read(key: key(accountId));
    } on Object {
      return ArcadeProgress.initial().withStars(number, stars);
    }
    final progress = _parse(saved).withStars(number, stars);
    await write(accountId, progress);
    return progress;
  }

  /// [saved] as progress. Nothing saved, a broken value, another version, or
  /// a value of another length is the first state.
  static ArcadeProgress _parse(String? saved) {
    if (saved == null) return ArcadeProgress.initial();
    try {
      return ArcadeProgress.fromJson(jsonDecode(saved));
    } on FormatException {
      return ArcadeProgress.initial();
    }
  }
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

  @override
  Future<ArcadeProgress> recordStage(
    int accountId,
    int number,
    int stars,
  ) async {
    final progress = (await read(accountId)).withStars(number, stars);
    await write(accountId, progress);
    return progress;
  }
}
