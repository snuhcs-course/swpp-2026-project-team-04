import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/hold_record.dart';
import 'package:gymrats_app/services/feedback/hold_record_store.dart';
import 'package:gymrats_app/viewmodels/hold_report_viewmodel.dart';

import '../models/hold_record_test.dart' show holdRecord;

class _SlowStore implements HoldRecordStore {
  final gate = Completer<void>();
  List<HoldRecord> kept = const [];
  Object? error;

  @override
  Future<void> save(HoldRecord record) async {}

  @override
  Future<List<HoldRecord>> list() async {
    await gate.future;
    if (error case final e?) throw e;
    return kept;
  }
}

void main() {
  final record = holdRecord();
  final earlier = holdRecord(
    endedAt: DateTime(2026, 11, 25, 9),
    heldMs: 20000,
    elapsedMs: 20000,
    warnings: const [],
    pauses: const [],
  );

  test('the numbers of the hold at once, compared after load', () async {
    final store = InMemoryHoldRecordStore();
    await store.save(earlier);
    await store.save(record);
    final vm = HoldReportViewModel(record: record, store: store);
    expect(vm.loaded, isFalse);
    expect(vm.metrics.recentHeld, isNull);
    var told = 0;
    vm.addListener(() => told++);
    await vm.load();
    expect(vm.loaded, isTrue);
    expect(told, 1);
    expect(vm.metrics.recentHeld, 20);
    expect(vm.metrics.best, isTrue);
  });

  test('a given body weight is used', () {
    final vm = HoldReportViewModel(record: record, weightKg: 80);
    expect(vm.metrics.weightKg, 80);
    expect(vm.metrics.weightAssumed, isFalse);
  });

  test('no store: loaded with nothing to compare', () async {
    final vm = HoldReportViewModel(record: record);
    await vm.load();
    expect(vm.loaded, isTrue);
    expect(vm.metrics.earlier, isEmpty);
  });

  test('a failing store leaves the report without comparisons', () async {
    final store = _SlowStore()..error = StateError('no files');
    final vm = HoldReportViewModel(record: record, store: store);
    store.gate.complete();
    await vm.load();
    expect(vm.loaded, isTrue);
    expect(vm.metrics.recentHeld, isNull);
  });

  test('nothing changes after dispose', () async {
    final store = _SlowStore()..kept = [earlier];
    final vm = HoldReportViewModel(record: record, store: store);
    final loading = vm.load();
    vm.dispose();
    store.gate.complete();
    await loading;
    expect(vm.loaded, isFalse);
  });
}
