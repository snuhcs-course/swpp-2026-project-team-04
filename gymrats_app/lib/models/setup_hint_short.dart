import '../services/pose/setup_checker.dart';

/// The picture in the setup band's icon box (A9 spec 2): an ink line icon.
enum SetupCueIcon {
  /// The pose is right: always the check, so the state is never told by
  /// color alone.
  check,

  /// The body: where it is, how it faces, how it stands.
  person,

  /// A phone with an arrow going away from it: step back.
  stepBack,

  /// A phone with an arrow coming to it: come closer.
  stepCloser,

  /// The hands or elbows are not seen.
  hand,

  /// The phone itself: its angle or its shaking.
  phone,

  /// The connection to the battle server.
  connection,
}

/// How the setup stands, as the band and the camera area's frame show it.
enum SetupCueState {
  /// Right: green.
  match,

  /// Something to fix: red.
  mismatch,

  /// Not about the pose (the connection): amber, and no frame.
  notice,
}

/// The setup's short cue, drawn large enough to read from where the user
/// exercises (A9 spec 2, design UxSq variant A2): two short lines, an icon,
/// and whether the setup is right. The long sentence it stands for
/// ([message], the same words as the voice) is what a screen reader hears.
///
/// It only says what the setup check already found ([SetupStatus]); it
/// decides nothing itself.
class SetupHintShort {
  const SetupHintShort({
    required this.first,
    required this.second,
    required this.icon,
    required this.state,
    required this.message,
    this.holding = false,
  });

  /// The cue for [status]. [outsideSilhouette] is true for a squat whose
  /// pose is right but which is not in the silhouette yet; that comes first,
  /// as on the battle screens.
  factory SetupHintShort.of(
    SetupStatus status, {
    bool outsideSilhouette = false,
  }) {
    if (outsideSilhouette) {
      return const SetupHintShort(
        first: '실루엣에',
        second: '맞춰요',
        icon: SetupCueIcon.person,
        state: SetupCueState.mismatch,
        message: silhouetteMessage,
      );
    }
    final message = status.message;
    SetupHintShort fix(String first, String second, SetupCueIcon icon) =>
        SetupHintShort(
          first: first,
          second: second,
          icon: icon,
          state: SetupCueState.mismatch,
          message: message,
        );
    if (status.isReady) {
      return SetupHintShort(
        first: '준비',
        second: '완료!',
        icon: SetupCueIcon.check,
        state: SetupCueState.match,
        message: message,
      );
    }
    return switch (status.reason) {
      SetupReason.ready => SetupHintShort(
        first: '그대로',
        second: '멈춰요',
        icon: SetupCueIcon.check,
        state: SetupCueState.match,
        message: message,
        holding: true,
      ),
      SetupReason.noPerson => fix('카메라', '앞으로', SetupCueIcon.person),
      SetupReason.tooClose => fix('한 걸음', '뒤로', SetupCueIcon.stepBack),
      SetupReason.tooFar => fix('조금 더', '가까이', SetupCueIcon.stepCloser),
      SetupReason.notFacingForward => fix('정면을', '봐요', SetupCueIcon.person),
      SetupReason.missingParts => _missing(status.missingParts, message),
      SetupReason.notInPushUp => fix('푸시업', '자세로', SetupCueIcon.person),
      SetupReason.notStanding => fix('똑바로', '서요', SetupCueIcon.person),
      SetupReason.phoneTooFlat => fix('폰을 더', '세워요', SetupCueIcon.phone),
      SetupReason.phoneShaky => fix('폰을', '고정해요', SetupCueIcon.phone),
    };
  }

  /// Online, the user is ready and the opponent is not yet.
  const SetupHintShort.waitingForOpponent()
    : first = '상대를',
      second = '기다려요',
      icon = SetupCueIcon.check,
      state = SetupCueState.match,
      message = '상대 준비를 기다리는 중…',
      holding = false;

  /// Online, the pose holds and ready goes by itself in [seconds]; the hold
  /// bar fills with that count.
  SetupHintShort.autoReady(int seconds)
    : first = '그대로',
      second = '멈춰요',
      icon = SetupCueIcon.check,
      state = SetupCueState.match,
      message = '자세 확인! $seconds초 후 자동으로 준비해요',
      holding = true;

  /// Online, the connection is down before the start.
  const SetupHintShort.reconnecting()
    : first = '연결',
      second = '확인 중',
      icon = SetupCueIcon.connection,
      state = SetupCueState.notice,
      message = '재연결 중 · 준비 상태 확인 중…',
      holding = false;

  /// What a screen reader hears for a squat outside the silhouette: the
  /// battle screens' sentence for it.
  static const silhouetteMessage = '실루엣 안에 몸을 맞춰 주세요.';

  /// The two lines, each one line on screen.
  final String first;
  final String second;

  final SetupCueIcon icon;
  final SetupCueState state;

  /// The long sentence: the setup's own words ([SetupStatus.message]).
  final String message;

  /// Whether the pose is being held: the band shows the hold bar.
  final bool holding;

  /// Whether the two show the same cue, whatever their sentences: the band
  /// keeps a cue for a moment before another replaces it, and a sentence
  /// that only counts down is the same cue.
  bool looksLike(SetupHintShort other) =>
      first == other.first &&
      second == other.second &&
      icon == other.icon &&
      state == other.state &&
      holding == other.holding;

  @override
  bool operator ==(Object other) =>
      other is SetupHintShort && looksLike(other) && message == other.message;

  @override
  int get hashCode => Object.hash(first, second, icon, state, message, holding);

  @override
  String toString() => 'SetupHintShort($first / $second, $icon, $state)';

  /// At most this many missing parts are named, as in [SetupStatus.message].
  static const _namedPartsAtMost = 2;

  /// "손이 / 안 보여요", "팔꿈치·손이 / 안 보여요": the parts in order, the
  /// subject marker fitted to the last one, and '안' on the second line so
  /// the first fits (task.md W9 decision 7). With none, or more than two,
  /// the whole body.
  static SetupHintShort _missing(List<BodyPart> parts, String message) {
    if (parts.isEmpty || parts.length > _namedPartsAtMost) {
      return SetupHintShort(
        first: '몸 전체가',
        second: '보이게',
        icon: SetupCueIcon.person,
        state: SetupCueState.mismatch,
        message: message,
      );
    }
    final names = parts.map((p) => p.label).join('·');
    final hands = parts.every(
      (p) => p == BodyPart.hands || p == BodyPart.elbows,
    );
    return SetupHintShort(
      first: '$names${subjectMarker(parts.last.label)}',
      second: '안 보여요',
      icon: hands ? SetupCueIcon.hand : SetupCueIcon.person,
      state: SetupCueState.mismatch,
      message: message,
    );
  }

  /// 이 after a final consonant (손이, 발목이), 가 after a vowel (머리가): the
  /// rule [SetupStatus.message] uses, which keeps it to itself.
  static String subjectMarker(String word) {
    const first = 0xAC00, last = 0xD7A3, finals = 28;
    final code = word.runes.last;
    final closed =
        code >= first && code <= last && (code - first) % finals != 0;
    return closed ? '이' : '가';
  }
}
