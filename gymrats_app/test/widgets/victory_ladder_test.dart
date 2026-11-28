// The A15 rank ladder over the victory scene against the design (the local
// A15 design hand-off's SpScene.dc.html, v="E").
//
// How victory_ladder_golden.json was made (the script and the design stay
// outside the repo): a node script read SpScene.dc.html, took its
// `class Component extends DCLogic` script (DCLogic stubbed) and ran its own
// `renderVals()` with v = E, live = false, result = ko or lose (all five for
// the scene), sc = each case and t = each time, and once with still = true.
// As for A7, `Number.prototype.toFixed` returned the number in full (the
// design rounds for its CSS), and the values were rounded to 1e-6. It read
// the CSS back as numbers: a row at `translate(x, y) scale(k)` (left 22,
// 316 x 42) has its middle at (x + 180, y + 21); a character box placed by
// `translate(X, Y) scale(sx, sy)` has its feet at (X + 70, Y + 150); the
// panel's `inset(top right bottom left round r)` as written; the dots'
// middle at (180 + gx, gy + 11). The times are SPEC 8.4's (0.9, 1.0, 1.3,
// 1.6, 1.9, 2.45 s, the way out + 0.2 and + 0.45 s, the end) and times next
// to every switch. The rankings are ScoreLadderCase's (the demo), the
// server's answers that give the design's SCN.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/demo/result_scene_demo.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/ranking_ladder.dart';
import 'package:gymrats_app/services/rankings/rankings_repository.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/viewmodels/ranking_ladder_viewmodel.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/victory_ladder.dart';
import 'package:gymrats_app/widgets/victory_motion.dart';
import 'package:gymrats_app/widgets/victory_overlay.dart';
import 'package:gymrats_app/widgets/victory_scene.dart';

import 'victory_test_support.dart';

final _golden = jsonDecode(
  File('test/widgets/victory_ladder_golden.json').readAsStringSync(),
) as Map<String, dynamic>;

final _tolerance = (_golden['tolerance'] as num).toDouble();

Matcher _near(Object? value) => closeTo((value as num).toDouble(), _tolerance);

void _expectPoint(Offset actual, Object? golden, String where) {
  final xy = golden as List;
  expect(actual.dx, _near(xy[0]), reason: '$where x');
  expect(actual.dy, _near(xy[1]), reason: '$where y');
}

const _results = {
  'ko': VictoryResult.koWin,
  'time': VictoryResult.timeWin,
  'left': VictoryResult.leftWin,
  'draw': VictoryResult.draw,
  'lose': VictoryResult.lose,
};

VictoryScene _scene(
  VictoryResult result, {
  bool hold = true,
  Size size = designSize,
  Offset seat = designSeat,
}) {
  final rig = VictoryRig.standard;
  return VictoryScene(
    rig: rig,
    character: rig.characterOf('mouse'),
    result: result,
    layout: VictoryLayout(size: size, seat: seat, values: rig.scene),
    opponentId: 'penguin',
    hold: hold,
  );
}

RankingLadder _ladder(String sc, VictoryResult result) {
  final c = ScoreLadderCase.all[sc]!;
  return RankingLadder.of(
    before: c.before,
    after: c.after(result),
    points: ScoreLadderCase.pointsOf(result),
  );
}

void _expectBand(VictoryBand? band, Object? golden, String at) {
  if (golden == null) {
    expect(band, isNull, reason: '$at band');
    return;
  }
  final want = golden as Map<String, dynamic>;
  expect(band, isNotNull, reason: '$at band');
  expect(band!.dx, _near(want['x']), reason: '$at band x');
  expect(band.dy, _near(want['y']), reason: '$at band y');
  expect(band.scale, _near(want['scale']), reason: '$at band scale');
  expect(band.opacity, _near(want['opacity']), reason: '$at band opacity');
  expect(band.rotDeg, _near(want['rot']), reason: '$at band turn');
}

