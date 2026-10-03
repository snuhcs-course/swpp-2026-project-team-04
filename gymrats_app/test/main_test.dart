import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/screens/coming_soon_screen.dart';
import 'package:gymrats_app/screens/home_screen.dart';
import 'package:gymrats_app/services/user/in_memory_user_repository.dart';
import 'package:gymrats_app/services/user/user_repository.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('opens on home, and start leads to the matching placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(const GymRatsApp());
    await tester.pumpAndSettle();
    expect(find.text('안녕하세요, 우현님'), findsOneWidget);

    await tester.tap(find.text('AI와 1v1 대결'));
    await tester.pumpAndSettle();
    expect(find.text('매칭 중 화면은 구현 예정'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('안녕하세요, 우현님'), findsOneWidget);
  });

  testWidgets('every screen gets the same repository', (tester) async {
    await tester.pumpWidget(const GymRatsApp());
    await tester.pumpAndSettle();
    final repository = tester
        .element(find.byType(HomeScreen))
        .read<UserRepository>();
    expect(repository, isA<InMemoryUserRepository>());

    await tester.tap(find.text('AI와 1v1 대결'));
    await tester.pumpAndSettle();
    final onPushedScreen = tester
        .element(find.byType(ComingSoonScreen))
        .read<UserRepository>();
    expect(onPushedScreen, same(repository));
  });
}
