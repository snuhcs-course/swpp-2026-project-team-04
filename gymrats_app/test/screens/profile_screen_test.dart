import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/screens/profile_screen.dart';
import 'package:gymrats_app/services/auth/in_memory_auth_repository.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/services/user/avatar_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';

import '../support/fakes.dart';
import '../support/flow_snapshot.dart';

class _FailingStore extends MemoryAvatarStore {
  bool fail = true;
  @override
  Future<void> write(int id, AvatarModel avatar) async {
    if (fail) throw StateError('test storage failure');
    await super.write(id, avatar);
  }
}

class _Session extends OnlineBattleSession {
  _Session({
    required super.endpoint,
    required super.accessToken,
    required super.avatar,
  });
  @override
  Future<void> connect() async {
    phase = OnlinePhase.queued;
    connected = true;
    notifyListeners();
  }
}

Future<InMemoryAuthRepository> _auth() async {
  final auth = InMemoryAuthRepository()
    ..addAccount(
      loginId: 'profile',
      nickname: '내프로필',
      password: 'test-password',
    );
  await auth.logIn(loginId: 'profile', password: 'test-password');
  return auth;
}

void main() {
  testWidgets(
    'profile offers four avatars, saves the selection and restores it',
    (tester) async {
      await prepareFlowSnapshotFonts(tester);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = await _auth();
      final avatars = MemoryAvatarStore();
      Widget app() => MaterialApp(
        theme: AppTheme.dark,
        home: ProfileScreen(
          auth: auth,
          avatars: avatars,
          previewBuilder: (model) => ColoredBox(
            color: AppColors.card,
            child: Center(child: Text('Preview · ${model.label}')),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('내프로필'), findsOneWidget);
      expect(find.byType(RadioListTile<AvatarModel>), findsNWidgets(4));
      await captureFlowSnapshot('profile-avatars');
      await tester.scrollUntilVisible(find.text('XCVG Humanoid'), 160);
      await tester.tap(find.text('XCVG Humanoid'));
      await tester.pumpAndSettle();
      expect(
        await avatars.read(auth.session!.account.id),
        AvatarModel.humanoid,
      );
      expect(
        tester
            .widget<RadioGroup<AvatarModel>>(
              find.byType(RadioGroup<AvatarModel>),
            )
            .groupValue,
        AvatarModel.humanoid,
      );
      expect(find.text('저장했어요. 다음 온라인 대결에 적용됩니다.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RadioGroup<AvatarModel>>(
              find.byType(RadioGroup<AvatarModel>),
            )
            .groupValue,
        AvatarModel.humanoid,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('save failure preserves last saved avatar and allows retry', (
    tester,
  ) async {
    final auth = await _auth();
    final avatars = _FailingStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ProfileScreen(
          auth: auth,
          avatars: avatars,
          previewBuilder: (_) => const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Corebreaker Robot'), 160);
    await tester.tap(find.text('Corebreaker Robot'));
    await tester.pumpAndSettle();
    expect(await avatars.read(auth.session!.account.id), AvatarModel.astronaut);
    expect(find.text('저장하지 못했어요. 다시 선택해주세요.'), findsOneWidget);
    avatars.fail = false;
    await tester.ensureVisible(find.text('Corebreaker Robot'));
    await tester.tap(find.text('Corebreaker Robot'));
    await tester.pumpAndSettle();
    expect(await avatars.read(auth.session!.account.id), AvatarModel.robot);
  });

  testWidgets(
    'home profile selection is shared with the primary online button',
    (tester) async {
      await prepareFlowSnapshotFonts(tester);
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = await _auth();
      final avatars = MemoryAvatarStore();
      _Session? joined;
      await tester.pumpWidget(
        testApp(
          auth: auth,
          avatarStore: avatars,
          createOnlineSession: (u, t, a) =>
              joined = _Session(endpoint: u, accessToken: t, avatar: a),
        ),
      );
      await tester.pumpAndSettle();
      await captureFlowSnapshot('home-online-primary');
      await tester.tap(find.byTooltip('프로필'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Corebreaker Robot'), 160);
      await tester.tap(find.text('Corebreaker Robot'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('온라인 1v1 대결'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(joined!.avatar, AvatarModel.robot);
      expect(find.text('실시간 상대를 찾는 중'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<AvatarModel>), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