void _expectLadder(
  VictoryLadderFrame frame,
  RankingLadder ladder,
  Map<String, dynamic> want,
  String at,
) {
  final rows = (want['rows'] as List).cast<Map<String, dynamic>>();
  final shown = rows.where((row) => (row['opacity'] as num) > 0).toList();
  // The end look draws no row; the design keeps them at opacity 0.
  final drawn = frame.rows.where((row) => row.opacity > 1e-9).toList();
  expect(drawn, hasLength(shown.length), reason: '$at rows');
  if (frame.rows.isNotEmpty) {
    expect(frame.rows, hasLength(rows.length), reason: '$at rows');
    for (final (i, row) in frame.rows.indexed) {
      final w = rows[i];
      final where = '$at row $i';
      expect(row.row.nickname, w['name'], reason: where);
      expect(row.isMe, w['me'], reason: where);
      expect(row.opacity, _near(w['opacity']), reason: '$where opacity');
      if ((w['opacity'] as num) > 0) {
        _expectPoint(row.center, w['center'], '$where middle');
        expect(row.scale, _near(w['scale']), reason: '$where scale');
      }
      expect(row.rank, w['rank'], reason: '$where rank');
      expect(row.rankScale, _near(w['rankScale']), reason: '$where pop');
      expect(row.points, w['score'], reason: '$where points');
      expect(row.first, w['first'], reason: '$where first cell');
      if (row.isMe) {
        expect(row.tagOpacity, _near(w['tagOpacity']), reason: '$where tag');
        expect(row.tagScale, _near(w['tagScale']), reason: '$where tag');
        expect(row.lift, _near(w['lift']), reason: '$where shadow');
      }
    }
  }
  final dots = want['dots'] as Map<String, dynamic>?;
  if (dots == null) {
    expect(frame.dotsCenter, isNull, reason: '$at dots');
  } else if (frame.rows.isNotEmpty) {
    expect(frame.dotsOpacity, _near(dots['opacity']), reason: '$at dots');
    if ((dots['opacity'] as num) > 0) {
      _expectPoint(frame.dotsCenter!, dots['center'], '$at dots');
    }
  }
  final cell = want['cell'] as List;
  expect(ladder.rankCellWidth, _near(cell[0]), reason: '$at cell');
  expect(ladder.rankCellText, _near(cell[1]), reason: '$at cell');
  final chip = want['chip'] as Map<String, dynamic>?;
  if (chip == null) {
    expect(frame.chip, isNull, reason: '$at chip');
  } else {
    expect(frame.chip!.opacity, _near(chip['opacity']), reason: '$at chip');
    expect(frame.chip!.scale, _near(chip['scale']), reason: '$at chip');
    _expectPoint(frame.chip!.center, [272, 53], '$at chip');
    final values = RankingLadder.chipOf(
      ScoreLadderCase.all[at.split(' ').first]!.after(
        _results[at.split(' ')[1]]!,
      ),
      ladder.gained,
    );
    expect(RankingLadder.rankText(values.rank), chip['rank'], reason: at);
    expect(RankingLadder.rankText(values.points), chip['points'], reason: at);
  }
}

