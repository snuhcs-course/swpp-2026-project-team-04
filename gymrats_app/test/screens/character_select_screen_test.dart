import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/screens/character_select_screen.dart';
import 'package:gymrats_app/services/user/character_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/character_viewmodel.dart';
import 'package:gymrats_app/widgets/accent_button.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:provider/provider.dart';

void main() {
  late MemoryCharacterStore store;
  late CharacterViewModel account;

  // A tap that misses its target must fail here, not pass with nothing done.
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);

  setUp(() async {
    store = MemoryCharacterStore()..values[7] = 'kangaroo';
    account = CharacterViewModel(store: store);
    await account.load(7);
    addTearDown(account.dispose);
  });

  /// The preview idles on its own clock, so the tests move time by hand
  /// instead of settling.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// The selection over a stub page ('below') over the first page
  /// ('root'), with the app's character above the navigator as in main.dart.
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(360, 780),
    double textScale = 1,
    bool reducedMotion = false,
    CharacterViewModel? characters,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ChangeNotifierProvider<CharacterViewModel>.value(
        value: characters ?? account,
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const CharacterSelectScreen(),
                          ),
                        ),
                        child: const Text('below'),
                      ),
                    ),
                  ),
                ),
                child: const Text('root'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('root'));
    await settle(tester);
    await tester.tap(find.text('below'));
    await settle(tester);
  }

  /// A cell's name, not the band's.
  Finder cellText(String name) =>
      find.descendant(of: find.byType(GridView), matching: find.text(name));

  String previewId(WidgetTester tester) => tester
      .widget<CharacterIdleFigure>(find.byType(CharacterIdleFigure))
      .characterId;

  testWidgets('shows the account\'s character large, its name and line, and '
      'the five characters to pick from', (tester) async {
    await open(tester);
    expect(find.text('캐릭터 선택'), findsOneWidget);
    expect(previewId(tester), 'kangaroo');
    final preview = tester.widget<CharacterIdleFigure>(
      find.byType(CharacterIdleFigure),
    );
    expect(preview.scale, 1.5);
    expect(preview.side.name, 'me');
    // The name is on the band and on its cell.
    expect(find.text('그루'), findsNWidgets(2));
    expect(find.text('캥거루 · 키 큰 점프 선수'), findsOneWidget);
    for (final name in ['GYM마우스', '곰탱이', '펭뚱이', '물렁범']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('RepBot'), findsNothing);
    // Five small still pictures, one large idling one.
    final cells = tester
        .widgetList<CharacterFigure>(find.byType(CharacterFigure))
        .where((figure) => figure.scale == 0.56)
        .map((figure) => figure.characterId);
    expect(cells, ['mouse', 'kangaroo', 'bear', 'penguin', 'seal']);
    expect(find.widgetWithText(AccentButton, '이 캐릭터로 하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tapped cell changes the preview, the name and the line, '
      'and nothing is saved yet', (tester) async {
    await open(tester);
    await tester.tap(find.text('펭뚱이'));
    await settle(tester);
    expect(previewId(tester), 'penguin');
    expect(find.text('펭뚱이'), findsNWidgets(2));
    expect(find.text('펭귄 · 지느러미로 때려요'), findsOneWidget);
    expect(find.text('그루'), findsOneWidget, reason: 'only its cell now');
    expect(account.characterId, 'kangaroo');
    expect(store.values[7], 'kangaroo');
  });

  testWidgets('이 캐릭터로 하기 saves the pick for the account and goes back', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('물렁범'));
    await settle(tester);
    await tester.tap(find.text('이 캐릭터로 하기'));
    await settle(tester);
    expect(find.byType(CharacterSelectScreen), findsNothing);
    expect(find.text('below'), findsOneWidget);
    expect(account.characterId, 'seal');
    expect(store.values[7], 'seal');
  });

  group('while a slow save runs', () {
    late _SlowStore slow;
    late CharacterViewModel characters;

    /// Made inside the test, so the save finishes on the test's clock.
    Future<void> slowAccount() async {
      slow = _SlowStore();
      characters = CharacterViewModel(store: slow);
      addTearDown(characters.dispose);
      await characters.load(7);
    }

    testWidgets('a second tap on 이 캐릭터로 하기 goes back only once', (
      tester,
    ) async {
      await slowAccount();
      await open(tester, characters: characters);
      await tester.tap(cellText('물렁범'));
      await tester.pump();
      await tester.tap(find.text('이 캐릭터로 하기'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('이 캐릭터로 하기'));
      await tester.pump(const Duration(milliseconds: 50));
      slow.written.complete();
      await settle(tester);
      expect(find.byType(CharacterSelectScreen), findsNothing);
      expect(find.text('below'), findsOneWidget);
      expect(slow.writes, 1);
      expect(characters.characterId, 'seal');
    });

    testWidgets('back during the save goes back only once', (tester) async {
      await slowAccount();
      await open(tester, characters: characters);
      await tester.tap(cellText('곰탱이'));
      await tester.pump();
      await tester.tap(find.text('이 캐릭터로 하기'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byTooltip('뒤로'));
      // The save ends while the page is still sliding away.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CharacterSelectScreen), findsOneWidget);
      slow.written.complete();
      await settle(tester);
      expect(find.text('below'), findsOneWidget);
      expect(find.text('root'), findsNothing);
      expect(characters.characterId, 'bear');
    });
  });

  testWidgets('the layout and type follow the design (ChSelectB)', (
    tester,
  ) async {
    await open(tester, reducedMotion: true);
    final text = Theme.of(tester.element(find.byType(CharacterSelectScreen)))
        .textTheme;
    TextStyle styleOf(Finder finder) => tester.widget<Text>(finder).style!;

    // Type: Do Hyeon 30 for the title and the name, 13 bold for the rest.
    expect(styleOf(find.text('캐릭터 선택')), text.characterTitle);
    expect(text.characterTitle.fontFamily, AppFonts.display);
    expect(text.characterTitle.fontSize, 30);
    expect(text.characterTitle.height! * 30, closeTo(36, 1e-9));
    final bandName = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data == '그루' &&
          w.maxLines == 1 &&
          w.style == text.characterName,
    );
    expect(bandName, findsOneWidget);
    expect(text.characterName.fontFamily, AppFonts.display);
    expect(text.characterName.fontSize, 30);
    expect(text.characterName.height, 1.25);
    expect(styleOf(find.text('캥거루 · 키 큰 점프 선수')), text.characterCaption);
    expect(styleOf(cellText('곰탱이')), text.characterCellName);
    for (final small in [text.characterCaption, text.characterCellName]) {
      expect(small.fontSize, 13);
      expect(small.fontWeight, FontWeight.w700);
    }

    // The preview: 300 high under a 3 px ink edge, the feet 246 into it,
    // the floor 192 x 18 under them, in the middle.
    final preview = tester.getRect(
      find
          .ancestor(
            of: find.byType(CharacterIdleFigure),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(preview.height, 300);
    expect(preview.width, 360);
    final figure = tester.getRect(find.byType(CharacterIdleFigure));
    expect(figure.top + 150 * 1.5, preview.top + 3 + 246);
    final floor = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is ShapeDecoration &&
          (w.decoration as ShapeDecoration).shape is StadiumBorder,
    );
    expect(
      tester.getRect(floor),
      Rect.fromLTWH(84, preview.top + 3 + 244, 192, 18),
    );
    expect(
      (tester.widget<DecoratedBox>(floor).decoration as ShapeDecoration).color,
      AppColors.accent,
    );

    // The name band leans like the stage's bands.
    final slant = tester.widget<Transform>(
      find.descendant(
        of: find.ancestor(of: bandName, matching: find.byType(Stack)).first,
        matching: find.byType(Transform),
      ),
    );
    expect(slant.transform, AppHighlight.battleSlant);

    // The cells: card corners, three to a row, 124 high.
    final cell = tester.widget<Material>(
      find.ancestor(of: cellText('곰탱이'), matching: find.byType(Material)).first,
    );
    expect(
      (cell.shape! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.all(Radius.circular(AppRadius.card)),
    );
    final first = tester.getRect(
      find
          .ancestor(of: cellText('GYM마우스'), matching: find.byType(Material))
          .first,
    );
    expect(first.height, 124);
    expect(first.left, 16);
  });

  testWidgets('back goes back without saving', (tester) async {
    await open(tester);
    await tester.tap(find.text('곰탱이'));
    await settle(tester);
    await tester.tap(find.byTooltip('뒤로'));
    await settle(tester);
    expect(find.byType(CharacterSelectScreen), findsNothing);
    expect(account.characterId, 'kangaroo');
    expect(store.values[7], 'kangaroo');
  });

  testWidgets('each cell says its name and animal, and which is picked', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('그루, 캥거루')),
      matchesSemantics(
        label: '그루, 캥거루',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('곰탱이, 곰')),
      matchesSemantics(
        label: '곰탱이, 곰',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('the picked cell is lime with a thicker ink edge', (
    tester,
  ) async {
    await open(tester);
    ShapeBorder shapeOf(String name) => tester
        .widget<Material>(
          find
              .ancestor(of: cellText(name), matching: find.byType(Material))
              .first,
        )
        .shape!;
    Color colorOf(String name) => tester
        .widget<Material>(
          find
              .ancestor(of: cellText(name), matching: find.byType(Material))
              .first,
        )
        .color!;
    expect(colorOf('곰탱이'), AppColors.card);
    expect((shapeOf('곰탱이') as RoundedRectangleBorder).side.width, 1.5);
    await tester.tap(find.text('곰탱이'));
    await settle(tester);
    expect(colorOf('곰탱이'), AppColors.accent);
    expect((shapeOf('곰탱이') as RoundedRectangleBorder).side.width, 3);
    expect((shapeOf('GYM마우스') as RoundedRectangleBorder).side.width, 1.5);
  });

  testWidgets('the preview stands the character on the floor in the middle', (
    tester,
  ) async {
    await open(tester, reducedMotion: true);
    final figure = tester.getRect(find.byType(CharacterIdleFigure));
    expect(figure.size, const Size(210, 240));
    // The feet (70, 150 of the box) at 1.5 times, on the screen's middle.
    expect(figure.left + 70 * 1.5, 180);
  });

  testWidgets('fits a 360 x 640 phone and a large text size, scrolling if '
      'it must', (tester) async {
    await open(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('물렁범'),
      50,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('이 캐릭터로 하기'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await open(tester, textScale: 2);
    expect(tester.takeException(), isNull);
  });
}

/// Saves only when told to, like a slow phone.
class _SlowStore implements CharacterStore {
  final written = Completer<void>();
  int writes = 0;

  @override
  Future<String> read(int accountId) async => 'kangaroo';

  @override
  Future<void> write(int accountId, String characterId) {
    writes++;
    return written.future;
  }
}
