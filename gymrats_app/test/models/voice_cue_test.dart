import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/voice_cue.dart';

void main() {
  test('every cue has a Korean line to speak', () {
    for (final cue in VoiceCue.values) {
      expect(cue.text.trim(), isNotEmpty, reason: cue.name);
      expect(cue.text, matches(RegExp(r'[가-힣]')), reason: cue.name);
    }
  });

  test('the lines are distinct', () {
    final texts = VoiceCue.values.map((c) => c.text).toSet();
    expect(texts, hasLength(VoiceCue.values.length));
  });

  test('battle events, ready, and the countdown cut off the current line; '
      'setup hints wait', () {
    final interrupting = VoiceCue.values.where((c) => c.interrupts).toSet();
    final waiting = VoiceCue.values.where((c) => !c.interrupts).toSet();
    expect(
      interrupting,
      containsAll({
        VoiceCue.ready,
        VoiceCue.countdownThree,
        VoiceCue.countdownTwo,
        VoiceCue.countdownOne,
        VoiceCue.battleStart,
        VoiceCue.fever,
        VoiceCue.lastSeconds,
        VoiceCue.ko,
        VoiceCue.timeUp,
        VoiceCue.win,
        VoiceCue.lose,
        VoiceCue.draw,
      }),
    );
    expect(
      waiting,
      everyElement(predicate<VoiceCue>((c) => c.group == VoiceCueGroup.setup)),
    );
    expect(waiting, contains(VoiceCue.noPerson));
    expect(waiting, contains(VoiceCue.holdStill));
  });

  test('battle cues are in the battle group and interrupt', () {
    final battle = VoiceCue.values.where(
      (c) => c.group == VoiceCueGroup.battle,
    );
    expect(battle, isNotEmpty);
    expect(battle, everyElement(predicate<VoiceCue>((c) => c.interrupts)));
  });
}
