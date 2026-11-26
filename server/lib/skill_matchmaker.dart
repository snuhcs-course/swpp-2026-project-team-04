/// Skill estimates for the main match (P10).
///
/// A player's estimate for an exercise is the median of the valid reps of
/// their latest [recentMatches] battles of it. Real players are paired at
/// once, whatever their skill; the estimates only choose who a simulated
/// opponent copies when no real player came in time.
library;

/// The battles an estimate is taken over.
const recentMatches = 5;

/// The exercises the main match has.
const skillExercises = ['push_up', 'squat'];

/// The median of the first [recentMatches] values of [reps], newest first;
/// null when there are none.
double? medianOf(List<int> reps) {
  if (reps.isEmpty) return null;
  final recent = reps.take(recentMatches).toList()..sort();
  final middle = recent.length ~/ 2;
  return recent.length.isOdd
      ? recent[middle].toDouble()
      : (recent[middle - 1] + recent[middle]) / 2;
}

/// One account's recent battles, as the API server reports them.
class SkillRecord {
  const SkillRecord(this.id, this.name, this.recent);

  /// The battle server's player id (the account id) and nickname.
  final String id, name;

  /// Valid reps per exercise, newest first.
  final Map<String, List<int>> recent;

  /// The record in one `players` item of `POST /internal/skills`; null
  /// when it is not one.
  static SkillRecord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['player_id'], name = raw['display_name'];
    final recent = raw['recent'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      return null;
    }
    if (recent is! Map) return null;
    final reps = <String, List<int>>{};
    for (final exercise in skillExercises) {
      final list = recent[exercise];
      if (list == null) continue;
      if (list is! List || list.any((r) => r is! int || r < 0)) return null;
      reps[exercise] = list.cast<int>();
    }
    return SkillRecord(id, name, reps);
  }
}

/// Where the estimates come from: the API server's recent battles.
abstract interface class SkillSource {
  /// Every account with a battle, with its latest battles per exercise.
  Future<List<SkillRecord>> loadSkills();
}

/// A player in the index of one exercise.
class SkillEntry {
  const SkillEntry(this.id, this.name, this.skill);
  final String id, name;
  final double skill;
}

/// Every account's estimate per exercise, sorted by it, so the nearest one
/// to a skill is found by binary search.
///
/// [SkillIndex.build] pays for the sort once; [nearest] and [estimateOf]
/// are then O(log n) and O(1).
class SkillIndex {
  SkillIndex._(this._sorted, this._byId, this._average);

  /// An index of no one: every estimate is [defaultSkill].
  SkillIndex.empty() : this._(const {}, const {}, const {});

  /// The estimate of someone with no battle at all when nobody has one
  /// either: about the AI 1v1 middle level's reps in 30 seconds.
  static const defaultSkill = 9.0;

  /// Sorts [records] by their estimate, per exercise. A record with no
  /// battle of an exercise is not in that exercise's list.
  factory SkillIndex.build(Iterable<SkillRecord> records) {
    final sorted = <String, List<SkillEntry>>{};
    final byId = <String, Map<String, SkillEntry>>{};
    for (final exercise in skillExercises) {
      final entries = <SkillEntry>[];
      final ids = <String, SkillEntry>{};
      for (final record in records) {
        final skill = medianOf(record.recent[exercise] ?? const []);
        if (skill == null) continue;
        final entry = SkillEntry(record.id, record.name, skill);
        // A repeated account keeps its last record.
        if (ids[record.id] case final old?) entries.remove(old);
        ids[record.id] = entry;
        entries.add(entry);
      }
      entries.sort(_bySkill);
      sorted[exercise] = entries;
      byId[exercise] = ids;
    }
    final average = <String, double>{
      for (final MapEntry(:key, :value) in sorted.entries)
        if (value.isNotEmpty)
          key: value.fold<double>(0, (sum, e) => sum + e.skill) / value.length,
    };
    return SkillIndex._(sorted, byId, average);
  }

  final Map<String, List<SkillEntry>> _sorted;
  final Map<String, Map<String, SkillEntry>> _byId;
  final Map<String, double> _average;

