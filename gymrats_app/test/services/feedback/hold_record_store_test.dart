import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/feedback/hold_record_store.dart';

import '../../models/hold_record_test.dart' show holdRecord;

void main() {
  late Directory root;

  setUp(() async => root = await Directory.systemTemp.createTemp('gymrats'));
  tearDown(() => root.delete(recursive: true));

  FileHoldRecordStore store({int keep = 100}) =>
      FileHoldRecordStore(root: () async => root.path, keep: keep);

  group('FileHoldRecordStore (P13)', () {
    test('keeps holds across instances, newest first', () async {
      await store().save(holdRecord(endedAt: DateTime(2026, 11, 24, 9)));
      await store().save(holdRecord(endedAt: DateTime(2026, 11, 26, 9)));
      await store().save(holdRecord(endedAt: DateTime(2026, 11, 25, 9)));
      final kept = await store().list();
      expect(kept.map((r) => r.endedAt.day), [26, 25, 24]);
      expect(
        Directory('${root.path}${Platform.pathSeparator}hold_records')
            .listSync()
            .length,
        3,
      );
    });

    test('only the newest [keep] stay', () async {
      final s = store(keep: 2);
      for (var day = 20; day <= 23; day++) {
        await s.save(holdRecord(endedAt: DateTime(2026, 11, day, 9)));
      }
      expect((await s.list()).map((r) => r.endedAt.day), [23, 22]);
    });

    test('a file it cannot read is skipped', () async {
      await store().save(holdRecord(endedAt: DateTime(2026, 11, 26, 9)));
      final folder = '${root.path}${Platform.pathSeparator}hold_records';
      File('$folder${Platform.pathSeparator}1.json').writeAsStringSync('{');
      File('$folder${Platform.pathSeparator}2.json')
          .writeAsStringSync('{"pose": "wall"}');
      File('$folder${Platform.pathSeparator}3.json').writeAsStringSync('[]');
      expect(await store().list(), hasLength(1));
    });

    test('without a files folder nothing is kept and nothing fails', () async {
      final none = FileHoldRecordStore(root: () async => null);
      await none.save(holdRecord());
      expect(await none.list(), isEmpty);
    });
  });

  group('InMemoryHoldRecordStore', () {
    test('lists the saved holds newest first, read-only', () async {
      final s = InMemoryHoldRecordStore();
      await s.save(holdRecord(endedAt: DateTime(2026, 11, 24, 9)));
      await s.save(holdRecord(endedAt: DateTime(2026, 11, 26, 9)));
      final kept = await s.list();
      expect(kept.map((r) => r.endedAt.day), [26, 24]);
      expect(() => kept.add(holdRecord()), throwsUnsupportedError);
    });
  });
}
