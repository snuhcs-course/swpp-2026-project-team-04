import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/theme/app_theme.dart';

void main() {
  final theme = AppTheme.dark;

  test('is dark and uses the design colors', () {
    final scheme = theme.colorScheme;
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(scheme.primary, AppColors.accent);
    expect(scheme.onPrimary, AppColors.background);
    expect(scheme.surface, AppColors.background);
    expect(scheme.onSurface, AppColors.textPrimary);
    expect(scheme.onSurfaceVariant, AppColors.textSecondary);
    expect(scheme.outline, AppColors.border);
  });

  test('text uses the primary text color', () {
    expect(theme.textTheme.bodyMedium!.color, AppColors.textPrimary);
    expect(theme.textTheme.displayLarge!.color, AppColors.textPrimary);
  });

  test('Oxanium for numbers, Black Han Sans for titles, Plex for the rest', () {
    final text = theme.textTheme;
    expect(text.displayLarge!.fontFamily, AppFonts.number);
    expect(text.displayLarge!.fontWeight, FontWeight.w700);
    expect(text.headlineMedium!.fontFamily, AppFonts.headline);
    expect(text.titleMedium!.fontFamily, AppFonts.body);
    expect(text.bodyMedium!.fontFamily, AppFonts.body);
    expect(text.labelLarge!.fontFamily, AppFonts.body);
  });

  test('falls back to Plex for glyphs Oxanium and Black Han Sans lack', () {
    expect(theme.textTheme.displayLarge!.fontFamilyFallback, [AppFonts.body]);
    expect(theme.textTheme.headlineMedium!.fontFamilyFallback, [AppFonts.body]);
  });

  test('cards are flat, rounded and outlined', () {
    final card = theme.cardTheme;
    expect(card.color, AppColors.card);
    expect(card.elevation, 0);
    expect(
      card.shape,
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.cardRadius)),
        side: BorderSide(color: AppColors.border),
      ),
    );
  });

  testWidgets('GymRatsApp uses the dark theme', (tester) async {
    await tester.pumpWidget(const GymRatsApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, same(AppTheme.dark));
  });
}
