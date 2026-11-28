import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/screens/matching_screen.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/arcade_parts.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/friend_wait_view.dart';
import 'package:gymrats_app/widgets/lobby_parts.dart';

void main() {
  late List<String> taps;

  setUp(() => taps = []);

  Future<void> show(
    WidgetTester tester,
    FriendWaitState state, {
    int secondsLeft = 42,
    bool retry = true,
    ExerciseType exercise = ExerciseType.squat,
    String? friendCharacter,
    bool still = true,
    Size size = const Size(360, 752),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: still),
          child: Scaffold(
            body: FriendWaitView(
              state: state,
              friendName: 'deadlift',
              myName: 'hellohello',
              myCharacter: 'mouse',
              friendCharacter: friendCharacter,
              exercise: exercise,
              duration: const Duration(seconds: 30),
              secondsLeft: secondsLeft,
              closedTitle: 'deadlift님이 대결을 취소했어요.',
              onBack: () => taps.add('back'),
              onToList: () => taps.add('list'),
              onRetry: retry ? () => taps.add('retry') : null,
            ),
          ),
        ),
      ),
    );
  }

  Color bandColor(WidgetTester tester) {
    final band = find.ancestor(
      of: find.byType(DecoratedBox),
      matching: find.byType(LobbySkew),
    );
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(of: band.first, matching: find.byType(DecoratedBox))
          .first,
    );
    return (box.decoration as BoxDecoration).color!;
  }

  test('each state\'s band and title, as FrWait has them', () {
    expect(
      {for (final s in FriendWaitState.values) s: FriendWaitView.tagOf(s)},
      {
        FriendWaitState.waiting: 'CHALLENGE',
        FriendWaitState.joining: 'MATCHING',
        FriendWaitState.declined: 'DECLINED',
        FriendWaitState.expired: 'TIME OUT',
        FriendWaitState.closed: 'CLOSED',
      },
    );
    expect(
      FriendWaitView.titleOf(FriendWaitState.waiting, 'deadlift', null),
      'deadlift님의\n수락을 기다리는 중',
    );
    expect(
      FriendWaitView.titleOf(FriendWaitState.joining, 'deadlift', null),
      'deadlift님을\n기다리는 중',
    );
    expect(
      FriendWaitView.titleOf(FriendWaitState.declined, 'deadlift', null),
      'deadlift님이\n대결 신청을 거절했어요',
    );
    expect(
      FriendWaitView.titleOf(FriendWaitState.expired, 'deadlift', null),
      'deadlift님이\n1분 안에 수락하지 않았어요',
    );
    expect(
      FriendWaitView.titleOf(FriendWaitState.closed, 'deadlift', 'x.'),
      'x.',
    );
    expect(
      [for (final s in FriendWaitState.values) s.ended],
      [false, false, true, true, true],
    );
  });

  testWidgets('the setup words are the matching screen\'s, word for word', (
    tester,
  ) async {
    for (final exercise in ExerciseType.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BattleSearchView(
              exercise: exercise,
              title: '',
              searchArea: const SizedBox(),
              onCancel: () {},
            ),
          ),
        ),
      );
      expect(find.text(FriendWaitView.prepTitle), findsOneWidget);
      expect(find.text(FriendWaitView.tipOf(exercise)), findsOneWidget);
    }
  });

  testWidgets('waiting: 신청 취소 with ✕, a lime band, the ring and the '
      'seconds, "?" below, and the setup card', (tester) async {
    await show(tester, FriendWaitState.waiting);
    expect(find.text('신청 취소'), findsOneWidget);
    expect(
      tester
          .widgetList<ArcadeGlyphIcon>(find.byType(ArcadeGlyphIcon))
          .map((g) => g.glyph),
      [ArcadeGlyph.cross],
    );
    expect(bandColor(tester), AppColors.accent);
    expect(find.text('42'), findsOneWidget);
    expect(
      tester.widget<FriendWaitRing>(find.byType(FriendWaitRing)).sweep,
      closeTo(0.7, 1e-12),
    );
    expect(find.text('?'), findsNWidgets(2));
    expect(find.text(FriendWaitView.prepTitle), findsOneWidget);
    expect(find.text('친구 목록으로'), findsNothing);
    await tester.tap(find.text('신청 취소'));
    expect(taps, ['back']);
  });

  testWidgets('the "?" is white with a 7 ink edge, Oxanium 800 150', (
    tester,
  ) async {
    await show(tester, FriendWaitState.waiting);
    final marks = tester.widgetList<Text>(find.text('?')).toList();
    final edge = marks.first.style!.foreground!;
    expect(edge.style, PaintingStyle.stroke);
    expect(edge.strokeWidth, 7);
    expect(edge.color.toARGB32(), AppColors.ink.toARGB32());
    expect(marks.last.style!.color, AppColors.card);
    expect(marks.last.style!.fontSize, 150);
    expect(marks.last.style!.fontFamily, AppFonts.number);
    expect(marks.last.style!.fontWeight, FontWeight.w800);
  });

  testWidgets('the circle: 92 across with a 3.6 ink edge, in the board\'s '
      'middle', (tester) async {
    await show(tester, FriendWaitState.waiting);
    final circle = find.ancestor(
      of: find.byType(FriendWaitRing),
      matching: find.byType(Container),
    );
    final box = tester.widget<Container>(circle.first);
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.border, Border.all(color: AppColors.ink, width: 3.6));
    expect(tester.getSize(circle.first), const Size(92, 92));
    final board = tester.getRect(
      find.ancestor(of: circle.first, matching: find.byType(Stack)).first,
    );
    expect(tester.getCenter(circle.first), board.center);
  });

  testWidgets('joining: 나가기 with ‹, MATCHING on lime, VS, and the inviter '
      'mirrored in place of "?"', (tester) async {
    await show(tester, FriendWaitState.joining, friendCharacter: 'bear');
    expect(find.text('나가기'), findsOneWidget);
    expect(bandColor(tester), AppColors.accent);
    expect(find.text('VS'), findsOneWidget);
    expect(find.byType(FriendWaitRing), findsNothing);
    expect(find.text('?'), findsNothing);
    final bear = find.byWidgetPredicate(
      (w) => w is CharacterIdleFigure && w.characterId == 'bear',
    );
    expect(
      tester.widget<CharacterIdleFigure>(bear.first).side,
      BattleSide.opponent,
    );
    expect(
      find.ancestor(of: bear.first, matching: find.byType(Transform)),
      findsWidgets,
    );
  });

  testWidgets('declined: a gray band, ✕ in the circle, the gray cell with "?" '
      'at 45%, 다시 신청 and 친구 목록으로', (tester) async {
    await show(tester, FriendWaitState.declined);
    expect(find.text('나가기'), findsOneWidget);
    expect(bandColor(tester), FriendColors.quiet);
    expect(find.byType(FriendWaitRing), findsNothing);
    expect(
      tester
          .widgetList<ArcadeGlyphIcon>(find.byType(ArcadeGlyphIcon))
          .where((g) => g.glyph == ArcadeGlyph.cross)
          .map((g) => g.size),
      [40],
    );
    final fade = tester.widget<Opacity>(
      find
          .ancestor(of: find.text('?').first, matching: find.byType(Opacity))
          .first,
    );
    expect(fade.opacity, 0.45);
    expect(
      tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((b) => b.color),
      contains(FriendColors.quiet),
    );
    expect(find.text(FriendWaitView.prepTitle), findsNothing);
    await tester.tap(find.text('deadlift님에게 다시 신청'));
    await tester.tap(find.text('친구 목록으로'));
    await tester.tap(find.text('나가기'));
    expect(taps, ['retry', 'list', 'back']);
  });

  testWidgets('expired: 0 and an empty ring, whatever is left', (tester) async {
    await show(tester, FriendWaitState.expired, secondsLeft: 12);
    expect(find.text('TIME OUT'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(tester.widget<FriendWaitRing>(find.byType(FriendWaitRing)).sweep, 0);
  });

  testWidgets('closed with no retry (invited): the end\'s words, 친구 목록으로 '
      'only', (tester) async {
    await show(tester, FriendWaitState.closed, retry: false);
    expect(find.text('CLOSED'), findsOneWidget);
    expect(find.text('deadlift님이 대결을 취소했어요.'), findsOneWidget);
    expect(find.text('deadlift님에게 다시 신청'), findsNothing);
    expect(find.text('친구 목록으로'), findsOneWidget);
  });

  testWidgets('the seconds stay in 0..60', (tester) async {
    await show(tester, FriendWaitState.waiting, secondsLeft: 75);
    expect(find.text('60'), findsOneWidget);
    expect(tester.widget<FriendWaitRing>(find.byType(FriendWaitRing)).sweep, 1);
  });

  testWidgets('the characters idle; with reduced motion they stand still', (
    tester,
  ) async {
    await show(tester, FriendWaitState.joining, friendCharacter: 'seal');
    expect(tester.hasRunningAnimations, isFalse);
    await show(
      tester,
      FriendWaitState.joining,
      friendCharacter: 'seal',
      still: false,
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (size, scale) in const [
    (Size(360, 752), 1.3),
    (Size(320, 616), 1.0),
    (Size(320, 616), 1.3),
  ]) {
    testWidgets('no overflow at ${size.width.toInt()} x ${size.height.toInt()} '
        'with $scale times the text, in every state', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final state in FriendWaitState.values) {
        await show(tester, state, size: size, friendCharacter: 'bear');
        expect(tester.takeException(), isNull, reason: '$state');
      }
    });
  }
}