  /// The index of the first entry of [list] with an estimate of at least
  /// [skill], or its length.
  static int _firstAtLeast(List<SkillEntry> list, double skill) {
    var low = 0, high = list.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (list[mid].skill < skill) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// Ties go to the smaller id, so a search is repeatable.
  static int _bySkill(SkillEntry a, SkillEntry b) {
    final bySkill = a.skill.compareTo(b.skill);
    return bySkill != 0 ? bySkill : compareIds(a.id, b.id);
  }

  /// Orders account ids as numbers ("2" before "10"): they are the API
  /// server's integer ids, written without leading zeros, so the shorter one
  /// is the smaller.
  static int compareIds(String a, String b) =>
      a.length != b.length ? a.length.compareTo(b.length) : a.compareTo(b);

  /// How many accounts have an estimate for [exercise].
  int count(String exercise) => _sorted[exercise]?.length ?? 0;

  /// The average estimate for [exercise], or [defaultSkill] when nobody
  /// has one.
  double average(String exercise) => _average[exercise] ?? defaultSkill;

  /// [id]'s estimate for [exercise]: the median of their latest battles, or
  /// the [average] when they have none.
  double estimateOf(String id, String exercise) =>
      _byId[exercise]?[id]?.skill ?? average(exercise);

  /// The account whose estimate for [exercise] is closest to [skill], other
  /// than [excludeId]; on a tie the lower estimate, then the smaller id.
  /// Null when there is no other account.
  SkillEntry? nearest(String exercise, double skill, {String? excludeId}) {
    final list = _sorted[exercise];
    if (list == null || list.isEmpty) return null;
    final low = _firstAtLeast(list, skill);
    // Walk out from there, skipping the player themself. Above, [low] is
    // already the smallest id of its estimate; below, go to the start of
    // the nearest lower estimate, so a tie there also takes the smallest id.
    var below = low - 1, above = low;
    if (below >= 0 && list[below].id == excludeId) below--;
    if (below >= 0) {
      below = _firstAtLeast(list, list[below].skill);
      if (list[below].id == excludeId) below++;
    }
    if (above < list.length && list[above].id == excludeId) above++;
    final down = below >= 0 ? list[below] : null;
    final up = above < list.length ? list[above] : null;
    if (down == null) return up;
    if (up == null) return down;
    return skill - down.skill <= up.skill - skill ? down : up;
  }
}

/// What [measureSkillIndex] measured, in microseconds.
class SkillIndexCost {
  const SkillIndexCost({
    required this.accounts,
    required this.lookups,
    required this.buildMicros,
    required this.lookupMicros,
  });
  final int accounts, lookups, buildMicros, lookupMicros;

  /// One lookup, on average.
  double get microsPerLookup => lookups == 0 ? 0 : lookupMicros / lookups;

  @override
  String toString() =>
      'accounts=$accounts build=${buildMicros}us '
      'lookups=$lookups total=${lookupMicros}us '
      'per_lookup=${microsPerLookup.toStringAsFixed(3)}us';
}

/// Measures the index apart from its searches (P10 → P20): building it
/// from [records], then [lookups] searches for the skills in [skills],
/// taken in turn.
SkillIndexCost measureSkillIndex(
  List<SkillRecord> records,
  List<double> skills, {
  int lookups = 10000,
  String exercise = 'push_up',
}) {
  final clock = Stopwatch()..start();
  final index = SkillIndex.build(records);
  final build = clock.elapsedMicroseconds;
  clock
    ..reset()
    ..start();
  var found = 0;
  for (var i = 0; i < lookups; i++) {
    if (index.nearest(exercise, skills[i % skills.length]) != null) found++;
  }
  final lookup = clock.elapsedMicroseconds;
  // Keeps the searches from being optimized away.
  if (found < 0) throw StateError('unreachable');
  return SkillIndexCost(
    accounts: records.length,
    lookups: lookups,
    buildMicros: build,
    lookupMicros: lookup,
  );
}
