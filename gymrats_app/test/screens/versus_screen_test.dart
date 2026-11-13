import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/main.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/matchup.dart';
import 'package:gymrats_app/screens/versus_screen.dart';
import 'package:gymrats_app/services/user/settings_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/settings_viewmodel.dart';
import 'package:gymrats_app/widgets/exit_dialog.dart';
import 'package:gymrats_app/widgets/exit_game_button.dart';
import 'package:gymrats_app/widgets/grid_background.dart';
import 'package:gymrats_app/widgets/safe_warning_dialog.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

const _matchup = Matchup(
  exercise: ExerciseType.pushUp,
  playerName: '우현',
  opponent: Opponent(name: 'RepBot', isBot: true),
);

void main() {
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
  Future<void> open(
    WidgetTester tester, {
    Matchup matchup = _matchup,
    Size size = const Size(412, 915),
    bool seeWarning = true,
    Duration? warningAutoClose,
    SettingsViewModel? settings,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    pushes = PushLog();
    Widget app(Widget child) => settings == null
        ? child
        : ChangeNotifierProvider<SettingsViewModel>.value(
            value: settings,
            child: child,
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
    expect(find.text('우'), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    expect(find.text('상대'), findsOneWidget);
    expect(find.text('RepBot'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
    expect(find.text('경기 규칙'), findsOneWidget);
    expect(find.text('가슴을 충분히 내렸다가 팔을 끝까지 펴야 1회로 인정돼요.'), findsOneWidget);
    expect(find.text('1회 인정될 때마다 효과음이 울려요.'), findsOneWidget);
    expect(find.text('자세 세팅 시작'), findsOneWidget);
    // No tier, record, or auto-cancel countdown.
    expect(find.textContaining('승률'), findsNothing);
    expect(find.textContaining('15'), findsNothing);
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

  testWidgets('fonts and colors: ink words; lime marks me, pink the '
      'opponent (palette B)', (tester) async {
    await open(tester);
    final found = tester.widget<Text>(find.text('MATCH FOUND')).style!;
    expect(found.fontFamily, AppFonts.number);
    expect(found.color, AppColors.ink);
    BoxDecoration behind(String text) =>
        tester
                .widget<DecoratedBox>(
                  find
                      .ancestor(
                        of: find.text(text),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(behind('MATCH FOUND').color, AppColors.accent);
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
    // A swatch of each player's color beside "나" and "상대".
    final swatches = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.border != null && d.borderRadius != null)
        .map((d) => d.color)
        .toList();
    expect(swatches, containsAll([AppColors.accent, AppColors.opponent]));
    final aiPill =
        tester
                .widget<DecoratedBox>(
                  find
                      .ancestor(
                        of: find.text('AI'),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as ShapeDecoration;
    expect(aiPill.color, AppColors.opponent.withValues(alpha: 0.3));
    for (final icon in [Icons.check_rounded, Icons.volume_up_outlined]) {
      expect(tester.widget<Icon>(find.byIcon(icon)).color, AppColors.ink);
    }
    expect(
      tester.widget<Text>(find.text('우현')).style!.fontFamily,
      AppFonts.headline,
    );
    expect(
      tester.widget<Text>(find.text('RepBot')).style!.fontFamily,
      AppFonts.number,
    );
    for (final words in ['나', '상대', 'AI']) {
      expect(
        tester.widget<Text>(find.text(words)).style!.color,
        AppColors.ink,
        reason: words,
      );
    }
    // Me above the VS, the opponent below it.
    final vs = tester.getRect(find.text('VS'));
    expect(tester.getRect(find.text('우현')).bottom, lessThan(vs.top));
    expect(tester.getRect(find.text('RepBot')).top, greaterThan(vs.bottom));
  });

  testWidgets('the swatch stands before 나 and after 상대, a swatch gap away; '
      'MATCH FOUND hugs its band; the halves are tinted', (tester) async {
    await open(tester);
    Rect swatch(Color color) => tester.getRect(
      find.byWidgetPredicate(
        (w) => w is DecoratedBox && w.decoration == AppHighlight.swatch(color),
      ),
    );
    final mine = swatch(AppColors.accent);
    final theirs = swatch(AppColors.opponent);
    expect(mine.size, const Size.square(AppHighlight.swatchSize));
    expect(
      tester.getRect(find.text('나')).left - mine.right,
      AppHighlight.swatchGap,
    );
    expect(
      theirs.left - tester.getRect(find.text('상대')).right,
      AppHighlight.swatchGap,
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
    final tints = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .map((box) => box.color)
        .toSet();
    expect(
      tints,
      containsAll([
        AppColors.accent.withValues(alpha: 0.05),
        AppColors.opponent.withValues(alpha: 0.05),
      ]),
    );
  });

  testWidgets('a human opponent gets an initial and no AI tag', (tester) async {
    await open(
      tester,
      matchup: const Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '우현',
        opponent: Opponent(name: 'Mina', isBot: false),
      ),
    );
    expect(find.text('Mina'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('AI'), findsNothing);
    expect(find.byIcon(Icons.smart_toy_rounded), findsNothing);
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
