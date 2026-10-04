import 'rep_event.dart';

/// Korean reasons for the battle's "카운트 안 됨" banner.
///
/// [RejectReason.message] is English, and rep_event.dart belongs to the rep
/// judge, so the Korean texts live here.
extension RejectReasonKorean on RejectReason {
  /// What to fix, e.g. "가슴을 더 내려요".
  String get koreanMessage => switch (this) {
    RejectReason.insufficientDepth => '가슴을 더 내려요',
    RejectReason.incompleteExtension => '팔을 끝까지 펴요',
    RejectReason.shouldersNotLevel => '어깨를 수평으로 맞춰요',
    RejectReason.tooFast => '조금 천천히 해요',
  };
}
