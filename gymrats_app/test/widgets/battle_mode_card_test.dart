import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_mode_card.dart';
import 'package:gymrats_app/widgets/lobby_parts.dart';

/// Tests otherwise draw every letter as the same square. The fonts stay loaded
/// for the rest of the run, so the tests that load them come last in the file.
Future<void> _loadAppFonts(WidgetTester tester) => tester.runAsync(() async {
  for (final entry in const {
    AppFonts.number: ['assets/fonts/Oxanium-Bold.ttf'],
    AppFonts.headline: ['assets/fonts/BlackHanSans-Regular.ttf'],
    AppFonts.body: [
      'assets/fonts/IBMPlexSansKR-Regular.ttf',
      'assets/fonts/IBMPlexSansKR-Medium.ttf',
      'assets/fonts/IBMPlexSansKR-Bold.ttf',
    ],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
});

void main() {
  // A tap that misses its target must fail here, not pass with nothing done.
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);

  int onlineTaps = 0;

  /// The two cards side by side, as 게임 시작 has them, in [height].
  Future<void> show(
    WidgetTester tester, {
    Size size = const Size(360, 780),
    double height = 440,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    onlineTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: BattleModeCard(
                        tag: 'ONLINE 1V1',
                        title: '온라인 1v1',
                        line: '다른 사람과\n실시간으로 대결',
                        offer: '푸쉬업 · 스쿼트',
                        color: AppColors.accent,
                        shade: AppColors.accentDeep,
                        picture: const BattleModePicture.online(),
                        onTap: () => onlineTaps++,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: BattleModeCard(
                        tag: 'AI 1V1',
                        title: 'AI 1v1',
                        line: 'RepBot과\n난이도별 대결',
                        offer: '초보 · 중수 · 고수',
                        color: AppColors.opponent,
                        shade: AppColors.opponentDeep,
                        shadeRises: false,
                        picture: const BattleModePicture.bot(),
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder inCard(String title, Finder finder) => find.descendant(
    of: find.ancestor(
      of: find.text(title),
      matching: find.byType(BattleModeCard),
    ),
    matching: finder,
  );

  testWidgets('shows the band over its tag, title, line and offer', (
    tester,
  ) async {
    await show(tester);
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    final band = tester.getRect(
      inCard('온라인 1v1', find.byType(BattleModePicture)),
    );
    expect(band.bottom, lessThan(top('ONLINE 1V1')));
    expect(top('ONLINE 1V1'), lessThan(top('온라인 1v1')));
    expect(top('온라인 1v1'), lessThan(top('다른 사람과\n실시간으로 대결')));
    expect(top('다른 사람과\n실시간으로 대결'), lessThan(top('푸쉬업 · 스쿼트')));
  });

  testWidgets('the arrow takes the card\'s color', (tester) async {
    await show(tester);
    LobbyArrowChip chipOf(String title) => tester.widget<LobbyArrowChip>(
      inCard(title, find.byType(LobbyArrowChip)),
    );
    expect(chipOf('온라인 1v1').color, AppColors.accent);
    expect(chipOf('AI 1v1').color, AppColors.opponent);
  });

  testWidgets('the band is its color with the shade slanted across', (
    tester,
  ) async {
    await show(tester);
    Finder bandOf(String title) => find.ancestor(
      of: inCard(title, find.byType(BattleModePicture)),
      matching: find.byType(CustomPaint),
    );
    expect(
      bandOf('온라인 1v1').first,
      paints
        ..rect(color: AppColors.accent)
        ..path(color: AppColors.accentDeep),
    );
    expect(
      bandOf('AI 1v1').first,
      paints
        ..rect(color: AppColors.opponent)
        ..path(color: AppColors.opponentDeep),
    );
  });

  testWidgets('online pits a person against a person, AI against RepBot', (
    tester,
  ) async {
    await show(tester);
    expect(
      inCard('온라인 1v1', find.byIcon(Icons.person_outline_rounded)),
      findsNWidgets(2),
    );
    expect(
      inCard('AI 1v1', find.byIcon(Icons.person_outline_rounded)),
      findsOneWidget,
    );
    expect(
      inCard('AI 1v1', find.byIcon(Icons.smart_toy_outlined)),
      findsOneWidget,
    );
    expect(find.text('VS'), findsNWidgets(2));
  });

  testWidgets('tapping the band or the text calls back', (tester) async {
    await show(tester);
    await tester.tap(inCard('온라인 1v1', find.byType(BattleModePicture)));
    await tester.tap(find.text('푸쉬업 · 스쿼트'));
    expect(onlineTaps, 2);
  });

  testWidgets('both cards are the same size and fill the height', (
    tester,
  ) async {
    await show(tester);
    final cards = find.byType(BattleModeCard);
    expect(tester.getSize(cards.first), tester.getSize(cards.last));
    expect(tester.getSize(cards.first).height, 440);
  });

  testWidgets('a short card keeps the band at its least height', (
    tester,
  ) async {
    await show(tester, height: 400);
    final band = tester.getSize(
      find
          .ancestor(
            of: inCard('온라인 1v1', find.byType(BattleModePicture)),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(band.height, greaterThanOrEqualTo(120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a screen reader hears one sentence and can tap it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await show(tester);
    const sentence = '온라인 1v1, 다른 사람과 실시간으로 대결, 푸쉬업 · 스쿼트';
    expect(find.bySemanticsLabel(sentence), findsOneWidget);
    tester.semantics.tap(find.semantics.byLabel(sentence));
    expect(onlineTaps, 1);
    semantics.dispose();
  });

  group('with the real fonts', () {
    /// The width a text was given, after any FittedBox above it scaled it.
    double shownWidth(WidgetTester tester, Finder text) {
      final box = tester.renderObject<RenderBox>(text);
      return box.localToGlobal(Offset(box.size.width, 0)).dx -
          box.localToGlobal(Offset.zero).dx;
    }

    testWidgets('every text fits at its full size at 360 wide', (tester) async {
      await _loadAppFonts(tester);
      await show(tester);
      final texts = find.descendant(
        of: find.byType(BattleModeCard),
        matching: find.byType(Text),
      );
      // Tag, title, line and offer, and "VS", on each card.
      expect(texts, findsNWidgets(10));
      for (final element in texts.evaluate()) {
        final text = find.byWidget(element.widget).first;
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
        );
        expect(
          shownWidth(tester, text),
          moreOrLessEquals(tester.getSize(text).width, epsilon: 0.01),
          reason: '${element.widget}',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at 320 wide at text scale 2 when tall '
        'enough', (tester) async {
      await _loadAppFonts(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await show(tester, size: const Size(320, 900), height: 560);
      expect(tester.takeException(), isNull);
    });
  });
}
