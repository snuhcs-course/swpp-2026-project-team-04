// The ladder's picks are the design's: the local A15 design hand-off's
// SpScene.dc.html (v="E", the A15 final), its renderVals() run with node
// (DCLogic stubbed, props v=E, sc=<case>, result=<result>, t=1000 and 2400).
// For each row of e.rows: the name, the points (w.s at 2400), the slot
// before the move ((y - 118) / 48 of w.t at 1000) and after it (at 2400),
// and the rank text before (w.rk at 1000) and after (at 2400); e.cw and
// e.cf for the rank cell; e.gd 'flex' for the dots (outside the list). The
// rankings are the demo's ScoreLadderCase, the server's answers that give
// the design's SCN. The script and the design file are not committed.

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/demo/result_scene_demo.dart';
import 'package:gymrats_app/models/ranking_ladder.dart';
import 'package:gymrats_app/widgets/victory_scene.dart';

typedef _Row = (String, int, double, double, String, String);

const _results = {
  'ko': VictoryResult.koWin,
  'time': VictoryResult.timeWin,
  'left': VictoryResult.leftWin,
  'draw': VictoryResult.draw,
  'lose': VictoryResult.lose,
};

const _design =
    <
      ({
        String sc,
        String result,
        double cellWidth,
        double cellText,
        bool outside,
        List<_Row> rows,
      })
    >[
      (
        sc: 'base',
        result: 'ko',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('펭귄짱', 31, 0.0, 0.0, '1', '1'),
          ('헬스쿼카', 23, 1.0, 2.0, '2', '3'),
          ('그루맨', 22, 2.0, 3.0, '3', '4'),
          ('쥐돌이', 29, 3.0, 1.0, '4', '2'),
        ],
      ),
      (
        sc: 'base',
        result: 'time',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('펭귄짱', 31, 0.0, 0.0, '1', '1'),
          ('헬스쿼카', 23, 1.0, 2.0, '2', '3'),
          ('그루맨', 22, 2.0, 3.0, '3', '4'),
          ('쥐돌이', 24, 3.0, 1.0, '4', '2'),
        ],
      ),
      (
        sc: 'base',
        result: 'left',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('펭귄짱', 31, 0.0, 0.0, '1', '1'),
          ('헬스쿼카', 23, 1.0, 2.0, '2', '3'),
          ('그루맨', 22, 2.0, 3.0, '3', '4'),
          ('쥐돌이', 24, 3.0, 1.0, '4', '2'),
        ],
      ),
      (
        sc: 'base',
        result: 'draw',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('펭귄짱', 31, 0.0, 0.0, '1', '1'),
          ('헬스쿼카', 23, 1.0, 1.0, '2', '2'),
          ('그루맨', 22, 2.0, 3.0, '3', '3'),
          ('쥐돌이', 22, 3.0, 2.0, '4', '3'),
        ],
      ),
      (
        sc: 'base',
        result: 'lose',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('펭귄짱', 31, 0.0, 0.0, '1', '1'),
          ('헬스쿼카', 23, 1.0, 1.0, '2', '2'),
          ('그루맨', 22, 2.0, 2.0, '3', '3'),
          ('쥐돌이', 20, 3.0, 3.0, '4', '4'),
        ],
      ),
      (
        sc: 'mid',
        result: 'ko',
        cellWidth: 40.0,
        cellText: 17.0,
        outside: false,
        rows: [
          ('스쿼트킹', 53, 0.0, 0.0, '14', '14'),
          ('하루백개', 47, 1.0, 2.0, '15', '16'),
          ('근육곰', 45, 2.0, 3.0, '16', '17'),
          ('쥐돌이', 50, 3.0, 1.0, '20', '15'),
        ],
      ),
      (
        sc: 'mid',
        result: 'time',
        cellWidth: 40.0,
        cellText: 17.0,
        outside: false,
        rows: [
          ('하루백개', 47, 0.0, 0.0, '15', '15'),
          ('근육곰', 45, 1.0, 2.0, '16', '16'),
          ('새벽러너', 44, 2.0, 3.0, '17', '18'),
          ('쥐돌이', 45, 3.0, 1.0, '20', '16'),
        ],
      ),
      (
        sc: 'mid',
        result: 'left',
        cellWidth: 40.0,
        cellText: 17.0,
        outside: false,
        rows: [
          ('하루백개', 47, 0.0, 0.0, '15', '15'),
          ('근육곰', 45, 1.0, 2.0, '16', '16'),
          ('새벽러너', 44, 2.0, 3.0, '17', '18'),
          ('쥐돌이', 45, 3.0, 1.0, '20', '16'),
        ],
      ),
      (
        sc: 'mid',
        result: 'draw',
        cellWidth: 40.0,
        cellText: 17.0,
        outside: false,
        rows: [
          ('새벽러너', 44, 0.0, 0.0, '17', '17'),
          ('오늘도출석', 42, 1.0, 2.0, '18', '19'),
          ('푸시푸시', 41, 2.0, 3.0, '19', '20'),
          ('쥐돌이', 43, 3.0, 1.0, '20', '18'),
        ],
      ),
      (
        sc: 'mid',
        result: 'lose',
        cellWidth: 40.0,
        cellText: 17.0,
        outside: false,
        rows: [
          ('새벽러너', 44, 0.0, 0.0, '17', '17'),
          ('오늘도출석', 42, 1.0, 1.0, '18', '18'),
          ('푸시푸시', 41, 2.0, 3.0, '19', '19'),
          ('쥐돌이', 41, 3.0, 2.0, '20', '19'),
        ],
      ),
      (
        sc: 'enter',
        result: 'ko',
        cellWidth: 40.0,
        cellText: 17.0,
        outside: false,
        rows: [
          ('팔굽혀', 21, 0.0, 0.0, '47', '47'),
          ('근성맨', 14, 1.0, 2.0, '48', '49'),
          ('꾸준히', 13, 2.0, 3.0, '49', '50'),
          ('쥐돌이', 19, 3.0, 1.0, '63', '48'),
        ],
      ),
      (
        sc: 'enter',
        result: 'time',
        cellWidth: 40.0,
        cellText: 17.0,
        outside: false,
        rows: [
          ('팔굽혀', 21, 0.0, 0.0, '47', '47'),
          ('근성맨', 14, 1.0, 2.0, '48', '48'),
          ('꾸준히', 13, 2.0, 3.0, '49', '50'),
          ('쥐돌이', 14, 3.0, 1.0, '63', '48'),
        ],
      ),
      (
        sc: 'enter',
        result: 'left',
        cellWidth: 40.0,
        cellText: 17.0,
        outside: false,
        rows: [
          ('팔굽혀', 21, 0.0, 0.0, '47', '47'),
          ('근성맨', 14, 1.0, 2.0, '48', '48'),
          ('꾸준히', 13, 2.0, 3.0, '49', '50'),
          ('쥐돌이', 14, 3.0, 1.0, '63', '48'),
        ],
      ),
      (
        sc: 'enter',
        result: 'draw',
        cellWidth: 40.0,
        cellText: 17.0,
        outside: false,
        rows: [
          ('근성맨', 14, 0.0, 0.0, '48', '48'),
          ('꾸준히', 13, 1.0, 1.0, '49', '49'),
          ('오늘만산다', 12, 2.0, 3.0, '50', '50'),
          ('쥐돌이', 12, 3.0, 2.0, '63', '50'),
        ],
      ),
      (
        sc: 'enter',
        result: 'lose',
        cellWidth: 40.0,
        cellText: 17.0,
        outside: true,
        rows: [
          ('오늘만산다', 12, 0.0, 0.0, '50', '50'),
          ('쥐돌이', 10, 1.5, 1.5, '63', '61'),
        ],
      ),
      (
        sc: 'big',
        result: 'ko',
        cellWidth: 58.0,
        cellText: 15.0,
        outside: true,
        rows: [
          ('꾸준히', 24, 0.0, 0.0, '50', '50'),
          ('쥐돌이', 13, 1.5, 1.5, '1,204', '803'),
        ],
      ),
      (
        sc: 'big',
        result: 'time',
        cellWidth: 58.0,
        cellText: 15.0,
        outside: true,
        rows: [
          ('꾸준히', 24, 0.0, 0.0, '50', '50'),
          ('쥐돌이', 8, 1.5, 1.5, '1,204', '1,012'),
        ],
      ),
      (
        sc: 'big',
        result: 'left',
        cellWidth: 58.0,
        cellText: 15.0,
        outside: true,
        rows: [
          ('꾸준히', 24, 0.0, 0.0, '50', '50'),
          ('쥐돌이', 8, 1.5, 1.5, '1,204', '1,012'),
        ],
      ),
      (
        sc: 'big',
        result: 'draw',
        cellWidth: 58.0,
        cellText: 15.0,
        outside: true,
        rows: [
          ('꾸준히', 24, 0.0, 0.0, '50', '50'),
          ('쥐돌이', 6, 1.5, 1.5, '1,204', '1,098'),
        ],
      ),
      (
        sc: 'big',
        result: 'lose',
        cellWidth: 58.0,
        cellText: 15.0,
        outside: true,
        rows: [
          ('꾸준히', 24, 0.0, 0.0, '50', '50'),
          ('쥐돌이', 4, 1.5, 1.5, '1,204', '1,177'),
        ],
      ),
      (
        sc: 'first',
        result: 'ko',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('그루맨', 22, 0.0, 0.0, '3', '3'),
          ('아침운동', 16, 1.0, 1.0, '4', '4'),
          ('스쿼트왕', 16, 2.0, 2.0, '4', '4'),
          ('쥐돌이', 10, 3.0, 3.0, '–', '6'),
        ],
      ),
      (
        sc: 'first',
        result: 'time',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('그루맨', 22, 0.0, 0.0, '3', '3'),
          ('아침운동', 16, 1.0, 1.0, '4', '4'),
          ('스쿼트왕', 16, 2.0, 2.0, '4', '4'),
          ('쥐돌이', 5, 3.0, 3.0, '–', '6'),
        ],
      ),
      (
        sc: 'first',
        result: 'left',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('그루맨', 22, 0.0, 0.0, '3', '3'),
          ('아침운동', 16, 1.0, 1.0, '4', '4'),
          ('스쿼트왕', 16, 2.0, 2.0, '4', '4'),
          ('쥐돌이', 5, 3.0, 3.0, '–', '6'),
        ],
      ),
      (
        sc: 'first',
        result: 'draw',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('그루맨', 22, 0.0, 0.0, '3', '3'),
          ('아침운동', 16, 1.0, 1.0, '4', '4'),
          ('스쿼트왕', 16, 2.0, 2.0, '4', '4'),
          ('쥐돌이', 3, 3.0, 3.0, '–', '6'),
        ],
      ),
      (
        sc: 'first',
        result: 'lose',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('그루맨', 22, 0.0, 0.0, '3', '3'),
          ('아침운동', 16, 1.0, 1.0, '4', '4'),
          ('스쿼트왕', 16, 2.0, 2.0, '4', '4'),
          ('쥐돌이', 1, 3.0, 3.0, '–', '6'),
        ],
      ),
      (
        sc: 'solo',
        result: 'ko',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [('쥐돌이', 10, 0.0, 0.0, '–', '1')],
      ),
      (
        sc: 'solo',
        result: 'time',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [('쥐돌이', 5, 0.0, 0.0, '–', '1')],
      ),
      (
        sc: 'solo',
        result: 'left',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [('쥐돌이', 5, 0.0, 0.0, '–', '1')],
      ),
      (
        sc: 'solo',
        result: 'draw',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [('쥐돌이', 3, 0.0, 0.0, '–', '1')],
      ),
      (
        sc: 'solo',
        result: 'lose',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [('쥐돌이', 1, 0.0, 0.0, '–', '1')],
      ),
      (
        sc: 'top',
        result: 'ko',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('펭귄짱', 31, 0.0, 1.0, '1', '2'),
          ('헬스쿼카', 23, 2.0, 2.0, '3', '3'),
          ('그루맨', 22, 3.0, 3.0, '4', '4'),
          ('쥐돌이', 36, 1.0, 0.0, '2', '1'),
        ],
      ),
      (
        sc: 'top',
        result: 'time',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('펭귄짱', 31, 0.0, 1.0, '1', '1'),
          ('헬스쿼카', 23, 2.0, 2.0, '3', '3'),
          ('그루맨', 22, 3.0, 3.0, '4', '4'),
          ('쥐돌이', 31, 1.0, 0.0, '2', '1'),
        ],
      ),
      (
        sc: 'top',
        result: 'left',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('펭귄짱', 31, 0.0, 1.0, '1', '1'),
          ('헬스쿼카', 23, 2.0, 2.0, '3', '3'),
          ('그루맨', 22, 3.0, 3.0, '4', '4'),
          ('쥐돌이', 31, 1.0, 0.0, '2', '1'),
        ],
      ),
      (
        sc: 'top',
        result: 'draw',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('펭귄짱', 31, 0.0, 0.0, '1', '1'),
          ('헬스쿼카', 23, 2.0, 2.0, '3', '3'),
          ('그루맨', 22, 3.0, 3.0, '4', '4'),
          ('쥐돌이', 29, 1.0, 1.0, '2', '2'),
        ],
      ),
      (
        sc: 'top',
        result: 'lose',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('펭귄짱', 31, 0.0, 0.0, '1', '1'),
          ('헬스쿼카', 23, 2.0, 2.0, '3', '3'),
          ('그루맨', 22, 3.0, 3.0, '4', '4'),
          ('쥐돌이', 27, 1.0, 1.0, '2', '2'),
        ],
      ),
      (
        sc: 'king',
        result: 'ko',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('근육왕', 298, 1.0, 1.0, '2', '2'),
          ('스쿼트킹', 287, 2.0, 2.0, '3', '3'),
          ('하루백개', 254, 3.0, 3.0, '4', '4'),
          ('쥐돌이', 322, 0.0, 0.0, '1', '1'),
        ],
      ),
      (
        sc: 'king',
        result: 'time',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('근육왕', 298, 1.0, 1.0, '2', '2'),
          ('스쿼트킹', 287, 2.0, 2.0, '3', '3'),
          ('하루백개', 254, 3.0, 3.0, '4', '4'),
          ('쥐돌이', 317, 0.0, 0.0, '1', '1'),
        ],
      ),
      (
        sc: 'king',
        result: 'left',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('근육왕', 298, 1.0, 1.0, '2', '2'),
          ('스쿼트킹', 287, 2.0, 2.0, '3', '3'),
          ('하루백개', 254, 3.0, 3.0, '4', '4'),
          ('쥐돌이', 317, 0.0, 0.0, '1', '1'),
        ],
      ),
      (
        sc: 'king',
        result: 'draw',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('근육왕', 298, 1.0, 1.0, '2', '2'),
          ('스쿼트킹', 287, 2.0, 2.0, '3', '3'),
          ('하루백개', 254, 3.0, 3.0, '4', '4'),
          ('쥐돌이', 315, 0.0, 0.0, '1', '1'),
        ],
      ),
      (
        sc: 'king',
        result: 'lose',
        cellWidth: 40.0,
        cellText: 19.0,
        outside: false,
        rows: [
          ('근육왕', 298, 1.0, 1.0, '2', '2'),
          ('스쿼트킹', 287, 2.0, 2.0, '3', '3'),
          ('하루백개', 254, 3.0, 3.0, '4', '4'),
          ('쥐돌이', 313, 0.0, 0.0, '1', '1'),
        ],
      ),
    ];

