import 'dart:convert';
import 'dart:io';

import '../../gymrats_app/lib/models/rep_event.dart';
import '../../gymrats_app/lib/services/pose/rep_judge.dart';

Future<void> main(List<String> args) async {
  final sink = File(args[1]).openWrite();
  for (final line in File(args[0]).readAsLinesSync()) {
    final row = jsonDecode(line), events = <List<Object>>[];
    for (final p in row['primary']) {
      final label = p[1] as String;
      final ev = RepEvent(
        index: 1,
        valid: label == 'normal',
        at: Duration.zero,
        reason: label == 'normal' ? null : RejectReason.values.byName(label),
      );
      final out = calibratePushupPrimary(
        ev,
        (p[2] as List?)?.map((n) => (n as num?)?.toDouble()).toList(),
        observedReturn: p[3] as bool,
      );
      events.add([p[0] as int, out.valid ? 'normal' : out.reason!.name]);
    }
    sink.writeln(
      jsonEncode({
        'source_id': row['source_id'],
        'events': {'selected': events},
      }),
    );
  }
  await sink.close();
}
