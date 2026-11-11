/// Which part of the app a voice line belongs to.
enum VoiceCueGroup { setup, battle }

/// A line the voice guidance can say, with its Korean text.
///
/// Setup lines repeat the setup screen's hint ("what to fix") and the ready
/// countdown; battle lines mark the round's events. The text is spoken by the
/// device's Korean TTS, so changing a line is changing a string here.
enum VoiceCue {
  // Setup: what to fix.
  noPerson('카메라 앞에 서 주세요.', VoiceCueGroup.setup),
  tooClose('조금 뒤로 물러나 주세요.', VoiceCueGroup.setup),
  tooFar('카메라에 조금 더 가까이 와 주세요.', VoiceCueGroup.setup),
  notFacingForward('카메라를 정면으로 봐 주세요.', VoiceCueGroup.setup),
  missingParts('몸 전체가 화면에 보이게 해 주세요.', VoiceCueGroup.setup),
  notInPushUp('팔을 펴고 푸시업 자세를 잡아 주세요.', VoiceCueGroup.setup),
  notStanding('정면을 보고 똑바로 서 주세요.', VoiceCueGroup.setup),
  phoneTooFlat('폰을 더 세워 주세요.', VoiceCueGroup.setup),
  phoneShaky('폰이 흔들리지 않게 두세요.', VoiceCueGroup.setup),
  holdStill('그대로 잠시 유지하세요.', VoiceCueGroup.setup),

  // Setup: ready and the start countdown.
  ready('준비 완료!', VoiceCueGroup.setup, interrupts: true),
  countdownThree('셋', VoiceCueGroup.setup, interrupts: true),
  countdownTwo('둘', VoiceCueGroup.setup, interrupts: true),
  countdownOne('하나', VoiceCueGroup.setup, interrupts: true),

  // Battle events.
  battleStart('시작!', VoiceCueGroup.battle, interrupts: true),
  fever('피버 타임!', VoiceCueGroup.battle, interrupts: true),
  lastSeconds('마지막 스퍼트!', VoiceCueGroup.battle, interrupts: true),
  ko('케이오!', VoiceCueGroup.battle, interrupts: true),
  timeUp('타임 업!', VoiceCueGroup.battle, interrupts: true),
  win('승리!', VoiceCueGroup.battle, interrupts: true),
  lose('패배.', VoiceCueGroup.battle, interrupts: true),
  draw('무승부.', VoiceCueGroup.battle, interrupts: true);

  const VoiceCue(this.text, this.group, {this.interrupts = false});

  /// What is spoken.
  final String text;

  final VoiceCueGroup group;

  /// Whether this line cuts off a line that is still being spoken. Events
  /// (ready, countdown, KO, ...) do; setup hints wait their turn.
  final bool interrupts;
}
