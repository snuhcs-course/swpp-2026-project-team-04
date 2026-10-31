import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Design Documentation 2.5.9: screens and widgets use only the names from
/// app_theme.dart. Checks the files listed in [_checked]; the older screens
/// join the list as they move onto the tokens (2.5, Iteration 2).
const _checked = [
  'lib/screens/login_screen.dart',
  'lib/screens/signup_screen.dart',
  'lib/screens/help_screen.dart',
  'lib/screens/history_screen.dart',
  'lib/screens/home_shell_screen.dart',
  'lib/screens/match_feedback_screen.dart',
  'lib/widgets/auth_form.dart',
  'lib/widgets/game_danger_edge.dart',
  'lib/widgets/game_fever_chip.dart',
  'lib/widgets/game_health_bar.dart',
  'lib/widgets/help_pictures.dart',
  'lib/widgets/help_rules.dart',
  'lib/widgets/match_record_card.dart',
  'lib/widgets/safe_warning_dialog.dart',
];

/// Pattern and what it catches.
final _rules = <RegExp, String>{
  RegExp(r'Color\(0x'): 'a raw color',
  RegExp(r'(?<!App)\bColors\.(?!transparent)'): 'a Colors.* value',
  RegExp(r'fontSize\s*:'): 'a font size',
  // A number other than 0 among the arguments of EdgeInsets.
  RegExp(
    r'EdgeInsets\.\w+\([^()]*?(?<![\w.])(?!0\b)\d+(\.\d+)?(?![\w.])[^()]*\)',
  ): 'a bare padding number',
  RegExp(r'SizedBox\(\s*(height|width)\s*:\s*\d'): 'a bare gap',
  RegExp(r'Radius\.circular\(\s*\d'): 'a bare radius',
  RegExp(r'BorderRadius\.circular\(\s*\d'): 'a bare radius',
};

void main() {
  for (final path in _checked) {
    test('$path uses only design tokens', () {
      final source = File(path).readAsStringSync();
      final problems = <String>[];
      for (final MapEntry(key: pattern, value: what) in _rules.entries) {
        for (final match in pattern.allMatches(source)) {
          final line =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          problems.add('$path:$line has $what: ${match[0]}');
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }

  test('the checker catches raw values', () {
    const bad = '''
      Color(0xFF000000); Colors.white; fontSize: 12;
      EdgeInsets.all(16); SizedBox(height: 8); Radius.circular(12);
    ''';
    final caught = _rules.keys.where((p) => p.hasMatch(bad)).length;
    expect(caught, 6);
    const good = '''
      Colors.transparent; EdgeInsets.all(AppSpacing.s16);
      EdgeInsets.fromLTRB(AppSpacing.s20, 0, AppSpacing.s20, AppSpacing.s24);
      SizedBox(height: AppSpacing.s8); Radius.circular(AppRadius.small);
    ''';
    expect(_rules.keys.where((p) => p.hasMatch(good)), isEmpty);
  });
}
