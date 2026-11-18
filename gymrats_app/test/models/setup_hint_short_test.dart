import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/setup_hint_short.dart';
import 'package:gymrats_app/services/pose/setup_checker.dart';

SetupStatus _status(
  SetupReason reason, {
  bool isReady = false,
  List<BodyPart> missing = const [],
}) => SetupStatus(
  reason: reason,
  isReady: isReady,
  readyProgress: 0,
  missingParts: missing,
);

/// The cue's two lines, icon and state, for a compact expectation.
(String, String, SetupCueIcon, SetupCueState) _look(SetupHintShort cue) =>
    (cue.first, cue.second, cue.icon, cue.state);

void main() {
  group('SetupHintShort.of: the A9 spec 2 table', () {
    const mismatch = SetupCueState.mismatch;
    final cases = <SetupReason, (String, String, SetupCueIcon, SetupCueState)>{
      SetupReason.noPerson: ('카메라', '앞으로', SetupCueIcon.person, mismatch),
      SetupReason.tooClose: ('한 걸음', '뒤로', SetupCueIcon.stepBack, mismatch),
      SetupReason.tooFar: ('조금 더', '가까이', SetupCueIcon.stepCloser, mismatch),
      SetupReason.notFacingForward: (
        '정면을',
        '봐요',
        SetupCueIcon.person,
        mismatch,
      ),
      SetupReason.notInPushUp: ('푸시업', '자세로', SetupCueIcon.person, mismatch),
      SetupReason.notStanding: ('똑바로', '서요', SetupCueIcon.person, mismatch),
      SetupReason.phoneTooFlat: ('폰을 더', '세워요', SetupCueIcon.phone, mismatch),
      SetupReason.phoneShaky: ('폰을', '고정해요', SetupCueIcon.phone, mismatch),
    };
    for (final MapEntry(key: reason, value: look) in cases.entries) {
      test('${reason.name}: ${look.$1} / ${look.$2}', () {
        final status = _status(reason);
        final cue = SetupHintShort.of(status);
        expect(_look(cue), look);
        expect(cue.holding, isFalse);
        // A screen reader hears the setup's own sentence, as the voice says.
        expect(cue.message, status.message);
      });
    }

    test('the pose held: 그대로 / 멈춰요, the check, right, with the hold bar', () {
      final status = _status(SetupReason.ready);
      final cue = SetupHintShort.of(status);
      expect(_look(cue), (
        '그대로',
        '멈춰요',
        SetupCueIcon.check,
        SetupCueState.match,
      ));
      expect(cue.holding, isTrue);
      expect(cue.message, '그대로 잠시 유지하세요.');
    });

    test('ready: 준비 / 완료!, the check, right, no hold bar; even while the '
        'latest frame is off but ready has not dropped yet', () {
      for (final reason in [SetupReason.ready, SetupReason.tooClose]) {
        final cue = SetupHintShort.of(_status(reason, isReady: true));
        expect(_look(cue), (
          '준비',
          '완료!',
          SetupCueIcon.check,
          SetupCueState.match,
        ));
        expect(cue.holding, isFalse);
        expect(cue.message, '준비 완료!');
      }
    });

    test('a squat outside the silhouette comes first: 실루엣에 / 맞춰요', () {
      for (final isReady in [false, true]) {
        final cue = SetupHintShort.of(
          _status(SetupReason.ready, isReady: isReady),
          outsideSilhouette: true,
        );
        expect(_look(cue), (
          '실루엣에',
          '맞춰요',
          SetupCueIcon.person,
          SetupCueState.mismatch,
        ));
        expect(cue.message, '실루엣 안에 몸을 맞춰 주세요.');
        expect(cue.message, SetupHintShort.silhouetteMessage);
      }
    });

    test('every cue that is not right is red, and every right one shows the '
        'check, so the state is never told by color alone', () {
      for (final reason in SetupReason.values) {
        for (final isReady in [false, true]) {
          final cue = SetupHintShort.of(
            _status(reason, isReady: isReady, missing: [BodyPart.head]),
          );
          expect(
            cue.state == SetupCueState.match,
            cue.icon == SetupCueIcon.check,
            reason: '$reason ready $isReady',
          );
        }
      }
    });
  });

  group('SetupHintShort.of: missing parts (task.md W9 decision 7)', () {
    SetupHintShort missing(List<BodyPart> parts) =>
        SetupHintShort.of(_status(SetupReason.missingParts, missing: parts));

    test('one part: its name and subject marker, then 안 보여요', () {
      expect(_look(missing([BodyPart.head])), (
        '머리가',
        '안 보여요',
        SetupCueIcon.person,
        SetupCueState.mismatch,
      ));
      expect(missing([BodyPart.ankles]).first, '발목이');
      expect(missing([BodyPart.hips]).first, '엉덩이가');
      expect(missing([BodyPart.shoulders]).first, '어깨가');
      expect(missing([BodyPart.knees]).first, '무릎이');
      expect(missing([BodyPart.head]).message, '머리가 화면에 안 보여요.');
    });

    test('the hands and the elbows show the hand; the other parts the '
        'person', () {
      expect(missing([BodyPart.hands]).first, '손이');
      expect(missing([BodyPart.hands]).icon, SetupCueIcon.hand);
      expect(missing([BodyPart.elbows]).first, '팔꿈치가');
      expect(missing([BodyPart.elbows]).icon, SetupCueIcon.hand);
      expect(missing([BodyPart.knees]).icon, SetupCueIcon.person);
    });

    test('two parts: both names joined by a dot, the marker fitted to the '
        'last; the hand only when both are arms', () {
      final arms = missing([BodyPart.elbows, BodyPart.hands]);
      expect(_look(arms), (
        '팔꿈치·손이',
        '안 보여요',
        SetupCueIcon.hand,
        SetupCueState.mismatch,
      ));
      expect(arms.message, '팔꿈치, 손이 화면에 안 보여요.');
      final mixed = missing([BodyPart.shoulders, BodyPart.elbows]);
      expect(mixed.first, '어깨·팔꿈치가');
      expect(mixed.icon, SetupCueIcon.person);
      expect(missing([BodyPart.hips, BodyPart.ankles]).first, '엉덩이·발목이');
    });

    test('three or more, or none named: 몸 전체가 / 보이게', () {
      for (final parts in [
        <BodyPart>[],
        [BodyPart.shoulders, BodyPart.hips, BodyPart.knees],
        BodyPart.values,
      ]) {
        final cue = missing(parts);
        expect(_look(cue), (
          '몸 전체가',
          '보이게',
          SetupCueIcon.person,
          SetupCueState.mismatch,
        ));
        expect(cue.message, '몸 전체가 화면에 보이게 해 주세요.');
      }
    });

    test('the subject marker: 이 after a final consonant, 가 after a vowel or '
        'a letter that is not Hangul', () {
      expect(SetupHintShort.subjectMarker('손'), '이');
      expect(SetupHintShort.subjectMarker('발목'), '이');
      expect(SetupHintShort.subjectMarker('머리'), '가');
      expect(SetupHintShort.subjectMarker('어깨'), '가');
      expect(SetupHintShort.subjectMarker('A'), '가');
      // The same rule as the setup's own sentence.
      for (final part in BodyPart.values) {
        expect(
          SetupHintShort.of(_status(SetupReason.missingParts, missing: [part]))
              .first,
          startsWith(part.label),
        );
        expect(
          _status(SetupReason.missingParts, missing: [part]).message,
          startsWith(
            '${part.label}${SetupHintShort.subjectMarker(part.label)} ',
          ),
        );
      }
    });
  });

  group('the online setup\'s own cues (task.md W9 decision 5)', () {
    test('waiting for the opponent: 상대를 / 기다려요, the check, right', () {
      const cue = SetupHintShort.waitingForOpponent();
      expect(_look(cue), (
        '상대를',
        '기다려요',
        SetupCueIcon.check,
        SetupCueState.match,
      ));
      expect(cue.holding, isFalse);
      expect(cue.message, '상대 준비를 기다리는 중…');
    });

    test('the count to the auto ready: 그대로 / 멈춰요 with the hold bar, the '
        'count in its sentence', () {
      final cue = SetupHintShort.autoReady(2);
      expect(_look(cue), (
        '그대로',
        '멈춰요',
        SetupCueIcon.check,
        SetupCueState.match,
      ));
      expect(cue.holding, isTrue);
      expect(cue.message, '자세 확인! 2초 후 자동으로 준비해요');
    });

    test('reconnecting: 연결 / 확인 중, the connection, a notice', () {
      const cue = SetupHintShort.reconnecting();
      expect(_look(cue), (
        '연결',
        '확인 중',
        SetupCueIcon.connection,
        SetupCueState.notice,
      ));
      expect(cue.message, '재연결 중 · 준비 상태 확인 중…');
    });
  });

  group('the same cue', () {
    test('looks alike whatever its sentence: a count is the same cue', () {
      final two = SetupHintShort.autoReady(2);
      final one = SetupHintShort.autoReady(1);
      expect(two.looksLike(one), isTrue);
      expect(two == one, isFalse);
      // The held pose and the auto ready count read the same, but only the
      // first sentence is the setup's.
      expect(
        two.looksLike(SetupHintShort.of(_status(SetupReason.ready))),
        isTrue,
      );
    });

    test('another line, icon, state or hold bar is another cue', () {
      final held = SetupHintShort.of(_status(SetupReason.ready));
      final ready = SetupHintShort.of(
        _status(SetupReason.ready, isReady: true),
      );
      expect(held.looksLike(ready), isFalse);
      const base = SetupHintShort(
        first: 'a',
        second: 'b',
        icon: SetupCueIcon.person,
        state: SetupCueState.mismatch,
        message: 'm',
      );
      for (final other in const [
        SetupHintShort(
          first: 'x',
          second: 'b',
          icon: SetupCueIcon.person,
          state: SetupCueState.mismatch,
          message: 'm',
        ),
        SetupHintShort(
          first: 'a',
          second: 'x',
          icon: SetupCueIcon.person,
          state: SetupCueState.mismatch,
          message: 'm',
        ),
        SetupHintShort(
          first: 'a',
          second: 'b',
          icon: SetupCueIcon.phone,
          state: SetupCueState.mismatch,
          message: 'm',
        ),
        SetupHintShort(
          first: 'a',
          second: 'b',
          icon: SetupCueIcon.person,
          state: SetupCueState.notice,
          message: 'm',
        ),
        SetupHintShort(
          first: 'a',
          second: 'b',
          icon: SetupCueIcon.person,
          state: SetupCueState.mismatch,
          message: 'm',
          holding: true,
        ),
      ]) {
        expect(base.looksLike(other), isFalse, reason: '$other');
        expect(base == other, isFalse);
      }
    });

    test('equal cues are equal and hash alike, and say what they are', () {
      final a = SetupHintShort.of(_status(SetupReason.tooFar));
      final b = SetupHintShort.of(_status(SetupReason.tooFar));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('조금 더 / 가까이'));
    });
  });
}