void _expectScene(VictoryFrame frame, Map<String, dynamic> want, String at) {
  final stand = want['stand'] as Map<String, dynamic>?;
  if (stand == null) {
    expect(frame.stand, isNull, reason: '$at stand');
  } else {
    expect(frame.stand!.opacity, _near(stand['opacity']), reason: at);
    expect(frame.stand!.scaleX, _near(stand['scaleX']), reason: at);
  }
  final panel = want['panel'] as Map<String, dynamic>?;
  if (panel == null) {
    expect(frame.panel, isNull, reason: '$at panel');
  } else {
    expect(frame.panel!.opacity, _near(panel['opacity']), reason: at);
    final inset = panel['inset'] as List?;
    if (inset == null) {
      expect(frame.panel, isNot(isA<VictoryShrink>()), reason: '$at panel');
    } else {
      final shrink = frame.panel! as VictoryShrink;
      for (final (i, value) in [
        shrink.top,
        shrink.right,
        shrink.bottom,
        shrink.left,
        shrink.radius,
      ].indexed) {
        expect(value, _near(inset[i]), reason: '$at inset $i');
      }
    }
  }
  final me = want['me'] as Map<String, dynamic>?;
  final opponent = want['opponent'] as Map<String, dynamic>?;
  if (frame.fighters.isNotEmpty || (me != null && me.containsKey('pose'))) {
    // A draw: the fighters, mine last.
    if (me == null) {
      expect(frame.fighters, isEmpty, reason: '$at fighters');
    } else {
      final mine = frame.fighters.last;
      _expectPoint(mine.foot, me['foot'], '$at my feet');
      expect(mine.scale, _near(me['sx']), reason: '$at my scale');
      expect(
        mine.pose,
        me['pose'] == 'atk' ? BattlePose.attack : BattlePose.idle,
        reason: '$at my pose',
      );
    }
    if (opponent == null) {
      expect(frame.fighters.length, lessThanOrEqualTo(1), reason: at);
    } else {
      final theirs = frame.fighters.first;
      _expectPoint(theirs.foot, opponent['foot'], '$at their feet');
      expect(theirs.opacity, _near(opponent['opacity']), reason: at);
    }
  } else if (me == null) {
    expect(frame.figure, isNull, reason: '$at figure');
  } else {
    final figure = frame.figure!;
    _expectPoint(figure.foot, me['foot'], '$at feet');
    expect(figure.scale * figure.stretchX, _near(me['sx']), reason: at);
    expect(figure.scale * figure.stretchY, _near(me['sy']), reason: at);
    expect(
      figure.motion,
      me['motion'] == 'cel'
          ? VictoryMotionKind.celebrate
          : VictoryMotionKind.frustrate,
      reason: at,
    );
    if (me['still'] == true) {
      expect(figure.still, isTrue, reason: '$at still');
    } else {
      expect(figure.timeMs, _near(me['time']), reason: '$at motion clock');
      expect(figure.endBlend, _near(me['endBlend']), reason: '$at blend');
    }
  }
  _expectBand(frame.band, want['band'], at);
  final confetti = (want['confetti'] as List).cast<Map<String, dynamic>>();
  expect(frame.confetti.isEmpty, confetti.isEmpty, reason: '$at confetti');
  for (final (i, piece) in confetti.indexed) {
    expect(frame.confetti[i].opacity, _near(piece['opacity']), reason: at);
    _expectPoint(frame.confetti[i].topLeft, piece['at'], '$at confetto $i');
  }
  final rain = want['rain'] as List?;
  if (rain == null) {
    expect(frame.rain, isEmpty, reason: '$at rain');
  } else {
    _expectPoint(frame.rain.first.topLeft, rain, '$at rain');
  }
}

/// [snapshot] as the server's weekly ranking.
WeeklyRanking _weekly(RankingSnapshot snapshot) {
  RankingEntry entry(LadderEntry e) => RankingEntry(
    rank: e.rank,
    userId: e.userId,
    nickname: e.nickname,
    points: e.points,
    battles: e.battles,
    wins: 0,
    koWins: 0,
    isMe: e.userId == snapshot.me?.userId,
  );
  return WeeklyRanking(
    scope: RankingScope.global,
    weekStart: DateTime.utc(2026, 11, 22, 15),
    weekEnd: DateTime.utc(2026, 11, 29, 15),
    entries: [for (final e in snapshot.entries) entry(e)],
    me: switch (snapshot.me) {
      final me? => entry(me),
      null => null,
    },
  );
}

/// A ranking that has the battle only from [confirmedFrom] reads on.
class _Rankings implements RankingsRepository {
  _Rankings(this.before, this.after, {this.confirmedFrom = 1});

  final WeeklyRanking before;
  final WeeklyRanking after;
  final int confirmedFrom;
  var reads = 0;

  @override
  Future<WeeklyRanking> fetchWeekly(
    RankingScope scope,
    ExerciseType exercise,
  ) async => ++reads >= confirmedFrom ? after : before;
}

