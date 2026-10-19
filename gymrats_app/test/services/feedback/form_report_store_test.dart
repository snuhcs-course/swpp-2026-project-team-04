import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';

FormReport report(int minute) => FormReport(
  endedAt: DateTime(2026, 10, 11, 9, minute),
  opponentName: 'RepBot',
  roundLength: const Duration(seconds: 60),
  reps: [
    const RepRecord(index: 1, valid: true, at: Duration(seconds: 3)),
    const RepRecord(
      index: 2,
      valid: false,
      at: Duration(seconds: 6),
      reason: RejectReason.bellyDown,
      maxDepth: 1.4,
      descent: Duration(milliseconds: 420),
    ),
  ],
  samples: const [
    FormSample(at: Duration(milliseconds: 100), depth: 0.5, leftElbow: 160),
  ],
);

void main() {
  late Directory root;

  setUp(() async => root = await Directory.systemTemp.createTemp('gymrats'));
  tearDown(() async => root.delete(recursive: true));

  FileFormReportStore store({int keep = 20}) =>
      FileFormReportStore(root: () async => root.path, keep: keep);

  test('a stick figure reads back from a new store', () async {
    const pose = FormPose(
      at: Duration(milliseconds: 1500),
      repIndex: 2,
      points: {
        'leftShoulder': FormPoint(-0.5, 0),
        'rightShoulder': FormPoint(0.5, 0),
        'leftElbow': FormPoint(-1.2, 0.4),
        'nose': FormPoint(0, -0.5),
      },
    );
    await store().save(
      FormReport(
        endedAt: DateTime(2026, 10, 11, 9, 8),
        opponentName: 'RepBot',
        roundLength: const Duration(seconds: 60),
        reps: const [],
        samples: const [],
        poses: [pose],
        leftFlarePose: pose,
      ),
    );
    final read = (await store().list()).single;
    expect(read.poses.single.repIndex, 2);
    expect(read.poses.single.points['leftElbow']!.x, -1.2);
    expect(read.leftFlarePose!.points['nose']!.y, -0.5);
    expect(read.rightFlarePose, isNull);
    expect(read.handsPose, isNull);
  });

  test('a saved report reads back the same, from a new store', () async {
    await store().save(report(0));
    final read = (await store().list()).single;
    expect(read.endedAt, DateTime(2026, 10, 11, 9, 0));
    expect(read.opponentName, 'RepBot');
    expect(read.reps.last.reason, RejectReason.bellyDown);
    expect(read.reps.last.maxDepth, 1.4);
    expect(read.reps.last.descent, const Duration(milliseconds: 420));
    expect(read.reps.first.descent, isNull);
    expect(read.reps.first.maxDepth, isNull);
    expect(read.samples.single.leftElbow, 160);
    expect(read.samples.single.rightElbow, isNull);
  });

  test('reports list newest first', () async {
    final s = store();
    await s.save(report(1));
    await s.save(report(3));
    await s.save(report(2));
    expect([for (final r in await s.list()) r.endedAt.minute], [3, 2, 1]);
  });

  test('saving past the limit deletes the oldest', () async {
    final s = store(keep: 20);
    for (var m = 0; m < 21; m++) {
      await s.save(report(m));
    }
    final minutes = [for (final r in await s.list()) r.endedAt.minute];
    expect(minutes, hasLength(20));
    expect(minutes, isNot(contains(0)));
    expect(minutes.first, 20);
  });

  test('a broken file is skipped', () async {
    final s = store();
    await s.save(report(1));
    File('${root.path}/form_reports/999.json').writeAsStringSync('{"cut');
    expect([for (final r in await s.list()) r.endedAt.minute], [1]);
  });

  test('without a files folder nothing is kept and nothing fails', () async {
    final s = FileFormReportStore(root: () async => null);
    await s.save(report(1));
    expect(await s.list(), isEmpty);
    expect(await s.latest(), isNull);
  });

  test('latest skips a newer file that cannot be read', () async {
    final s = store();
    await s.save(report(4));
    File(
      '${root.path}${Platform.pathSeparator}form_reports${Platform.pathSeparator}9999999999999.json',
    ).writeAsStringSync('{');
    expect((await s.latest())!.endedAt.minute, 4);
  });
}
