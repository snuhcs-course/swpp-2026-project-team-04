#!/usr/bin/env python3
"""Export the frozen development-trained knee classifier and Dart parity cases.

The paired benchmark owns feature extraction, model settings and split rules.
This script reuses those Python functions and exports their selected baseline.
Generated artifacts stay outside the repository unless explicitly requested.
"""

import argparse
import csv
import json
from pathlib import Path

import numpy as np
from sklearn.utils.class_weight import compute_sample_weight

import compare_sapiens_mlkit as benchmark


DART_CLASS = r'''
/// Five-phase, two-class classifier exported from the paired pose benchmark.
/// Supply 10/30/50/70/90 percent samples of one completed attempt, in order.
/// This classifier evaluates an already segmented attempt.
class KneeForestClassifier {
  static const double rejectionThreshold = 0.5;
  static const int phaseCount = 5;
  static const int featureCount = 432;
  static const List<int> _joints = <int>[
    11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28,
  ];

  /// Returns null when fewer than three phases contain all twelve body joints.
  /// A probability strictly above [rejectionThreshold] selects knees-down.
  static double? kneeProbability(List<PoseFrame?> phaseFrames) {
    final features = featuresForPhases(phaseFrames);
    return features == null ? null : probabilityFromFeatures(features);
  }

  static List<double>? featuresForPhases(List<PoseFrame?> phaseFrames) {
    if (phaseFrames.length != phaseCount) {
      throw ArgumentError.value(phaseFrames.length, 'phaseFrames.length',
          'Exactly five chronological phase samples are required');
    }
    final samples = phaseFrames.map(_frameFeatures).toList(growable: false);
    final observed = samples.whereType<List<double>>().toList(growable: false);
    if (observed.length < 3) return null;
    final median = List<double>.generate(48, (column) {
      final values = observed.map((row) => row[column]).toList()..sort();
      final middle = values.length ~/ 2;
      return values.length.isOdd
          ? values[middle]
          : (values[middle - 1] + values[middle]) / 2;
    }, growable: false);
    final matrix = samples.map((row) => row ?? median).toList(growable: false);
    final mean = List<double>.filled(48, 0);
    final standardDeviation = List<double>.filled(48, 0);
    final minimum = List<double>.filled(48, double.infinity);
    final maximum = List<double>.filled(48, double.negativeInfinity);
    for (var column = 0; column < 48; column++) {
      for (final row in matrix) {
        mean[column] += row[column];
        minimum[column] = math.min(minimum[column], row[column]);
        maximum[column] = math.max(maximum[column], row[column]);
      }
      mean[column] /= phaseCount;
      for (final row in matrix) {
        final deviation = row[column] - mean[column];
        standardDeviation[column] += deviation * deviation;
      }
      standardDeviation[column] =
          math.sqrt(standardDeviation[column] / phaseCount);
    }
    return <double>[
      for (final row in matrix) ...row,
      ...mean, ...standardDeviation, ...minimum, ...maximum,
    ];
  }

  static double probabilityFromFeatures(List<double> features) {
    if (features.length != featureCount ||
        features.any((value) => !value.isFinite)) {
      throw ArgumentError('Expected 432 finite feature values');
    }
    // sklearn applies its float64 scaler before the forest's float32 cast.
    final scaled = Float32List(featureCount);
    for (var index = 0; index < featureCount; index++) {
      scaled[index] = (features[index] - _mean[index]) / _scale[index];
    }
    var probability = 0.0;
    for (final root in _roots) {
      var node = root;
      while (_feature[node] >= 0) {
        node = scaled[_feature[node]] <= _threshold[node]
            ? _left[node]
            : _right[node];
      }
      probability += _kneeProbability[node];
    }
    return probability / _roots.length;
  }

  static List<double>? _frameFeatures(PoseFrame? frame) {
    if (frame == null || !frame.imageWidth.isFinite ||
        !frame.imageHeight.isFinite || frame.imageWidth <= 0 ||
        frame.imageHeight <= 0) {
      return null;
    }
    final coordinates = <List<double>>[];
    for (final index in _joints) {
      final point = frame[BodyLandmark.values[index]];
      if (point == null || !point.x.isFinite || !point.y.isFinite) return null;
      coordinates.add(<double>[point.x, point.y]);
    }
    final torso = (_distance(coordinates[0], coordinates[6]) +
        _distance(coordinates[1], coordinates[7])) / 2;
    final scale = math.max(torso, math.max(
        _distance(coordinates[0], coordinates[1]),
        math.sqrt(frame.imageWidth * frame.imageWidth +
            frame.imageHeight * frame.imageHeight) * 0.04));
    final originX = (coordinates[6][0] + coordinates[7][0]) / 2;
    final originY = (coordinates[6][1] + coordinates[7][1]) / 2;
    final relative = coordinates.map((point) => <double>[
      ((point[0] - originX) / scale).clamp(-8.0, 8.0).toDouble(),
      ((point[1] - originY) / scale).clamp(-8.0, 8.0).toDouble(),
    ]).toList(growable: false);
    final values = <double>[for (final point in relative) ...point];
    for (var side = 0; side < 2; side++) {
      final shoulder = side;
      final elbow = side + 2;
      final wrist = side + 4;
      final hip = side + 6;
      final knee = side + 8;
      final ankle = side + 10;
      values.addAll(<double>[
        _angle(coordinates[shoulder], coordinates[elbow], coordinates[wrist]),
        _angle(coordinates[shoulder], coordinates[hip], coordinates[knee]),
        _angle(coordinates[hip], coordinates[knee], coordinates[ankle]),
      ]);
      for (final pair in <List<int>>[
        <int>[hip, wrist], <int>[knee, wrist],
        <int>[ankle, wrist], <int>[knee, ankle],
      ]) {
        values.add(relative[pair[0]][0] - relative[pair[1]][0]);
        values.add(relative[pair[0]][1] - relative[pair[1]][1]);
      }
      final supportX = relative[ankle][0] - relative[wrist][0];
      final supportY = relative[ankle][1] - relative[wrist][1];
      final offsetX = relative[knee][0] - relative[wrist][0];
      final offsetY = relative[knee][1] - relative[wrist][1];
      final length = math.max(
          math.sqrt(supportX * supportX + supportY * supportY), 0.05);
      values.add((supportX * offsetY - supportY * offsetX) / length);
    }
    return values;
  }

  static double _distance(List<double> first, List<double> second) {
    final x = first[0] - second[0];
    final y = first[1] - second[1];
    return math.sqrt(x * x + y * y);
  }

  static double _angle(List<double> first, List<double> middle,
      List<double> last) {
    final firstX = first[0] - middle[0];
    final firstY = first[1] - middle[1];
    final lastX = last[0] - middle[0];
    final lastY = last[1] - middle[1];
    final denominator = math.sqrt(firstX * firstX + firstY * firstY) *
        math.sqrt(lastX * lastX + lastY * lastY);
    if (denominator < 1e-8) return 0;
    final cosine = ((firstX * lastX + firstY * lastY) / denominator)
        .clamp(-1.0, 1.0).toDouble();
    return math.acos(cosine) / math.pi;
  }
'''


