import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/feedback_goal.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/services/feedback/goal_progress.dart';
import 'package:gymrats_app/services/feedback/goal_store.dart';

/// A goal of [kind] and [target] for [exercise], set with the seal.
FeedbackGoal goalOf(
  GoalKind kind,
  int target, {
  ExerciseType exercise = ExerciseType.squat,
}) => FeedbackGoal(
  exercise: exercise,
  kind: kind,
  target: target,
  baseline: target - 2,
  title: '목표 $target',
  setAt: DateTime(2026, 11, 17, 14),
  characterId: 'seal',
  fromMatch: 'report-1',
);

/// Reps closed at [valid] seconds (counted) and [rejected] seconds.
List<RepRecord> reps({
  List<double> valid = const [],
  List<double> rejected = const [],
}) {
  final all = [
    for (final t in valid) (t, true),
    for (final t in rejected) (t, false),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [
    for (final (i, (t, counted)) in all.indexed)
      RepRecord(
        index: i,
        valid: counted,
        at: Duration(milliseconds: (t * 1000).round()),
        reason: counted ? null : RejectReason.shallowSquat,
      ),
  ];
}

const round = Duration(seconds: 30);

/// A store whose reads of [failing] throw.
class _ThrowingStore extends MemoryGoalStore {
  _ThrowingStore(this.failing);

  final ExerciseType failing;

  @override
  Future<FeedbackGoal?> read(int accountId, ExerciseType exercise) {
    if (exercise == failing) throw StateError('locked');
    return super.read(accountId, exercise);
  }
}

void main() {
  group('reps: counted reps, at least the target', () {
    test('counts only the counted reps; reached at the target', () {
      final goal = goalOf(GoalKind.reps, 3);
      final two = GoalProgress.of(
        goal,
        reps(valid: [1, 2], rejected: [3]),
        roundLength: round,
      );
      expect(two.value, 2);
      expect(two.reached, isFalse);
      expect(two.fill, closeTo(2 / 3, 1e-9));
      expect(two.chipText(late: false), '목표 2/3');

      final three = GoalProgress.of(
        goal,
        reps(valid: [1, 2, 4], rejected: [3]),
        roundLength: round,
      );
      expect(three.value, 3);
      expect(three.reached, isTrue);
      expect(three.fill, 1);
      expect(three.chipText(late: true), '목표 3/3');
    });

    test('past the target the chip says the real count, all lime', () {
      final p = GoalProgress.of(
        goalOf(GoalKind.reps, 2),
        reps(valid: [1, 2, 3, 4]),
        roundLength: round,
      );
      expect(p.chipText(late: false), '목표 4/2');
      expect(p.fill, 1);
      expect(p.over, isFalse);
    });

    test('no reps yet: 0, nothing filled', () {
      final p = GoalProgress.of(
        goalOf(GoalKind.reps, 20),
        const [],
        roundLength: round,
      );
      expect(p.value, 0);
      expect(p.fill, 0);
      expect(p.chipText(late: false), '목표 0/20');
    });
  });

  group('lateReps: counted reps in the later half', () {
    test('a rep exactly on the half counts as late; one just before does '
        'not', () {
      final p = GoalProgress.of(
        goalOf(GoalKind.lateReps, 3),
        reps(valid: [5, 14.999, 15, 20], rejected: [16]),
        roundLength: round,
      );
      expect(GoalProgress.lateFrom(round), const Duration(seconds: 15));
      expect(p.value, 2);
      expect(p.reached, isFalse);
    });

    test('the chip waits for the later half, then counts', () {
      final p = GoalProgress.of(
        goalOf(GoalKind.lateReps, 8),
        reps(valid: [16, 17, 18]),
        roundLength: round,
      );
      expect(p.chipText(late: false), '후반 목표 8');
      expect(p.chipText(late: true), '후반 3/8');
      expect(p.chipLabel(late: false), '후반 목표 8회');
      expect(p.chipLabel(late: true), '후반 목표 8회 중 3회');
    });

    test('a KO at 20 s keeps the full round\'s half (15 s) and its reps '
        'so far', () {
      // The round ended early, but the half is still 15 s into 30 s.
      final p = GoalProgress.of(
        goalOf(GoalKind.lateReps, 2),
        reps(valid: [8, 12, 16, 19.5]),
        roundLength: round,
        ended: true,
      );
      expect(p.value, 2);
      expect(p.reached, isTrue);
    });
  });

  group('combo: the longest run, by the game\'s rule', () {
    test('reps at most 1.5 s apart run on; a longer gap starts over', () {
      final p = GoalProgress.of(
        goalOf(GoalKind.combo, 4),
        // 1.0 -> 2.5 -> 4.0 is three (1.5 s gaps); 5.6 is 1.6 s later.
        reps(valid: [1, 2.5, 4, 5.6, 6.6]),
        roundLength: round,
      );
      expect(p.value, 3);
      expect(p.reached, isFalse);
      expect(p.chipText(late: false), '콤보 3/4');
    });

    test('a rejected rep breaks the combo', () {
      final p = GoalProgress.of(
        goalOf(GoalKind.combo, 3),
        reps(valid: [1, 2, 3.2, 4], rejected: [2.6]),
        roundLength: round,
      );
      // 1, 2 | rejected | 3.2, 4: two runs of two.
      expect(p.value, 2);
    });

    test('reps in any order are taken in time order', () {
      final ordered = reps(valid: [1, 2, 3]);
      final shuffled = [ordered[2], ordered[0], ordered[1]];
      expect(GoalProgress.longestCombo(shuffled), 3);
    });

    test('one counted rep is a combo of one; reached at the target', () {
      expect(GoalProgress.longestCombo(reps(valid: [3])), 1);
      final p = GoalProgress.of(
        goalOf(GoalKind.combo, 2),
        reps(valid: [3, 4]),
        roundLength: round,
      );
      expect(p.reached, isTrue);
      expect(p.chipLabel(late: false), '콤보 목표 2 중 최고 2, 목표 달성');
    });
  });

  group('maxRejects: rejected reps, at most the target, at the end', () {
    test('during the battle it is never reached, and white', () {
      final p = GoalProgress.of(
        goalOf(GoalKind.maxRejects, 3),
        reps(valid: [1], rejected: [2, 3]),
        roundLength: round,
      );
      expect(p.value, 2);
      expect(p.reached, isFalse);
      expect(p.over, isFalse);
      expect(p.fill, 0);
      expect(p.chipText(late: false), '무효 2/3');
      expect(p.chipLabel(late: false), '무효 3회 이하 목표, 지금 2회');
    });

    test('at the end, within the target: reached and all lime', () {
      final p = GoalProgress.of(
        goalOf(GoalKind.maxRejects, 3),
        reps(rejected: [2, 3, 4]),
        roundLength: round,
      ).atEnd();
      expect(p.ended, isTrue);
      expect(p.reached, isTrue);
      expect(p.fill, 1);
    });

    test('past the target it is over (red), at the end too', () {
      final p = GoalProgress.of(
        goalOf(GoalKind.maxRejects, 1),
        reps(rejected: [2, 3]),
        roundLength: round,
      );
      expect(p.over, isTrue);
      expect(p.atEnd().reached, isFalse);
      expect(p.atEnd().over, isTrue);
      expect(p.chipLabel(late: false), '무효 1회 이하 목표, 지금 2회, 목표를 넘었어요');
    });

    test('a target of 0: no ratio, reached at the end without a rejection', () {
      final clean = GoalProgress.of(
        goalOf(GoalKind.maxRejects, 0),
        reps(valid: [1, 2]),
        roundLength: round,
      );
      expect(clean.fill, 0);
      expect(clean.atEnd().reached, isTrue);
      expect(clean.atEnd().fill, 1);
    });
  });

  test('the sticker words of each kind (spec 2)', () {
    expect(GoalProgress.stickerText(GoalKind.reps, 20), '목표 20회');
    expect(GoalProgress.stickerText(GoalKind.lateReps, 8), '후반 8회');
    expect(GoalProgress.stickerText(GoalKind.combo, 5), '콤보 5');
    expect(GoalProgress.stickerText(GoalKind.maxRejects, 2), '무효 2회 이하');
  });

  test('the chip label of a reps goal says the count in words', () {
    final p = GoalProgress.of(
      goalOf(GoalKind.reps, 20),
      reps(valid: [1, 2]),
      roundLength: round,
    );
    expect(p.chipLabel(late: false), '이번 판 목표 20회 중 2회');
  });

  test('two progresses of the same values are equal', () {
    const a = GoalProgress(kind: GoalKind.reps, target: 3, value: 1);
    expect(a, const GoalProgress(kind: GoalKind.reps, target: 3, value: 1));
    expect(
      a.hashCode,
      const GoalProgress(kind: GoalKind.reps, target: 3, value: 1).hashCode,
    );
    expect(a == a.atEnd(), isFalse);
    expect(a.toString(), 'GoalProgress(reps 1/3)');
    expect(a.atEnd().toString(), 'GoalProgress(reps 1/3, ended)');
  });

  group('GoalTracker', () {
    test('says true once: on the rep that first reaches the goal', () {
      final tracker = GoalTracker(goalOf(GoalKind.reps, 2));
      expect(tracker.progress.value, 0);
      expect(tracker.count(reps(valid: [1]), roundLength: round), isFalse);
      expect(tracker.progress.value, 1);
      expect(tracker.count(reps(valid: [1, 2]), roundLength: round), isTrue);
      expect(
        tracker.count(reps(valid: [1, 2, 3]), roundLength: round),
        isFalse,
      );
      expect(tracker.progress.value, 3);
    });

    test('a later half and a combo goal are celebrated too', () {
      final late = GoalTracker(goalOf(GoalKind.lateReps, 1));
      expect(late.count(reps(valid: [3]), roundLength: round), isFalse);
      expect(late.count(reps(valid: [3, 16]), roundLength: round), isTrue);
      final combo = GoalTracker(goalOf(GoalKind.combo, 2));
      expect(combo.count(reps(valid: [3, 4]), roundLength: round), isTrue);
    });

    test('a maxRejects goal is never celebrated during the battle', () {
      final tracker = GoalTracker(goalOf(GoalKind.maxRejects, 0));
      expect(tracker.count(reps(valid: [1, 2]), roundLength: round), isFalse);
      expect(tracker.progress.reached, isFalse);
      expect(tracker.progress.atEnd().reached, isTrue);
    });
  });

  group('readGoals', () {
    test(
      'reads each exercise\'s goal of the account; none is left out',
      () async {
        final store = MemoryGoalStore();
        final squat = goalOf(GoalKind.reps, 20);
        await store.write(1, squat);
        await store.write(
          2,
          goalOf(GoalKind.combo, 4, exercise: ExerciseType.pushUp),
        );
        expect(await readGoals(store, 1), {ExerciseType.squat: squat});
        expect((await readGoals(store, 2)).keys, [ExerciseType.pushUp]);
        expect(await readGoals(store, 3), isEmpty);
      },
    );

    test('a read that fails is no goal; the others still come', () async {
      final store = _ThrowingStore(ExerciseType.pushUp);
      final squat = goalOf(GoalKind.reps, 20);
      await store.write(1, squat);
      expect(await readGoals(store, 1), {ExerciseType.squat: squat});
    });

    test('a goal saved under another exercise is not this one\'s', () async {
      final store = MemoryGoalStore();
      store.goals[(1, ExerciseType.pushUp)] = goalOf(GoalKind.reps, 9);
      expect(await readGoals(store, 1), isEmpty);
    });
  });
}
