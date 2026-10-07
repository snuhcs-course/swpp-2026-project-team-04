import '../../models/user_profile.dart';

/// Where the user's data comes from.
///
/// GymRatsApp creates one instance and shares it through Provider, so every
/// screen sees the same data. Iteration 1 has no server or login and uses
/// InMemoryUserRepository.
abstract interface class UserRepository {
  /// Loads the user's name, best record, and latest battle.
  ///
  /// Throws an [Exception] when the profile cannot be loaded.
  Future<UserProfile> fetchProfile();
}
