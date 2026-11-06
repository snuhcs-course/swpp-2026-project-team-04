// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:flutter/material.dart';

import 'home_screen.dart';

/// The first screen after login: the home lobby.
///
/// It held the 홈 | 기록 tabs until the lobby got its own 기록보관소 entry,
/// which opens the history as a page; the app still starts here.
class HomeShellScreen extends StatelessWidget {
  const HomeShellScreen({super.key, this.onLogOut, this.buildHome});

  /// Passed to [HomeScreen]: logs out after the user confirms.
  final Future<void> Function()? onLogOut;

  /// Builds home; replaces the default screen in tests.
  final Widget Function()? buildHome;

  @override
  Widget build(BuildContext context) =>
      buildHome?.call() ?? HomeScreen(onLogOut: onLogOut);
}
