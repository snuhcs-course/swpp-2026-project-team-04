import 'dart:math' as math;

import '../../models/battle_rules.dart';
import '../../models/character_rig.dart';
import '../../models/exercise_type.dart';
import '../../models/exercise_type_korean.dart';
import '../../models/feedback_goal.dart';
import '../../models/form_report.dart';
import '../../models/game_score.dart';
import '../../models/rep_event.dart';
import '../../models/reject_reason_korean.dart';
import '../../utils/korean_josa.dart';
import '../../widgets/battle_stage_model.dart';
import '../game/player_game_score.dart';
import 'form_analyzer.dart';

// The character's talk after a battle (A10 spec 4): lines built by rules
// from the battle's numbers, never by a language model.
//
// CoachScript.build is a pure function of CoachInput. The talk before the
// goal question is a list of CoachTalkSteps run in order; a step adds its
// lines, or none when its condition does not hold. W11 puts its check of
// the last goal in front by passing its own list of steps.

/// How the character stands while saying a line.
enum CoachPose { idle, win, hit }

/// A run of a line's letters, highlighted or plain.
class CoachPiece {
  const CoachPiece(this.text, {this.marked = false});

  final String text;

  /// Bold on the lime highlighter (the lower 42% of the letters).
  final bool marked;

  @override
  bool operator ==(Object other) =>
      other is CoachPiece && other.text == text && other.marked == marked;

  @override
  int get hashCode => Object.hash(text, marked);

  @override
  String toString() => marked ? '**$text**' : text;
}

/// One page of the talk: what the character says and how, and the card
/// shown above it.
class CoachLine {
  const CoachLine({
    required this.pose,
    required this.pieces,
    this.graphic,
    this.asksGoal = false,
  });

  final CoachPose pose;
  final List<CoachPiece> pieces;

  /// The card above the character; null for none.
  final CoachGraphic? graphic;

  /// The goal question: the talk waits here until a goal is picked.
  final bool asksGoal;

  /// The whole line.
  String get text => pieces.map((p) => p.text).join();

  /// How many letters the line has, as it types them one by one.
  int get length => text.runes.length;

  @override
  String toString() => pieces.join();
}

/// The card above the character (A10 spec 6).
sealed class CoachGraphic {
  const CoachGraphic();
}

/// "이번 판 인정 횟수": this battle's counted reps against the earlier ones.
class CoachScoreGraphic extends CoachGraphic {
  const CoachScoreGraphic({
    required this.reps,
    this.earlier = const [],
    this.average,
  });

  final int reps;

  /// The earlier battles' counted reps, oldest first; empty for none.
  final List<int> earlier;

  /// Their rounded mean; null without earlier battles.
  final int? average;
}

/// Which slices of the pace card are colored.
enum CoachPaceMark {
  /// None: the pace was even.
  none,

  /// The first two slices, lime: faster than usual.
  early,

  /// The last four, amber: slower than usual (or than the start).
  late,
}

/// "N초마다 인정 횟수": the six slices of this battle, and the usual reps
/// per slice when earlier battles have a pace.
class CoachPaceGraphic extends CoachGraphic {
  const CoachPaceGraphic({
    required this.buckets,
    required this.sliceSeconds,
    this.usual,
    this.mark = CoachPaceMark.none,
  });

  /// Counted reps in each slice.
  final List<int> buckets;
  final double sliceSeconds;

  /// The usual reps in a slice this long, per slice; null when the card
  /// compares the start with the rest instead (no earlier pace, or a line
  /// about the drop from this battle's own start).
  final List<double>? usual;
  final CoachPaceMark mark;
}

/// The form card: the issue's pictogram and words, and the round's reps on
/// a time line with the later half shaded.
class CoachFormGraphic extends CoachGraphic {
  const CoachFormGraphic({
    required this.word,
    required this.sentence,
    required this.roundLength,
    required this.validTimes,
    this.reason,
    this.count,
    this.rejectTimes = const [],
  });

