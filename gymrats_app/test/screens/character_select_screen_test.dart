import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/character_idle_motion.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/screens/character_select_screen.dart';
import 'package:gymrats_app/services/user/character_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/character_viewmodel.dart';
import 'package:gymrats_app/widgets/accent_button.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:provider/provider.dart';

import '../widgets/battle_test_support.dart';

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

    // The line: under the floor, 4 below it, on the band's left line (user,
    // 2026-11-14; the design has it under the band).
    final line = tester.getRect(find.text('캥거루 · 키 큰 점프 선수'));
    expect(line.left, 16);
    expect(line.top, tester.getRect(floor).bottom + 4);
    expect(line.bottom, lessThanOrEqualTo(preview.bottom - 3));

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

  testWidgets('opened while the saved character is still read, 이 캐릭터로 '
      '하기 says so and cannot be pressed; then the preview takes the saved '
      'one and the button saves', (tester) async {
    final slow = _SlowReadStore()..saved[7] = 'seal';
    final reading = CharacterViewModel(store: slow);
    addTearDown(reading.dispose);
    unawaited(reading.load(7));
    await open(tester, characters: reading);
    expect(find.text('저장된 캐릭터를 불러오는 중…'), findsOneWidget);
    expect(previewId(tester), 'mouse');
    await tester.tap(find.text('이 캐릭터로 하기'), warnIfMissed: false);
    await settle(tester);
    expect(find.byType(CharacterSelectScreen), findsOneWidget);
    expect(slow.writes, 0);

    slow.finishRead();
    await settle(tester);
    expect(find.text('저장된 캐릭터를 불러오는 중…'), findsNothing);
    expect(previewId(tester), 'seal');
    await tester.tap(find.text('이 캐릭터로 하기'));
    await settle(tester);
    expect(find.byType(CharacterSelectScreen), findsNothing);
    expect(slow.saved[7], 'seal');
    expect(slow.writes, 1);
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

  // Found on the phone (user, 2026-11-14): at the top of its hop 그루's ears
  // covered the line under the name band. The line now sits under the floor.
  // Placed last: it loads the app's fonts, so the band and the line are as
  // wide as on a phone, and the tests above keep the test font.
  group('no picture overlaps the name band or its line', () {
    setUpAll(loadBattleFonts);

    final rig = CharacterRig.standard;

    /// The preview's character as drawn now, idle motion included.
    Finder figure() => find.descendant(
      of: find.byType(CharacterIdleFigure),
      matching: find.byType(CharacterFigure),
    );

    /// The name band as drawn: its slanted white box.
    Path bandArea(WidgetTester tester, String name) {
      final band = find.ancestor(
        of: find.byWidgetPredicate(
          (w) => w is Text && w.data == name && w.maxLines == 1,
        ),
        matching: find.byType(Stack),
      );
      final box = tester.renderObject<RenderBox>(
        find.descendant(of: band.first, matching: find.byType(DecoratedBox)),
      );
      final size = box.size;
      return Path()..addPolygon([
        for (final corner in [
          Offset.zero,
          size.topRight(Offset.zero),
          size.bottomRight(Offset.zero),
          size.bottomLeft(Offset.zero),
        ])
          box.localToGlobal(corner),
      ], true);
    }

    /// How many points of the character, drawn as the screen draws it now,
    /// fall inside [area], counted on a grid 8 times finer than a point.
    Future<int> paintedInside(WidgetTester tester, Path area) async {
      const fine = 8.0;
      final box = tester.renderObject<RenderBox>(figure());
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: figure(),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as CharacterFigurePainter;
      final bounds = area.getBounds();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..scale(fine)
        ..translate(-bounds.left, -bounds.top)
        ..clipPath(area)
        ..transform(box.getTransformTo(null).storage);
      painter.paint(canvas, box.size);
      final width = (bounds.width * fine).ceil();
      final height = (bounds.height * fine).ceil();
      final count = await tester.runAsync(() async {
        final image = await recorder.endRecording().toImage(width, height);
        final bytes = (await image.toByteData())!;
        image.dispose();
        var inside = 0;
        for (var i = 3; i < bytes.lengthInBytes; i += 4) {
          if (bytes.getUint8(i) > 0) inside++;
        }
        return inside;
      });
      return count!;
    }

    /// The moments to check: at rest (the feet lowest for a hop), and where
    /// each part of [motion] is at its most: the top of a hop, the lean to
    /// either side, the stretch and the squash.
    List<double> extremesOf(CharacterIdleMotion motion) => [
      0,
      if (motion.hopPeriodMs > 0) motion.hopPeriodMs / 2,
      for (final period in [motion.rockPeriodMs, motion.stretchPeriodMs])
        if (period > 0) ...[period / 4, period * 3 / 4],
    ]..sort();

    // The default text size, a larger one, and twice: the name keeps its
    // size and the line grows under the floor (user, 2026-11-14).
    for (final textScale in const [1.0, 1.3, 2.0]) {
      testWidgets('for all five, at every extreme of their idle motion (rig '
          'pose, idle motion values, 360 x 780, the app\'s fonts, '
          '$textScale× text)', (tester) async {
        // The account's 그루 first, so every cell below picks a new one.
        await open(tester, textScale: textScale);
        for (final art in rig.selectable) {
          // A cell picks the character and starts its idle clock at 0.
          await tester.ensureVisible(cellText(art.name));
          await tester.pump();
          await tester.tap(cellText(art.name));
          await tester.pump();
          await tester.pump();
          final rest = tester
              .renderObject<RenderBox>(figure())
              .localToGlobal(Offset.zero);
          final caption = find.textContaining('${art.species} · ');
          var now = 0.0;
          for (final moment in extremesOf(art.idleMotion)) {
            await tester.pump(
              Duration(microseconds: ((moment - now) * 1000).round()),
            );
            now = moment;
            final sample = art.idleMotion.sampleAt(moment);
            if (art.idleMotion.hopPeriodMs > 0) {
              // The clock is the screen's: at the top of the hop the
              // picture is hopAmp x 1.5 higher than at rest.
              final at = tester
                  .renderObject<RenderBox>(figure())
                  .localToGlobal(Offset.zero);
              expect(rest.dy - at.dy, closeTo(sample.up * 1.5, 0.01));
            }
            final where = '${art.id} at $moment ms ($sample)';
            expect(
              await paintedInside(tester, bandArea(tester, art.name)),
              0,
              reason: 'name band, $where',
            );
            expect(
              await paintedInside(
                tester,
                Path()..addRect(tester.getRect(caption)),
              ),
              0,
              reason: 'line, $where',
            );
          }
        }
      });
    }

    testWidgets('the same count finds 그루\'s ears where the line used to be, '
        'under the band', (tester) async {
      await open(tester);
      await tester.tap(cellText('GYM마우스'));
      await tester.pump();
      await tester.tap(cellText('그루'));
      await tester.pump();
      await tester.pump();
      final hop = rig.art('kangaroo').idleMotion.hopPeriodMs / 2;
      await tester.pump(Duration(microseconds: (hop * 1000).round()));
      final band = bandArea(tester, '그루').getBounds();
      final line = tester.getRect(find.text('캥거루 · 키 큰 점프 선수'));
      final designPlace = Rect.fromLTWH(
        band.left,
        band.bottom + AppSpacing.s8,
        line.width,
        line.height,
      );
      expect(
        await paintedInside(tester, Path()..addRect(designPlace)),
        greaterThan(0),
      );
    });

    testWidgets('at 2× text the name keeps the design\'s 30, and the line, '
        'grown to 1.5× at most, stays inside the preview', (tester) async {
      await open(tester, textScale: 2, reducedMotion: true);
      final text = Theme.of(tester.element(find.byType(CharacterSelectScreen)))
          .textTheme;
      final name = find.byWidgetPredicate(
        (w) => w is Text && w.data == '그루' && w.style == text.characterName,
      );
      // One line of 30 x 1.25 (laid out whole: 38); scaled it would be 75.
      expect(tester.getSize(name).height, closeTo(30 * 1.25, 1));
      final line = tester.getRect(find.text('캥거루 · 키 큰 점프 선수'));
      expect(line.height, closeTo(18 * 1.5, 0.01));
      final preview = tester.getRect(
        find
            .ancestor(
              of: find.byType(CharacterIdleFigure),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(line.bottom, lessThanOrEqualTo(preview.bottom - 3));
    });
  });
}

/// Reads only when told to ([finishRead]), like a slow phone; writes land
/// at once. A read answers what was saved when it began.
class _SlowReadStore implements CharacterStore {
  final saved = <int, String>{};
  final _reads = <(Completer<String>, String)>[];
  int writes = 0;

  void finishRead() {
    for (final (answer, value) in _reads) {
      answer.complete(value);
    }
    _reads.clear();
  }

  @override
  Future<String> read(int accountId) {
    final answer = Completer<String>();
    _reads.add((answer, saved[accountId] ?? 'mouse'));
    return answer.future;
  }

  @override
  Future<void> write(int accountId, String characterId) async {
    writes++;
    saved[accountId] = characterId;
  }
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