DART_VALIDATOR = r'''
void main(List<String> arguments) {
  var maximumFeatureError = 0.0;
  var maximumProbabilityError = 0.0;
  var records = 0;
  var unknown = 0;
  var sameDecisions = 0;
  var normalCorrect = 0;
  var kneeCorrect = 0;
  var holdoutCount = 0;
  for (final line in File(arguments.single).readAsLinesSync()) {
    final record = jsonDecode(line) as Map<String, dynamic>;
    final phases = (record['phases'] as List).map<PoseFrame?>((dynamic item) {
      if (item == null) return null;
      final points = item['points'] as List;
      final keypoints = <BodyLandmark, Keypoint>{};
      for (var index = 0; index < points.length; index++) {
        final point = points[index] as List?;
        if (point == null) continue;
        final landmark = BodyLandmark.values[index];
        keypoints[landmark] = Keypoint(landmark: landmark,
            x: (point[0] as num).toDouble(),
            y: (point[1] as num).toDouble(), likelihood: 1);
      }
      return PoseFrame(imageWidth: (item['width'] as num).toDouble(),
          imageHeight: (item['height'] as num).toDouble(), keypoints: keypoints);
    }).toList();
    final features = KneeForestClassifier.featuresForPhases(phases);
    final expected = record['features'] as List?;
    if ((features == null) != (expected == null)) {
      throw StateError('Feature availability mismatch at ${record['id']}');
    }
    final probability = KneeForestClassifier.kneeProbability(phases);
    final expectedProbability = (record['knee_probability'] as num?)?.toDouble();
    if (features == null) {
      unknown++;
    } else {
      for (var index = 0; index < features.length; index++) {
        maximumFeatureError = math.max(maximumFeatureError,
            (features[index] - (expected![index] as num).toDouble()).abs());
      }
      maximumProbabilityError = math.max(maximumProbabilityError,
          (probability! - expectedProbability!).abs());
    }
    final prediction = probability == null ? -1 : (probability > 0.5 ? 1 : 0);
    if (prediction != record['prediction']) {
      throw StateError('Decision mismatch at ${record['id']}');
    }
    sameDecisions++;
    records++;
    if (record['split'] == 'holdout') {
      holdoutCount++;
      if (prediction == 0 && record['label'] == 'normal') normalCorrect++;
      if (prediction == 1 && record['label'] == 'kneesDown') kneeCorrect++;
    }
  }
  if (maximumFeatureError > 1e-9 || maximumProbabilityError > 1e-12) {
    throw StateError('Python/Dart numerical parity tolerance exceeded');
  }
  print(jsonEncode(<String, dynamic>{
    'records': records, 'unknown': unknown, 'same_decisions': sameDecisions,
    'maximum_feature_error': maximumFeatureError,
    'maximum_probability_error': maximumProbabilityError,
    'holdout_count': holdoutCount, 'holdout_normal_correct': normalCorrect,
    'holdout_knee_correct': kneeCorrect,
  }));
}
'''