  /// The rejection; null for another issue (no pictogram).
  final RejectReason? reason;

  /// The short words on the red band, e.g. "더 앉기".
  final String word;

  /// The sentence under them.
  final String sentence;

  /// How often the rejection came up ("× 3"); null for another issue.
  final int? count;

  final Duration roundLength;

  /// When the counted reps and the rejected ones of [reason] closed.
  final List<Duration> validTimes;
  final List<Duration> rejectTimes;

  /// Where the later half starts.
  Duration get half => roundLength ~/ 2;

  /// The rejections in the later half.
  int get lateCount => rejectTimes.where((t) => t >= half).length;
}

/// "가장 긴 콤보": the new longest combo against the earlier best.
class CoachComboGraphic extends CoachGraphic {
  const CoachComboGraphic({required this.combo, required this.previousBest});

  final int combo;
  final int previousBest;
}

/// "다음 판 목표": the goal just picked.
class CoachGoalGraphic extends CoachGraphic {
  const CoachGoalGraphic({
    required this.title,
    required this.subtitle,
    required this.exercise,
  });

  final String title;
  final String subtitle;
  final ExerciseType exercise;
}

/// Who talks: the character's name tag and the ending put after its
/// sentences (A10 spec 4.4).
class CoachVoice {
  const CoachVoice._(this.characterId, this.name, this.ending);

  /// [characterId]'s voice; an unknown id or `bot` talks as the mouse.
  factory CoachVoice.of(String characterId, {CharacterRig? rig}) {
    final id = _endings.containsKey(characterId) ? characterId : _default;
    final art = (rig ?? CharacterRig.standard).art(id);
    return CoachVoice._(id, art.name, _endings[id]!);
  }

  static const _default = 'mouse';
  static const _endings = {
    'mouse': '찍',
    'kangaroo': '깡',
    'bear': '곰',
    'penguin': '펭',
    'seal': '범',
  };

  /// The character drawn while it talks.
  final String characterId;

  /// e.g. "물렁범".
  final String name;

  /// e.g. "범", as in "수고했다범!".
  final String ending;
}

/// One battle's pace: counted reps in each of the round's slices.
class CoachPace {
  const CoachPace({required this.buckets, required this.sliceSeconds});

  /// Counted reps in each of the [battleTimeSlices] slices.
  final List<int> buckets;

  /// Seconds in one slice: 5 for a 30 s round, less after a KO.
  final double sliceSeconds;

  /// The slices that make the start; the rest make the later part.
  static const earlySlices = 2;

  /// Reps per second in each slice, so a KO round's shorter slices compare
  /// on the same scale.
  List<double> get rates => [
    for (final count in buckets) sliceSeconds <= 0 ? 0 : count / sliceSeconds,
  ];

  /// Reps per second at the start and in the later part.
  double get early => _mean(rates.take(earlySlices));
  double get late => _mean(rates.skip(earlySlices));
}

/// An earlier battle of the same exercise, as the talk compares with it.
class CoachEarlier {
  const CoachEarlier({required this.reps, this.pace, this.longestCombo});

  /// Its counted reps.
  final int reps;

  /// Its pace and longest combo; null when it kept no form report.
  final CoachPace? pace;
  final int? longestCombo;
}

/// What the talk is built from (A10 spec 4).
class CoachInput {
  const CoachInput({
    required this.report,
    required this.findings,
    required this.pace,
    required this.characterId,
    this.earlier = const [],
    this.lastGoal,
  });

  /// The battle's form report.
  final FormReport report;

  /// Its findings by the form analyzer ([FormAnalyzer.analyze]).
  final List<FormFinding> findings;

  /// Its pace ([FormFeedback.paceBuckets] and its slice length).
  final CoachPace pace;

  /// The character the user has now.
  final String characterId;

  /// Up to five earlier battles of the same exercise, oldest first.
  final List<CoachEarlier> earlier;

