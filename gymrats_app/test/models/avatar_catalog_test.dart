import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/shared/battle_protocol.dart';
import 'package:gymrats_app/services/user/avatar_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'catalog IDs are unique, preserve originals and match server allowlist',
    () {
      expect(AvatarModel.values, hasLength(25));
      expect(AvatarModel.astronaut.protocolId, 'avatar_01');
      expect(AvatarModel.robot.protocolId, 'avatar_02');
      expect(AvatarModel.mannequiny.protocolId, 'avatar_03');
      expect(AvatarModel.humanoid.protocolId, 'avatar_04');
      expect(
        AvatarModel.values.map((a) => a.protocolId).toSet(),
        battleAvatarIds,
      );
      expect(AvatarModel.values.map((a) => a.assetName).toSet(), hasLength(25));
    },
  );
  test(
    'all bundled avatars have embedded skinned meshes and real PNG thumbnails',
    () async {
      final inventory = jsonDecode(
        await rootBundle.loadString('assets/avatar/catalog-assets.json'),
      ) as List;
      expect(
        inventory.map((v) => v['asset']).toSet(),
        AvatarModel.values.map((a) => a.assetName).toSet(),
      );
      for (final avatar in AvatarModel.values) {
        final bytes = await rootBundle.load(avatar.assetPath);
        expect(bytes.getUint32(0, Endian.little), 0x46546c67);
        final jsonLength = bytes.getUint32(12, Endian.little);
        final gltf = jsonDecode(
          utf8.decode(
            bytes.buffer.asUint8List(bytes.offsetInBytes + 20, jsonLength),
          ),
        ) as Map;
        expect(gltf['skins'], isNotEmpty, reason: avatar.label);
        final meshes = gltf['meshes'] as List;
        expect(
          meshes.any(
            (m) => (m['primitives'] as List).any(
              (p) =>
                  p['attributes']['JOINTS_0'] != null &&
                  p['attributes']['WEIGHTS_0'] != null,
            ),
          ),
          isTrue,
          reason: avatar.label,
        );
        expect(
          (gltf['buffers'] as List).every((b) => b['uri'] == null),
          isTrue,
        );
        final png = await rootBundle.load(avatar.thumbnailPath);
        expect(png.getUint32(0), 0x89504e47);
        expect(png.lengthInBytes, greaterThan(1000));
      }
    },
  );
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
