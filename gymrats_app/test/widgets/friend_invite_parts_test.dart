import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/services/friends/friend_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';
import 'package:gymrats_app/widgets/character_figure.dart';
import 'package:gymrats_app/widgets/friend_invite_parts.dart';

BattleInvite _invite({String character = '', String nickname = '헬창'}) =>
    BattleInvite(
      id: 7,
      from: FriendPerson(id: 2, nickname: nickname, code: '$nickname#0002'),
      to: const FriendPerson(id: 1, nickname: '쥐돌이', code: '쥐돌이#0001'),
      exercise: ExerciseType.squat,
      status: InviteStatus.pending,
      expiresAt: DateTime(2026, 11, 27, 12, 1),
      character: character,
    );

Future<void> _show(WidgetTester tester, Widget child, {double width = 320}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    );

void main() {
  test('friendClock writes m:ss', () {
    expect(friendClock(60), '1:00');
    expect(friendClock(48), '0:48');
    expect(friendClock(5), '0:05');
    expect(friendClock(0), '0:00');
    expect(friendClock(-3), '0:00');
  });

  test('the character drawn: the one sent, or GYM마우스 (A11 spec 7)', () {
    expect(friendInviteCharacter(_invite(character: 'bear')), 'bear');
    expect(friendInviteCharacter(_invite()), 'mouse');
    expect(friendInviteCharacter(_invite(character: 'dragon')), 'mouse');
  });

  test('the invite alert\'s sentence', () {
    expect(FriendInviteAlertCard.lineOf(_invite()), '헬창님이 스쿼트 대결을 신청했어요');
  });

  testWidgets('the time bar fills its share of the minute in pink', (
    tester,
  ) async {
    for (final (seconds, share) in [
      (60, 1.0),
      (30, 0.5),
      (0, 0.0),
      (75, 1.0),
    ]) {
      await _show(tester, FriendTimeBar(seconds: seconds, height: 6));
      final bar = tester.widget<FriendTimeBar>(find.byType(FriendTimeBar));
      expect(bar.fraction, share, reason: '$seconds s');
      final fill = tester.getSize(
        find.descendant(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(fill.width, closeTo(320 * share, 1e-9));
      expect(tester.getSize(find.byType(FriendTimeBar)).height, 6);
    }
    final fill = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(FractionallySizedBox),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((fill.decoration as BoxDecoration).color, AppColors.opponent);
  });

  testWidgets('거절 and 수락: 1 to 1.6, white and lime, both off while busy', (
    tester,
  ) async {
    final taps = <String>[];
    Future<void> buttons({required bool busy}) => _show(
      tester,
      FriendAnswerButtons(
        busy: busy,
        onDecline: () => taps.add('decline'),
        onAccept: () => taps.add('accept'),
      ),
    );
    await buttons(busy: false);
    final decline = tester.getSize(find.text('거절').hitTestable());
    expect(decline, isNotNull);
    final declineBox = tester.getSize(
      find.ancestor(of: find.text('거절'), matching: find.byType(OutlinedButton)),
    );
    final acceptBox = tester.getSize(
      find.ancestor(of: find.text('수락'), matching: find.byType(OutlinedButton)),
    );
    expect(acceptBox.width / declineBox.width, closeTo(1.6, 0.01));
    expect(acceptBox.height, greaterThanOrEqualTo(40));
    OutlinedButton button(String word) => tester.widget<OutlinedButton>(
      find.ancestor(of: find.text(word), matching: find.byType(OutlinedButton)),
    );
    expect(button('거절').style!.backgroundColor!.resolve({}), AppColors.card);
    expect(button('수락').style!.backgroundColor!.resolve({}), AppColors.accent);
    await tester.tap(find.text('거절'));
    await tester.tap(find.text('수락'));
    expect(taps, ['decline', 'accept']);
    await buttons(busy: true);
    expect(button('거절').onPressed, isNull);
    expect(button('수락').onPressed, isNull);
  });

  testWidgets('the panel stands the figure on its disc at the given feet', (
    tester,
  ) async {
    await _show(
      tester,
      const SizedBox(
        height: 146,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 96,
              child: FriendInvitePanel(
                characterId: 'seal',
                feet: Offset(48, 122),
                scale: 0.55,
                discWidth: 62,
              ),
            ),
          ],
        ),
      ),
    );
    final panel = tester.getRect(find.byType(FriendInvitePanel));
    final disc = tester.getRect(
      find
          .descendant(
            of: find.byType(FriendInvitePanel),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(disc.size, const Size(62, 14));
    expect(disc.center - panel.topLeft, const Offset(48, 122));
    final figure = tester.widget<CharacterIdleFigure>(
      find.byType(CharacterIdleFigure).first,
    );
    expect((figure.characterId, figure.side), ('seal', BattleSide.opponent));
  });

  testWidgets('a long nickname is cut short, the time left stays whole', (
    tester,
  ) async {
    await _show(
      tester,
      FriendInviteCard(
        invite: _invite(nickname: '가나다라마바사아자차카타'),
        secondsLeft: 42,
        busy: false,
        onDecline: () {},
        onAccept: () {},
      ),
      width: 280,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('0:42'), findsOneWidget);
    final name = tester.widget<Text>(find.text('가나다라마바사아자차카타'));
    expect(name.overflow, TextOverflow.ellipsis);
    expect(name.maxLines, 1);
  });

  testWidgets('the alert\'s error card: its words in the alert\'s frame', (
    tester,
  ) async {
    await _show(tester, const FriendAlertErrorCard(line: '이미 끝난 대결 신청이에요.'));
    expect(find.text('이미 끝난 대결 신청이에요.'), findsOneWidget);
    final frame =
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byType(FriendAlertErrorCard),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(frame, friendAlertFrame());
  });
}