  /// The goal set after an earlier battle. Always null in A10; W11's step
  /// checks it.
  final FeedbackGoal? lastGoal;
}

/// The numbers the talk's rules look at (A10 spec 4.1), worked out once.
class CoachFacts {
  CoachFacts._(this.input, {required this.issues, required this.longestCombo});

  factory CoachFacts.of(CoachInput input) => CoachFacts._(
    input,
    issues: [
      for (final f in input.findings)
        if (f.kind == FindingKind.issue) f,
    ],
    longestCombo: longestComboOf(input.report),
  );

  final CoachInput input;

  /// The findings to fix, in the analyzer's order.
  final List<FormFinding> issues;

  /// The longest run of counted reps, by the game's combo rule.
  final int longestCombo;

  /// Faster than usual by this share or more, slower by as much.
  static const usualMargin = 0.1;

  /// The later part this much slower than the start, or more, is a drop.
  static const slowdown = 0.3;

  /// Far below any difference of reps a second, far above the rounding
  /// error of a division: exactly 10% or 30% counts.
  static const _tolerance = 1e-9;

  FormReport get report => input.report;
  ExerciseType get exercise => report.exercise;
  String get exerciseName => exercise.koreanName;
  int get validReps => report.validReps;
  int get invalidReps => report.invalidReps;
  CoachPace get pace => input.pace;
  Duration get roundLength => report.roundLength;

  /// Where the round's later half starts.
  Duration get half => roundLength ~/ 2;

  /// The earlier battles' counted reps, oldest first.
  List<int> get earlierReps => [for (final e in input.earlier) e.reps];

  /// Their mean, rounded; null without earlier battles.
  int? get average => earlierReps.isEmpty ? null : _mean(earlierReps).round();

  /// The usual reps per second in each slice: the mean over the earlier
  /// battles that kept a pace; null when none did.
  List<double>? get usualRates {
    final paces = [
      for (final e in input.earlier)
        if (e.pace case final pace?) pace.rates,
    ];
    if (paces.isEmpty) return null;
    return [
      for (var i = 0; i < pace.buckets.length; i++)
        _mean([for (final rates in paces) i < rates.length ? rates[i] : 0]),
    ];
  }

  /// This battle against the usual pace: faster than usual at the start
  /// and slower than usual in the later part. False without a usual pace.
  bool get fastStartSlowEnd {
    final usual = usualRates;
    if (usual == null) return false;
    final usualEarly = _mean(usual.take(CoachPace.earlySlices));
    final usualLate = _mean(usual.skip(CoachPace.earlySlices));
    final faster =
        pace.early > usualEarly &&
        pace.early >= usualEarly * (1 + usualMargin) - _tolerance;
    final slower =
        pace.late < usualLate &&
        pace.late <= usualLate * (1 - usualMargin) + _tolerance;
    return faster && slower;
  }

  /// The later part [slowdown] or more slower than the start.
  bool get slowedDown =>
      pace.early > 0 && pace.late <= pace.early * (1 - slowdown) + _tolerance;

  /// How much slower the later part was than the start, in percent.
  int get slowdownPercent =>
      pace.early <= 0 ? 0 : ((1 - pace.late / pace.early) * 100).round();

  /// The rejection that came up most: the analyzer's first rejection by
  /// count. Null when no rep was rejected for a reason this app knows.
  FormFinding? get topRejection {
    final rejections = [
      for (final f in issues)
        if (_reasonOf(f) != null) f,
    ];
    if (rejections.isEmpty) return null;
    // A stable sort: equal counts keep the analyzer's order.
    return rejections.reduce((a, b) => b.count > a.count ? b : a);
  }

  /// [topRejection]'s reason.
  RejectReason? get topReason => switch (topRejection) {
    final f? => _reasonOf(f),
    null => null,
  };

  /// The first good point; null without one.
  FormFinding? get firstGood =>
      input.findings.where((f) => f.kind == FindingKind.good).firstOrNull;

