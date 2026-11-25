import 'arcade_catalog.dart';

/// How far an account has come in the arcade (arcade spec 6): the most stars
/// it ever got in each of the 24 stages. Everything else is counted from
/// that one list.
class ArcadeProgress {
  /// [best] holds a count from 0 to 3 for every stage, in stage order.
  /// Throws an [ArgumentError] for any other length or count.
  ArcadeProgress(Iterable<int> best) : best = List.unmodifiable(best) {
    if (this.best.length != stageCount) {
      throw ArgumentError.value(best, 'best', 'needs $stageCount stages');
    }
    if (this.best.any((stars) => stars < 0 || stars > starsPerStage)) {
      throw ArgumentError.value(best, 'best', 'counts go from 0 to 3');
    }
  }

  /// No stage played yet: only the first one is open.
  ArcadeProgress.initial()
    : best = List.unmodifiable(List.filled(stageCount, 0));

  /// The saved form, `{"v":1,"best":[...]}` (arcade spec 7). Throws a
  /// [FormatException] for another version or a broken value.
  factory ArcadeProgress.fromJson(Object? json) {
    if (json case {
      'v': ArcadeProgress.version,
      'best': final List<Object?> best,
    }) {
      if (best.every((stars) => stars is int)) {
        try {
          return ArcadeProgress(best.cast<int>());
        } on ArgumentError catch (error) {
          throw FormatException('Arcade progress: ${error.message}');
        }
      }
    }
    throw const FormatException('Not arcade progress of this version');
  }

  /// The version of the saved form.
  static const version = 1;

  static int get stageCount => ArcadeCatalog.stages.length;

  static const starsPerStage = 3;

  /// The most stars in all: 72.
  static int get maxStars => stageCount * starsPerStage;

  /// The most stars got in each stage, from stage 1.
  final List<int> best;

  /// The most stars got in stage [number], from 1 to 24.
  int bestOf(int number) {
    RangeError.checkValueInInterval(number, 1, stageCount, 'number');
    return best[number - 1];
  }

  /// Whether stage [number] can be played: the first always, any other once
  /// the one before it has a star.
  bool isOpen(int number) {
    RangeError.checkValueInInterval(number, 1, stageCount, 'number');
    return number == 1 || best[number - 2] > 0;
  }

  /// The stage to play next: the first one with no star. Null once every
  /// stage has one.
  int? get currentStage {
    final index = best.indexOf(0);
    return index < 0 ? null : index + 1;
  }

  /// Whether floor [number]'s boss match, its last stage, has a star.
  bool isFloorCleared(int number) =>
      bestOf(ArcadeCatalog.stagesOn(number).last.number) > 0;

  /// Whether 5F shows, under construction: the last stage has a star.
  bool get showsUnderConstruction => best.last > 0;

  /// The stars of every stage together, from 0 to [maxStars].
  int get totalStars => best.fold(0, (sum, stars) => sum + stars);

  /// This progress after stage [number] was played for [stars]: the stage
  /// keeps the more of the two, so playing again never loses a star.
  ArcadeProgress withStars(int number, int stars) {
    RangeError.checkValueInInterval(stars, 0, starsPerStage, 'stars');
    if (stars <= bestOf(number)) return this;
    return ArcadeProgress([
      for (final (index, saved) in best.indexed)
        index == number - 1 ? stars : saved,
    ]);
  }

  Map<String, Object> toJson() => {'v': version, 'best': best};

  @override
  bool operator ==(Object other) {
    if (other is! ArcadeProgress || other.best.length != best.length) {
      return false;
    }
    for (var i = 0; i < best.length; i++) {
      if (other.best[i] != best[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(best);

  @override
  String toString() => 'ArcadeProgress(${best.join(',')})';
}
