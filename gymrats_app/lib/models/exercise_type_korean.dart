import 'exercise_type.dart';

/// Korean exercise names for the screens.
///
/// [ExerciseType.label] is English, and exercise_type.dart is a shared model,
/// so the Korean names live here.
extension ExerciseTypeKorean on ExerciseType {
  /// Name shown on screen, e.g. "푸쉬업".
  String get koreanName => switch (this) {
    ExerciseType.pushUp => '푸쉬업',
  };
}