  /// When the counted reps closed.
  List<Duration> get validTimes => [
    for (final rep in report.reps)
      if (rep.valid) rep.at,
  ];

  /// When the reps rejected for [reason] closed.
  List<Duration> rejectTimes(RejectReason reason) => [
    for (final rep in report.reps)
      if (!rep.valid && rep.reason == reason) rep.at,
  ];

  /// Counted reps in the round's later half.
  int get lateValidReps => validTimes.where((t) => t >= half).length;

  /// The longest combo of the earlier battles that kept one; null when
  /// none did.
  int? get earlierBestCombo {
    final combos = [for (final e in input.earlier) ?e.longestCombo];
    return combos.isEmpty ? null : combos.reduce(math.max);
  }

  /// The longest combo of [report]: the same count the game's score keeps
  /// ([PlayerGameScore.combo]), as the reps close in time order.
  static int longestComboOf(
    FormReport report, {
    BattleRules rules = battleRules,
  }) {
    final score = PlayerGameScore(rules);
    final reps = [...report.reps]..sort((a, b) => a.at.compareTo(b.at));
    var longest = 0;
    for (final rep in reps) {
      if (rep.valid) {
        score.addValid(GameGrade.good, rep.at);
        longest = math.max(longest, score.combo);
      } else {
        score.addRejected();
      }
    }
    return longest;
  }

  static RejectReason? _reasonOf(FormFinding finding) {
    final code = finding.code;
    if (code == null || !code.startsWith(_rejectPrefix)) return null;
    return RejectReason.values.asNameMap()[code.substring(
      _rejectPrefix.length,
    )];
  }

  static const _rejectPrefix = 'reject.';
}

/// One goal the character offers for the next battle (A10 spec 5.1).
class GoalSuggestion {
  const GoalSuggestion({
    required this.kind,
    required this.target,
    required this.baseline,
    required this.title,
    required this.subtitle,
  });

  final GoalKind kind;
  final int target;

  /// This battle's value of [kind].
  final int baseline;

  /// e.g. "스쿼트 20회 인정받기".
  final String title;

  /// e.g. "이번 판 18회보다 2회 더".
  final String subtitle;

  /// The goal to save when the user picks this one.
  FeedbackGoal toGoal({
    required ExerciseType exercise,
    required DateTime setAt,
    required String characterId,
    required String fromMatch,
  }) => FeedbackGoal(
    exercise: exercise,
    kind: kind,
    target: target,
    baseline: baseline,
    title: title,
    setAt: setAt,
    characterId: characterId,
    fromMatch: fromMatch,
  );

  @override
  String toString() => 'GoalSuggestion(${kind.name} $target: $title)';
}

/// The two goals offered after a battle (A10 spec 5.1).
abstract final class CoachGoals {
  /// A record goal and a goal on the weakest point, in that order.
  static List<GoalSuggestion> suggest(CoachFacts facts) => [
    record(facts),
    weakPoint(facts),
  ];

  /// More counted reps: two above this battle or the recent average,
  /// whichever is higher.
  static GoalSuggestion record(CoachFacts facts) {
    final reps = facts.validReps;
    final target = math.max(reps, facts.average ?? reps) + 2;
    return GoalSuggestion(
      kind: GoalKind.reps,
      target: target,
      baseline: reps,
      title: '${facts.exerciseName} $target회 인정받기',
      subtitle: '이번 판 $reps회보다 ${target - reps}회 더',
    );
  }

