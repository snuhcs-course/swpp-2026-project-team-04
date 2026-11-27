import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_goal.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/feedback/coach_script.dart';
import 'package:gymrats_app/services/feedback/form_analyzer.dart';
import 'package:gymrats_app/services/game/player_game_score.dart';

import '../../support/goal_fixtures.dart';

/// The design's battle (UxDlg / UxGfx): a squat with 18 counted reps,
/// 5, 5, 2, 2, 2, 2 per 5 s, and 3 too shallow late in the round.
final _designReport = coachReport(
  valid: designPace(),
  rejected: const [
    (19.4, RejectReason.shallowSquat),
    (24.2, RejectReason.shallowSquat),
    (28.8, RejectReason.shallowSquat),
  ],
);

/// Five earlier battles averaging 16, at 3 a slice early and 3 then 2 late
/// (a usual 0.6 then 0.5 reps a second), the longest combo 6.
final _usualEarlier = [
  for (final reps in const [14, 17, 15, 18, 16])
    earlierBattle(reps, buckets: const [3, 3, 3, 3, 2, 2], combo: 6),
];

CoachScript _build(
  CoachInput input, {
  List<CoachTalkStep> steps = CoachScript.defaultSteps,
}) => CoachScript.build(input, steps: steps);

/// The marked runs of [line].
List<String> _marks(CoachLine line) => [
  for (final p in line.pieces)
    if (p.marked) p.text,
];

/// Each character's ending (A10 spec 4.4), written here apart from the code.
const _endings = {
  'mouse': '찍',
  'kangaroo': '깡',
  'bear': '곰',
  'penguin': '펭',
  'seal': '범',
};

/// A squat goal of [kind] set with 그루 the day before the battle.
FeedbackGoal _lastGoalOf(GoalKind kind, int target, String title) =>
    FeedbackGoal(
      exercise: ExerciseType.squat,
      kind: kind,
      target: target,
      baseline: 0,
      title: title,
      setAt: coachEndedAt.subtract(const Duration(days: 1)),
      characterId: 'kangaroo',
      fromMatch: 'earlier',
    );

/// [report]'s talk by [characterId], checking [goal] first.
CoachInput _checkingGoal(
  FormReport report,
  FeedbackGoal goal, {
  required String characterId,
  List<CoachEarlier> earlier = const [],
}) {
  final base = coachInputOf(report, characterId: characterId, earlier: earlier);
  return CoachInput(
    report: base.report,
    findings: base.findings,
    pace: base.pace,
    characterId: characterId,
    earlier: base.earlier,
    lastGoal: goal,
  );
}

/// Talks by [id] that together take every branch of the script (A9 spec
/// 5.1); [_branchMarks] checks that none is missing.
List<(String, CoachInput)> _talks(String id) {
  List<CoachEarlier> reps(List<int> earlier) => [
    for (final r in earlier) earlierBattle(r),
  ];
  CoachInput plain(
    FormReport report, {
    List<CoachEarlier> earlier = const [],
  }) => coachInputOf(report, characterId: id, earlier: earlier);
  CoachInput checking(
    FormReport report,
    GoalKind kind,
    int target,
    String title, {
    List<CoachEarlier> earlier = const [],
  }) => _checkingGoal(
    report,
    _lastGoalOf(kind, target, title),
    characterId: id,
    earlier: earlier,
  );
  final few = coachReport(valid: const [1, 2, 3]);
  final imbalanced = coachReport(valid: evenly(8));
  const shallow = RejectReason.shallowSquat;
  return [
    ('the design battle', plain(_designReport, earlier: _usualEarlier)),
    ('a first battle', plain(_designReport)),
    ('an even first battle', plain(coachReport(valid: evenly(12)))),
    (
      'as many as the average',
      plain(coachReport(valid: evenly(18)), earlier: reps(const [18, 18])),
    ),
    (
      'fewer than the average',
      plain(coachReport(valid: evenly(12)), earlier: reps(const [15, 16])),
    ),
    (
      'a combo record, nothing to fix',
      plain(
        coachReport(valid: evenly(10, from: 1, to: 10)),
        earlier: [
          earlierBattle(9, buckets: const [2, 2, 2, 1, 1, 1], combo: 4),
        ],
      ),
    ),
    (
      'mixed rejections',
      plain(
        coachReport(
          exercise: ExerciseType.pushUp,
          valid: evenly(8),
          rejected: const [
            (3, RejectReason.phoneMoved),
            (6, RejectReason.phoneMoved),
            (8, RejectReason.insufficientDepth),
          ],
        ),
      ),
    ),
    (
      'another issue',
      CoachInput(
        report: imbalanced,
        findings: const [
          FormFinding(
            kind: FindingKind.issue,
            code: 'imbalance',
            title: '좌우 불균형',
            detail: '양팔 각도가 평균 20° 달라요.',
          ),
        ],
        pace: paceOf(imbalanced),
        characterId: id,
      ),
    ),
    (
      'three reps, nothing else to say',
      CoachInput(
        report: few,
        findings: const [],
        pace: paceOf(few),
        characterId: id,
      ),
    ),
    (
      'reps reached',
      checking(
        coachReport(valid: evenly(21)),
        GoalKind.reps,
        20,
        '스쿼트 20회 인정받기',
      ),
    ),
    (
      'reps reached, above the average',
      checking(
        coachReport(valid: evenly(21)),
        GoalKind.reps,
        20,
        '스쿼트 20회 인정받기',
        earlier: _usualEarlier,
      ),
    ),
    (
      'reps reached, as many as the average',
      checking(
        coachReport(valid: evenly(16)),
        GoalKind.reps,
        15,
        '스쿼트 15회 인정받기',
        earlier: reps(const [16, 16]),
      ),
    ),
    (
      'reps reached, fewer than the average',
      checking(
        coachReport(valid: evenly(12)),
        GoalKind.reps,
        10,
        '스쿼트 10회 인정받기',
        earlier: reps(const [15, 16]),
      ),
    ),
    (
      'reps missed',
      checking(
        coachReport(valid: evenly(19)),
        GoalKind.reps,
        20,
        '스쿼트 20회 인정받기',
      ),
    ),
    (
      'later half reached',
      checking(
        coachReport(valid: [2, 16, 18, 20]),
        GoalKind.lateReps,
        3,
        '후반 15초에 3회 이상',
      ),
    ),
    (
      'later half missed',
      checking(
        coachReport(valid: [2, 4, 16]),
        GoalKind.lateReps,
        3,
        '후반 15초에 3회 이상',
      ),
    ),
    (
      'combo reached',
      checking(
        coachReport(valid: [1, 2, 3, 10]),
        GoalKind.combo,
        3,
        '콤보 3번 이상',
      ),
    ),
    (
      'combo missed',
      checking(coachReport(valid: [1, 2, 10]), GoalKind.combo, 4, '콤보 4번 이상'),
    ),
    (
      'no rejection at all',
      checking(coachReport(valid: [1, 2]), GoalKind.maxRejects, 1, '무효 1회 이하'),
    ),
    (
      'rejections within the limit',
      checking(
        coachReport(valid: [1], rejected: const [(5, shallow)]),
        GoalKind.maxRejects,
        1,
        '무효 1회 이하',
      ),
    ),
    (
      'rejections past the limit',
      checking(
        coachReport(
          valid: [1],
          rejected: const [(5, shallow), (6, shallow), (7, shallow)],
        ),
        GoalKind.maxRejects,
        2,
        '무효 2회 이하',
      ),
    ),
  ];
}

