// AI-assisted: Cursor, Grok 4.7, 2026-10-16, 송현우
import 'dart:convert';
import 'dart:io';

import '../../models/form_report.dart';
import '../device/device_controls.dart';

/// Keeps form reports on this device across app restarts.
abstract interface class FormReportStore {
  Future<void> save(FormReport report);

  /// Newest first.
  Future<List<FormReport>> list();

  /// The newest report that can be read, or null when there is none.
  /// A file that cannot be read is skipped. Prefer this on the home
  /// screen: [list] parses every saved battle.
  Future<FormReport?> latest();
}

/// One JSON file per battle in a `form_reports` folder under [root].
///
/// Only the newest [keep] reports stay; saving one more deletes the oldest.
/// A file that cannot be read is skipped.
class FileFormReportStore implements FormReportStore {
  FileFormReportStore({Future<String?> Function()? root, this.keep = 20})
    : _root = root ?? appFilesDirectory;

  final Future<String?> Function() _root;
  final int keep;

  Future<Directory?> _folder() async {
    final root = await _root();
    if (root == null) return null;
    return Directory('$root${Platform.pathSeparator}form_reports')
        .create(recursive: true);
  }

  @override
  Future<void> save(FormReport report) async {
    final folder = await _folder();
    if (folder == null) return;
    final file = File(
      '${folder.path}${Platform.pathSeparator}${report.id}.json',
    );
    await file.writeAsString(jsonEncode(report.toJson()), flush: true);
    final files = await _files(folder);
    for (final old in files.skip(keep)) {
      await old.delete();
    }
  }

  @override
  Future<List<FormReport>> list() async {
    final folder = await _folder();
    if (folder == null) return const [];
    final reports = <FormReport>[];
    for (final file in await _files(folder)) {
      final report = _read(await file.readAsString());
      if (report != null) reports.add(report);
    }
    return reports;
  }

  @override
  Future<FormReport?> latest() async {
    final folder = await _folder();
    if (folder == null) return null;
    for (final file in await _files(folder)) {
      final report = _read(await file.readAsString());
      if (report != null) return report;
    }
    return null;
  }

  /// Null when the file is cut off or from another layout.
  FormReport? _read(String text) {
    try {
      final json = jsonDecode(text);
      return FormReport.fromJson((json as Map).cast<String, Object?>());
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Report files, newest first. Names are end times in milliseconds.
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

/// Reports kept in memory, for tests and demos.
class InMemoryFormReportStore implements FormReportStore {
  final List<FormReport> _reports = [];

  @override
  Future<void> save(FormReport report) async => _reports.insert(0, report);

  @override
  Future<List<FormReport>> list() async => List.unmodifiable(_reports);

  @override
  Future<FormReport?> latest() async => _reports.firstOrNull;
}
