import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/arcade_stage.dart';
import 'package:gymrats_app/models/hold_record.dart';

HoldRecord holdRecord({
  DateTime? endedAt,
  HoldPose pose = HoldPose.plank,
  int heldMs = 24600,
  int elapsedMs = 26700,
  int stars = 2,
  List<int> starSeconds = const [15, 20, 30],
  List<HoldRecordWarning>? warnings,
  List<HoldRecordPause>? pauses,
  bool endedByWarnings = true,
}) => HoldRecord(
  endedAt: endedAt ?? DateTime(2026, 11, 26, 21, 10),
  pose: pose,
  stage: 3,
  held: Duration(milliseconds: heldMs),
  elapsed: Duration(milliseconds: elapsedMs),
  stars: stars,
  starSeconds: starSeconds,
  warnings:
      warnings ??
      const [
        HoldRecordWarning(
          at: Duration(seconds: 12),
          faultId: 'plank.kneeDown',
          words: '무릎 떼요',
        ),
        HoldRecordWarning(
          at: Duration(milliseconds: 26700),
          faultId: 'plank.headDown',
          words: '머리 들어요',
        ),
      ],
  pauses:
      pauses ??
      const [
        HoldRecordPause(
          start: Duration(seconds: 12),
          end: Duration(milliseconds: 14100),
        ),
      ],
  endedByWarnings: endedByWarnings,
);

void main() {
  group('HoldRecord (P13)', () {
    test('goes to JSON and back unchanged', () {
      final record = holdRecord();
      final back = HoldRecord.fromJson(record.toJson());
      expect(back.endedAt, record.endedAt);
      expect(back.pose, HoldPose.plank);
      expect(back.stage, 3);
      expect(back.held, const Duration(milliseconds: 24600));
      expect(back.elapsed, const Duration(milliseconds: 26700));
      expect(back.stars, 2);
      expect(back.starSeconds, [15, 20, 30]);
      expect(back.warnings.map((w) => (w.at, w.faultId, w.words)), [
        (const Duration(seconds: 12), 'plank.kneeDown', '무릎 떼요'),
        (const Duration(milliseconds: 26700), 'plank.headDown', '머리 들어요'),
      ]);
      expect(back.pauses.single.length, const Duration(milliseconds: 2100));
      expect(back.endedByWarnings, isTrue);
      expect(back.id, record.id);
    });

    test('keeps only numbers: no frames, joints or video', () {
      final json = holdRecord().toJson();
      expect(json.keys.toSet(), {
        'ended_at',
        'pose',
        'stage',
        'held_ms',
        'elapsed_ms',
        'stars',
        'star_seconds',
        'warnings',
        'pauses',
        'ended_by_warnings',
      });
      expect(json['ended_at'], endsWith('Z'));
    });

    test('a chair hold without warnings', () {
      final back = HoldRecord.fromJson(
        holdRecord(
          pose: HoldPose.chair,
          warnings: const [],
          pauses: const [],
          endedByWarnings: false,
        ).toJson(),
      );
      expect(back.pose, HoldPose.chair);
      expect(back.warnings, isEmpty);
      expect(back.pauses, isEmpty);
    });

    test('a map it did not write is refused', () {
      expect(() => HoldRecord.fromJson({'pose': 'plank'}), throwsA(anything));
      expect(
        () => HoldRecord.fromJson({...holdRecord().toJson(), 'pose': 'wall'}),
        throwsArgumentError,
      );
    });

    test('the id is the end time', () {
      final at = DateTime(2026, 11, 26, 21, 10);
      expect(holdRecord(endedAt: at).id, '${at.microsecondsSinceEpoch}');
    });
  });
}