  /// The first that fits: keep the pace late in the round, fewer
  /// rejections, or a longer combo.
  static GoalSuggestion weakPoint(CoachFacts facts) {
    if (facts.slowedDown) {
      final later = facts.lateValidReps;
      return GoalSuggestion(
        kind: GoalKind.lateReps,
        target: later + 2,
        baseline: later,
        title: '후반 ${_seconds(facts.half)}초에 ${later + 2}회 이상',
        subtitle: '이번 판 후반은 $later회',
      );
    }
    final rejected = facts.invalidReps;
    if (rejected >= 2) {
      final target = math.max(0, rejected - 2);
      return GoalSuggestion(
        kind: GoalKind.maxRejects,
        target: target,
        baseline: rejected,
        title: '무효 $target회 이하',
        subtitle: '이번 판 무효 $rejected회',
      );
    }
    final combo = facts.longestCombo;
    // A combo is two reps or more, so the goal is at least two.
    final target = math.max(combo, 1) + 1;
    return GoalSuggestion(
      kind: GoalKind.combo,
      target: target,
      baseline: combo,
      title: '콤보 $target번 이상',
      subtitle: '이번 판 최고 콤보 $combo번',
    );
  }
}

/// One part of the talk before the goal question: the lines it adds, in
/// order, or none.
typedef CoachTalkStep = List<CoachLine> Function(
  CoachFacts facts,
  CoachVoice voice,
);

/// The talk's steps of A10 spec 4.2, items 1 to 4.
abstract final class CoachSteps {
  /// Item 1, always: the counted reps, and against the recent average.
  static List<CoachLine> summary(CoachFacts f, CoachVoice v) {
    final e = v.ending;
    final reps = f.validReps;
    final average = f.average;
    final difference = average == null ? 0 : reps - average;
    return [
      CoachLine(
        pose: average != null && difference >= 0
            ? CoachPose.win
            : CoachPose.idle,
        pieces: [
          CoachPiece('수고했다$e! 이번 ${f.exerciseName}에서 '),
          CoachPiece('$reps번', marked: true),
          const CoachPiece(' 인정받았어.'),
          if (average != null)
            ...switch (difference) {
              > 0 => [
                CoachPiece(' 최근 ${f.earlierReps.length}판 평균보다 '),
                CoachPiece('$difference번 더', marked: true),
                const CoachPiece(' 했어!'),
              ],
              0 => const [CoachPiece(' 평균만큼 했어.')],
              _ => [CoachPiece(' 평균보다 ${-difference}번 적었지만 괜찮아.')],
            },
        ],
        graphic: CoachScoreGraphic(
          reps: reps,
          earlier: f.earlierReps,
          average: average,
        ),
      ),
    ];
  }

  /// Item 2, with four counted reps or more: the pace.
  static List<CoachLine> pace(CoachFacts f, CoachVoice v) {
    if (f.validReps < minRepsForPace) return const [];
    final e = v.ending;
    final usual = f.usualRates;
    final slice = f.pace.sliceSeconds;
    CoachPaceGraphic card(CoachPaceMark mark, {bool againstStart = false}) =>
        CoachPaceGraphic(
          buckets: f.pace.buckets,
          sliceSeconds: slice,
          usual: usual == null || againstStart
              ? null
              : [for (final r in usual) r * slice],
          mark: mark,
        );
    if (f.fastStartSlowEnd) {
      final start = _secondsText(slice * CoachPace.earlySlices);
      return [
        CoachLine(
          pose: CoachPose.idle,
          pieces: [
            const CoachPiece('먼저 페이스를 살펴보자. '),
            CoachPiece('초반 $start초', marked: true),
            const CoachPiece('는 평소보다 빨랐는데, 그다음부터는 평소보다 '),
            const CoachPiece('느려졌어', marked: true),
            const CoachPiece('.'),
          ],
          graphic: card(CoachPaceMark.early),
        ),
        CoachLine(
          pose: CoachPose.idle,
          pieces: [
            const CoachPiece('멈추지 않고 '),
            const CoachPiece('같은 속도로', marked: true),
            CoachPiece(' 하는 게 중요하다$e! 처음부터 너무 달리지 말자.'),
          ],
          graphic: card(CoachPaceMark.late),
        ),
      ];
    }
    // A later part 30% or more slower than its own start is no even pace,
    // with or without a usual one (task.md W10 decision 9).
    if (f.slowedDown) {
      return [
        CoachLine(
          pose: CoachPose.idle,
          pieces: [
            const CoachPiece('후반에 속도가 '),
            CoachPiece('${f.slowdownPercent}%', marked: true),
            CoachPiece(' 떨어졌어. 처음부터 끝까지 같은 속도로 가 보자$e.'),
          ],
          // The card compares with the start too, as the line does.
          graphic: card(CoachPaceMark.late, againstStart: true),
        ),
      ];
    }
    return [
      CoachLine(
        pose: CoachPose.win,
        pieces: [
          const CoachPiece('처음부터 끝까지 '),
          const CoachPiece('고른 속도', marked: true),
          CoachPiece('였어. 좋다$e!'),
        ],
        graphic: card(CoachPaceMark.none),
      ),
    ];
  }

