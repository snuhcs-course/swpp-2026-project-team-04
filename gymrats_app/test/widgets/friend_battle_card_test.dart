import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/arcade_parts.dart';
import 'package:gymrats_app/widgets/arcade_play_card.dart';
import 'package:gymrats_app/widgets/exercise_sheet.dart';
import 'package:gymrats_app/widgets/friend_battle_card.dart';

void main() {
  Future<List<String>> show(
    WidgetTester tester, {
    bool waiting = false,
    Size size = const Size(320, 154),
    bool still = false,
  }) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: size,
                child: FriendBattleCard(
                  waiting: waiting,
                  onTap: () => taps.add('friends'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return taps;
  }

  group('pictureScale (user, 2026-11-27)', () {
    test('min(height / 152, (width − 128) / 190, 1.3)', () {
      // 360 x 780: the card's inside is 318 x 152, exactly as designed.
      expect(FriendBattleCard.pictureScale(const Size(318, 152)), 1);
      // Narrow: the width decides, so the name keeps its 128.
      expect(
        FriendBattleCard.pictureScale(const Size(278, 180)),
        closeTo(150 / 190, 1e-12),
      );
      // Short: the height decides.
      expect(
        FriendBattleCard.pictureScale(const Size(400, 130)),
        closeTo(130 / 152, 1e-12),
      );
      // Large: never past 1.3.
      expect(FriendBattleCard.pictureScale(const Size(600, 400)), 1.3);
      // Never below 0.
      expect(FriendBattleCard.pictureScale(const Size(100, 100)), 0);
    });
  });

  testWidgets('measured it asks for its least height; laid out it takes '
      'what it is given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 320,
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Expanded(
                      child: FriendBattleCard(waiting: false, onTap: () {}),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(FriendBattleCard)).height,
      FriendBattleCard.minHeight,
    );
    await show(tester, size: const Size(320, 200));
    expect(tester.getSize(find.byType(FriendBattleCard)), const Size(320, 200));
  });

  for (final (size, panel) in const [
    (Size(320, 154), 190.0),
    (Size(280, 154), 150.0),
    (Size(372, 400), 242.0),
    (Size(600, 400), 247.0),
  ]) {
    testWidgets('a ${size.width.toInt()} x ${size.height.toInt()} card: the '
        'panel is $panel wide, the picture at its bottom center', (
      tester,
    ) async {
      await show(tester, size: size);
      final inside = Size(size.width - 2, size.height - 2);
      final scale = FriendBattleCard.pictureScale(inside);
      final panelRect = tester.getRect(find.byType(ArcadeFriendPanel));
      expect(panelRect.width, closeTo(panel, 1e-9));
      expect(panelRect.height, inside.height);
      final card = tester.getRect(find.byType(FriendBattleCard));
      expect(panelRect.topLeft, card.topLeft + const Offset(1, 1));
      // The drawing: 190 x 152 times the scale, on the panel's bottom.
      final drawing = tester.getRect(
        find
            .descendant(
              of: find.byType(ArcadeFriendPanel),
              matching: find.byType(FittedBox),
            )
            .first,
      );
      expect(drawing.width, closeTo(190 * scale, 1e-9));
      expect(drawing.height, closeTo(152 * scale, 1e-9));
      expect(drawing.bottom, closeTo(panelRect.bottom, 1e-9));
      expect(drawing.center.dx, closeTo(panelRect.center.dx, 1e-9));
      expect(
        inside.width - panelRect.width,
        greaterThanOrEqualTo(FriendBattleCard.nameMinWidth - 1e-9),
      );
    });
  }

  testWidgets('the name sits in the middle of the white part; the arrow chip '
      '10 in from the bottom right', (tester) async {
    await show(tester);
    final card = tester.getRect(find.byType(FriendBattleCard));
    final panel = tester.getRect(find.byType(ArcadeFriendPanel));
    final name = tester.getCenter(find.text('친구와의\n대전'));
    expect(name.dx, closeTo((panel.right + card.right - 1) / 2, 0.5));
    expect(name.dy, closeTo(card.center.dy, 0.5));
    final chip = tester.getRect(
      find
          .ancestor(
            of: find.byType(ArcadeGlyphIcon),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(chip.size, const Size(34, 34));
    expect(chip.right, card.right - 1 - 10);
    expect(chip.bottom, card.bottom - 1 - 10);
  });

  testWidgets('one button: a tap anywhere opens, the sticker too', (
    tester,
  ) async {
    final taps = await show(tester, waiting: true, still: true);
    await tester.tap(find.text('친구와의\n대전'));
    await tester.tap(find.byType(ArcadeFriendPanel));
    // Where the sticker hangs over the card's corner.
    final card = tester.getRect(find.byType(FriendBattleCard));
    await tester.tapAt(card.topRight + const Offset(-20, 8));
    expect(taps, ['friends', 'friends', 'friends']);
  });

  testWidgets('the sticker only while something waits, over the top right '
      'corner', (tester) async {
    await show(tester, still: true);
    expect(find.byType(FriendWaitSticker), findsNothing);
    await show(tester, waiting: true, still: true);
    expect(find.text('수락 대기!'), findsOneWidget);
    final card = tester.getRect(find.byType(FriendBattleCard));
    final sticker = tester.getRect(find.byType(FriendWaitSticker));
    // 6 past the right and 16 above the top of the inside, before its turn.
    expect(sticker.right, card.right - 1 + 6);
    expect(sticker.top, card.top + 1 - 16);
    expect(sticker.height, 32);
  });

  testWidgets('the sticker is the design\'s: amber, ink edge and shadow, '
      'Do Hyeon 19 at any text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await show(tester, waiting: true, still: true);
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(FriendWaitSticker),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.warning);
    expect(decoration.border, Border.all(color: AppColors.ink, width: 2));
    expect(decoration.boxShadow!.single.offset, const Offset(2, 3));
    expect(decoration.boxShadow!.single.blurRadius, 0);
    final words = tester.widget<Text>(find.text('수락 대기!'));
    expect(words.textScaler, TextScaler.noScaling);
    expect(words.style!.fontSize, 19);
    expect(words.style!.fontFamily, AppFonts.display);
    expect(tester.getSize(find.byType(FriendWaitSticker)).height, 32);
  });

  Matrix4 stickerTurn(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(FriendWaitSticker),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform;

  Matrix4 poseMatrix(double t) {
    final pose = GoalSticker.poseAt(t);
    return Matrix4.rotationZ(pose.degrees * math.pi / 180)
      ..scaleByDouble(pose.scale, pose.scale, 1, 1);
  }

  /// [actual] is [GoalSticker.poseAt]'s turn and size at [t] (a pump's
  /// time is whole microseconds, so not to the last digit).
  void expectPose(Matrix4 actual, double t) {
    final expected = poseMatrix(t).storage;
    for (var i = 0; i < 16; i++) {
      expect(actual.storage[i], closeTo(expected[i], 1e-6), reason: '[$i]');
    }
  }

  testWidgets('the sticker shakes as the 미션 sticker does, every 2.5 s', (
    tester,
  ) async {
    await show(tester, waiting: true);
    expectPose(stickerTurn(tester), 0);
    await tester.pump(GoalSticker.period * 0.8);
    expectPose(stickerTurn(tester), 0.8);
    expect(GoalSticker.poseAt(0.8).degrees, -6);
    await tester.pump(GoalSticker.period * 0.04);
    expectPose(stickerTurn(tester), 0.84);
    expect(GoalSticker.poseAt(0.84).degrees, 12);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('it holds still with reduced motion, at its 6° rest', (
    tester,
  ) async {
    await show(tester, waiting: true, still: true);
    final rest = stickerTurn(tester);
    expect(rest, poseMatrix(0));
    expect(GoalSticker.poseAt(0).degrees, 6);
    await tester.pump(GoalSticker.period * 0.8);
    expect(stickerTurn(tester), rest);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a screen reader hears one button: the name, and the waiting '
      'request', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester, still: true);
    expect(
      tester.getSemantics(find.bySemanticsLabel('친구와의 대전')),
      matchesSemantics(label: '친구와의 대전', isButton: true, hasTapAction: true),
    );
    await show(tester, waiting: true, still: true);
    expect(find.bySemanticsLabel('친구와의 대전, 수락을 기다리는 신청이 있어요'), findsOneWidget);
    // The picture and the sticker are not read.
    expect(find.bySemanticsLabel('VS'), findsNothing);
    expect(find.bySemanticsLabel('수락 대기!'), findsNothing);
    semantics.dispose();
  });
}