/// Each branch of the script (A9 spec 5.1) and words only it says.
final _branchMarks = <String, Pattern>{
  'last goal recalled': '지난번 미션 기억나? ‘',
  'reached: reps': RegExp(r'^이번에 \d+번 인정받았어\. 미션 성공'),
  'reached: later half': RegExp(r'^이번엔 후반에 \d+번 인정받았어\. 미션 성공'),
  'reached: combo': RegExp(r'^이번엔 콤보를 \d+번까지 이어 갔어\. 미션 성공'),
  'reached: no rejection': '한 번도 없었어. 미션 성공',
  'reached: within the limit': '번뿐이었어. 미션 성공',
  'missed: reps': RegExp(r'^이번엔 \d+번이라서 딱 \d+번 모자랐어\. 아깝다'),
  'missed: later half': RegExp(r'^이번엔 후반에 \d+번이라서 딱'),
  'missed: combo': RegExp(r'^이번엔 콤보가 \d+번이라서 딱'),
  'missed: rejections': '이라 미션보다 ',
  'summary: no average': RegExp(r'에서 \d+번 인정받았어\.$'),
  'summary: above the average': RegExp(r'인정받았어\. 최근 \d+판 평균보다 \d+번 더 했어!$'),
  'summary: as many': '인정받았어. 평균만큼 했어.',
  'summary: fewer': RegExp(r'인정받았어\. 평균보다 \d+번 적었지만 괜찮아\.$'),
  'summary after reps: above': RegExp(r'^최근 \d+판 평균보다 \d+번 더 했어\. 좋다'),
  'summary after reps: as many': RegExp(r'^최근 \d+판 평균만큼 했어\.$'),
  'summary after reps: fewer': RegExp(r'^최근 \d+판 평균보다는 \d+번 적었지만'),
  'pace: fast, then slower': '는 평소보다 빨랐는데',
  'pace: keep one speed': '하는 게 중요하다',
  'pace: slowed down': ' 떨어졌어. 처음부터 끝까지',
  'pace: even': '고른 속도였어. 좋다',
  'form: one reason': '은 모두 ‘',
  'form: mixed reasons': RegExp(r'번 중 \d+번이 ‘'),
  'form: tiring': '지치니까 그랬던 것 같아',
  'form: another issue': '가장 눈에 띈 건 ‘',
  'praise: combo record': RegExp(r'^콤보는 \d+번까지'),
  'praise: combo record after a fix': '대신 콤보는 ',
  'praise: good point': RegExp(r'’(은|는) 잘했다'),
  'question: no last goal': '다음 판 미션을 정할 차례다',
  'question: goal reached': RegExp(r'^다음 미션을 정할 차례다'),
  'question: goal missed': '미션을 다시 정할 차례다',
  'answer: declined': '알겠다',
  'answer: a goal': ' 미션 접수! ',
  'end': '오늘 이야기는 여기까지다',
};

