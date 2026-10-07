import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:gymrats_app/models/pose_frame.dart';

void main() {
  test('BodyLandmark matches ML Kit PoseLandmarkType order', () {
    expect(
      BodyLandmark.values.map((l) => l.name).toList(),
      PoseLandmarkType.values.map((l) => l.name).toList(),
    );
  });
}
