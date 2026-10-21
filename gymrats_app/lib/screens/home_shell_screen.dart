// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'history_screen.dart';
import 'home_screen.dart';

/// The two tabs after login: 홈 and 기록.
enum HomeTab { home, history }

/// The first screen after login: a bottom bar with 홈 | 기록.
///
/// Each tab is built when it is chosen, so coming back to it shows the
/// battles saved meanwhile (a battle is played from 홈 and lands in both).
class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({
    super.key,
    this.onLogOut,
    this.initialTab = HomeTab.home,
    this.buildHome,
    this.buildHistory,
  });

  /// Passed to [HomeScreen]: logs out after the user confirms.
  final Future<void> Function()? onLogOut;

  final HomeTab initialTab;

  /// Build the tabs; replace the default screens in tests. [openHistory]
  /// switches to the 기록 tab.
  final Widget Function(VoidCallback openHistory)? buildHome;
  final Widget Function()? buildHistory;

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  late HomeTab _tab = widget.initialTab;

  void _select(HomeTab tab) {
    if (tab != _tab) setState(() => _tab = tab);
  }

  void _openHistory() => _select(HomeTab.history);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Back on 기록 goes to 홈 first, like other tab bars; back on 홈 leaves.
    return PopScope(
      canPop: _tab == HomeTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(HomeTab.home);
      },
      child: _scaffold(text),
    );
  }

  Widget _scaffold(TextTheme text) {
    return Scaffold(
      body: switch (_tab) {
        HomeTab.home =>
          widget.buildHome?.call(_openHistory) ??
              HomeScreen(
                onLogOut: widget.onLogOut,
                onOpenHistory: _openHistory,
              ),
        HomeTab.history =>
          widget.buildHistory?.call() ?? const HistoryScreen(asTab: true),
      },
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (i) => _select(HomeTab.values[i]),
          backgroundColor: AppColors.card,
          indicatorColor: AppColors.accent.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => text.bodySmall?.copyWith(
              color: states.contains(WidgetState.selected)
                  ? AppColors.accent
                  : AppColors.textSecondary,
            ),
          ),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.accent),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(
                Icons.history_rounded,
                color: AppColors.accent,
              ),
              label: '기록',
            ),
          ],
        ),
      ),
    );
  }
}
