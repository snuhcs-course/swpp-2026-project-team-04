import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/avatar_model.dart';
import 'package:gymrats_app/models/pose_frame.dart';
import 'package:gymrats_app/services/online/online_battle_session.dart';
import 'package:gymrats_app/widgets/opponent_avatar_panel.dart';
import 'package:gymrats_app/widgets/pose_camera_view.dart';

void main() {
  testWidgets(
    'remote panel uses received avatar and coordinates, never a camera',
    (tester) async {
      const frame = PoseFrame(
        imageWidth: 480,
        imageHeight: 640,
        keypoints: {
          BodyLandmark.leftElbow: Keypoint(
            landmark: BodyLandmark.leftElbow,
            x: 200,
            y: 300,
            likelihood: 1,
          ),
        },
      );
      PoseFrame? passed;
      AvatarModel? model;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: OpponentAvatarPanel(
                    name: '상대',
                    model: AvatarModel.robot,
                    frame: frame,
                    avatarBuilder: (f, a) {
                      passed = f;
                      model = a;
                      return const Text('remote-avatar');
                    },
                  ),
                ),
                const Expanded(child: Text('local-camera-area')),
              ],
            ),
          ),
        ),
      );
      expect(passed, same(frame));
      expect(model, AvatarModel.robot);
      expect(find.byType(PoseCameraView), findsNothing);
      expect(find.text('LIVE'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('remote-avatar')).dy,
        lessThan(tester.getTopLeft(find.text('local-camera-area')).dy),
      );
    },
  );
  test(
    'unknown avatar ID falls back to bundled default, never a remote URL',
    () {
      final p = OnlinePlayer.fromJson({
        'player_id': 'other',
        'display_name': 'Other',
        'avatar_id': 'https://untrusted/model.glb',
      });
      expect(p.avatar, AvatarModel.astronaut);
    },
  );
}