def dart_list(name, values, integer=False):
    element_type = "int" if integer else "double"
    literals = [str(int(value)) if integer else repr(float(value)) for value in values]
    lines = ["    " + ", ".join(literals[index:index + 6]) + ","
             for index in range(0, len(literals), 6)]
    return (f"  static const List<{element_type}> {name} = <{element_type}>[\n"
            + "\n".join(lines) + "\n  ];\n")


def flatten_forest(forest):
    values = {name: [] for name in ("roots", "feature", "threshold", "left", "right", "kneeProbability")}
    for estimator in forest.estimators_:
        tree = estimator.tree_
        offset = len(values["feature"])
        values["roots"].append(offset)
        values["feature"].extend(tree.feature.tolist())
        values["threshold"].extend(tree.threshold.tolist())
        values["left"].extend(-1 if child < 0 else child + offset for child in tree.children_left)
        values["right"].extend(-1 if child < 0 else child + offset for child in tree.children_right)
        counts = tree.value[:, 0, :]
        values["kneeProbability"].extend((counts[:, 1] / counts.sum(axis=1)).tolist())
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--predictions", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    report = json.loads(args.report.read_text(encoding="utf-8"))
    benchmark.check_manifest(manifest)
    if benchmark.file_hash(args.manifest) != report["manifest_sha256"]:
        raise ValueError("Manifest differs from the frozen benchmark")
    if benchmark.file_hash(args.predictions) != report["baseline_input"]["predictions_sha256"]:
        raise ValueError("Baseline predictions differ from the frozen benchmark")
    baseline_key = report["baseline_key"]
    selected = report["models"][baseline_key]["selected"]
    if selected != "forest_depth4":
        raise ValueError(f"Expected the selected depth-four forest, received {selected}")
    frames = {frame["key"]: frame for frame in manifest["frames"]}
    predictions = benchmark.read_predictions(args.predictions)
    benchmark.check_prediction_coverage(frames, predictions)
    units = manifest["units"]
    if any(len(unit["frame_keys"]) != 5 for unit in units):
        raise ValueError("Exactly five frozen phases are required")
    features = [benchmark.unit_features(unit, frames, predictions) for unit in units]
    train = [index for index, unit in enumerate(units)
             if unit["split"] == "development" and features[index] is not None]
    target = np.asarray([benchmark.LABELS.index(units[index]["label"]) for index in train])
    model = benchmark.candidate_models()[selected]
    model.fit(np.stack([features[index] for index in train]), target,
              randomforestclassifier__sample_weight=compute_sample_weight("balanced", target))
    scaler = model.named_steps["standardscaler"]
    forest = model.named_steps["randomforestclassifier"]
    if forest.classes_.tolist() != [0, 1]:
        raise ValueError("The export requires normal/kneesDown class order")
    available = [index for index, feature in enumerate(features) if feature is not None]
    probabilities = [None] * len(units)
    result = np.full(len(units), -1, dtype=int)
    matrix = np.stack([features[index] for index in available])
    result[available] = model.predict(matrix)
    for index, probability in zip(available, model.predict_proba(matrix)[:, 1]):
        probabilities[index] = float(probability)
    holdout = [index for index, unit in enumerate(units) if unit["split"] == "holdout"]
    measured = benchmark.metrics([benchmark.LABELS.index(units[index]["label"]) for index in holdout],
                                 result[holdout])
    if measured != report["models"][baseline_key]["holdout"]:
        raise ValueError("Refitted model does not reproduce the selected holdout result")
    with (args.report.parent / "holdout-predictions.csv").open(encoding="utf-8-sig") as stream:
        published = {row["unit_id"]: row for row in csv.DictReader(stream)}
    for index in holdout:
        prediction = "unknown" if result[index] < 0 else benchmark.LABELS[result[index]]
        if prediction != published[units[index]["id"]][baseline_key]:
            raise ValueError(f"Refit changed published decision for {units[index]['id']}")
    args.out.mkdir(parents=True, exist_ok=True)
    flattened = flatten_forest(forest)
    source = "// Generated by tools/diagnose/export_mobile_knee_forest.py.\n"
    source += f"// Frozen manifest SHA256 {report['manifest_sha256']}.\n"
    source += f"// Seed {benchmark.SEED}, {len(train)} usable development intervals, 150 trees.\n"
    source += DART_CLASS
    source += dart_list("_mean", scaler.mean_)
    source += dart_list("_scale", scaler.scale_)
    for name, values in flattened.items():
        source += dart_list("_" + name, values, name in ("roots", "feature", "left", "right"))
    source += "}\n"
    snippet = args.out / "knee_forest.dart"
    snippet.write_text(source, encoding="utf-8")
    validation = args.out / "validation.jsonl"
    goldens = {}
    with validation.open("w", encoding="utf-8", newline="\n") as stream:
        for index, unit in enumerate(units):
            phases = []
            for key in unit["frame_keys"]:
                frame, points = frames[key], predictions[key]
                phases.append(None if points is None else {
                    "width": frame["width"], "height": frame["height"],
                    "points": [point[:2] if point is not None and joint in benchmark.JOINTS else None
                               for joint, point in enumerate(points)]})
            row = {"id": unit["id"], "split": unit["split"], "label": unit["label"],
                   "phases": phases, "features": None if features[index] is None else features[index].tolist(),
                   "prediction": int(result[index]), "knee_probability": probabilities[index]}
            stream.write(json.dumps(row, allow_nan=False, separators=(",", ":")) + "\n")
            if unit["label"] not in goldens and result[index] == benchmark.LABELS.index(unit["label"]):
                goldens[unit["label"]] = row
    for label, row in goldens.items():
        benchmark.save_json(args.out / ("golden_" + label + ".json"), row)
    pose_file = Path(__file__).resolve().parents[2] / "gymrats_app/lib/models/pose_frame.dart"
    validator = ("import 'dart:convert';\nimport 'dart:io';\nimport 'dart:math' as math;\n"
                 "import 'dart:typed_data';\n" + f"import '{pose_file.as_uri()}';\n" + source + DART_VALIDATOR)
    (args.out / "validate_knee_forest.dart").write_text(validator, encoding="utf-8")
    summary = {
        "selected": selected, "baseline_name": report["baseline_name"],
        "training_usable_intervals": len(train), "training_scope": "development only",
        "seed": benchmark.SEED, "trees": len(forest.estimators_),
        "nodes": len(flattened["feature"]), "features": int(scaler.n_features_in_),
        "holdout": measured, "published_holdout_decisions_reproduced": len(holdout),
        "validation_records": len(units), "unknown_records": int(np.sum(result < 0)),
        "input_hashes": {"manifest": benchmark.file_hash(args.manifest),
                         "predictions": benchmark.file_hash(args.predictions),
                         "report": benchmark.file_hash(args.report),
                         "benchmark_helper": benchmark.file_hash(Path(benchmark.__file__)),
                         "exporter": benchmark.file_hash(Path(__file__))},
        "output_hashes": {"dart_snippet": benchmark.file_hash(snippet),
                          "validation_records": benchmark.file_hash(validation)},
        "phase_fractions": list(benchmark.PHASES), "minimum_valid_phases": 3,
        "feature_contract": "12 joints, no confidence threshold; same 48 frame features and 432 unit features as paired benchmark",
        "numeric_contract": "float64 features/scaling, float32 scaled forest input, float64 thresholds/probabilities",
        "decision_contract": "kneesDown only if probability > 0.5; missing coverage returns null",
        "limitations": report["limitations"],
    }
    benchmark.save_json(args.out / "export-report.json", summary)
    print(json.dumps({key: value for key, value in summary.items()
                      if key not in ("input_hashes", "output_hashes", "limitations")}, indent=2))


if __name__ == "__main__":
    main()
