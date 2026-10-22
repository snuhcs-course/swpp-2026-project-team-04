import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/services/user/avatar_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'secure avatar selection survives a new store and is isolated per account',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'gymrats.session': 'existing-login-session',
      });
      await SecureAvatarStore().write(7, AvatarModel.robot);
      expect(await SecureAvatarStore().read(7), AvatarModel.robot);
      expect(await SecureAvatarStore().read(8), AvatarModel.astronaut);
      expect(
        await const FlutterSecureStorage().read(key: 'gymrats.session'),
        'existing-login-session',
      );
    },
  );

  test(
    'missing or obsolete model ID falls back to the supported default',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'gymrats.avatar.7': 'obsolete-avatar',
      });
      final store = SecureAvatarStore();
      expect(await store.read(7), AvatarModel.astronaut);
      expect(await store.read(9), AvatarModel.astronaut);
      await store.write(7, AvatarModel.humanoid);
      expect(await store.read(7), AvatarModel.humanoid);
    },
  );
}
