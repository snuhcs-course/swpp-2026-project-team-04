// Compare the production Dart feature/inference path with the saved model.
import 'dart:convert';
import 'dart:io';

import '../../gymrats_app/lib/models/pose_frame.dart';
import '../../gymrats_app/lib/services/pose/pose_metrics.dart';

Future<void> main(List<String> args) async {
  final proposals = <String, Set<int>>{};
  for (final line in File(args[1]).readAsLinesSync()) {
    final row = jsonDecode(line);
    proposals[row['source_id']] = {
      for (final e in row['events']['app_default']) e[0] as int,
    };
  }
  final out = File(args[2]).openWrite();
  await for (final line in File(
    args[0],
  ).openRead().transform(utf8.decoder).transform(const LineSplitter())) {
    final source = jsonDecode(line);
    final wanted = proposals[source['source_id']];
    if (wanted == null) continue;
    final history = PushupMlpHistory();
    final predicted = <Map<String, Object>>[];
    for (final f in source['frames']) {
      final joints = f[2] as List?;
      final at = source['time_unit'] == 'us'
          ? Duration(microseconds: f[1])
          : Duration(milliseconds: f[1]);
      history.add(
        PoseFrame(
          imageWidth: (source['width'] as num).toDouble(),
          imageHeight: (source['height'] as num).toDouble(),
          keypoints: {
            if (joints != null)
              for (var i = 0; i < joints.length; i++)
                if (joints[i] != null)
                  BodyLandmark.values[i]: Keypoint(
                    landmark: BodyLandmark.values[i],
                    x: (joints[i][0] as num).toDouble(),
                    y: (joints[i][1] as num).toDouble(),
                    likelihood: (joints[i][2] as num).toDouble(),
                  ),
          },
        ),
        at,
      );
      if (wanted.contains(f[0])) {
        final vector = history.featuresAt(at);
        predicted.add({
          'frame': f[0],
          'features': vector,
          'probability': history.classifyAt(at),
        });
      }
    }
    out.writeln(
      jsonEncode({'source_id': source['source_id'], 'predictions': predicted}),
    );
  }
  await out.close();
}