/// The ladder view model of case [sc] and [result], its ranking confirmed
/// from read [confirmedFrom] on (0 never), loaded.
RankingLadderViewModel _viewModel(
  String sc,
  VictoryResult result, {
  int confirmedFrom = 1,
}) {
  final c = ScoreLadderCase.all[sc]!;
  return RankingLadderViewModel(
    repository: _Rankings(
      _weekly(c.before),
      _weekly(c.after(result)),
      confirmedFrom: confirmedFrom == 0 ? 1 << 30 : confirmedFrom,
    ),
    exercise: ExerciseType.pushUp,
    ranked: true,
    before: c.before,
    points: ScoreLadderCase.pointsOf(result),
    elapsed: () => Duration.zero,
  )..load();
}

/// A report's seat and the scene over it, as the result screen has them:
/// the seat shows the end look only once the scene is over ([seatOnly] from
/// the start, as with reduced motion or a past report).
class _Report extends StatefulWidget {
  const _Report({
    required this.result,
    this.ladder,
    this.reduceMotion = false,
    this.textScale = 1,
    this.onEnd,
    this.seatOnly = false,
    this.seat = designSeat,
  });

  final VictoryResult result;
  final RankingLadderViewModel? ladder;
  final bool reduceMotion;
  final double textScale;
  final VoidCallback? onEnd;
  final bool seatOnly;

  /// The seat's top left: the design's, or where the report puts it on
  /// another screen (its right edge 16 inside the screen's).
  final Offset seat;

  @override
  State<_Report> createState() => _ReportState();
}

