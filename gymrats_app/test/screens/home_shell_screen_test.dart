import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/screens/home_shell_screen.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('opens home with the logout action, and no tab bar', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    Future<void> logOut() async {}

    await tester.pumpWidget(
      Provider<UserRepository>.value(
        value: FakeUserRepository(),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: HomeShellScreen(onLogOut: logOut),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<HomeScreen>(find.byType(HomeScreen)).onLogOut,
      same(logOut),
    );
    // History opens from the lobby's 기록보관소 now.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('기록보관소'), findsOneWidget);
  });

  testWidgets('home can be replaced for tests', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeShellScreen(buildHome: () => const Text('home'))),
    );
    expect(find.text('home'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