void main() {
  group('the design\'s battle against five earlier ones (spec 4.2)', () {
    final script = _build(coachInputOf(_designReport, earlier: _usualEarlier));
    final talk = script.talk;

    test('six lines: the summary, two on the pace, two on the form, the '
        'combo', () {
      expect(talk.map((l) => l.graphic.runtimeType), [
        CoachScoreGraphic,
        CoachPaceGraphic,
        CoachPaceGraphic,
        CoachFormGraphic,
        CoachFormGraphic,
        CoachComboGraphic,
      ]);
    });

    test('1, the summary: 18 counted, 2 above the average of 5, a win '
        'pose and the bars', () {
      final line = talk[0];
      expect(line.text, '수고했다범! 이번 스쿼트에서 18번 인정받았어. 최근 5판 평균보다 2번 더 했어!');
      expect(_marks(line), ['18번', '2번 더']);
      expect(line.pose, CoachPose.win);
      final card = line.graphic! as CoachScoreGraphic;
      expect(card.reps, 18);
      expect(card.earlier, [14, 17, 15, 18, 16]);
      expect(card.average, 16);
    });

    test('2, the pace: faster than usual at first, slower after it; then '
        'keep the same speed', () {
      expect(
        talk[1].text,
        '먼저 페이스를 살펴보자. 초반 10초는 평소보다 빨랐는데, 그다음부터는 '
        '평소보다 느려졌어.',
      );
      expect(_marks(talk[1]), ['초반 10초', '느려졌어']);
      expect(talk[2].text, '멈추지 않고 같은 속도로 하는 게 중요하다범! 처음부터 너무 달리지 말자.');
      final fast = talk[1].graphic! as CoachPaceGraphic;
      final slow = talk[2].graphic! as CoachPaceGraphic;
      expect(fast.mark, CoachPaceMark.early);
      expect(slow.mark, CoachPaceMark.late);
      expect(fast.buckets, [5, 5, 2, 2, 2, 2]);
      // The usual reps in a slice this long.
      expect(fast.usual, [3, 3, 3, 3, 2, 2]);
    });

    test('3, the form: all three were too shallow, after 15 s, and how to '
        'fix it on its own page', () {
      expect(talk[3].text, '인정 못 받은 3번은 모두 ‘더 앉기’였어. 15초가 지나 지치니까 그랬던 것 같아.');
      expect(_marks(talk[3]), ['3번', '15초가 지나']);
      expect(talk[3].pose, CoachPose.hit);
      expect(talk[4].text, '엉덩이를 뒤로 빼며 허벅지가 바닥과 나란해질 때까지 앉아요.');
      expect(talk[4].pose, CoachPose.hit);
      final card = talk[3].graphic! as CoachFormGraphic;
      expect(card.reason, RejectReason.shallowSquat);
      expect(card.word, '더 앉기');
      expect(card.sentence, '엉덩이를 무릎 높이까지 내려요');
      expect(card.count, 3);
      expect(card.lateCount, 3);
      expect(card.validTimes, hasLength(18));
      expect(card.rejectTimes, const [
        Duration(milliseconds: 19400),
        Duration(milliseconds: 24200),
        Duration(milliseconds: 28800),
      ]);
      expect(talk[4].graphic, same(card));
    });

    test('4, the praise: a combo longer than any earlier one', () {
      expect(talk[5].text, '대신 콤보는 11번까지 이어 갔어. 지금까지 중에 가장 길다범!');
      final card = talk[5].graphic! as CoachComboGraphic;
      expect((card.combo, card.previousBest), (11, 6));
      expect(talk[5].pose, CoachPose.win);
    });

    test('5, the question; its goals: 20 counted reps, and 8 in the later '
        '15 s (spec 5.1)', () {
      expect(script.question.text, '다음 판 미션을 정할 차례다범! 뭐로 할까?');
      expect(script.question.asksGoal, isTrue);
      expect(script.question.pose, CoachPose.idle);
      final [record, weak] = script.suggestions;
      expect(
        (record.kind, record.target, record.baseline),
        (GoalKind.reps, 20, 18),
      );
      expect(record.title, '스쿼트 20회 인정받기');
      expect(record.subtitle, '이번 판 18회보다 2회 더');
      expect(
        (weak.kind, weak.target, weak.baseline),
        (GoalKind.lateReps, 8, 6),
      );
      expect(weak.title, '후반 15초에 8회 이상');
      expect(weak.subtitle, '이번 판 후반은 6회');
    });

    test('6, the answer to a goal: it is written down, with its card', () {
      final goal = script.suggestions.first;
      final line = script.answer(goal);
      expect(
        line.text,
        '좋다범! ‘스쿼트 20회 인정받기’ 미션 접수! 스쿼트를 고르면 다시 보여 줄게. '
        '다음 판에서 깨 보자!',
      );
      expect(_marks(line), ['‘스쿼트 20회 인정받기’']);
      expect(line.pose, CoachPose.win);
      final card = line.graphic! as CoachGoalGraphic;
      expect(
        (card.title, card.subtitle, card.exercise),
        ('스쿼트 20회 인정받기', '이번 판 18회보다 2회 더', ExerciseType.squat),
      );
    });

    test('6, the answer to 사양할래, and 7, the end', () {
      final declined = script.answer(null);
      expect(declined.text, '알겠다범! 이번엔 미션 없이 편하게 해 보자. 다음에 또 이야기하자.');
      expect(declined.pose, CoachPose.idle);
      expect(declined.graphic, isNull);
      expect(script.end.text, '오늘 이야기는 여기까지다범! 자세한 건 상세 리포트에서 볼 수 있어.');
      expect(script.end.graphic, isNull);
    });
  });

  group('no earlier battles (task.md W10 decision 2)', () {
    final script = _build(coachInputOf(_designReport));

    test('no average: the plain summary, standing idle, no bars', () {
      expect(script.talk.first.text, '수고했다범! 이번 스쿼트에서 18번 인정받았어.');
      expect(script.talk.first.pose, CoachPose.idle);
      final card = script.talk.first.graphic! as CoachScoreGraphic;
      expect(card.average, isNull);
      expect(card.earlier, isEmpty);
    });

    test('the pace against its own start: 60% slower later', () {
      final pace = script.talk[1];
      expect(pace.text, '후반에 속도가 60% 떨어졌어. 처음부터 끝까지 같은 속도로 가 보자.');
      expect(_marks(pace), ['60%']);
      final card = pace.graphic! as CoachPaceGraphic;
      expect(card.usual, isNull);
      expect(card.mark, CoachPaceMark.late);
    });

    test('no combo record without battles to beat; here no good point '
        'either, so no praise', () {
      expect(script.talk.map((l) => l.graphic.runtimeType), [
        CoachScoreGraphic,
        CoachPaceGraphic,
        CoachFormGraphic,
        CoachFormGraphic,
      ]);
    });

    test('an even first battle: the good pace, and a good point', () {
      final even = coachReport(valid: evenly(12));
      final script = _build(coachInputOf(even));
      expect(script.talk[1].text, '처음부터 끝까지 고른 속도였어. 좋다범!');
      expect(script.talk[1].pose, CoachPose.win);
      expect(script.talk.last.text, '‘정확도 100%’는 잘했다범!');
    });

    test('battles without a form report give the average but no pace or '
        'combo', () {
      final script = _build(
        coachInputOf(
          _designReport,
          earlier: [earlierBattle(16), earlierBattle(16)],
        ),
      );
      expect(script.talk.first.text, endsWith('최근 2판 평균보다 2번 더 했어!'));
      // Without a usual pace it compares with its own start.
      expect(script.talk[1].text, startsWith('후반에 속도가 60%'));
      expect(
        script.talk.whereType<CoachLine>().map((l) => l.graphic),
        isNot(contains(isA<CoachComboGraphic>())),
      );
    });
  });

  group('the summary against the average', () {
    String summaryWith(List<int> earlier, {int reps = 18}) => _build(
      coachInputOf(
        coachReport(valid: evenly(reps)),
        earlier: [for (final r in earlier) earlierBattle(r)],
      ),
    ).talk.first.text;

    test('as many: "평균만큼 했어." and a win pose', () {
      expect(summaryWith(const [18, 18]), endsWith('인정받았어. 평균만큼 했어.'));
      final line = _build(
        coachInputOf(
          coachReport(valid: evenly(18)),
          earlier: [earlierBattle(18), earlierBattle(18)],
        ),
      ).talk.first;
      expect(line.pose, CoachPose.win);
    });

    test('fewer: "평균보다 N번 적었지만 괜찮아." and idle', () {
      final line = _build(
        coachInputOf(
          coachReport(valid: evenly(12)),
          earlier: [earlierBattle(15), earlierBattle(16)],
        ),
      ).talk.first;
      // The average 15.5 rounds to 16.
      expect(line.text, endsWith('평균보다 4번 적었지만 괜찮아.'));
      expect(line.pose, CoachPose.idle);
    });
  });

  group('the pace', () {
    test('fewer than four counted reps: no pace line', () {
      final script = _build(
        coachInputOf(
          coachReport(valid: const [1, 2, 3]),
          earlier: _usualEarlier,
        ),
      );
      expect(
        script.talk.map((l) => l.graphic),
        isNot(contains(isA<CoachPaceGraphic>())),
      );
    });

    test('not faster at first but much slower later: the drop from its own '
        'start, not the praise (task.md W10 decision 9)', () {
      final report = coachReport(
        valid: [...inSlice(0, 3), ...inSlice(1, 3), ...inSlice(3, 1)],
      );
      final script = _build(coachInputOf(report, earlier: _usualEarlier));
      expect(script.talk[1].text, startsWith('후반에 속도가 92% 떨어졌어.'));
      final card = script.talk[1].graphic! as CoachPaceGraphic;
      expect(card.mark, CoachPaceMark.late);
      // Its card compares with the start too.
      expect(card.usual, isNull);
    });

    test(
      'an even pace with a usual one: the praise, with the usual dashes',
      () {
        final report = coachReport(
          valid: [for (var slice = 0; slice < 6; slice++) ...inSlice(slice, 3)],
        );
        final script = _build(coachInputOf(report, earlier: _usualEarlier));
        expect(script.talk[1].text, '처음부터 끝까지 고른 속도였어. 좋다범!');
        final card = script.talk[1].graphic! as CoachPaceGraphic;
        expect(card.mark, CoachPaceMark.none);
        expect(card.usual, isNotNull);
      },
    );

    test('exactly 30% slower counts as a drop; 29% does not', () {
      CoachFacts factsWith(List<int> buckets) => CoachFacts.of(
        CoachInput(
          report: coachReport(valid: evenly(24)),
          findings: const [],
          pace: CoachPace(buckets: buckets, sliceSeconds: 5),
          characterId: 'seal',
        ),
      );
      // 1.0 a second early, 0.7 later; in this order the float is 0.7000…1.
      final thirty = factsWith(const [5, 5, 4, 4, 3, 3]);
      expect(thirty.slowdownPercent, 30);
      expect(thirty.slowedDown, isTrue);
      expect(factsWith(const [5, 5, 3, 4, 3, 4]).slowedDown, isTrue);
      expect(CoachGoals.weakPoint(thirty).kind, GoalKind.lateReps);
      // 0.71 a second later: 29% slower.
      final under = CoachFacts.of(
        CoachInput(
          report: coachReport(valid: evenly(24)),
          findings: const [],
          pace: const CoachPace(
            buckets: [50, 50, 36, 36, 35, 35],
            sliceSeconds: 50,
          ),
          characterId: 'seal',
        ),
      );
      expect(under.slowdownPercent, 29);
      expect(under.slowedDown, isFalse);
    });

    test(
      'exactly 10% faster at first and 10% slower later than usual counts',
      () {
        CoachFacts factsWith(
          List<int> buckets, {
          required int usual,
          required double slice,
        }) => CoachFacts.of(
          CoachInput(
            report: coachReport(valid: evenly(24)),
            findings: const [],
            pace: CoachPace(buckets: buckets, sliceSeconds: slice),
            characterId: 'seal',
            earlier: [
              CoachEarlier(
                reps: usual * 6,
                pace: CoachPace(
                  buckets: List.filled(6, usual),
                  sliceSeconds: slice,
                ),
              ),
            ],
          ),
        );
        // Exactly 10% faster at first: 33 against a usual 30 in 5 s slices,
        // where 6.0 x 1.1 rounds to 6.6000000000000005, above 33 / 5.
        expect(
          factsWith(
            const [33, 33, 20, 20, 20, 20],
            usual: 30,
            slice: 5,
          ).fastStartSlowEnd,
          isTrue,
        );
        // Exactly 10% slower later: 297 against a usual 330 in 50 s slices,
        // where 6.6 x 0.9 rounds below 297 / 50.
        expect(
          factsWith(
            const [400, 400, 297, 297, 297, 297],
            usual: 330,
            slice: 50,
          ).fastStartSlowEnd,
          isTrue,
        );
        // Less than 10% either way: no.
        expect(
          factsWith(
            const [32, 32, 20, 20, 20, 20],
            usual: 30,
            slice: 5,
          ).fastStartSlowEnd,
          isFalse,
        );
        expect(
          factsWith(
            const [400, 400, 298, 298, 298, 298],
            usual: 330,
            slice: 50,
          ).fastStartSlowEnd,
          isFalse,
        );
      },
    );

    test('a KO round: slices are shorter, so the start is compared per '
        'second ("초반 5.7초")', () {
      // 17 s: slices of 2.83 s. Three reps in each early slice is as many
      // per slice as usual, but more per second.
      final report = coachReport(
        roundSeconds: 17,
        valid: [
          ...evenly(6, from: 0.3, to: 5.4),
          ...evenly(4, from: 6.5, to: 16.5),
        ],
      );
      final input = coachInputOf(
        report,
        earlier: [
          for (var i = 0; i < 3; i++)
            earlierBattle(18, buckets: const [3, 3, 3, 3, 3, 3]),
        ],
      );
      final facts = CoachFacts.of(input);
      expect(facts.pace.buckets.take(2), [3, 3]);
      expect(facts.fastStartSlowEnd, isTrue);
      final script = _build(input);
      expect(script.talk[1].text, contains('초반 5.7초는 평소보다 빨랐는데'));
      final card = script.talk[1].graphic! as CoachPaceGraphic;
      // The usual 0.6 a second, in this round's 2.83 s slices.
      expect(card.usual!.first, closeTo(1.7, 0.01));
      // The later-half goal names this round's half.
      expect(script.suggestions.last.title, startsWith('후반 8.5초에'));
    });

    test('rates: reps per second; a round of no length counts none', () {
      const pace = CoachPace(buckets: [5, 5, 2, 2, 2, 2], sliceSeconds: 5);
      expect(pace.rates, [1, 1, 0.4, 0.4, 0.4, 0.4]);
      expect(pace.early, 1);
      expect(pace.late, closeTo(0.4, 1e-9));
      const none = CoachPace(buckets: [1, 1, 0, 0, 0, 0], sliceSeconds: 0);
      expect(none.rates, everyElement(0));
    });
  });

  group('the form', () {
    test('mixed reasons: the biggest first, "N번 중 M번이", with 이었 after a '
        'final consonant; early rejections say nothing of tiring', () {
      final report = coachReport(
        exercise: ExerciseType.pushUp,
        valid: evenly(8),
        rejected: const [
          (3, RejectReason.phoneMoved),
          (6, RejectReason.phoneMoved),
          (8, RejectReason.insufficientDepth),
        ],
      );
      final form = _build(coachInputOf(report)).talk
          .firstWhere((l) => l.graphic is CoachFormGraphic);
      expect(form.text, '인정 못 받은 3번 중 2번이 ‘폰 고정’이었어.');
      final card = form.graphic! as CoachFormGraphic;
      expect(card.count, 2);
      // Only the rejections of the reason it talks about.
      expect(card.rejectTimes, hasLength(2));
      expect(card.lateCount, 0);
    });

    test('half of them late is enough for the tiring sentence', () {
      final report = coachReport(
        valid: evenly(10),
        rejected: const [
          (5, RejectReason.standUpFully),
          (20, RejectReason.standUpFully),
        ],
      );
      final form = _build(coachInputOf(report)).talk
          .firstWhere((l) => l.graphic is CoachFormGraphic);
      expect(form.text, '인정 못 받은 2번은 모두 ‘끝까지 서기’였어. 15초가 지나 지치니까 그랬던 것 같아.');
    });

    test('no rejection, another issue: its title, then its fix', () {
      final report = coachReport(
        exercise: ExerciseType.pushUp,
        valid: evenly(8),
      );
      final input = CoachInput(
        report: report,
        findings: const [
          FormFinding(
            kind: FindingKind.issue,
            code: 'depth_loss',
            title: '후반 깊이 감소',
            detail: '전반 평균 1.20 → 후반 0.80 (어깨 너비 기준 머리 하강).',
            fix: '지치면 속도를 줄이더라도 매번 같은 깊이까지 내려가요.',
          ),
        ],
        pace: paceOf(report),
        characterId: 'bear',
      );
      final talk = _build(input).talk;
      final pages = [
        for (final l in talk)
          if (l.graphic is CoachFormGraphic) l,
      ];
      expect(pages.map((l) => l.text), [
        '가장 눈에 띈 건 ‘후반 깊이 감소’야.',
        '지치면 속도를 줄이더라도 매번 같은 깊이까지 내려가요.',
      ]);
      final card = pages.first.graphic! as CoachFormGraphic;
      expect(card.reason, isNull);
      expect(card.count, isNull);
      expect(card.word, '후반 깊이 감소');
    });

    test('an issue without a fix keeps to one page', () {
      final report = coachReport(valid: evenly(8));
      final input = CoachInput(
        report: report,
        findings: const [
          FormFinding(
            kind: FindingKind.issue,
            code: 'imbalance',
            title: '좌우 불균형',
            detail: '양팔 각도가 평균 20° 달라요.',
          ),
        ],
        pace: paceOf(report),
        characterId: 'mouse',
      );
      final pages = _build(input).talk
          .where((l) => l.graphic is CoachFormGraphic);
      expect(pages.single.text, '가장 눈에 띈 건 ‘좌우 불균형’이야.');
    });
  });

  group('the praise', () {
    test('a combo record with nothing to fix: no "대신"', () {
      final script = _build(
        coachInputOf(
          coachReport(valid: evenly(10, from: 1, to: 10)),
          earlier: [
            earlierBattle(9, buckets: const [2, 2, 2, 1, 1, 1], combo: 4),
          ],
        ),
      );
      expect(script.talk.last.text, '콤보는 10번까지 이어 갔어. 지금까지 중에 가장 길다범!');
    });

    test('no record (as long as before): the first good point instead', () {
      final script = _build(
        coachInputOf(
          coachReport(valid: evenly(10, from: 1, to: 10)),
          earlier: [
            earlierBattle(9, buckets: const [2, 2, 2, 1, 1, 1], combo: 10),
          ],
        ),
      );
      expect(script.talk.last.text, '‘정확도 100%’는 잘했다범!');
      expect(script.talk.last.graphic, isNull);
    });

    test('neither a thing to fix nor a good point: the summary alone', () {
      final report = coachReport(valid: const [1, 2, 3]);
      final script = _build(
        CoachInput(
          report: report,
          findings: const [],
          pace: paceOf(report),
          characterId: 'seal',
        ),
      );
      expect(script.talk, hasLength(1));
      expect(script.talk.single.graphic, isA<CoachScoreGraphic>());
    });
  });

  group('the goals (spec 5.1)', () {
    CoachFacts factsOf(
      List<double> valid, {
      List<(double, RejectReason)> rejected = const [],
      List<int> earlier = const [],
    }) => CoachFacts.of(
      coachInputOf(
        coachReport(valid: valid, rejected: rejected),
        earlier: [for (final r in earlier) earlierBattle(r)],
      ),
    );

    test('the record goal: two above this battle or the rounded average, '
        'whichever is higher', () {
      expect(CoachGoals.record(factsOf(evenly(18))).target, 20);
      final belowAverage = CoachGoals.record(
        factsOf(evenly(10), earlier: const [14, 15]),
      );
      expect(belowAverage.target, 17);
      expect(belowAverage.subtitle, '이번 판 10회보다 7회 더');
    });

    test('slowed down by 30% or more: the later-half goal', () {
      final weak = CoachGoals.weakPoint(factsOf(designPace()));
      expect(weak.kind, GoalKind.lateReps);
    });

    test('else two or more rejected: at most two fewer, not below 0', () {
      final three = CoachGoals.weakPoint(
        factsOf(
          evenly(12),
          rejected: const [
            (5, RejectReason.shallowSquat),
            (10, RejectReason.shallowSquat),
            (25, RejectReason.shallowSquat),
          ],
        ),
      );
      expect(
        (three.kind, three.target, three.baseline),
        (GoalKind.maxRejects, 1, 3),
      );
      expect(three.title, '무효 1회 이하');
      expect(three.subtitle, '이번 판 무효 3회');
      final two = CoachGoals.weakPoint(
        factsOf(
          evenly(12),
          rejected: const [
            (5, RejectReason.shallowSquat),
            (25, RejectReason.shallowSquat),
          ],
        ),
      );
      expect(two.target, 0);
    });

    test('else a longer combo, at least two', () {
      // An even pace (0.4 and 0.3 reps a second), no rejection, and a run of
      // six reps a second apart late in the round.
      final weak = CoachGoals.weakPoint(
        factsOf(const [1, 3, 5, 7, 20, 21, 22, 23, 24, 25]),
      );
      expect((weak.kind, weak.target, weak.baseline), (GoalKind.combo, 7, 6));
      expect(weak.title, '콤보 7번 이상');
      expect(weak.subtitle, '이번 판 최고 콤보 6번');
      final none = CoachGoals.weakPoint(factsOf(const []));
      expect(none.target, 2);
    });

    test(
      'a suggestion becomes the goal saved with the picker\'s character',
      () {
        final goal =
            const GoalSuggestion(
              kind: GoalKind.reps,
              target: 20,
              baseline: 18,
              title: '스쿼트 20회 인정받기',
              subtitle: '이번 판 18회보다 2회 더',
            ).toGoal(
              exercise: ExerciseType.squat,
              setAt: DateTime(2026, 11, 17, 15),
              characterId: 'seal',
              fromMatch: '123',
            );
        expect(goal.characterId, 'seal');
        expect(goal.fromMatch, '123');
        expect(goal.baseline, 18);
      },
    );
  });

  group('the longest combo is the game\'s combo', () {
    int gameCombo(List<(double, bool)> reps) {
      final score = PlayerGameScore();
      var longest = 0;
      for (final (t, valid) in reps) {
        final at = Duration(milliseconds: (t * 1000).round());
        score.addRep(valid ? GameGrade.excellent : null, at);
        if (score.combo > longest) longest = score.combo;
      }
      return longest;
    }

    final cases = <String, List<(double, bool)>>{
      'gaps of exactly the window keep it': [(1, true), (2.5, true), (4, true)],
      'a gap past the window breaks it': [(1, true), (2.501, true), (3, true)],
      'a rejected rep breaks it': [
        (1, true),
        (2, true),
        (2.5, false),
        (3, true),
        (4, true),
        (5, true),
      ],
      'no counted rep': [(1, false), (2, false)],
    };
    for (final MapEntry(key: name, value: reps) in cases.entries) {
      test(name, () {
        final report = coachReport(
          valid: [
            for (final (t, valid) in reps)
              if (valid) t,
          ],
          rejected: [
            for (final (t, valid) in reps)
              if (!valid) (t, RejectReason.shallowSquat),
          ],
        );
        expect(CoachFacts.longestComboOf(report), gameCombo(reps));
      });
    }

    test('the window is the game\'s', () {
      expect(battleRules.comboWindow, const Duration(milliseconds: 1500));
      expect(
        CoachFacts.longestComboOf(coachReport(valid: const [1, 2.5, 4])),
        3,
      );
    });
  });

  group('the voice (spec 4.4)', () {
    test('each character\'s name and ending', () {
      expect(
        [
          for (final id in const [
            'mouse',
            'kangaroo',
            'bear',
            'penguin',
            'seal',
          ])
            (CoachVoice.of(id).name, CoachVoice.of(id).ending),
        ],
        const [
          ('GYM마우스', '찍'),
          ('그루', '깡'),
          ('곰탱이', '곰'),
          ('펭뚱이', '펭'),
          ('물렁범', '범'),
        ],
      );
    });

    test('RepBot and an unknown id talk as the mouse', () {
      for (final id in const ['bot', 'dragon', '']) {
        final voice = CoachVoice.of(id);
        expect(
          (voice.characterId, voice.name, voice.ending),
          ('mouse', 'GYM마우스', '찍'),
        );
      }
    });

    test('the ending follows "~다" before "!" only, never a question or a '
        'promise (A9 spec 1)', () {
      final script = _build(
        coachInputOf(_designReport, characterId: 'kangaroo'),
      );
      expect(script.talk.first.text, startsWith('수고했다깡!'));
      expect(script.question.text, '다음 판 미션을 정할 차례다깡! 뭐로 할까?');
      expect(script.end.text, '오늘 이야기는 여기까지다깡! 자세한 건 상세 리포트에서 볼 수 있어.');
    });

    test('a push-up goal says 을 after 푸쉬업', () {
      final report = coachReport(
        exercise: ExerciseType.pushUp,
        valid: evenly(6),
      );
      final script = _build(coachInputOf(report));
      expect(
        script.answer(script.suggestions.first).text,
        contains('푸쉬업을 고르면'),
      );
    });
  });

  group('the ending only after "~다", before "!" (A9 spec 1 and 5)', () {
    test('exclaim puts each character\'s ending and "!" after a saying in '
        '"~다"', () {
      expect(
        {for (final id in _endings.keys) id: CoachVoice.of(id).exclaim('좋다')},
        {
          for (final MapEntry(:key, :value) in _endings.entries)
            key: '좋다$value!',
        },
      );
      expect(CoachVoice.of('kangaroo').exclaim('정할 차례다'), '정할 차례다깡!');
    });

    test('exclaim fails on a saying that does not end in "~다": a question, '
        'a suggestion, a promise, "~어", or one already closed', () {
      final voice = CoachVoice.of('kangaroo');
      for (final saying in const [
        '뭐로 할까',
        '기억나',
        '가 보자',
        '돌아갈게',
        '잘했어',
        '좋다!',
        '좋다 ',
        '',
      ]) {
        expect(
          () => voice.exclaim(saying),
          throwsA(isA<AssertionError>()),
          reason: saying,
        );
      }
    });

    test('every line of every branch, for every character: the ending only '
        'right after "다" and right before "!", at most once, never before '
        '"?", and no other character\'s ending', () {
      for (final MapEntry(key: id, value: ending) in _endings.entries) {
        final branches = <String>{};
        var lines = 0;
        for (final (name, input) in _talks(id)) {
          final script = _build(input);
          for (final line in [
            ...script.talk,
            script.question,
            for (final goal in script.suggestions) script.answer(goal),
            script.answer(null),
            script.end,
          ]) {
            final text = line.text;
            final reason = '$id, $name: "$text"';
            final count = ending.allMatches(text).length;
            expect(count, lessThanOrEqualTo(1), reason: reason);
            expect('다$ending!'.allMatches(text).length, count, reason: reason);
            expect(text, isNot(contains('$ending?')), reason: reason);
            for (final other in _endings.values.where((o) => o != ending)) {
              expect(text, isNot(contains('다$other!')), reason: reason);
            }
            branches.addAll([
              for (final MapEntry(:key, :value) in _branchMarks.entries)
                if (text.contains(value)) key,
            ]);
            lines++;
          }
        }
        // Every branch of the talk was said by this character.
        expect(branches, _branchMarks.keys.toSet(), reason: id);
        expect(lines, greaterThan(_talks(id).length), reason: id);
      }
    });

    test('the nine changed lines, word for word, for every character, with '
        'the marked runs where they were (spec 2)', () {
      for (final MapEntry(key: id, value: e) in _endings.entries) {
        final first = _build(coachInputOf(_designReport, characterId: id));
        final even = _build(
          coachInputOf(coachReport(valid: evenly(12)), characterId: id),
        );
        final reached = _build(
          _checkingGoal(
            coachReport(valid: evenly(21)),
            _lastGoalOf(GoalKind.reps, 20, '스쿼트 20회 인정받기'),
            characterId: id,
          ),
        );
        final missed = _build(
          _checkingGoal(
            coachReport(valid: evenly(15)),
            _lastGoalOf(GoalKind.reps, 20, '스쿼트 20회 인정받기'),
            characterId: id,
          ),
        );
        final recall = reached.talk.first;
        final slowed = first.talk[1];
        final good = even.talk.last;
        final answer = first.answer(first.suggestions.first);
        final rows = <(String, CoachLine, String, List<String>)>[
          ('1', recall, '지난번 미션 기억나? ‘스쿼트 20회 인정받기’였다$e!', ['‘스쿼트 20회 인정받기’']),
          ('2', slowed, '후반에 속도가 60% 떨어졌어. 처음부터 끝까지 같은 속도로 가 보자.', ['60%']),
          ('3', good, '‘정확도 100%’는 잘했다$e!', ['‘정확도 100%’']),
          ('4', first.question, '다음 판 미션을 정할 차례다$e! 뭐로 할까?', []),
          ('5', reached.question, '다음 미션을 정할 차례다$e! 뭐로 할까?', []),
          ('6', missed.question, '미션을 다시 정할 차례다$e! 어떻게 할까?', []),
          (
            '7',
            first.answer(null),
            '알겠다$e! 이번엔 미션 없이 편하게 해 보자. 다음에 또 이야기하자.',
            [],
          ),
          (
            '8',
            answer,
            '좋다$e! ‘스쿼트 20회 인정받기’ 미션 접수! 스쿼트를 고르면 다시 보여 줄게. 다음 판에서 깨 보자!',
            ['‘스쿼트 20회 인정받기’'],
          ),
          ('9', first.end, '오늘 이야기는 여기까지다$e! 자세한 건 상세 리포트에서 볼 수 있어.', []),
        ];
        for (final (number, line, text, marks) in rows) {
          expect(line.text, text, reason: '$id, line $number');
          expect(_marks(line), marks, reason: '$id, line $number');
        }
      }
      // 그루's question as the spec writes it, and 이었 after a final
      // consonant in line 1.
      expect(
        _build(coachInputOf(_designReport, characterId: 'kangaroo'))
            .question
            .text,
        '다음 판 미션을 정할 차례다깡! 뭐로 할까?',
      );
      expect(
        _build(
          _checkingGoal(
            coachReport(valid: [2, 16, 18, 20]),
            _lastGoalOf(GoalKind.lateReps, 3, '후반 15초에 3회 이상'),
            characterId: 'kangaroo',
          ),
        ).talk.first.text,
        '지난번 미션 기억나? ‘후반 15초에 3회 이상’이었다깡!',
      );
    });
  });

  group('steps (for W11)', () {
    test('a step put in front adds its lines first; one with nothing to '
        'say adds none', () {
      List<CoachLine> first(CoachFacts facts, CoachVoice voice) => [
        CoachLine(
          pose: CoachPose.idle,
          pieces: [CoachPiece(voice.exclaim('지난번 목표를 볼 차례다'))],
        ),
      ];
      List<CoachLine> silent(CoachFacts facts, CoachVoice voice) => const [];
      final script = _build(
        coachInputOf(_designReport),
        steps: [first, silent, ...CoachScript.defaultSteps],
      );
      expect(script.talk.first.text, '지난번 목표를 볼 차례다범!');
      expect(
        script.talk.length,
        _build(coachInputOf(_designReport)).talk.length + 1,
      );
    });

    test('the input carries the last goal for such a step', () {
      final goal = FeedbackGoal(
        exercise: ExerciseType.squat,
        kind: GoalKind.reps,
        target: 20,
        baseline: 18,
        title: '스쿼트 20회 인정받기',
        setAt: DateTime(2026, 11, 16),
        characterId: 'seal',
        fromMatch: '1',
      );
      final input = CoachInput(
        report: _designReport,
        findings: const [],
        pace: paceOf(_designReport),
        characterId: 'seal',
        lastGoal: goal,
      );
      expect(CoachFacts.of(input).input.lastGoal, same(goal));
    });
  });

  group('lines', () {
    test('a line\'s text and length; pieces compare by value', () {
      const line = CoachLine(
        pose: CoachPose.idle,
        pieces: [CoachPiece('수고했다! '), CoachPiece('18번', marked: true)],
      );
      expect(line.text, '수고했다! 18번');
      expect(line.length, 9);
      expect(line.toString(), '수고했다! **18번**');
      expect(
        const CoachPiece('a', marked: true),
        const CoachPiece('a', marked: true),
      );
      expect(const CoachPiece('a').hashCode, const CoachPiece('a').hashCode);
      expect(const CoachPiece('a'), isNot(const CoachPiece('a', marked: true)));
    });

    test('the form card\'s later half starts at half the round', () {
      const card = CoachFormGraphic(
        word: '더 앉기',
        sentence: '',
        roundLength: Duration(seconds: 17),
        validTimes: [],
        rejectTimes: [Duration(seconds: 8), Duration(seconds: 9)],
      );
      expect(card.half, const Duration(milliseconds: 8500));
      expect(card.lateCount, 1);
    });

    test('suggestions print their kind and title', () {
      final script = _build(coachInputOf(_designReport));
      expect(
        script.suggestions.first.toString(),
        'GoalSuggestion(reps 20: 스쿼트 20회 인정받기)',
      );
    });
  });

  group('the last goal checked (A11 spec 6)', () {
    /// A goal of [kind] set the day before with the kangaroo (그루).
    FeedbackGoal lastGoal(
      GoalKind kind,
      int target, {
      String title = '스쿼트 20회 인정받기',
      ExerciseType exercise = ExerciseType.squat,
      DateTime? setAt,
    }) => FeedbackGoal(
      exercise: exercise,
      kind: kind,
      target: target,
      baseline: target - 2,
      title: title,
      setAt: setAt ?? coachEndedAt.subtract(const Duration(days: 1)),
      characterId: 'kangaroo',
      fromMatch: 'earlier',
    );

    /// [report]'s talk input with [goal] to check, the seal talking.
    CoachInput checking(
      FormReport report,
      FeedbackGoal? goal, {
      List<CoachEarlier> earlier = const [],
    }) {
      final base = coachInputOf(report, earlier: earlier);
      return CoachInput(
        report: base.report,
        findings: base.findings,
        pace: base.pace,
        characterId: base.characterId,
        earlier: base.earlier,
        lastGoal: goal,
      );
    }

    test('recalled first: the seal talks, the card names who set it (그루), '
        'then the reached result, marked, with the full result card', () {
      final script = _build(
        checking(coachReport(valid: evenly(21)), lastGoal(GoalKind.reps, 20)),
      );
      final recall = script.talk[0];
      expect(recall.text, '지난번 미션 기억나? ‘스쿼트 20회 인정받기’였다범!');
      expect(_marks(recall), ['‘스쿼트 20회 인정받기’']);
      expect(recall.pose, CoachPose.idle);
      final card = recall.graphic! as CoachGoalGraphic;
      expect(card.tag, '지난번 미션');
      expect(card.subtitle, '지난 판에 그루가 준 미션');
      // 이 after a final consonant: the seal's 물렁범.
      final seal = FeedbackGoal(
        exercise: ExerciseType.squat,
        kind: GoalKind.reps,
        target: 20,
        baseline: 18,
        title: '스쿼트 20회 인정받기',
        setAt: coachEndedAt.subtract(const Duration(days: 1)),
        characterId: 'seal',
        fromMatch: 'earlier',
      );
      expect(
        (_build(checking(coachReport(valid: evenly(21)), seal)).talk[0].graphic!
                as CoachGoalGraphic)
            .subtitle,
        '지난 판에 물렁범이 준 미션',
      );
      expect(card.showsWhere, isFalse);
      final result = script.talk[1];
      expect(result.text, '이번에 21번 인정받았어. 미션 성공이다범!');
      expect(_marks(result), ['21번', '미션 성공']);
      expect(result.pose, CoachPose.win);
      final checked = result.graphic! as CoachGoalResultGraphic;
      expect(checked.title, '스쿼트 20회 인정받기');
      expect((checked.result.value, checked.result.reached), (21, true));
    });

    test('missed by one: how many, and how far, with the miss pose', () {
      final line = _build(
        checking(coachReport(valid: evenly(19)), lastGoal(GoalKind.reps, 20)),
      ).talk[1];
      expect(line.text, '이번엔 19번이라서 딱 1번 모자랐어. 아깝다범!');
      expect(_marks(line), ['19번', '1번']);
      expect(line.pose, CoachPose.hit);
      expect((line.graphic! as CoachGoalResultGraphic).result.reached, isFalse);
    });

    for (final (name, report, goal, text) in [
      (
        'later half reached',
        coachReport(valid: [2, 16, 18, 20]),
        lastGoal(GoalKind.lateReps, 3, title: '후반 15초에 3회 이상'),
        '이번엔 후반에 3번 인정받았어. 미션 성공이다범!',
      ),
      (
        'later half missed',
        coachReport(valid: [2, 4, 16]),
        lastGoal(GoalKind.lateReps, 3, title: '후반 15초에 3회 이상'),
        '이번엔 후반에 1번이라서 딱 2번 모자랐어. 아깝다범!',
      ),
      (
        'combo reached',
        coachReport(valid: [1, 2, 3, 10]),
        lastGoal(GoalKind.combo, 3, title: '콤보 3번 이상'),
        '이번엔 콤보를 3번까지 이어 갔어. 미션 성공이다범!',
      ),
      (
        'combo missed',
        coachReport(valid: [1, 2, 10]),
        lastGoal(GoalKind.combo, 4, title: '콤보 4번 이상'),
        '이번엔 콤보가 2번이라서 딱 2번 모자랐어. 아깝다범!',
      ),
      (
        'no rejection at all',
        coachReport(valid: [1, 2]),
        lastGoal(GoalKind.maxRejects, 1, title: '무효 1회 이하'),
        '이번엔 무효가 한 번도 없었어. 미션 성공이다범!',
      ),
      (
        'rejections within the limit',
        coachReport(
          valid: [1],
          rejected: const [(5, RejectReason.shallowSquat)],
        ),
        lastGoal(GoalKind.maxRejects, 1, title: '무효 1회 이하'),
        '이번엔 무효가 1번뿐이었어. 미션 성공이다범!',
      ),
      (
        'rejections past the limit (decision 14)',
        coachReport(
          valid: [1],
          rejected: const [
            (5, RejectReason.shallowSquat),
            (6, RejectReason.shallowSquat),
            (7, RejectReason.shallowSquat),
          ],
        ),
        lastGoal(GoalKind.maxRejects, 2, title: '무효 2회 이하'),
        '이번엔 무효가 3번이라 미션보다 1번 많았어. 아깝다범!',
      ),
    ]) {
      test('$name: "$text"', () {
        expect(_build(checking(report, goal)).talk[1].text, text);
      });
    }

    test('a KO keeps the full round\'s half: reps after 15 s of a 20 s '
        'round are the later half', () {
      final line = _build(
        checking(
          coachReport(valid: [2, 12, 16, 18], roundSeconds: 20),
          lastGoal(GoalKind.lateReps, 3, title: '후반 15초에 3회 이상'),
        ),
      ).talk[1];
      // Its own half (10 s) would count three and reach it.
      expect(line.text, '이번엔 후반에 2번이라서 딱 1번 모자랐어. 아깝다범!');
    });

    test('only a goal of this exercise, set before this battle ended, is '
        'checked', () {
      final report = coachReport(valid: evenly(21));
      for (final goal in [
        null,
        lastGoal(GoalKind.reps, 20, exercise: ExerciseType.pushUp),
        lastGoal(
          GoalKind.reps,
          20,
          setAt: coachEndedAt.add(const Duration(minutes: 1)),
        ),
      ]) {
        final script = _build(checking(report, goal));
        expect(script.talk.first.text, startsWith('수고했다범!'));
        expect(script.facts.lastResult, isNull);
        expect(script.question.text, '다음 판 미션을 정할 차례다범! 뭐로 할까?');
      }
    });

    test('after a reps goal the summary keeps only the average; without '
        'earlier battles it has nothing left to say', () {
      final report = coachReport(valid: evenly(21));
      final goal = lastGoal(GoalKind.reps, 20);
      final withAverage = _build(
        checking(report, goal, earlier: _usualEarlier),
      );
      expect(withAverage.talk[2].text, '최근 5판 평균보다 5번 더 했어. 좋다범!');
      final alone = _build(checking(report, goal));
      expect(alone.talk.where((l) => l.text.contains('인정받았어')), hasLength(1));
      expect(alone.talk.any((l) => l.graphic is CoachScoreGraphic), isFalse);
    });

    test('after another kind of goal the summary is whole', () {
      final script = _build(
        checking(
          coachReport(valid: [1, 2, 3, 10]),
          lastGoal(GoalKind.combo, 3, title: '콤보 3번 이상'),
        ),
      );
      expect(script.talk[2].text, startsWith('수고했다범! 이번 스쿼트에서 4번'));
    });

    test('the two check lines count among the lines to say', () {
      final report = coachReport(valid: evenly(21));
      final plain = _build(checking(report, null)).talk.length;
      final checked = _build(
        checking(report, lastGoal(GoalKind.combo, 2, title: '콤보 2번 이상')),
      ).talk.length;
      expect(checked, plain + 2);
    });

    group('the goal question after the check (spec 6.4)', () {
      List<GoalSuggestion> choices(FormReport report, FeedbackGoal goal) =>
          _build(checking(report, goal)).suggestions;
      GoalSuggestion weak(FormReport report, FeedbackGoal goal) =>
          CoachGoals.weakPoint(CoachFacts.of(checking(report, goal)));

      test('reached: one step up, then the weak point', () {
        final report = coachReport(valid: evenly(21));
        final goal = lastGoal(GoalKind.reps, 20);
        final script = _build(checking(report, goal));
        expect(script.question.text, '다음 미션을 정할 차례다범! 뭐로 할까?');
        final [up, second] = script.suggestions;
        expect((up.kind, up.target, up.baseline), (GoalKind.reps, 22, 21));
        expect((up.title, up.subtitle), ('스쿼트 22회 인정받기', '한 단계 올리기'));
        expect(second.title, weak(report, goal).title);
      });

      test('one step up for each kind: +2 later reps, +1 combo, one '
          'rejection fewer but not below 0', () {
        expect(
          choices(
            coachReport(valid: [16, 17, 18]),
            lastGoal(GoalKind.lateReps, 3, title: '후반 15초에 3회 이상'),
          ).first.title,
          '후반 15초에 5회 이상',
        );
        expect(
          choices(
            coachReport(valid: [1, 2, 3]),
            lastGoal(GoalKind.combo, 3, title: '콤보 3번 이상'),
          ).first.title,
          '콤보 4번 이상',
        );
        expect(
          choices(
            coachReport(valid: [1, 2]),
            lastGoal(GoalKind.maxRejects, 1, title: '무효 1회 이하'),
          ).first.title,
          '무효 0회 이하',
        );
        final floor = choices(
          coachReport(valid: [1, 2]),
          lastGoal(GoalKind.maxRejects, 0, title: '무효 0회 이하'),
        ).first;
        expect((floor.target, floor.subtitle), (0, '같은 미션 그대로'));
      });

      test('missed: the same goal again, then this battle + 1 when that is '
          'below the goal', () {
        final report = coachReport(valid: evenly(15));
        final script = _build(checking(report, lastGoal(GoalKind.reps, 20)));
        expect(script.question.text, '미션을 다시 정할 차례다범! 어떻게 할까?');
        final [same, easier] = script.suggestions;
        expect((same.title, same.target), ('스쿼트 20회 인정받기', 20));
        expect(same.subtitle, '같은 미션 그대로');
        expect((easier.title, easier.target), ('스쿼트 16회 인정받기', 16));
        expect(easier.subtitle, '이번 기록 넘기기');
      });

      test('missed by one: no easier goal than the goal itself, so the '
          'weak point (decision 13)', () {
        final report = coachReport(valid: evenly(19));
        final goal = lastGoal(GoalKind.reps, 20);
        expect(choices(report, goal).last.title, weak(report, goal).title);
      });

      test('a rejection limit missed: one fewer than this battle when looser '
          'than the goal, else the weak point (decision 14)', () {
        FormReport rejecting(int count) => coachReport(
          valid: [1],
          rejected: [
            for (var i = 0; i < count; i++)
              (5.0 + i, RejectReason.shallowSquat),
          ],
        );
        final goal = lastGoal(GoalKind.maxRejects, 1, title: '무효 1회 이하');
        final easier = choices(rejecting(4), goal).last;
        expect((easier.title, easier.target), ('무효 3회 이하', 3));
        expect(
          choices(rejecting(2), goal).last.title,
          weak(rejecting(2), goal).title,
        );
      });

      test('a second choice the same as the first becomes the record goal', () {
        // Three in a row in each slice: an even pace, no rejection, so the
        // weak point is a combo of 4, the same as one step up from 3.
        final report = coachReport(
          valid: [
            for (var slice = 0; slice < 6; slice++)
              for (var i = 0; i < 3; i++) slice * 5 + 0.5 + i,
          ],
        );
        final goal = lastGoal(GoalKind.combo, 3, title: '콤보 3번 이상');
        expect(weak(report, goal).title, '콤보 4번 이상');
        final [first, second] = choices(report, goal);
        expect(first.title, '콤보 4번 이상');
        expect(second.kind, GoalKind.reps);
        expect(second.title, '스쿼트 20회 인정받기');
      });
    });
  });
}
