import 'package:flutter/foundation.dart';

import '../models/hold_record.dart';
import '../services/feedback/hold_metrics.dart';
import '../services/feedback/hold_record_store.dart';

/// The hold report of one played hold (P13, design H-A): its numbers at
/// once, and against the earlier holds of the pose once [load] has read
/// them from [store].
class HoldReportViewModel extends ChangeNotifier {
  HoldReportViewModel({required this.record, this.store, this.weightKg})
    : _metrics = HoldMetrics.of(record, weightKg: weightKg);

  final HoldRecord record;

  /// The holds kept on the phone; null compares with nothing.
  final HoldRecordStore? store;

  /// The user's body weight for the calories; null uses 65 kg.
  final double? weightKg;

  HoldMetrics _metrics;
  bool _loaded = false;
  bool _disposed = false;

  HoldMetrics get metrics => _metrics;

  /// Whether the earlier holds were read (or there was nothing to read).
  bool get loaded => _loaded;

  /// Reads the earlier holds; a store that fails leaves the report as it
  /// is, without comparisons.
  Future<void> load() async {
    final store = this.store;
    var kept = const <HoldRecord>[];
    if (store != null) {
      try {
        kept = await store.list();
      } on Object {
        kept = const [];
      }
    }
    if (_disposed) return;
    _metrics = HoldMetrics.of(record, weightKg: weightKg, kept: kept);
    _loaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