RankingLadder _ladderOf(String sc, VictoryResult result) {
  final c = ScoreLadderCase.all[sc]!;
  return RankingLadder.of(
    before: c.before,
    after: c.after(result),
    points: ScoreLadderCase.pointsOf(result),
  );
}

LadderEntry _entry(int userId, int points, int rank, {int battles = 3}) => (
  userId: userId,
  nickname: '선수$userId',
  points: points,
  rank: rank,
  battles: battles,
);

void main() {
  group('RankingLadder.of matches the design', () {
    for (final want in _design) {
      test('${want.sc} ${want.result}', () {
        final result = _results[want.result]!;
        final c = ScoreLadderCase.all[want.sc]!;
        expect(
          RankingLadder.pathOf(
            ranked: true,
            before: c.before,
            after: c.after(result),
            points: ScoreLadderCase.pointsOf(result),
          ),
          LadderPath.confirmed,
        );
        final ladder = _ladderOf(want.sc, result);
        expect([
          for (final row in ladder.rows)
            (
              row.nickname,
              row.points,
              row.fromSlot,
              row.toSlot,
              row.rankBeforeText,
              row.rankAfterText,
            ),
        ], want.rows);
        expect(ladder.rows.last.isMe, isTrue);
        expect(ladder.others.every((row) => !row.isMe), isTrue);
        expect(ladder.outside, want.outside);
        expect(ladder.rankCellWidth, want.cellWidth);
        expect(ladder.rankCellText, want.cellText);
        expect(ladder.gained, ScoreLadderCase.pointsOf(result));
        expect(ladder.pointsBefore, c.old ?? 0);
      });
    }
  });

  group("every rank shown is the server's", () {
    const cases = [
      'base',
      'mid',
      'enter',
      'big',
      'first',
      'solo',
      'top',
      'king',
    ];
    for (final sc in cases) {
      for (final result in VictoryResult.values) {
        test('$sc ${result.name}', () {
          final c = ScoreLadderCase.all[sc]!;
          final before = c.before;
          final after = c.after(result);
          final ladder = _ladderOf(sc, result);
          for (final row in ladder.others) {
            final now = after.entries.singleWhere(
              (e) => e.nickname == row.nickname,
            );
            final then = before.entries
                .where((e) => e.userId == now.userId)
                .firstOrNull;
            expect(row.rankAfter, now.rank);
            expect(row.rankBefore, then?.rank ?? now.rank);
          }
          expect(ladder.me.rankBefore, before.me?.rank);
          expect(ladder.me.rankAfter, after.me!.rank);
          expect(ladder.me.points, after.me!.points);
        });
      }
    }
  });

  group('the cases SPEC 7 names', () {
    test('passing four or more shows the two nearest and the real ranks', () {
      // mid KO: 40 -> 50 passes 47, 45, 44, 42 and 41.
      final ladder = _ladderOf('mid', VictoryResult.koWin);
      expect(ladder.others.map((row) => row.nickname), ['스쿼트킹', '하루백개', '근육곰']);
      expect((ladder.me.rankBeforeText, ladder.me.rankAfterText), ('20', '15'));
    });

    test('equal points share a rank (1, 1, 3) and mine stands above', () {
      final ladder = _ladderOf('top', VictoryResult.timeWin);
      expect(ladder.me.toSlot, 0);
      expect(ladder.others.first.toSlot, 1);
      expect([for (final row in ladder.rows) row.rankAfter]..sort(), [
        1,
        1,
        3,
        4,
      ]);
    });

    test('ranks of 1,000 and more get commas and the widest cell', () {
      final ladder = _ladderOf('big', VictoryResult.koWin);
      expect(ladder.me.rankBeforeText, '1,204');
      expect(ladder.me.rankAfterText, '803');
      expect(ladder.rankChars, 5);
      expect((ladder.rankCellWidth, ladder.rankCellText), (58, 15));
    });

    test('three-digit points stay as they are', () {
      final ladder = _ladderOf('king', VictoryResult.koWin);
      expect(ladder.me.points, 322);
      expect(ladder.me.fromSlot, 0);
      expect(ladder.me.toSlot, 0);
    });

    test('the first battle of the week starts at the bottom with no rank', () {
      final ladder = _ladderOf('first', VictoryResult.koWin);
      expect(ladder.me.rankBefore, isNull);
      expect(ladder.me.rankBeforeText, '–');
      expect(ladder.me.fromSlot, ladder.others.length);
      expect(ladder.me.rankAfter, 6);
      expect(ladder.pointsBefore, 0);
    });

    test('alone this week: only my row, – to 1', () {
      final ladder = _ladderOf('solo', VictoryResult.lose);
      expect(ladder.others, isEmpty);
      expect((ladder.me.rankBeforeText, ladder.me.rankAfterText), ('–', '1'));
    });

    test('still outside the list: its last row, the dots and mine', () {
      final after = ScoreLadderCase.all['enter']!.after(VictoryResult.lose);
      expect(after.entries.any(after.isMine), isFalse);
      final ladder = _ladderOf('enter', VictoryResult.lose);
      expect(ladder.outside, isTrue);
      expect(ladder.others.single.rankAfter, 50);
      expect(ladder.others.single.rankChanged, isFalse);
      expect((ladder.me.rankBefore, ladder.me.rankAfter), (63, 61));
    });

    test('equal to the last row but cut from the list is still in it', () {
      // enter draw: 12 points, as many as the 50th; the server lists that
      // player first by name, so my row is not in its 50 rows.
      final after = ScoreLadderCase.all['enter']!.after(VictoryResult.draw);
      expect(after.entries.any(after.isMine), isFalse);
      expect(after.me!.rank, 50);
      final ladder = _ladderOf('enter', VictoryResult.draw);
      expect(ladder.outside, isFalse);
      expect(ladder.me.toSlot, 2);
      expect(ladder.others.last.nickname, '오늘만산다');
    });

    test('a player who played during my battle starts where the ranking '
        'before had them', () {
      // C went from 15 to 25 while I went from 18 to 23 (PR #122 review).
      final before = RankingSnapshot(
        entries: [
          _entry(1, 30, 1),
          _entry(2, 20, 2),
          _entry(9, 18, 3, battles: 3),
          _entry(3, 15, 4),
        ],
        me: _entry(9, 18, 3, battles: 3),
      );
      final after = RankingSnapshot(
        entries: [
          _entry(1, 30, 1),
          _entry(3, 25, 2),
          _entry(9, 23, 3, battles: 4),
          _entry(2, 20, 4),
        ],
        me: _entry(9, 23, 3, battles: 4),
      );
      final ladder = RankingLadder.of(before: before, after: after, points: 5);
      final slots = {
        for (final row in ladder.rows) row.nickname: (row.fromSlot, row.toSlot),
      };
      // The start is the order before: 선수1, 선수2, me, 선수3.
      expect(slots, {
        '선수1': (0.0, 0.0),
        '선수2': (1.0, 3.0),
        '선수9': (2.0, 2.0),
        '선수3': (3.0, 1.0),
      });
      // Drawn by the points now, as before.
      expect(ladder.others.map((row) => row.nickname), ['선수1', '선수3', '선수2']);
      final c = ladder.others.singleWhere((row) => row.nickname == '선수3');
      expect((c.rankBefore, c.rankAfter), (4, 2));
    });

    test('my first battle: rows above me start in the order before', () {
      // 선수2 went from 15 to 25 while I played my first battle (10).
      final before = RankingSnapshot(
        entries: [_entry(1, 20, 1), _entry(2, 15, 2)],
      );
      final after = RankingSnapshot(
        entries: [
          _entry(2, 25, 1),
          _entry(1, 20, 2),
          _entry(9, 10, 3, battles: 1),
        ],
        me: _entry(9, 10, 3, battles: 1),
      );
      final ladder = RankingLadder.of(before: before, after: after, points: 10);
      expect(
        {
          for (final row in ladder.rows)
            row.nickname: (row.fromSlot, row.toSlot),
        },
        {'선수1': (0.0, 1.0), '선수2': (1.0, 0.0), '선수9': (2.0, 2.0)},
      );
    });

    test('a newcomer starts by its points now among rows that moved', () {
      // 선수4 is new this week (22); 선수3 went from 10 to 21.
      final before = RankingSnapshot(
        entries: [
          _entry(1, 30, 1),
          _entry(9, 18, 2, battles: 2),
          _entry(3, 10, 3),
        ],
        me: _entry(9, 18, 2, battles: 2),
      );
      final after = RankingSnapshot(
        entries: [
          _entry(1, 30, 1),
          _entry(9, 23, 2, battles: 3),
          _entry(4, 22, 3),
          _entry(3, 21, 4),
        ],
        me: _entry(9, 23, 2, battles: 3),
      );
      final ladder = RankingLadder.of(before: before, after: after, points: 5);
      expect(
        {
          for (final row in ladder.rows)
            row.nickname: (row.fromSlot, row.toSlot),
        },
        {
          '선수1': (0.0, 0.0),
          '선수4': (1.0, 2.0),
          '선수9': (2.0, 1.0),
          '선수3': (3.0, 3.0),
        },
      );
    });

    test('a player not in the ranking before keeps one rank', () {
      final before = RankingSnapshot(
        entries: [_entry(1, 30, 1), _entry(9, 10, 2, battles: 1)],
        me: _entry(9, 10, 2, battles: 1),
      );
      final after = RankingSnapshot(
        entries: [
          _entry(1, 30, 1),
          _entry(2, 20, 2),
          _entry(9, 15, 3, battles: 2),
        ],
        me: _entry(9, 15, 3, battles: 2),
      );
      final ladder = RankingLadder.of(before: before, after: after, points: 5);
      final newcomer = ladder.others.singleWhere(
        (row) => row.nickname == '선수2',
      );
      expect((newcomer.rankBefore, newcomer.rankAfter), (2, 2));
      expect(newcomer.rankChanged, isFalse);
      expect((ladder.me.rankBefore, ladder.me.rankAfter), (2, 3));
    });

    test('outside the list with equal lowest rows: the first of them', () {
      final rows = [_entry(1, 30, 1), _entry(2, 12, 2), _entry(3, 12, 2)];
      final ladder = RankingLadder.of(
        before: RankingSnapshot(entries: rows, me: _entry(9, 4, 80)),
        after: RankingSnapshot(entries: rows, me: _entry(9, 5, 70, battles: 4)),
        points: 1,
      );
      expect(ladder.outside, isTrue);
      expect(ladder.others.single.nickname, '선수2');
      expect(ladder.others.single.rankAfter, 2);
    });

    test('a three-character rank gets the middle cell', () {
      final ladder = RankingLadder.of(
        before: RankingSnapshot(entries: const [], me: _entry(9, 40, 120)),
        after: RankingSnapshot(
          entries: const [],
          me: _entry(9, 45, 101, battles: 4),
        ),
        points: 5,
      );
      expect(ladder.rankChars, 3);
      expect((ladder.rankCellWidth, ladder.rankCellText), (46, 15));
    });

    test('an empty list: only my row', () {
      final ladder = RankingLadder.of(
        before: const RankingSnapshot(entries: []),
        after: RankingSnapshot(
          entries: const [],
          me: _entry(9, 1, 7, battles: 1),
        ),
        points: 1,
      );
      expect(ladder.outside, isFalse);
      expect(ladder.others, isEmpty);
      expect(ladder.me.rankAfterText, '7');
    });
  });

  group('RankingLadder.pathOf', () {
    final c = ScoreLadderCase.all['base']!;
    final confirmed = c.after(VictoryResult.koWin);

    LadderPath path({
      bool ranked = true,
      RankingSnapshot? before,
      bool noBefore = false,
      RankingSnapshot? after,
      int points = 10,
    }) => RankingLadder.pathOf(
      ranked: ranked,
      before: noBefore ? null : before ?? c.before,
      after: after,
      points: points,
    );

    test('confirmed when after has one battle more', () {
      expect(RankingLadder.confirms(c.before, confirmed), isTrue);
      expect(path(after: confirmed), LadderPath.confirmed);
    });

    test('confirmed for the first battle of the week', () {
      final first = ScoreLadderCase.all['first']!;
      expect(first.before.me, isNull);
      expect(
        path(before: first.before, after: first.after(VictoryResult.lose)),
        LadderPath.confirmed,
      );
    });

    test('late without a confirmed after', () {
      expect(path(), LadderPath.late);
      // The battle is not in it yet.
      expect(path(after: c.before), LadderPath.late);
      // Two battles more is not this battle's ranking.
      final mine = confirmed.me!;
      final twoOn = RankingSnapshot(
        entries: confirmed.entries,
        me: (
          userId: mine.userId,
          nickname: mine.nickname,
          points: mine.points,
          rank: mine.rank,
          battles: mine.battles + 1,
        ),
      );
      expect(path(after: twoOn), LadderPath.late);
      // Without my row after the battle it is not confirmed either.
      expect(
        path(after: RankingSnapshot(entries: confirmed.entries)),
        LadderPath.late,
      );
    });

    group('across a week reset (Monday 00:00 KST)', () {
      final lastWeek = DateTime.utc(2026, 11, 22, 15);
      final thisWeek = DateTime.utc(2026, 11, 29, 15);
      RankingSnapshot week(
        DateTime start,
        LadderEntry? me, {
        int others = 30,
      }) => RankingSnapshot(
        weekStart: start,
        entries: [_entry(1, others, 1), ?me],
        me: me,
      );

      test("the new week's first battle: late, never the ladder", () {
        final before = week(lastWeek, _entry(9, 19, 4, battles: 4));
        final after = week(thisWeek, _entry(9, 10, 2, battles: 1), others: 12);
        expect(RankingLadder.sameWeek(before, after), isFalse);
        expect(RankingLadder.confirms(before, after), isTrue);
        expect(path(before: before, after: after), LadderPath.late);
        // The chip has only the new week's values and the battle's points.
        expect(RankingLadder.chipOf(after, 10), (
          rank: 2,
          points: 10,
          gained: 10,
        ));
      });

      test('one battle more than last week is not this battle', () {
        final before = week(lastWeek, _entry(9, 19, 4, battles: 4));
        final after = week(thisWeek, _entry(9, 10, 2, battles: 5));
        expect(RankingLadder.confirms(before, after), isFalse);
        expect(path(before: before, after: after), LadderPath.late);
      });

      test("no row last week and the new week's first battle: still late", () {
        final before = week(lastWeek, null);
        final after = week(thisWeek, _entry(9, 10, 2, battles: 1));
        expect(RankingLadder.confirms(before, after), isTrue);
        expect(path(before: before, after: after), LadderPath.late);
      });

      test('the new week without the battle yet: nothing is confirmed', () {
        final before = week(lastWeek, _entry(9, 19, 4, battles: 4));
        for (final after in [
          week(thisWeek, null),
          week(thisWeek, _entry(9, 0, 2, battles: 0)),
        ]) {
          expect(RankingLadder.confirms(before, after), isFalse);
          expect(path(before: before, after: after), LadderPath.late);
        }
      });

      test('the same week as before: the ladder as usual', () {
        final before = week(thisWeek, _entry(9, 19, 2, battles: 4));
        final after = week(thisWeek, _entry(9, 29, 2, battles: 5));
        expect(RankingLadder.sameWeek(before, after), isTrue);
        expect(path(before: before, after: after), LadderPath.confirmed);
      });

      test('a week not known counts as the same week', () {
        final before = RankingSnapshot(
          entries: const [],
          me: _entry(9, 19, 2, battles: 4),
        );
        final after = week(thisWeek, _entry(9, 29, 2, battles: 5));
        expect(RankingLadder.sameWeek(before, after), isTrue);
        expect(RankingLadder.sameWeek(after, before), isTrue);
      });
    });

    test('none for a friend battle, no ranking before, or no points', () {
      expect(path(ranked: false, after: confirmed), LadderPath.none);
      expect(path(noBefore: true, after: confirmed), LadderPath.none);
      expect(path(after: confirmed, points: 0), LadderPath.none);
    });
  });

  test("chipOf gives the confirmed rank, week's points and the gain", () {
    final after = ScoreLadderCase.all['big']!.after(VictoryResult.koWin);
    expect(RankingLadder.chipOf(after, 10), (
      rank: 803,
      points: 13,
      gained: 10,
    ));
  });

  test('rankText writes commas from 1,000 and – for none', () {
    expect(RankingLadder.rankText(null), '–');
    expect(RankingLadder.rankText(1), '1');
    expect(RankingLadder.rankText(999), '999');
    expect(RankingLadder.rankText(1000), '1,000');
    expect(RankingLadder.rankText(1204), '1,204');
    expect(RankingLadder.rankText(1234567), '1,234,567');
  });

  test('the rank cell sizes by the longest rank text', () {
    LadderRow row(int? before, int after) => LadderRow(
      nickname: '',
      points: 0,
      isMe: true,
      order: 0,
      fromSlot: 0,
      toSlot: 0,
      rankBefore: before,
      rankAfter: after,
    );
    expect(row(null, 1).rankChanged, isTrue);
    expect(row(5, 5).rankChanged, isFalse);
    expect(_ladderOf('base', VictoryResult.lose).rankChars, 1);
    expect(_ladderOf('mid', VictoryResult.lose).rankChars, 2);
    final king = _ladderOf('king', VictoryResult.koWin);
    expect((king.rankCellWidth, king.rankCellText), (40, 19));
  });
}
