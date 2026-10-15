// Sign-up, login, and match history demo without the server.
//
// Run from gymrats_app/:
//   flutter run -t lib/demo/auth_history_demo.dart -d <device-id>
//
// The app as it is, on in-memory accounts and battles instead of the
// GymRats server: it opens on login with nobody signed up. One account
// exists already: id "demo_user", password "password1". Its history has
// 45 battles, so the list loads three pages of 20 as it scrolls. A new
// account starts with the same battles. Everything is forgotten when the
// app closes.
//
// To try the real server instead, run the app itself:
//   flutter run -d <device-id>
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/exercise_type.dart';
import '../models/match_record.dart';
import '../services/auth/in_memory_auth_repository.dart';
import '../services/user/in_memory_user_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(authHistoryDemoApp());
}

/// The battles in the demo history: one every evening, newest first.
List<MatchRecord> demoMatches({int count = 45, DateTime? now}) {
  final latest = now ?? DateTime.now();
  return [
    for (var i = 0; i < count; i++)
      MatchRecord(
        exercise: ExerciseType.pushUp,
        opponentName: 'RepBot',
        myReps: 15 + (i * 7) % 20,
        opponentReps: 14 + (i * 5) % 20,
        playedAt: latest.subtract(Duration(days: i, minutes: i * 13)),
      ),
  ];
}

GymRatsApp authHistoryDemoApp() => GymRatsApp(
  authRepository: InMemoryAuthRepository()
    ..addAccount(loginId: 'demo_user', nickname: '데모', password: 'password1'),
  userRepository: InMemoryUserRepository(name: '데모', matches: demoMatches()),
);