class _ReportState extends State<_Report> {
  late bool _over = widget.seatOnly;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: widget.reduceMotion,
          textScaler: TextScaler.linear(widget.textScale),
        ),
        child: ColoredBox(
          color: AppColors.background,
          child: Stack(
            children: [
              if (_over)
                Positioned(
                  left: widget.seat.dx,
                  top: widget.seat.dy,
                  child: VictorySeat(
                    result: widget.result,
                    characterId: 'mouse',
                    ladder: widget.ladder,
                  ),
                ),
              if (!_over)
                Positioned.fill(
                  child: VictoryOverlay(
                    result: widget.result,
                    characterId: 'mouse',
                    seat: widget.seat,
                    onEnd: () {
                      widget.onEnd?.call();
                      setState(() => _over = true);
                    },
                    ladder: widget.ladder,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _show(
  WidgetTester tester,
  Widget report, {
  Size size = designSize,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(report);
  await tester.pump();
}

/// How visible the seat's rank chip is.
double _chipOpacity(WidgetTester tester) {
  final fades = find.ancestor(
    of: find.byType(VictoryRankChip),
    matching: find.byType(Opacity),
  );
  if (fades.evaluate().isEmpty) return 1;
  return tester.widget<Opacity>(fades.first).opacity;
}

/// Plays [ms] more of the scene in frames of 20 ms.
Future<void> _play(WidgetTester tester, int ms) async {
  for (var left = ms; left > 0; left -= 20) {
    await tester.pump(Duration(milliseconds: left < 20 ? left : 20));
  }
}

void main() {
  group('the ladder matches the design', () {
    final ladders = _golden['ladder'] as Map<String, dynamic>;
    for (final MapEntry(key: sc, value: byResult) in ladders.entries) {
      for (final MapEntry(key: name, value: samples)
          in (byResult as Map<String, dynamic>).entries) {
        test('$sc $name', () {
          final result = _results[name]!;
          final ladder = _ladder(sc, result);
          final scene = _scene(result);
          final ladderScene = VictoryLadderScene(ladder: ladder, scene: scene);
          for (final sample in (samples as List).cast<Map<String, dynamic>>()) {
            final t = (sample['tMs'] as num).toDouble();
            final at = '$sc $name $t';
            _expectLadder(ladderScene.at(t), ladder, sample, at);
            _expectBand(scene.at(t).band, sample['band'], at);
          }
        });
      }
    }
  });

  test('the still look is the chip alone', () {
    final stills = _golden['still'] as Map<String, dynamic>;
    for (final MapEntry(key: name, value: want) in stills.entries) {
      final [sc, result] = name.split(' ');
      final ladder = _ladder(sc, _results[result]!);
      final end = VictoryLadderScene(
        ladder: ladder,
        scene: _scene(_results[result]!),
      ).end;
      final chip = (want as Map<String, dynamic>)['chip'] as Map;
      expect(end.rows, isEmpty, reason: name);
      expect(end.chip!.opacity, _near(chip['opacity']), reason: name);
      expect(end.chip!.scale, _near(chip['scale']), reason: name);
      for (final row in (want['rows'] as List).cast<Map<String, dynamic>>()) {
        expect(row['opacity'], 0, reason: name);
      }
    }
  });

  group('the held scene matches the design', () {
    final scenes = _golden['scene'] as Map<String, dynamic>;
    for (final MapEntry(key: name, value: samples) in scenes.entries) {
      test(name, () {
        final noLayer = name.endsWith('noLayer');
        final scene = _scene(_results[name.split(' ').first]!, hold: !noLayer);
        for (final sample in (samples as List).cast<Map<String, dynamic>>()) {
          final t = (sample['tMs'] as num).toDouble();
          _expectScene(scene.at(t), sample, '$name $t');
          if (noLayer) expect(sample['chip'], isNull);
        }
      });
    }
  });

  test('a late chip comes in as the design\'s (0.8 with an overshoot)', () {
    for (final sample
        in (_golden['late'] as List).cast<Map<String, dynamic>>()) {
      final chip = sample['chip'] as Map<String, dynamic>?;
      if (chip == null) continue;
      final u = (chip['opacity'] as num).toDouble();
      expect(
        VictoryLadderScene.chipScaleAt(u),
        _near(chip['scale']),
        reason: '${sample['tMs']}',
      );
    }
  });

  group('the scene\'s times', () {
    final rig = VictoryRig.standard;
    test('with the hold: a win ends at 3.3 s, a loss and a draw at 3.2 s', () {
      expect(VictoryScene.endMsOf(rig, VictoryResult.koWin, hold: true), 3300);
      expect(
        VictoryScene.endMsOf(rig, VictoryResult.timeWin, hold: true),
        3300,
      );
      expect(
        VictoryScene.endMsOf(rig, VictoryResult.leftWin, hold: true),
        3300,
      );
      expect(VictoryScene.endMsOf(rig, VictoryResult.lose, hold: true), 3200);
      expect(VictoryScene.endMsOf(rig, VictoryResult.draw, hold: true), 3200);
      expect(_scene(VictoryResult.koWin).outFromMs, 2800);
      expect(_scene(VictoryResult.lose).outFromMs, 2700);
    });

    test('without it: 2.1 s and 2.0 s, and the way out reads the clock', () {
      expect(VictoryScene.endMsOf(rig, VictoryResult.koWin), 2100);
      expect(VictoryScene.endMsOf(rig, VictoryResult.draw), 2000);
      final scene = _scene(VictoryResult.koWin, hold: false);
      for (final t in [0.0, 900.0, 1600.0, 1800.0, 2099.0]) {
        expect(scene.heldTime(t), t);
        expect(scene.bandLiftAt(t), 0);
      }
    });

    test('the hold stops the way-out clock at the way out', () {
      final scene = _scene(VictoryResult.lose);
      expect(scene.heldTime(1400), 1400);
      expect(scene.heldTime(1500), 1500);
      expect(scene.heldTime(2699), 1500);
      expect(scene.heldTime(2700), 1500);
      expect(scene.heldTime(3000), 1800);
    });
  });

  group('on a screen', () {
    testWidgets('a confirmed ranking: the ladder plays in the hold, the '
        'scene ends at 3.3 s and the chip stays on the seat', (tester) async {
      final ladder = _viewModel('base', VictoryResult.koWin);
      addTearDown(ladder.dispose);
      var ended = 0;
      await _show(
        tester,
        _Report(
          result: VictoryResult.koWin,
          ladder: ladder,
          onEnd: () => ended++,
        ),
      );
      expect(find.text('펭귄짱'), findsNothing);
      await _play(tester, 1000);
      expect(ladder.path, LadderPath.confirmed);
      expect(find.text('펭귄짱'), findsOneWidget);
      // Mine comes in last, at 1.17 s.
      await _play(tester, 300);
      expect(find.text('쥐돌이'), findsOneWidget);
      expect(find.text(VictoryLadder.meWord), findsOneWidget);
      await _play(tester, 900);
      // Past the scene's old end: still playing.
      expect(ended, 0);
      expect(find.text('+10'), findsOneWidget);
      await _play(tester, 1200);
      expect(ended, 1);
      expect(find.text('펭귄짱'), findsNothing);
      // The chip on the seat: 2위, 29점, +10.
      expect(find.text('29'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);
      expect(
        find.bySemanticsLabel('주간 랭킹 2위, 이번 주 29점, 이번 판 10점'),
        findsOneWidget,
      );
    });

    testWidgets('a tap before 0.88 s skips to the end look with the chip', (
      tester,
    ) async {
      final ladder = _viewModel('base', VictoryResult.lose);
      addTearDown(ladder.dispose);
      var ended = 0;
      await _show(
        tester,
        _Report(
          result: VictoryResult.lose,
          ladder: ladder,
          onEnd: () => ended++,
        ),
      );
      await _play(tester, 400);
      await tester.tap(find.bySemanticsLabel(VictoryOverlay.skipLabel));
      await tester.pump();
      expect(ended, 1);
      expect(ladder.path, LadderPath.confirmed);
      expect(
        find.bySemanticsLabel('주간 랭킹 4위, 이번 주 20점, 이번 판 1점'),
        findsOneWidget,
      );
    });

    testWidgets('late: the scene as before, no rank drawn until the ranking '
        'is confirmed, then only the chip', (tester) async {
      // The first four reads have no battle: confirmed at 4 s.
      final ladder = _viewModel('base', VictoryResult.koWin, confirmedFrom: 5);
      addTearDown(ladder.dispose);
      var ended = 0;
      await _show(
        tester,
        _Report(
          result: VictoryResult.koWin,
          ladder: ladder,
          onEnd: () => ended++,
        ),
      );
      await _play(tester, 1500);
      expect(ladder.path, LadderPath.late);
      for (final rank in ['1', '2', '3', '4', '–']) {
        expect(find.text(rank), findsNothing);
      }
      expect(find.text('펭귄짱'), findsNothing);
      await _play(tester, 600);
      // Ended as the scene without the hold does.
      expect(ended, 1);
      expect(find.byType(VictoryRankChip), findsNothing);
      await _play(tester, 1900);
      expect(ladder.chip, isNotNull);
      // It comes in at once, over 0.22 s.
      expect(_chipOpacity(tester), 0);
      await _play(tester, 240);
      expect(_chipOpacity(tester), 1);
      expect(find.text('+10'), findsOneWidget);
      expect(
        find.bySemanticsLabel('주간 랭킹 2위, 이번 주 29점, 이번 판 10점'),
        findsOneWidget,
      );
      expect(ladder.holds, isFalse);
    });

    testWidgets('late but confirmed before the end: the chip comes in 0.3 s '
        'after the seat shows', (tester) async {
      // Confirmed at 2 s, after the path was chosen at 0.88 s.
      final ladder = _viewModel('base', VictoryResult.koWin, confirmedFrom: 4);
      addTearDown(ladder.dispose);
      await _show(tester, _Report(result: VictoryResult.koWin, ladder: ladder));
      await _play(tester, 2120);
      expect(ladder.path, LadderPath.late);
      expect(_chipOpacity(tester), 0);
      await _play(tester, 280);
      expect(_chipOpacity(tester), lessThan(0.2));
      await _play(tester, 260);
      expect(_chipOpacity(tester), 1);
    });

    testWidgets('across a week reset: no ladder and nothing of last week, '
        'then only the chip with the new week\'s values', (tester) async {
      final lastWeek = DateTime.utc(2026, 11, 22, 15);
      final thisWeek = DateTime.utc(2026, 11, 29, 15);
      final base = ScoreLadderCase.all['base']!;
      final mine = RankingEntry(
        rank: 7,
        userId: ScoreLadderCase.myId,
        nickname: ScoreLadderCase.myName,
        points: 10,
        battles: 1,
        wins: 1,
        koWins: 1,
        isMe: true,
      );
      final newWeek = WeeklyRanking(
        scope: RankingScope.global,
        weekStart: thisWeek,
        weekEnd: DateTime.utc(2026, 12, 6, 15),
        entries: [mine],
        me: mine,
      );
      final ladder = RankingLadderViewModel(
        repository: _Rankings(newWeek, newWeek),
        exercise: ExerciseType.pushUp,
        ranked: true,
        before: RankingSnapshot(
          weekStart: lastWeek,
          entries: base.before.entries,
          me: base.before.me,
        ),
        points: RankingPoints.koWin,
        elapsed: () => Duration.zero,
      )..load();
      addTearDown(ladder.dispose);
      var ended = 0;
      await _show(
        tester,
        _Report(
          result: VictoryResult.koWin,
          ladder: ladder,
          onEnd: () => ended++,
        ),
      );
      await _play(tester, 1500);
      expect(ladder.path, LadderPath.late);
      expect(find.text('펭귄짱'), findsNothing);
      await _play(tester, 1000);
      // The scene without the hold, then the chip: 7위, 10점, +10.
      expect(ended, 1);
      expect(
        find.bySemanticsLabel('주간 랭킹 7위, 이번 주 10점, 이번 판 10점'),
        findsOneWidget,
      );
      // Last week's rank and points are nowhere.
      expect(find.text('19'), findsNothing);
      expect(find.text('4'), findsNothing);
    });

    testWidgets('never confirmed: nothing is left', (tester) async {
      final ladder = _viewModel('base', VictoryResult.koWin, confirmedFrom: 0);
      addTearDown(ladder.dispose);
      await _show(tester, _Report(result: VictoryResult.koWin, ladder: ladder));
      await _play(tester, 7000);
      expect(ladder.chip, isNull);
      expect(find.text('+10'), findsNothing);
      expect(find.byType(VictoryRankChip), findsNothing);
    });

    testWidgets('reduced motion: the end look with the chip at once', (
      tester,
    ) async {
      final ladder = _viewModel('king', VictoryResult.koWin);
      addTearDown(ladder.dispose);
      await _show(
        tester,
        _Report(
          result: VictoryResult.koWin,
          ladder: ladder,
          reduceMotion: true,
          seatOnly: true,
        ),
      );
      expect(ladder.path, LadderPath.confirmed);
      expect(find.text('322'), findsOneWidget);
      expect(
        find.bySemanticsLabel('주간 랭킹 1위, 이번 주 322점, 이번 판 10점'),
        findsOneWidget,
      );
    });

    testWidgets('the seat without a ladder has no chip', (tester) async {
      await _show(
        tester,
        const _Report(result: VictoryResult.draw, seatOnly: true),
      );
      expect(find.byType(VictorySeatChip), findsNothing);
      expect(find.byType(VictoryRankChip), findsNothing);
    });

    testWidgets('the chip sits at the seat\'s top, in the middle, within '
        '140 x 26', (tester) async {
      final ladder = _viewModel('big', VictoryResult.koWin);
      addTearDown(ladder.dispose);
      await _show(
        tester,
        _Report(
          result: VictoryResult.koWin,
          ladder: ladder,
          reduceMotion: true,
          seatOnly: true,
        ),
      );
      final chip = tester.getRect(find.byType(VictoryRankChip));
      expect(chip.top, greaterThanOrEqualTo(designSeat.dy + 4 - 0.01));
      expect(chip.bottom, lessThanOrEqualTo(designSeat.dy + 30 + 0.01));
      expect(chip.width, lessThanOrEqualTo(140 + 0.01));
      expect(
        chip.center.dx,
        closeTo(designSeat.dx + VictoryOverlay.seatSize.width / 2, 0.5),
      );
      expect(find.text('803'), findsOneWidget);
    });

    for (final (name, size, scale) in [
      ('360 x 780, text x1.3', const Size(360, 780), 1.3),
      ('320 x 640', const Size(320, 640), 1.0),
    ]) {
      for (final (sc, result) in [
        ('big', VictoryResult.koWin),
        ('king', VictoryResult.koWin),
        ('top', VictoryResult.timeWin),
      ]) {
        testWidgets('$sc ${result.name} fits $name', (tester) async {
          final ladder = _viewModel(sc, result);
          addTearDown(ladder.dispose);
          await _show(
            tester,
            _Report(
              result: result,
              ladder: ladder,
              textScale: scale,
              seat: Offset(
                size.width - 16 - VictoryOverlay.seatSize.width,
                designSeat.dy,
              ),
            ),
            size: size,
          );
          for (var t = 0; t < 3400; t += 100) {
            await _play(tester, 100);
            expect(tester.takeException(), isNull, reason: '$t ms');
          }
          final chip = tester.getRect(find.byType(VictoryRankChip));
          expect(chip.width, lessThanOrEqualTo(140 + 0.01));
          expect(chip.height, lessThanOrEqualTo(26 + 0.01));
          expect(chip.right, lessThanOrEqualTo(size.width));
        });
      }
    }

    testWidgets('the ladder is decoration: screen readers skip it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final ladder = _viewModel('base', VictoryResult.koWin);
      addTearDown(ladder.dispose);
      await _show(tester, _Report(result: VictoryResult.koWin, ladder: ladder));
      await _play(tester, 1500);
      expect(find.text('펭귄짱'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('펭귄짱')), findsNothing);
      handle.dispose();
    });
  });

  testWidgets('a chip wider than 140 is made smaller to fit', (tester) async {
    tester.view
      ..physicalSize = designSize
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final values = (rank: 1204, points: 1234, gained: 10);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Center(child: VictoryRankChip(values: values)),
      ),
    );
    final chip = tester.getRect(find.byType(VictoryRankChip));
    expect(chip.width, lessThanOrEqualTo(140 + 0.01));
    expect(chip.height, lessThanOrEqualTo(26 + 0.01));
    expect(tester.takeException(), isNull);
    // It was wider: the fit scaled it down.
    final fit = tester.getSize(find.byType(FittedBox));
    final inside = tester.getSize(
      find
          .descendant(of: find.byType(FittedBox), matching: find.byType(Row))
          .first,
    );
    expect(inside.width, greaterThan(fit.width));
    expect(find.text('1,204'), findsOneWidget);
    expect(find.text('1,234'), findsOneWidget);
  });

  for (final (sc, result, rank) in [
    ('base', VictoryResult.lose, '4'),
    ('mid', VictoryResult.koWin, '20'),
    ('big', VictoryResult.koWin, '1,204'),
  ]) {
    testWidgets('$sc: the rank cell draws its digits at the cell\'s size', (
      tester,
    ) async {
      final ladder = _ladder(sc, result);
      final frame = VictoryLadderScene(
        ladder: ladder,
        scene: _scene(result),
      ).at(1000);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Center(
            child: VictoryLadderRow(frame: frame.rows.last, ladder: ladder),
          ),
        ),
      );
      final digits = tester.widget<Text>(find.text(rank));
      expect(digits.style!.fontSize, ladder.rankCellText);
      expect(digits.style!.color, AppColors.accent);
      expect(
        tester.getSize(find.byType(VictoryLadderRow)),
        const Size(VictoryLadder.rowWidth, VictoryLadder.rowHeight),
      );
    });
  }

  test('chipLabel reads rank, week and battle in one sentence', () {
    expect(
      VictoryLadder.chipLabel((rank: 1204, points: 3, gained: 10)),
      '주간 랭킹 1,204위, 이번 주 3점, 이번 판 10점',
    );
    expect(VictoryLadder.gainText(5), '+5');
  });

  test('a ladder row is first place only for another player at rank 1', () {
    final ladder = _ladder('top', VictoryResult.timeWin);
    final frame = VictoryLadderScene(
      ladder: ladder,
      scene: _scene(VictoryResult.timeWin),
    ).at(2000);
    expect(
      [for (final row in frame.rows) (row.row.nickname, row.first)],
      [('펭귄짱', true), ('헬스쿼카', false), ('그루맨', false), ('쥐돌이', false)],
    );
    expect(frame.rows.last.rank, '1');
  });
}
