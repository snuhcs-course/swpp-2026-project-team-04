import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/character_idle_motion.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/versus_screen.dart';
import 'package:gymrats_app/services/user/character_store.dart';
import 'package:gymrats_app/services/user/settings_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/character_viewmodel.dart';
import 'package:gymrats_app/viewmodels/settings_viewmodel.dart';
import 'package:gymrats_app/widgets/battle_fighter.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:gymrats_app/widgets/exit_game_button.dart';
import 'package:gymrats_app/widgets/grid_background.dart';
import 'package:gymrats_app/widgets/player_avatar.dart';
import 'package:gymrats_app/widgets/safe_warning_dialog.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';
import '../widgets/battle_test_support.dart';

const _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: Opponent(name: 'RepBot', isBot: true),
);

void main() {
  // The app's own fonts, so the rules card and the names measure as on a
  // phone and the board's cells are as tall as on a Galaxy S22.
  setUpAll(loadBattleFonts);

  late PushLog pushes;

  /// The safety warning's 확인 button, with or without a countdown.
  final warningButton = find.descendant(
    of: find.byType(SafeWarningDialog),
    matching: find.byType(FilledButton),
  );

  /// Opens VersusScreen from a home page and, unless [seeWarning] is false,
  /// closes the safety warning it opens with. The battle route, where the
  /// pose setup is, shows its matchup. With [settings], the app's settings
  /// view model is above the app, as main.dart has it.
  ///
  /// The system's reduced motion is on, so the characters stand still and
  /// `pumpAndSettle` settles; [textScale] is the system text size and [top]
  /// the status bar's height.
  Future<void> open(
    WidgetTester tester, {
    Matchup matchup = _matchup,
    Size size = const Size(412, 915),
    bool seeWarning = true,
    Duration? warningAutoClose,
    SettingsViewModel? settings,
    CharacterViewModel? chosen,
    BattleCharacters? characters,
    double textScale = 1,
    double top = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: top);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    pushes = PushLog();
    Widget withSettings(Widget child) => settings == null
        ? child
        : ChangeNotifierProvider<SettingsViewModel>.value(
            value: settings,
            child: child,
          );
    // The app's character choice above the app, as main.dart has it.
    Widget app(Widget child) => withSettings(
      chosen == null
          ? child
          : ChangeNotifierProvider<CharacterViewModel>.value(
              value: chosen,
              child: child,
            ),
    );
    await tester.pumpWidget(
      app(
        MaterialApp(
          theme: AppTheme.dark,
          navigatorObservers: [pushes],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => VersusScreen(
                      matchup: matchup,
                      warningAutoClose: warningAutoClose,
                      characters: characters,
                    ),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
          onGenerateRoute: (settings) => switch (settings.name) {
            GymRatsApp.battleRoute => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) {
                final matchup = settings.arguments! as Matchup;
                return Scaffold(
                  appBar: AppBar(),
                  body: Text('battle vs ${matchup.opponent.name}'),
                );
              },
            ),
            _ => null,
          },
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    if (seeWarning) {
      await tester.tap(warningButton);
      await tester.pumpAndSettle();
    }
  }

  /// How often the battle, which starts with the pose setup, was opened.
  int battleOpens() =>
      pushes.names.where((name) => name == GymRatsApp.battleRoute).length;

  /// The 게임 나가기 button at the top left.
  final exitButton = find.byType(ExitGameButton);

  /// The dialog's 게임 나가기, not the button on the screen.
  final dialogExit = find.descendant(
    of: find.byType(ExitDialog),
    matching: find.text('게임 나가기'),
  );

  /// The board: the box with the ink edge drawn over its cells.
  final board = find.byWidgetPredicate(
    (w) => w is DecoratedBox && w.position == DecorationPosition.foreground,
  );

  /// Every widget on the board, in the order they are built and painted.
  List<Widget> boardWidgets() => find
      .descendant(of: board, matching: find.byWidgetPredicate((_) => true))
      .evaluate()
      .map((element) => element.widget)
      .toList();

  /// A box of [color] on the board: the cells and the line between them.
  Finder cell(Color color) => find.descendant(
    of: board,
    matching: find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == color,
    ),
  );
  final lime = cell(AppColors.accent);
  final pink = cell(AppColors.opponent);

  /// The white "VS" disc.
  final disc = find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle,
  );

  /// A player's character itself, not one of its white copies (they come
  /// first).
  Finder character(BattleSide side) => find
      .byWidgetPredicate((w) => w is CharacterFigure && w.side == side)
      .last;

  /// The white copies under a player's character.
  Finder whiteCopies(BattleSide side) => find.descendant(
    of: find.byType(ColorFiltered),
    matching: find.byWidgetPredicate(
      (w) => w is CharacterFigure && w.side == side,
    ),
  );

  /// Which character stands for [side].
  String characterOf(WidgetTester tester, BattleSide side) =>
      tester.widget<CharacterFigure>(character(side)).characterId;

  /// The two pedestals, the user's first.
  final pedestals = find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is ShapeDecoration &&
        (w.decoration as ShapeDecoration).shape ==
            const StadiumBorder(
              side: BorderSide(color: AppColors.ink, width: 3),
            ),
  );

  /// The white pill around [label].
  Finder pill(String label) => find
      .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
      .first;

  void expectRect(Rect actual, Rect expected, {String? reason}) {
    for (final (a, b) in [
      (actual.left, expected.left),
      (actual.top, expected.top),
      (actual.right, expected.right),
      (actual.bottom, expected.bottom),
    ]) {
      expect(a, moreOrLessEquals(b, epsilon: 0.01), reason: reason);
    }
  }

  void expectOffset(Offset actual, Offset expected) {
    expect(actual.dx, moreOrLessEquals(expected.dx, epsilon: 0.01));
    expect(actual.dy, moreOrLessEquals(expected.dy, epsilon: 0.01));
  }

  /// The parts of [style] the design sets.
  List<Object?> look(TextStyle? style) => [
    style?.fontFamily,
    style?.fontSize,
    style?.fontWeight,
    style?.height,
    style?.letterSpacing,
    style?.color,
  ];

  testWidgets('shows me versus RepBot, the rules and the setup button', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(GridBackground), findsOneWidget);
    expect(exitButton, findsOneWidget);
    expect(find.text('게임 나가기'), findsOneWidget);
    expect(find.text('MATCH FOUND'), findsOneWidget);
    expect(find.text('푸쉬업 · 30초'), findsOneWidget);
    expect(find.text('나'), findsOneWidget);
    expect(find.text('우현'), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    expect(find.text('상대'), findsOneWidget);
    expect(find.text('RepBot'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    // The W3 characters, idle, each in its team color, with eight white
    // copies: without a choice mine is the default one, against RepBot.
    for (final side in BattleSide.values) {
      expect(
        tester.widget<CharacterFigure>(character(side)).pose,
        BattlePose.idle,
      );
      expect(whiteCopies(side), findsNWidgets(8));
    }
    expect(characterOf(tester, BattleSide.me), CharacterRig.defaultId);
    expect(characterOf(tester, BattleSide.opponent), CharacterRig.botId);
    expect(find.byType(CharacterFigure), findsNWidgets(18));
    expect(find.byType(BattleFighter), findsNothing);
    expect(find.byType(PlayerAvatar), findsNothing);
    expect(find.text('경기 규칙'), findsOneWidget);
    expect(find.text('가슴을 충분히 내렸다가 팔을 끝까지 펴야 1회로 인정돼요.'), findsOneWidget);
    expect(find.text('1회 인정될 때마다 효과음이 울려요.'), findsOneWidget);
    expect(find.text('자세 세팅 시작'), findsOneWidget);
    // No tier, record, or auto-cancel countdown.
    expect(find.textContaining('승률'), findsNothing);
    expect(find.textContaining('15'), findsNothing);
  });

  testWidgets("the user's saved character stands against RepBot; online, the "
      'characters the lobby gives, the opponent\'s as the server sent it; '
      'each is read as a picture with its name', (tester) async {
    final store = MemoryCharacterStore()..values[7] = 'seal';
    final chosen = CharacterViewModel(store: store);
    addTearDown(chosen.dispose);
    await chosen.load(7);
    final handle = tester.ensureSemantics();
    await open(tester, chosen: chosen);
    expect(characterOf(tester, BattleSide.me), 'seal');
    expect(characterOf(tester, BattleSide.opponent), CharacterRig.botId);
    final rig = CharacterRig.standard;
    for (final id in ['seal', CharacterRig.botId]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(rig.art(id).name)),
        matchesSemantics(label: rig.art(id).name, isImage: true),
      );
    }

    // A new screen, from the online lobby.
    await tester.pumpWidget(const SizedBox());
    await open(
      tester,
      chosen: chosen,
      matchup: const Matchup(
        exercise: ExerciseType.squat,
        playerName: '우현',
        opponent: Opponent(name: '상대사용자', isBot: false),
      ),
      characters: const BattleCharacters(me: 'bear', opponent: 'kangaroo'),
    );
    expect(characterOf(tester, BattleSide.me), 'bear');
    expect(characterOf(tester, BattleSide.opponent), 'kangaroo');
    handle.dispose();
  });

  testWidgets('a human opponent without a given character stands as the '
      'default one', (tester) async {
    await open(
      tester,
      matchup: const Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '우현',
        opponent: Opponent(name: '상대사용자', isBot: false),
      ),
    );
    expect(characterOf(tester, BattleSide.opponent), CharacterRig.defaultId);
  });

  testWidgets('게임 나가기 on the left; MATCH FOUND over the exercise, '
      'right aligned', (tester) async {
    await open(tester);
    final exit = tester.getRect(exitButton);
    // "MATCH FOUND" stands on its slanted band, which ends at the padding.
    final found = tester.getRect(
      find
          .ancestor(
            of: find.text('MATCH FOUND'),
            matching: find.byType(Transform),
          )
          .first,
    );
    final exercise = tester.getRect(find.text('푸쉬업 · 30초'));
    expect(exit.left, 20);
    expect(found.left, greaterThan(exit.right));
    // Two lines, both ending at the right padding.
    expect(found.bottom, lessThanOrEqualTo(exercise.top));
    expect(found.right, 412 - 20);
    expect(exercise.right, 412 - 20);
    // Side by side with the button.
    expect(found.top, greaterThanOrEqualTo(exit.top));
    expect(exercise.bottom, lessThanOrEqualTo(exit.bottom));
  });

  testWidgets('MATCH FOUND: ink on a slanted lime band hugging the words '
      '(palette B); the rules\' icons are ink', (tester) async {
    await open(tester);
    final found = tester.widget<Text>(find.text('MATCH FOUND')).style!;
    expect(found.fontFamily, AppFonts.number);
    expect(found.color, AppColors.ink);
    final band = find
        .ancestor(
          of: find.text('MATCH FOUND'),
          matching: find.byType(DecoratedBox),
        )
        .first;
    expect(
      (tester.widget<DecoratedBox>(band).decoration as BoxDecoration).color,
      AppColors.accent,
    );
    // The band leans with the words, as the design draws it.
    expect(
      tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.text('MATCH FOUND'),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform,
      AppHighlight.slant,
    );
    expect(
      tester
          .widget<Padding>(
            find
                .ancestor(
                  of: find.text('MATCH FOUND'),
                  matching: find.byType(Padding),
                )
                .first,
          )
          .padding,
      AppHighlight.tightBandPadding,
    );
    for (final icon in [Icons.check_rounded, Icons.volume_up_outlined]) {
      expect(tester.widget<Icon>(find.byIcon(icon)).color, AppColors.ink);
    }
  });

  testWidgets('the board (W2b 2-A3): a lime cell over a pink one, an ink '
      'line between, a white VS disc over its middle, in one ink-edged box '
      'that takes the height between the header and the rules', (tester) async {
    await open(tester, size: const Size(360, 780), top: 26);
    final box = tester.getRect(board);
    final top = tester.getRect(lime);
    final bottom = tester.getRect(pink);
    final header = tester.getRect(
      find.ancestor(of: exitButton, matching: find.byType(Row)).first,
    );
    final rules = tester.getRect(
      find.ancestor(of: find.text('경기 규칙'), matching: find.byType(Card)),
    );
    expect(box.left, 20);
    expect(box.right, 340);
    expect(box.top, moreOrLessEquals(header.bottom + AppSpacing.s16));
    expect(rules.top, moreOrLessEquals(box.bottom + AppSpacing.s16));
    final edge = tester.widget<DecoratedBox>(board).decoration as BoxDecoration;
    expect(edge.border, Border.all(color: AppColors.ink, width: 2));
    expect(
      edge.borderRadius,
      const BorderRadius.all(Radius.circular(AppRadius.sheet)),
    );
    // The cells fill the box inside its edge, half each around the line.
    expectRect(top, Rect.fromLTRB(22, box.top + 2, 338, top.bottom));
    expectRect(bottom, Rect.fromLTRB(22, top.bottom + 3, 338, box.bottom - 2));
    expect(top.height, moreOrLessEquals(bottom.height));
    expectRect(
      tester.getRect(cell(AppColors.ink)),
      Rect.fromLTRB(22, top.bottom, 338, bottom.top),
    );
    // On a Galaxy S22 the cells are tall enough for full-size characters.
    expect(top.height, greaterThanOrEqualTo(189));

    expectRect(
      tester.getRect(disc),
      Rect.fromCenter(
        center: Offset(180, top.bottom + 1.5),
        width: 80,
        height: 80,
      ),
    );
    final face = tester.widget<DecoratedBox>(disc).decoration as BoxDecoration;
    expect(face.color, AppColors.card);
    expect(face.border, Border.all(color: AppColors.ink, width: 3.6));
    expect(look(tester.widget<Text>(find.text('VS')).style), [
      AppFonts.number,
      34,
      FontWeight.w800,
      1,
      -1,
      AppColors.ink,
    ]);
    // The disc is drawn over both cells and the characters.
    final all = boardWidgets();
    expect(
      all.indexOf(tester.widget(disc)),
      greaterThan(all.lastIndexWhere((w) => w is CharacterFigure)),
    );
    // No tints from before.
    expect(
      tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((box) => box.color),
      isNot(contains(AppColors.accent.withValues(alpha: 0.05))),
    );
  });

  testWidgets("each player stands on a white pedestal in their cell's outer "
      'bottom corner, the feet on its middle; the opponent faces left', (
    tester,
  ) async {
    await open(tester, size: const Size(360, 780), top: 26);
    final top = tester.getRect(lime);
    final bottom = tester.getRect(pink);
    final mine = tester.getRect(pedestals.first);
    final theirs = tester.getRect(pedestals.last);
    expect(pedestals, findsNWidgets(2));
    expectRect(mine, Rect.fromLTWH(top.left + 12, top.bottom - 30, 116, 16));
    expectRect(
      theirs,
      Rect.fromLTWH(bottom.right - 12 - 116, bottom.bottom - 30, 116, 16),
    );
    expect(
      (tester.widget<DecoratedBox>(pedestals.first).decoration
              as ShapeDecoration)
          .color,
      AppColors.card,
    );

    // Full size, facing right, the feet (70, 150 in the box) on the
    // pedestal's top middle.
    final me = character(BattleSide.me);
    expectRect(
      tester.getRect(me),
      Rect.fromLTWH(top.left, top.bottom - 180, 140, 160),
    );
    expect(tester.getTopLeft(me).dx, moreOrLessEquals(top.left));
    expectOffset(
      tester.getRect(me).topLeft + BattleFighter.foot,
      mine.topCenter,
    );
    // The opponent's is mirrored: its left edge is drawn on the right.
    final them = character(BattleSide.opponent);
    expectRect(
      tester.getRect(them),
      Rect.fromLTWH(bottom.right - 140, bottom.bottom - 180, 140, 160),
    );
    expect(tester.getTopLeft(them).dx, moreOrLessEquals(bottom.right));
    expect(
      tester.getBottomRight(them).dx,
      moreOrLessEquals(bottom.right - 140),
    );
    expectOffset(
      Offset(
        tester.getTopLeft(them).dx - BattleFighter.foot.dx,
        tester.getTopLeft(them).dy + BattleFighter.foot.dy,
      ),
      theirs.topCenter,
    );
  });

  testWidgets('a white edge 2.5 wide goes round each character, under it '
      'and over the pedestal; the pedestal has none', (tester) async {
    await open(tester, size: const Size(360, 780), top: 26);
    for (final side in BattleSide.values) {
      final at = tester.getTopLeft(character(side));
      final offsets = {
        for (var i = 0; i < 8; i++)
          _rounded(tester.getTopLeft(whiteCopies(side).at(i)) - at),
      };
      expect(offsets, {
        for (final dx in [-2.5, 0.0, 2.5])
          for (final dy in [-2.5, 0.0, 2.5])
            if (dx != 0 || dy != 0) Offset(dx, dy),
      }, reason: '$side');
    }
    expect(find.byType(ColorFiltered), findsNWidgets(2));
    for (final filter in tester.widgetList<ColorFiltered>(
      find.byType(ColorFiltered),
    )) {
      expect(
        filter.colorFilter,
        const ColorFilter.mode(AppColors.card, BlendMode.srcIn),
      );
    }
    expect(
      find.descendant(of: find.byType(ColorFiltered), matching: pedestals),
      findsNothing,
    );
    // Each pedestal is drawn first, its character's white copies over it,
    // then the character.
    final all = boardWidgets();
    for (final (i, side) in BattleSide.values.indexed) {
      final pedestal = all.indexOf(tester.widget(pedestals.at(i)));
      final copy = all.indexOf(tester.widget(whiteCopies(side).first));
      expect(pedestal, lessThan(copy), reason: '$side');
      expect(
        copy,
        lessThan(all.indexOf(tester.widget(character(side)))),
        reason: '$side',
      );
    }
  });

  testWidgets('beside each character: "나" or "상대" on a white pill over the '
      "name in Do Hyeon 28, and \"AI\" on a pill for a bot; the user's to the "
      "left, the opponent's to the right, in the middle of the cell", (
    tester,
  ) async {
    await open(tester, size: const Size(360, 780), top: 26);
    final text = AppTheme.light.textTheme;
    final top = tester.getRect(lime);
    final bottom = tester.getRect(pink);
    for (final (label, style, inside) in [
      ('나', text.versusSide, AppHighlight.tightBandPadding),
      ('상대', text.versusSide, AppHighlight.tightBandPadding),
      ('AI', text.versusAiTag, AppHighlight.tagPadding),
    ]) {
      expect(
        look(tester.widget<Text>(find.text(label)).style),
        look(style),
        reason: label,
      );
      final edge =
          tester.widget<DecoratedBox>(pill(label)).decoration
              as ShapeDecoration;
      expect(edge.color, AppColors.card, reason: label);
      expect(
        edge.shape,
        const StadiumBorder(side: BorderSide(color: AppColors.ink, width: 1.5)),
        reason: label,
      );
      // The words' 20 line, the room inside, and the 1.5 edge around it.
      final words = tester.getSize(find.text(label));
      expect(words.height, moreOrLessEquals(20, epsilon: 0.01), reason: label);
      final size = tester.getSize(pill(label));
      expect(
        size.width,
        moreOrLessEquals(words.width + inside.horizontal + 2 * 1.5),
        reason: label,
      );
      expect(
        size.height,
        moreOrLessEquals(words.height + inside.vertical + 2 * 1.5),
        reason: label,
      );
    }
    // "나" and "상대" 25 high (1 x 8 inside), "AI" 27 (2 x 12).
    expect(tester.getSize(pill('나')).height, moreOrLessEquals(25));
    expect(tester.getSize(pill('AI')).height, moreOrLessEquals(27));
    for (final name in ['우현', 'RepBot']) {
      expect(
        look(tester.widget<Text>(find.text(name)).style),
        look(text.versusName),
        reason: name,
      );
    }
    // The user's words start 146 from the cell's left; the opponent's end
    // 146 from its right.
    final myPill = tester.getRect(pill('나'));
    final myName = tester.getRect(find.text('우현'));
    expect(myPill.left, moreOrLessEquals(top.left + 146));
    expect(myName.left, moreOrLessEquals(top.left + 146));
    expect(myName.top - myPill.bottom, moreOrLessEquals(AppSpacing.s4));
    expect(
      (myPill.top + myName.bottom) / 2,
      moreOrLessEquals(top.center.dy, epsilon: 0.5),
    );
    final theirPill = tester.getRect(pill('상대'));
    final theirName = tester.getRect(find.text('RepBot'));
    final ai = tester.getRect(pill('AI'));
    for (final rect in [theirPill, theirName, ai]) {
      expect(rect.right, moreOrLessEquals(bottom.right - 146));
    }
    expect(theirName.top - theirPill.bottom, moreOrLessEquals(AppSpacing.s4));
    expect(ai.top - theirName.bottom, moreOrLessEquals(AppSpacing.s4));
    expect(
      (theirPill.top + ai.bottom) / 2,
      moreOrLessEquals(bottom.center.dy, epsilon: 0.5),
    );
    // The words' width on a Galaxy S22, 16 from the far side: 154.
    expect(
      tester
          .getSize(
            find
                .ancestor(of: find.text('우현'), matching: find.byType(SizedBox))
                .first,
          )
          .width,
      moreOrLessEquals(154),
    );
  });

  testWidgets('a human opponent has no AI pill', (tester) async {
    await open(
      tester,
      matchup: const Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '우현',
        opponent: Opponent(name: 'Mina', isBot: false),
      ),
    );
    expect(find.text('Mina'), findsOneWidget);
    expect(find.text('AI'), findsNothing);
    // A person's character stands mirrored on the pink cell too.
    expect(whiteCopies(BattleSide.opponent), findsNWidgets(8));
  });

  testWidgets('a long name is cut with "…" on one line and read whole; a '
      "screen reader reads each cell's words as one and skips the disc", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const long = '가나다라마바사아자차카타';
    await open(
      tester,
      size: const Size(360, 780),
      top: 26,
      matchup: const Matchup(
        exercise: ExerciseType.squat,
        playerName: long,
        opponent: Opponent(name: 'RepBot', isBot: true),
      ),
    );
    final name = tester.widget<Text>(find.text(long));
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
    expect(
      tester.renderObject<RenderParagraph>(find.text(long)).didExceedMaxLines,
      isTrue,
    );
    expect(tester.getSize(find.text(long)).width, lessThanOrEqualTo(154));
    expect(
      tester.getSize(find.text(long)).height,
      moreOrLessEquals(34, epsilon: 0.01),
    );
    expect(find.bySemanticsLabel('나, $long'), findsOneWidget);
    expect(find.bySemanticsLabel('상대, RepBot, AI'), findsOneWidget);
    expect(find.bySemanticsLabel('VS'), findsNothing);
    expect(find.bySemanticsLabel('나'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets("online, the opponent's cell reads \"상대, name\" with no AI", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(
      tester,
      matchup: const Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '우현',
        opponent: Opponent(name: 'Mina', isBot: false),
      ),
    );
    expect(find.bySemanticsLabel('나, 우현'), findsOneWidget);
    expect(find.bySemanticsLabel('상대, Mina'), findsOneWidget);
    semantics.dispose();
  });

  test('characterScale: full size from a 189 cell, then down with the cell '
      'to 0.6', () {
    expect(VersusScreen.characterScale(400), 1);
    expect(VersusScreen.characterScale(189), 1);
    expect(
      VersusScreen.characterScale(174),
      moreOrLessEquals((174 - 38) / 151),
    );
    expect(VersusScreen.characterScale(38 + 151 * 0.6), moreOrLessEquals(0.6));
    expect(VersusScreen.characterScale(100), 0.6);
  });

  for (final (name, size, scale) in [
    ('a small phone', const Size(360, 640), 1.0),
    ('large system text on a Galaxy S22', const Size(360, 780), 1.3),
  ]) {
    testWidgets('$name: in the lower cells the characters and pedestals '
        'shrink around the feet and the words stay clear of them', (
      tester,
    ) async {
      await open(tester, size: size, top: 26, textScale: scale);
      expect(tester.takeException(), isNull);
      final top = tester.getRect(lime);
      final bottom = tester.getRect(pink);
      final s = VersusScreen.characterScale(top.height);
      expect(s, lessThan(1));
      expect(s, greaterThanOrEqualTo(0.6));

      final me = tester.getRect(character(BattleSide.me));
      expect(me.width, moreOrLessEquals(140 * s));
      expect(me.height, moreOrLessEquals(160 * s));
      // The feet stay where they are at full size.
      final feet = Offset(top.left + 70, top.bottom - 30);
      expectOffset(me.topLeft + BattleFighter.foot * s, feet);
      final mine = tester.getRect(pedestals.first);
      expect(mine.width, moreOrLessEquals(116 * s));
      expect(mine.height, moreOrLessEquals(16 * s));
      expectOffset(mine.topCenter, feet);

      final them = tester.getRect(character(BattleSide.opponent));
      expect(them.width, moreOrLessEquals(140 * s));
      expectOffset(
        Offset(them.right - 70 * s, them.top + 150 * s),
        Offset(bottom.right - 70, bottom.bottom - 30),
      );
      expect(tester.getRect(pedestals.last).width, moreOrLessEquals(116 * s));

      // The words begin 70 + 76 x scale from the character's side, past
      // its box (the user's choice of 2026-11-13).
      final myPill = tester.getRect(pill('나'));
      expect(myPill.left, moreOrLessEquals(top.left + 70 + 76 * s));
      expect(myPill.left, greaterThan(me.right));
      expect(tester.getRect(find.text('우현')).left, greaterThan(me.right));
      final theirPill = tester.getRect(pill('상대'));
      expect(theirPill.right, moreOrLessEquals(bottom.right - 70 - 76 * s));
      expect(theirPill.right, lessThan(them.left));
      expect(tester.getRect(find.text('RepBot')).right, lessThan(them.left));
    });
  }

  group("the characters' idle motion", () {
    /// Opens the screen at once on a Galaxy S22, with motion unless
    /// [still], and with no safety warning (seen and off) unless [warning].
    Future<void> openNow(
      WidgetTester tester, {
      bool still = false,
      bool warning = false,
    }) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (still) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      final settings = SettingsViewModel();
      if (!warning) {
        settings
          ..setSafetyNoticeEveryMatch(false)
          ..markSafetyNoticeSeen();
      }
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsViewModel>.value(
          value: settings,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const VersusScreen(matchup: _matchup),
          ),
        ),
      );
      // The clock starts on this frame.
      await tester.pump();
    }

    /// How tall each player's character stands now, as drawn.
    (double, double) heights(WidgetTester tester) => (
      tester.getRect(character(BattleSide.me)).height,
      tester.getRect(character(BattleSide.opponent)).height,
    );

    /// The idle motion on [figure], a character or one of its copies: the
    /// transform right above it, about its feet.
    Transform motionOn(WidgetTester tester, Finder figure) =>
        tester.widget<Transform>(
          find.ancestor(of: figure, matching: find.byType(Transform)).first,
        );

    /// How [idle] moves a character facing right, as the stage does.
    Matrix4 moved(IdleSample idle) => Matrix4.translationValues(0, -idle.up, 0)
        .multiplied(Matrix4.rotationZ(idle.rockDeg * math.pi / 180))
        .multiplied(Matrix4.diagonal3Values(idle.scaleX, idle.scaleY, 1));

    void expectMatrix(Matrix4 actual, Matrix4 expected, String reason) {
      for (var i = 0; i < 16; i++) {
        expect(
          actual.storage[i],
          moreOrLessEquals(expected.storage[i], epsilon: 1e-9),
          reason: '$reason [$i]',
        );
      }
    }

    testWidgets('they move by their own idle motions from the moment the '
        "board shows, the opponent's running 230 ms later, as on the "
        'stage; the pedestals and the words stay', (tester) async {
      await openNow(tester);
      final rig = CharacterRig.standard;
      final mouse = rig.art(CharacterRig.defaultId).idleMotion;
      final bot = rig.art(CharacterRig.botId).idleMotion;
      expect(rig.idleOpponentOffsetMs, 230);
      final mine = tester.getRect(pedestals.first);
      final words = tester.getRect(find.text('우현'));
      var now = 0;
      // At once (the user's clock at 0), then later.
      for (final ms in [0, 500, 700, 1200, 2950]) {
        await tester.pump(Duration(milliseconds: ms - now));
        now = ms;
        final me = motionOn(tester, character(BattleSide.me));
        expect(me.origin, BattleFighter.foot);
        expectMatrix(me.transform, moved(mouse.sampleAt(ms * 1.0)), 'me $ms');
        expectMatrix(
          motionOn(tester, character(BattleSide.opponent)).transform,
          moved(bot.sampleAt(ms + 230.0)),
          'opponent $ms',
        );
        // The white edge moves with the character.
        expectMatrix(
          motionOn(tester, whiteCopies(BattleSide.me).first).transform,
          me.transform,
          'copy $ms',
        );
        expect(tester.getRect(pedestals.first), mine);
        expect(tester.getRect(find.text('우현')), words);
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('they keep moving under the safety warning', (tester) async {
      await openNow(tester, warning: true);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SafeWarningDialog), findsOneWidget);
      final before = [
        for (final side in BattleSide.values)
          motionOn(tester, character(side)).transform.clone(),
      ];
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SafeWarningDialog), findsOneWidget);
      for (final (i, side) in BattleSide.values.indexed) {
        expect(
          motionOn(tester, character(side)).transform,
          isNot(before[i]),
          reason: '$side',
        );
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with reduced motion they stand still in the idle pose and '
        'nothing keeps the screen redrawing', (tester) async {
      await openNow(tester, still: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(heights(tester), (160.0, 160.0));
      await tester.pump(const Duration(milliseconds: 900));
      expect(heights(tester), (160.0, 160.0));
      for (final side in BattleSide.values) {
        expectMatrix(
          motionOn(tester, character(side)).transform,
          Matrix4.identity(),
          '$side',
        );
      }
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(
        tester.widget<CharacterFigure>(character(BattleSide.me)).pose,
        BattlePose.idle,
      );
    });
  });

  final asks = <(String, Future<void> Function(WidgetTester))>[
    ('system back', (tester) => tester.binding.handlePopRoute()),
    ('the 게임 나가기 button', (tester) => tester.tap(exitButton)),
  ];
  for (final (name, ask) in asks) {
    testWidgets('$name keeps the screen and asks; 계속하기 stays', (tester) async {
      await open(tester);
      await ask(tester);
      await tester.pumpAndSettle();
      expect(find.text('게임에서 나갈까요?'), findsOneWidget);
      expect(find.text('MATCH FOUND'), findsOneWidget);

      await tester.tap(find.text('계속하기'));
      await tester.pumpAndSettle();
      expect(find.byType(ExitDialog), findsNothing);
      expect(find.text('MATCH FOUND'), findsOneWidget);
    });

    testWidgets('$name, then 게임 나가기 in the dialog, goes home', (tester) async {
      await open(tester);
      await ask(tester);
      await tester.pumpAndSettle();
      await tester.tap(dialogExit);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(VersusScreen), findsNothing);
    });
  }

  testWidgets('the dialog names the opponent from the matchup', (tester) async {
    await open(
      tester,
      matchup: const Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '우현',
        opponent: Opponent(name: 'IronBot', isBot: true),
      ),
    );
    await tester.tap(exitButton);
    await tester.pumpAndSettle();
    expect(find.text('IronBot 님과의 대결이 취소되고\n홈으로 돌아가요.'), findsOneWidget);
  });

  testWidgets('the setup button replaces this screen with the battle, '
      'which sets up itself', (tester) async {
    await open(tester);
    await tester.tap(find.text('자세 세팅 시작'));
    await tester.pumpAndSettle();
    expect(find.text('battle vs RepBot'), findsOneWidget);
    expect(find.byType(VersusScreen), findsNothing);
    // The bot battle no longer goes through the setup screen.
    expect(pushes.names, isNot(contains(GymRatsApp.matchSetupRoute)));
    expect(battleOpens(), 1);

    // Replaced, not pushed: going back skips the versus screen.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('pressing again while setup opens does nothing', (tester) async {
    await open(tester);
    // Called directly: after a push the navigator already ignores taps for
    // a frame, so a second real tap would not reach the button.
    final press = tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text('자세 세팅 시작'),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed!;
    press();
    press();
    await tester.pumpAndSettle();
    expect(battleOpens(), 1);
  });

  testWidgets('fits a small phone without overflow', (tester) async {
    await open(tester, size: const Size(360, 640), seeWarning: false);
    expect(find.byType(SafeWarningDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(warningButton);
    await tester.pumpAndSettle();

    expect(find.text('자세 세팅 시작'), findsOneWidget);
    expect(find.text('MATCH FOUND'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(exitButton);
    await tester.pumpAndSettle();
    expect(find.byType(ExitDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('safety warning', () {
    /// Calls the setup button directly: the warning's barrier would stop a
    /// real tap.
    void pressSetup(WidgetTester tester) => tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text('자세 세팅 시작'),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed!();

    testWidgets('opens over MATCH FOUND with the picture, the message and '
        '확인', (tester) async {
      await open(tester, seeWarning: false);
      expect(find.byType(SafeWarningDialog), findsOneWidget);
      expect(find.text('무리하지 마세요'), findsOneWidget);
      expect(
        find.text('무리해서 운동하면 몸을 다칠 수 있어요.\n몸 상태를 살피며 플레이해 주세요.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(SafeWarningDialog.pictureLabel),
        findsOneWidget,
      );
      expect(find.text('확인'), findsOneWidget);
      expect(find.text('확인을 누르면 자세 세팅을 시작할 수 있어요'), findsOneWidget);
      // The screen is underneath, not replaced.
      expect(find.text('MATCH FOUND'), findsOneWidget);
    });

    testWidgets('the pose setup starts only after 확인', (tester) async {
      await open(tester, seeWarning: false);
      pressSetup(tester);
      await tester.pumpAndSettle();
      expect(battleOpens(), 0);
      expect(find.byType(SafeWarningDialog), findsOneWidget);

      await tester.tap(warningButton);
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsNothing);
      await tester.tap(find.text('자세 세팅 시작'));
      await tester.pumpAndSettle();
      expect(find.text('battle vs RepBot'), findsOneWidget);
    });

    testWidgets('a tap outside keeps it open', (tester) async {
      await open(tester, seeWarning: false);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsOneWidget);
      expect(find.byType(ExitDialog), findsNothing);
    });

    testWidgets('back on it asks whether to leave; 계속하기 shows it again', (
      tester,
    ) async {
      await open(tester, seeWarning: false);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsNothing);
      expect(find.text('게임에서 나갈까요?'), findsOneWidget);

      await tester.tap(find.text('계속하기'));
      await tester.pumpAndSettle();
      expect(find.byType(ExitDialog), findsNothing);
      expect(find.byType(SafeWarningDialog), findsOneWidget);
      pressSetup(tester);
      await tester.pumpAndSettle();
      expect(battleOpens(), 0);
    });

    testWidgets('back on it, then 게임 나가기, goes home with no warning left', (
      tester,
    ) async {
      await open(tester, seeWarning: false);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(dialogExit);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(VersusScreen), findsNothing);
      expect(find.byType(SafeWarningDialog), findsNothing);
    });

    testWidgets('closed by a logout, which closes every screen, it asks '
        'nothing', (tester) async {
      await open(tester, seeWarning: false);
      // What GymRatsApp does when the login ends.
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(VersusScreen), findsNothing);
      expect(find.byType(SafeWarningDialog), findsNothing);
      expect(find.byType(ExitDialog), findsNothing);
    });

    testWidgets('every match shows it again', (tester) async {
      await open(tester);
      await tester.tap(exitButton);
      await tester.pumpAndSettle();
      await tester.tap(dialogExit);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);

      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsOneWidget);
    });

    testWidgets('online: counts down from 5 on the button and closes by '
        'itself', (tester) async {
      await open(
        tester,
        seeWarning: false,
        warningAutoClose: const Duration(seconds: 5),
      );
      expect(find.text('확인 (5)'), findsOneWidget);
      expect(find.text('5초 뒤 자동으로 닫혀요'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('확인 (4)'), findsOneWidget);
      expect(find.text('4초 뒤 자동으로 닫혀요'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsNothing);
      await tester.tap(find.text('자세 세팅 시작'));
      await tester.pumpAndSettle();
      expect(find.text('battle vs RepBot'), findsOneWidget);
    });

    testWidgets('online: 확인 closes it before the countdown ends', (
      tester,
    ) async {
      await open(
        tester,
        seeWarning: false,
        warningAutoClose: const Duration(seconds: 5),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(warningButton);
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsNothing);

      // The countdown is gone: running out later pops nothing.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('MATCH FOUND'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group("the settings' '매 경기 안전 안내'", () {
    /// Leaves for home through 게임 나가기, then opens the next match.
    Future<void> nextMatch(WidgetTester tester) async {
      await tester.tap(exitButton);
      await tester.pumpAndSettle();
      await tester.tap(dialogExit);
      await tester.pumpAndSettle();
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
    }

    late SettingsViewModel settings;
    setUp(() => settings = SettingsViewModel());
    tearDown(() => settings.dispose());

    testWidgets('on, as designed: every match shows it, seen or not; 확인 '
        'counts as seen', (tester) async {
      await open(tester, settings: settings);
      expect(settings.safetyNotice.seen, isTrue);
      await nextMatch(tester);
      expect(find.byType(SafeWarningDialog), findsOneWidget);
    });

    testWidgets('off: it shows until it is seen once, then a match goes '
        'straight to the setup button', (tester) async {
      settings.setSafetyNoticeEveryMatch(false);
      await open(tester, settings: settings, seeWarning: false);
      expect(find.byType(SafeWarningDialog), findsOneWidget);
      await tester.tap(warningButton);
      await tester.pumpAndSettle();
      expect(settings.safetyNotice.seen, isTrue);

      await nextMatch(tester);
      expect(find.byType(SafeWarningDialog), findsNothing);
      expect(find.text('MATCH FOUND'), findsOneWidget);
      await tester.tap(find.text('자세 세팅 시작'));
      await tester.pumpAndSettle();
      expect(find.text('battle vs RepBot'), findsOneWidget);
    });

    testWidgets('off and seen in an earlier run: no warning, the setup at '
        'once', (tester) async {
      final store = MemorySettingsStore()
        ..safetyNoticeEveryMatch = false
        ..safetyNoticeSeen = true;
      final loaded = SettingsViewModel(store: store);
      addTearDown(loaded.dispose);
      await tester.runAsync(loaded.load);
      await open(tester, settings: loaded, seeWarning: false);
      expect(find.byType(SafeWarningDialog), findsNothing);
      await tester.tap(find.text('자세 세팅 시작'));
      await tester.pumpAndSettle();
      expect(battleOpens(), 1);
    });

    testWidgets('leaving from the warning is not seeing it: off, the next '
        'match shows it again', (tester) async {
      settings.setSafetyNoticeEveryMatch(false);
      await open(tester, settings: settings, seeWarning: false);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(dialogExit);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(settings.safetyNotice.seen, isFalse);

      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsOneWidget);
    });

    testWidgets('online, closing by itself counts as seen', (tester) async {
      settings.setSafetyNoticeEveryMatch(false);
      await open(
        tester,
        settings: settings,
        seeWarning: false,
        warningAutoClose: const Duration(seconds: 5),
      );
      expect(settings.safetyNotice.seen, isFalse);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsNothing);
      expect(settings.safetyNotice.seen, isTrue);
    });

    testWidgets('turned off while the warning is up, it still waits for '
        '확인', (tester) async {
      await open(tester, settings: settings, seeWarning: false);
      settings.setSafetyNoticeEveryMatch(false);
      await tester.pumpAndSettle();
      expect(find.byType(SafeWarningDialog), findsOneWidget);
      await tester.tap(warningButton);
      await tester.pumpAndSettle();
      await nextMatch(tester);
      expect(find.byType(SafeWarningDialog), findsNothing);
    });
  });
}

/// [offset] to a tenth of a point.
Offset _rounded(Offset offset) =>
    Offset((offset.dx * 10).round() / 10, (offset.dy * 10).round() / 10);
