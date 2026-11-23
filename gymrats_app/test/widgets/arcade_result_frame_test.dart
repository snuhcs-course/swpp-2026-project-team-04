import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/user/character_store.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/character_viewmodel.dart';
import 'package:gymrats_app/widgets/arcade_parts.dart';
import 'package:gymrats_app/widgets/arcade_result_frame.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:provider/provider.dart';

void main() {
  late List<String> taps;

  Future<void> show(
    WidgetTester tester, {
    Size size = const Size(360, 780),
    Widget? figures,
    String? link,
  }) async {
    taps = [];
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final characters = CharacterViewModel(store: MemoryCharacterStore());
    addTearDown(characters.dispose);
    await characters.choose('kangaroo');
    await tester.pumpWidget(
      ChangeNotifierProvider<CharacterViewModel>.value(
        value: characters,
        child: MaterialApp(
          theme: AppTheme.light,
          home: ArcadeBattleResultFrame(
            tag: 'STAGE 8 · 2F',
            title: '실패',
            titleColor: AppColors.facetDark,
            titleStyle: const TextStyle(),
            score: const ArcadeScoreLine(
              me: 98,
              opponent: 140,
              meLarger: false,
            ),
            stars: const ArcadeResultStars(
              labels: ['승리', '콤보 5 이상', 'KO 승리'],
              lit: [false, false, false],
            ),
            figures:
                figures ?? const ArcadeBattleFigures.lost(opponent: 'seal'),
            buttons: ArcadeBattleButtons(
              first: '리포트 보기',
              onFirst: () => taps.add('first'),
              second: '다시 도전',
              onSecond: () => taps.add('second'),
              link: link,
              onLink: () => taps.add('link'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the fail (ArcResult fail): tag, title, score, stars, the '
      'stand, the buttons and the link', (tester) async {
    await show(tester, link: '아케이드로');
    expect(find.text('STAGE 8 · 2F'), findsOneWidget);
    expect(find.text('실패'), findsOneWidget);
    expect(find.text('98'), findsOneWidget);
    expect(find.text('140'), findsOneWidget);
    for (final label in ['리포트 보기', '다시 도전', '아케이드로']) {
      await tester.tap(find.text(label));
    }
    expect(taps, ['first', 'second', 'link']);
  });

  testWidgets('a lost stand: the user knocked out, the opponent cheering', (
    tester,
  ) async {
    await show(tester);
    final figures = {
      for (final figure in tester.widgetList<CharacterFigure>(
        find.byType(CharacterFigure),
      ))
        (figure.characterId, figure.pose, figure.side),
    };
    expect(figures, {
      ('kangaroo', BattlePose.knockedOut, BattleSide.me),
      ('seal', BattlePose.win, BattleSide.opponent),
    });
    expect(find.byType(ArcadePedestal), findsOneWidget);
  });

  testWidgets('a stand of its own: where each stands and how', (tester) async {
    await show(
      tester,
      figures: const ArcadeBattleFigures(
        pedestalLeft: 70,
        height: 200,
        stands: [
          ArcadeBattleStand.me(left: 56, bottom: 12, scale: 1.05),
          ArcadeBattleStand.opponent(
            id: 'bear',
            pose: BattlePose.knockedOut,
            right: 4,
            bottom: 0,
            scale: 0.62,
            outline: false,
            opacity: 0.9,
          ),
        ],
      ),
    );
    expect(
      tester.getSize(find.byType(ArcadeBattleFigures)),
      const Size(320, 200),
    );
    expect(tester.widget<Opacity>(find.byType(Opacity).last).opacity, 0.9);
    expect(find.byType(ArcadeWhiteOutline), findsOneWidget);
  });

  testWidgets('a short screen scrolls rather than overflows', (tester) async {
    await show(tester, size: const Size(320, 480), link: '아케이드로');
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('아케이드로'));
    await tester.pumpAndSettle();
    expect(find.text('아케이드로').hitTestable(), findsOneWidget);
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
  });
}