  /// The counted reps below which the pace is not talked about.
  static const minRepsForPace = 4;

  /// Item 3, when there is something to fix: the biggest rejection (or the
  /// first other issue), then how to fix it on a page of its own (task.md
  /// W10 decision 8: one page went past four lines).
  static List<CoachLine> form(CoachFacts f, CoachVoice v) {
    if (f.issues.isEmpty) return const [];
    final top = f.topRejection;
    final reason = f.topReason;
    final CoachFormGraphic card;
    final List<CoachPiece> first;
    final FormFinding issue;
    if (top != null && reason != null) {
      issue = top;
      final word = reason.signLabel;
      final count = top.count;
      final rejected = f.invalidReps;
      final times = f.rejectTimes(reason);
      card = CoachFormGraphic(
        reason: reason,
        word: word,
        sentence: reason.koreanMessage,
        count: count,
        roundLength: f.roundLength,
        validTimes: f.validTimes,
        rejectTimes: times,
      );
      final quoted = '‘$word’${Josa.ieot.of(word)}어.';
      final lateCount = card.lateCount;
      first = [
        const CoachPiece('인정 못 받은 '),
        CoachPiece('$rejected번', marked: true),
        CoachPiece(count >= rejected ? '은 모두 $quoted' : ' 중 $count번이 $quoted'),
        if (lateCount > 0 && lateCount * 2 >= count) ...[
          const CoachPiece(' '),
          CoachPiece('${_seconds(f.half)}초가 지나', marked: true),
          const CoachPiece(' 지치니까 그랬던 것 같아.'),
        ],
      ];
    } else {
      issue = f.issues.first;
      card = CoachFormGraphic(
        word: issue.title,
        sentence: issue.detail,
        roundLength: f.roundLength,
        validTimes: f.validTimes,
      );
      first = [
        const CoachPiece('가장 눈에 띈 건 '),
        CoachPiece('‘${issue.title}’', marked: true),
        CoachPiece('${Josa.iya.of(issue.title)}.'),
      ];
    }
    final fix = issue.fix;
    return [
      CoachLine(pose: CoachPose.hit, pieces: first, graphic: card),
      if (fix != null)
        CoachLine(
          pose: CoachPose.hit,
          pieces: [CoachPiece(fix)],
          graphic: card,
        ),
    ];
  }

  /// Item 4, when there is one: a new longest combo, else the first good
  /// point. A record needs earlier battles to beat (task.md W10 decision 2).
  static List<CoachLine> praise(CoachFacts f, CoachVoice v) {
    final e = v.ending;
    final best = f.earlierBestCombo;
    final combo = f.longestCombo;
    if (best != null && combo >= 2 && combo > best) {
      return [
        CoachLine(
          pose: CoachPose.win,
          pieces: [
            // "대신" only follows something to fix.
            CoachPiece(f.issues.isEmpty ? '콤보는 ' : '대신 콤보는 '),
            CoachPiece('$combo번', marked: true),
            CoachPiece('까지 이어 갔어. 지금까지 중에 가장 길다$e!'),
          ],
          graphic: CoachComboGraphic(combo: combo, previousBest: best),
        ),
      ];
    }
    final good = f.firstGood;
    if (good == null) return const [];
    return [
      CoachLine(
        pose: CoachPose.win,
        pieces: [
          CoachPiece('‘${good.title}’', marked: true),
          CoachPiece('${Josa.eunNeun.of(good.title)} 잘했어$e!'),
        ],
      ),
    ];
  }
}

