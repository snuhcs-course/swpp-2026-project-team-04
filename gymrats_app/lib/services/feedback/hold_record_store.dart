import 'dart:convert';
import 'dart:io';

import '../../models/hold_record.dart';
import '../device/device_controls.dart';

/// Keeps played holds on this device across app restarts (P13): the hold
/// report and the archive read them. Nothing goes to the server.
abstract interface class HoldRecordStore {
  Future<void> save(HoldRecord record);

  /// Newest first; a record that cannot be read is skipped.
  Future<List<HoldRecord>> list();
}

/// One JSON file per hold in a `hold_records` folder under [root].
///
/// Only the newest [keep] records stay; saving one more deletes the oldest.
class FileHoldRecordStore implements HoldRecordStore {
  FileHoldRecordStore({Future<String?> Function()? root, this.keep = 100})
    : _root = root ?? appFilesDirectory;

  final Future<String?> Function() _root;
  final int keep;

  Future<Directory?> _folder() async {
    final root = await _root();
    if (root == null) return null;
    return Directory('$root${Platform.pathSeparator}hold_records')
        .create(recursive: true);
  }

  @override
  Future<void> save(HoldRecord record) async {
    final folder = await _folder();
    if (folder == null) return;
    final file = File(
      '${folder.path}${Platform.pathSeparator}${record.id}.json',
    );
    await file.writeAsString(jsonEncode(record.toJson()), flush: true);
    final files = await _files(folder);
    for (final old in files.skip(keep)) {
      await old.delete();
    }
  }

  @override
  Future<List<HoldRecord>> list() async {
    final folder = await _folder();
    if (folder == null) return const [];
    final records = <HoldRecord>[];
    for (final file in await _files(folder)) {
      final record = _read(await file.readAsString());
      if (record != null) records.add(record);
    }
    return records;
  }

  /// Null when the file is cut off or from another layout.
  HoldRecord? _read(String text) {
    try {
      final json = jsonDecode(text);
      return HoldRecord.fromJson((json as Map).cast<String, Object?>());
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// Record files, newest first. Names are end times in microseconds.
  Future<List<File>> _files(Directory folder) async {
    final files = await folder
        .list()
        .where((e) => e is File && e.path.endsWith('.json'))
        .cast<File>()
        .toList();
    int stamp(File f) =>
        int.tryParse(f.uri.pathSegments.last.replaceAll('.json', '')) ?? 0;
    files.sort((a, b) => stamp(b).compareTo(stamp(a)));
    return files;
  }
}

/// Records kept in memory, for tests, demos and an app without files.
class InMemoryHoldRecordStore implements HoldRecordStore {
  final List<HoldRecord> _records = [];

  @override
  Future<void> save(HoldRecord record) async {
    _records
      ..add(record)
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
  }

  @override
  Future<List<HoldRecord>> list() async => List.unmodifiable(_records);
}
