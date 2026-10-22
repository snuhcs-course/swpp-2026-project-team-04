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
        RejectReason.kneesDown: '무릎을 바닥에서 떼요',
        RejectReason.armsStraight: '팔을 굽혀서 내려요',
        RejectReason.bellyDown: '배를 바닥에서 떼요',
        RejectReason.notFloorPushUp: '바닥에서 푸시업해요',
        RejectReason.phoneMoved: '폰을 고정해 주세요',
      },
    );
  });
}
