import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/reject_reason_korean.dart';
import 'package:gymrats_app/models/rep_event.dart';

void main() {
  test('every reject reason says in Korean what to fix', () {
    expect(
      {for (final reason in RejectReason.values) reason: reason.koreanMessage},
      {
        RejectReason.insufficientDepth: '가슴을 더 내려요',
        RejectReason.incompleteExtension: '팔을 끝까지 펴요',
        RejectReason.shouldersNotLevel: '어깨를 수평으로 맞춰요',
        RejectReason.tooFast: '조금 천천히 해요',
      },
    );
  });
}