/// The whole talk of one battle (A10 spec 4.2): the [talk] before the goal
/// question, the [question] with its two [suggestions] and '사양할래', the
/// line after the choice ([answer]) and the [end].
class CoachScript {
  const CoachScript._({
    required this.facts,
    required this.voice,
    required this.talk,
    required this.suggestions,
  });

  /// The talk of [input]. [steps] are the talk's parts in order; W11 adds
  /// its check of the last goal in front of [defaultSteps].
  factory CoachScript.build(
    CoachInput input, {
    List<CoachTalkStep> steps = defaultSteps,
  }) {
    final facts = CoachFacts.of(input);
    final voice = CoachVoice.of(input.characterId);
    return CoachScript._(
      facts: facts,
      voice: voice,
      talk: List.unmodifiable([
        for (final step in steps) ...step(facts, voice),
      ]),
      suggestions: List.unmodifiable(CoachGoals.suggest(facts)),
    );
  }

  /// A10 spec 4.2 items 1 to 4.
  static const defaultSteps = <CoachTalkStep>[
    CoachSteps.summary,
    CoachSteps.pace,
    CoachSteps.form,
    CoachSteps.praise,
  ];

  final CoachFacts facts;
  final CoachVoice voice;

  /// The lines before the question; the report's card says how many.
  final List<CoachLine> talk;

  /// The record goal and the weak-point goal.
  final List<GoalSuggestion> suggestions;

  /// Item 5: the goal question.
  CoachLine get question => CoachLine(
    pose: CoachPose.idle,
    pieces: [CoachPiece('다음 판 목표를 하나 세워 볼까${voice.ending}?')],
    asksGoal: true,
  );

  /// Item 6: the line after the user picked [goal], or declined (null).
  CoachLine answer(GoalSuggestion? goal) {
    final e = voice.ending;
    if (goal == null) {
      return CoachLine(
        pose: CoachPose.idle,
        pieces: [CoachPiece('알겠어. 이번엔 목표 없이 편하게 해 보자. 다음에 또 이야기하자$e!')],
      );
    }
    final exercise = facts.exerciseName;
    return CoachLine(
      pose: CoachPose.win,
      pieces: [
        const CoachPiece('좋아! '),
        CoachPiece('‘${goal.title}’', marked: true),
        CoachPiece(
          ' 목표로 적어 둘게. ${Josa.eulReul.after(exercise)} 고르면 '
          '보여 줄 테니 다음 판에서 확인하자$e!',
        ),
      ],
      graphic: CoachGoalGraphic(
        title: goal.title,
        subtitle: goal.subtitle,
        exercise: facts.exercise,
      ),
    );
  }

  /// Item 7: the last line.
  CoachLine get end => CoachLine(
    pose: CoachPose.win,
    pieces: [CoachPiece('오늘 이야기는 여기까지! 리포트로 돌아갈게${voice.ending}.')],
  );
}

double _mean(Iterable<num> values) {
  if (values.isEmpty) return 0;
  return values.fold<double>(0, (sum, v) => sum + v) / values.length;
}

/// [d] in seconds as the talk says them: whole, or with one decimal.
String _seconds(Duration d) => _secondsText(d.inMilliseconds / 1000);

String _secondsText(double seconds) {
  final tenths = (seconds * 10).round();
  return tenths % 10 == 0
      ? '${tenths ~/ 10}'
      : (tenths / 10).toStringAsFixed(1);
}
