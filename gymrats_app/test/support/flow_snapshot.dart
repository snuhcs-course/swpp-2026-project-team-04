import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _fontsLoaded = false;

/// Flutter tests otherwise use the placeholder Ahem font, not the app's fonts.
Future<void> prepareFlowSnapshotFonts(WidgetTester tester) async {
  if (const String.fromEnvironment('ONLINE_FLOW_SNAPSHOT_URI').isEmpty ||
      _fontsLoaded) {
    return;
  }
  await tester.runAsync(() async {
    for (final entry in {
      'BlackHanSans': ['assets/fonts/BlackHanSans-Regular.ttf'],
      'Oxanium': ['assets/fonts/Oxanium-Bold.ttf'],
      'IBMPlexSansKR': [
        'assets/fonts/IBMPlexSansKR-Regular.ttf',
        'assets/fonts/IBMPlexSansKR-Medium.ttf',
        'assets/fonts/IBMPlexSansKR-Bold.ttf',
      ],
      'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final asset in entry.value) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }
    _fontsLoaded = true;
  });
}

/// Optional visual QA output outside the repository. No snapshots in CI unless
/// an explicit file URI is provided along with --update-goldens.
Future<void> captureFlowSnapshot(String name) async {
  const directory = String.fromEnvironment('ONLINE_FLOW_SNAPSHOT_URI');
  if (directory.isEmpty) return;
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(Uri.parse('$directory/$name.png')),
  );
}
