// The 3D avatars and their assets are gone (W3); the ids stay only for
// `avatar_store.dart`, which `test/support/fakes.dart` still uses.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/shared/battle_protocol.dart';
import 'package:gymrats_app/services/user/avatar_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('catalog IDs are unique, preserve originals and have the shape the '
      'server takes', () {
    expect(AvatarModel.values, hasLength(28));
    expect(AvatarModel.astronaut.protocolId, 'avatar_01');
    expect(AvatarModel.robot.protocolId, 'avatar_02');
    expect(AvatarModel.mannequiny.protocolId, 'avatar_03');
    expect(AvatarModel.humanoid.protocolId, 'avatar_04');
    // Old apps still send these; the server takes any such short id.
    expect(
      AvatarModel.values.map((a) => a.protocolId),
      everyElement(predicate(isBattleAvatarId)),
    );
    expect(AvatarModel.values.map((a) => a.assetName).toSet(), hasLength(28));
  });
  test('every new choice survives secure-store reload without changing another account', () async {
    final store = SecureAvatarStore();
    FlutterSecureStorage.setMockInitialValues({});
    for (final avatar in AvatarModel.values) {
      await store.write(42, avatar);
      expect(await SecureAvatarStore().read(42), avatar);
      expect(await store.read(43), AvatarModel.astronaut);
    }
  });
}
