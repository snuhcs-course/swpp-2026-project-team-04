import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/battle_rules.dart';
import 'package:gymrats_app/models/character_idle_motion.dart';
import 'package:gymrats_app/models/character_rig.dart';
import 'package:gymrats_app/models/game_score.dart';
import 'package:gymrats_app/models/rep_event.dart';
import 'package:gymrats_app/widgets/battle_fx_motion.dart';
import 'package:gymrats_app/widgets/battle_stage_model.dart';

/// The design prototype's own output (FxA, spec v2.2), sampled at fixed
/// times: 18 scenarios, 248 samples. `t` counts from the scenario's event;
/// the stage was made 1000 ms before it.
///
/// Compared in every sample: the meeting point, both fighters, the tags, the
/// shake and zoom, the star, twinkle, puff, sign, the bands (in the order
/// they are drawn, with their band sizes), the combo marks, the bumps, the
/// fever and danger opacities, the chip and the result button. Not compared:
/// `hud.clock` and the time bar (the design's own demo values). The scores
/// and rep counts are inputs: the game
/// gives them to the stage, so here they pick the chip's words and whether a
/// score has three digits. Each scenario's `after` is checked against how
/// the scenario was played.
const _goldenPath = 'test/widgets/battle_fx_golden.json';

/// The stage clock at a sample's `t = 0`.
const _eventAt = 1000.0;

/// One thing that happens in a scenario, [at] on the stage clock.
typedef _Step = ({
  double at,
  void Function(BattleFxTimeline fx, double now) run,
});

double _share(int lead) => battleRules.barShare(lead);

BattleStageEvent _rep(
  BattleSide side,
  GameGrade? grade, {
  int points = 0,
  int combo = 0,
  bool fever = false,
  RejectReason? reason,
  bool knockout = false,
}) => BattleStageEvent(
  side: side,
  grade: grade,
  points: points,
  combo: combo,
  fever: fever,
  reason: reason,
  knockout: knockout,
);

_Step _at(double t, void Function(BattleFxTimeline fx, double now) run) =>
    (at: _eventAt + t, run: run);

/// How a golden scenario is played: the standing when the stage was made,
/// whether fever is on and the reconnect band up at the end, and the
/// scenario's events. The scores come from the game in the app; here they
/// are the scenario's own.
class _Play {
  const _Play({
    this.leadBefore = 0,
    this.scoresBefore = (0, 0),
    this.fever = false,
    this.reconnecting = false,
    required this.steps,
  });

  final int leadBefore;
  final (int, int) scoresBefore;
  final bool fever;
  final bool reconnecting;
  final List<_Step> steps;
}

/// A rep of [event] at [t], with the scores and the share it leaves.
_Step _scored(double t, int mine, int theirs, BattleStageEvent event) =>
    _at(t, (fx, now) {
      fx
        ..setShare(_share(mine - theirs), now)
        ..setScores(mine, theirs)
        ..rep(event, now);
    });

final _scenarios = <String, _Play>{
  'my_good': _Play(
    steps: [
      _scored(
        0,
        10,
        0,
        _rep(BattleSide.me, GameGrade.good, points: 10, combo: 1),
      ),
    ],
  ),
  'my_excellent_combo': _Play(
    steps: [
      _scored(
        -1000,
        10,
        0,
        _rep(BattleSide.me, GameGrade.good, points: 10, combo: 1),
      ),
      _scored(
        0,
        30,
        0,
        _rep(BattleSide.me, GameGrade.excellent, points: 20, combo: 2),
      ),
    ],
  ),
  'my_average': _Play(
    steps: [
      _scored(
        0,
        5,
        0,
        _rep(
          BattleSide.me,
          GameGrade.average,
          points: 5,
          reason: RejectReason.insufficientDepth,
        ),
      ),
    ],
  ),
  'my_reject': _Play(
    steps: [
      _scored(
        0,
        0,
        0,
        _rep(BattleSide.me, null, reason: RejectReason.kneesDown),
      ),
    ],
  ),
  'opponent_good': _Play(
    steps: [
      _scored(
        0,
        0,
        10,
        _rep(BattleSide.opponent, GameGrade.good, points: 10, combo: 1),
      ),
    ],
  ),
  'combo_while_reconnecting': _Play(
    leadBefore: 15,
    scoresBefore: (60, 45),
    reconnecting: true,
    steps: [
      // The file's meeting point is still at 60 : 45 when the second Good
      // comes (x 195 at t = 0): its script gave the first Good's points
      // without moving the bar. So here the first Good moves only the
      // scores; the bar follows the second.
      _at(-1000, (fx, now) {
        fx
          ..setScores(70, 45)
          ..rep(_rep(BattleSide.me, GameGrade.good, points: 10, combo: 1), now);
      }),
      _scored(
        0,
        85,
        45,
        _rep(BattleSide.me, GameGrade.good, points: 15, combo: 2),
      ),
    ],
  ),
  'score_bump_three_digits': _Play(
    leadBefore: -65,
    scoresBefore: (245, 310),
    steps: [
      _at(0, (fx, now) => fx.danger = battleRules.inDanger(255 - 310)),
      _scored(
        0,
        255,
        310,
        _rep(BattleSide.me, GameGrade.good, points: 10, combo: 1),
      ),
    ],
  ),
  'both_words_overlap': _Play(
    steps: [
      _scored(
        -100,
        0,
        10,
        _rep(BattleSide.opponent, GameGrade.good, points: 10, combo: 1),
      ),
      _scored(
        0,
        10,
        10,
        _rep(BattleSide.me, GameGrade.good, points: 10, combo: 1),
      ),
    ],
  ),
  'valid_count_bump': _Play(
    leadBefore: 15,
    scoresBefore: (60, 45),
    steps: [
      _scored(
        0,
        70,
        45,
        _rep(BattleSide.me, GameGrade.good, points: 10, combo: 1),
      ),
    ],
  ),
  'fever_then_good': _Play(
    fever: true,
    steps: [
      _at(0, (fx, now) => fx.setFever(true, now)),
      _scored(
        1600,
        20,
        0,
        _rep(BattleSide.me, GameGrade.good, points: 20, combo: 1, fever: true),
      ),
    ],
  ),
  'danger': _Play(
    steps: [
      _at(0, (fx, now) => fx.danger = battleRules.inDanger(-65)),
      _scored(
        0,
        0,
        65,
        _rep(BattleSide.opponent, GameGrade.good, points: 10, combo: 1),
      ),
    ],
  ),
  'ko_win': _Play(
    steps: [
      _scored(
        0,
        100,
        0,
        _rep(
          BattleSide.me,
          GameGrade.excellent,
          points: 15,
          combo: 1,
          knockout: battleRules.isKo(100),
        ),
      ),
    ],
  ),
  'ko_lose': _Play(
    steps: [
      _at(0, (fx, now) => fx.danger = battleRules.inDanger(-100)),
      _scored(
        0,
        0,
        100,
        _rep(
          BattleSide.opponent,
          GameGrade.good,
          points: 10,
          combo: 1,
          knockout: battleRules.isKo(-100),
        ),
      ),
    ],
  ),
  'time_up_win': _Play(
    scoresBefore: (155, 150),
    steps: [
      _at(0, (fx, now) {
        fx
          ..setShare(_share(5), now)
          ..finish(
            const BattleStageEnd(
              kind: BattleEndKind.timeUp,
              winner: BattleSide.me,
            ),
            now,
          );
      }),
    ],
  ),
  'opponent_left': _Play(
    leadBefore: 15,
    scoresBefore: (60, 45),
    steps: [
      _at(0, (fx, now) {
        fx.finish(
          const BattleStageEnd(
            kind: BattleEndKind.playerLeft,
            winner: BattleSide.me,
          ),
          now,
        );
      }),
    ],
  ),
  'opponent_disconnected': _Play(
    leadBefore: 15,
    scoresBefore: (60, 45),
    steps: [_at(0, (fx, now) => fx.opponentGone = true)],
  ),
  'pre_setup_then_waiting': _Play(
    steps: [
      _at(0, (fx, now) => fx.setSetup(active: true, opponentReady: true)),
      _at(1000, (fx, now) => fx.setSetup(active: true, meReady: true)),
    ],
  ),
  'countdown_go': _Play(steps: [_at(0, (fx, now) => fx.countDown(3000, now))]),
};

const _poses = {
  'idle': BattlePose.idle,
  'atk': BattlePose.attack,
  'hit': BattlePose.hit,
  'ko': BattlePose.knockedOut,
  'win': BattlePose.win,
};

/// The design's fills as the tones the widgets turn into theme colors.
const _tones = {
  '#C6FF3D': BattleFxTone.me,
  '#FF4F81': BattleFxTone.opponent,
  '#FFFFFF': BattleFxTone.plain,
  '#FFB547': BattleFxTone.average,
  '#3DE8FF': BattleFxTone.fever,
  '#FF3B30': BattleFxTone.danger,
};

const _comboSides = {'me': BattleSide.me, 'opponent': BattleSide.opponent};

const _fonts = {'number': BattleFxFont.number, 'display': BattleFxFont.display};

/// Compares one frame with one golden sample and collects what differs.
class _Check {
  _Check(this.where, Map<String, dynamic> tolerance)
    : position = (tolerance['position'] as num).toDouble(),
      rotation = (tolerance['rot'] as num).toDouble(),
      scale = (tolerance['scale'] as num).toDouble(),
      opacity = (tolerance['opacity'] as num).toDouble();

  final String where;
  final double position;
  final double rotation;
  final double scale;
  final double opacity;
  final problems = <String>[];

  void near(String what, num actual, dynamic expected, double tolerance) {
    final want = (expected as num).toDouble();
    if ((actual - want).abs() > tolerance + 1e-9) {
      problems.add('$where $what: $actual, golden $want');
    }
  }

  void same(String what, Object? actual, Object? expected) {
    if (actual != expected) {
      problems.add('$where $what: $actual, golden $expected');
    }
  }

  /// Whether both are there, so their fields can be compared. A thing that
  /// fades ([faded] is its opacity) may be missing on one side once it is
  /// within the opacity tolerance of gone; anything else must be on both
  /// sides or on neither.
  bool both(String what, Object? actual, dynamic expected, double? faded) {
    if (actual != null && expected != null) return true;
    final gone = faded != null && faded <= opacity;
    if (!(actual == null && expected == null) && !gone) {
      problems.add('$where $what: ${actual == null ? 'missing' : 'extra'}');
    }
    return false;
  }

  void fighter(String who, BattleFxFighter f, Map<String, dynamic> g) {
    same('$who pose', f.pose, _poses[g['pose']]);
    near('$who footX', f.footX, g['footX'], position);
    near('$who footY', f.footY, g['footY'], position);
    near('$who rot', f.rotation, g['rot'], rotation);
    near('$who scaleX', f.scaleX, g['scaleX'], scale);
    near('$who scaleY', f.scaleY, g['scaleY'], scale);
    near('$who opacity', f.opacity, g['opacity'], opacity);
    same('$who flash', f.flash, g['flash']);
    same('$who glow', f.glow, g['glow']);
    same('$who front', f.front, g['front']);
  }

  void tag(String who, BattleFxTag? t, Map<String, dynamic>? g) {
    if (!both('$who tag', t, g, null)) return;
    same('$who tag text', t!.text, g!['text']);
    same('$who tag fill', t.tone, _tones[g['fill']]);
    near('$who tag cx', t.centerX, g['cx'], position);
  }

  /// The bands in the order they are drawn: a later one goes over an
  /// earlier one, so the order is part of the design (the user's band over
  /// the opponent's).
  void banners(List<BattleFxBanner> actual, List<dynamic> golden) {
    final shown = [
      for (final b in actual)
        if (b.opacity > opacity) b,
    ];
    final wanted = [
      for (final g in golden.cast<Map<String, dynamic>>())
        if ((g['opacity'] as num) > opacity) g,
    ];
    same(
      'bands',
      shown.map((b) => b.text).join(' | '),
      wanted.map((g) => g['text']).join(' | '),
    );
    if (shown.length != wanted.length) return;
    for (var i = 0; i < wanted.length; i++) {
      final g = wanted[i];
      final b = shown[i];
      final text = b.text;
      same('band "$text" font', b.font, _fonts[g['font']]);
      near('band "$text" top', b.top, g['top'], position);
      near('band "$text" size', b.textSize, g['fontSize'], position);
      near('band "$text" height', b.bandHeight, g['bandHeight'], position);
      near('band "$text" padX', b.padX, g['padX'], position);
      same('band "$text" fill', b.tone, _tones[g['band']]);
      same('band "$text" align', 'center', g['align']);
      near(
        'band "$text" opacity',
        b.opacity.clamp(0, 1),
        g['opacity'],
        opacity,
      );
      near('band "$text" dx', b.dx, g['dx'], position);
      near('band "$text" dy', b.dy, g['dy'], position);
      near('band "$text" rot', b.rotation, g['rot'], rotation);
      near('band "$text" scaleX', b.scaleX, g['scaleX'], scale);
      near('band "$text" scaleY', b.scaleY, g['scaleY'], scale);
    }
  }

  /// The combo marks, the opponent's first. Their place comes from
  /// [BattleFx.comboTop] and the side; the band is a plain number band.
  void combos(
    List<BattleFxCombo> actual,
    List<dynamic> golden, {
    required bool reconnecting,
  }) {
    final shown = [
      for (final c in actual)
        if (c.opacity > opacity) c,
    ];
    final wanted = [
      for (final g in golden.cast<Map<String, dynamic>>())
        if ((g['opacity'] as num) > opacity) g,
    ];
    same(
      'combos',
      shown.map((c) => '${c.side.name} ${c.text}').join(' | '),
      wanted
          .map((g) => '${_comboSides[g['side']]!.name} ${g['text']}')
          .join(' | '),
    );
    if (shown.length != wanted.length) return;
    final box = BattleFx.bandBox(BattleFx.comboTextSize);
    for (var i = 0; i < wanted.length; i++) {
      final g = wanted[i];
      final c = shown[i];
      final what = 'combo "${c.text}"';
      same('$what font', 'number', g['font']);
      near(
        '$what top',
        BattleFx.comboTop(reconnecting: reconnecting),
        g['top'],
        position,
      );
      near('$what size', BattleFx.comboTextSize, g['fontSize'], position);
      near('$what height', box.height, g['bandHeight'], position);
      near('$what padX', box.padX, g['padX'], position);
      same('$what fill', BattleFxTone.plain, _tones[g['band']]);
      same(
        '$what align',
        c.side == BattleSide.me ? 'left' : 'right',
        g['align'],
      );
      near('$what opacity', c.opacity, g['opacity'], opacity);
      near('$what dx', 0, g['dx'], position);
      near('$what dy', 0, g['dy'], position);
      near('$what rot', c.rotation, g['rot'], rotation);
      near('$what scaleX', c.scaleX, g['scaleX'], scale);
      near('$what scaleY', c.scaleY, g['scaleY'], scale);
    }
  }

  void frame(
    BattleFxFrame f,
    Map<String, dynamic> g, {
    required bool fever,
    required bool reconnecting,
  }) {
    near('xm', f.meetX, g['xm'], position);
    fighter('me', f.me, g['me'] as Map<String, dynamic>);
    fighter('op', f.opponent, g['op'] as Map<String, dynamic>);
    tag('me', f.myTag, g['meTag'] as Map<String, dynamic>?);
    tag('op', f.opponentTag, g['opTag'] as Map<String, dynamic>?);

    final stage = g['stage'] as Map<String, dynamic>;
    near('shake dx', f.shakeX, stage['dx'], position);
    near('shake dy', f.shakeY, stage['dy'], position);
    near('zoom', f.zoom, stage['zoom'], scale);
    near('zoom origin', f.meetX, stage['originX'], position);

    final star = g['star'] as Map<String, dynamic>?;
    if (both('star', f.star, star, f.star?.opacity ?? star?['opacity'])) {
      near('star cx', f.star!.centerX, star!['cx'], position);
      near('star cy', f.star!.centerY, star['cy'], position);
      near('star rot', f.star!.rotation, star['rot'], rotation);
      near('star diameter', f.star!.diameter, star['diameter'], position);
      near('star opacity', f.star!.opacity, star['opacity'], opacity);
    }
    final twinkle = g['twinkle'] as Map<String, dynamic>?;
    if (both(
      'twinkle',
      f.twinkle,
      twinkle,
      f.twinkle?.opacity ?? twinkle?['opacity'],
    )) {
      near('twinkle cx', f.twinkle!.centerX, twinkle!['cx'], position);
      near('twinkle cy', f.twinkle!.centerY, twinkle['cy'], position);
      near('twinkle rot', f.twinkle!.rotation, twinkle['rot'], rotation);
      near('twinkle scale', f.twinkle!.scale, twinkle['scale'], scale);
      near('twinkle opacity', f.twinkle!.opacity, twinkle['opacity'], opacity);
    }
    final puff = g['puff'] as Map<String, dynamic>?;
    if (both('puff', f.puff, puff, f.puff?.opacity ?? puff?['opacity'])) {
      near('puff cx', f.puff!.centerX, puff!['cx'], position);
      near('puff cy', f.puff!.centerY, puff['cy'], position);
      near('puff scale', f.puff!.scale, puff['scale'], scale);
      near('puff opacity', f.puff!.opacity, puff['opacity'], opacity);
    }
    final sign = g['sign'] as Map<String, dynamic>?;
    if (both('sign', f.sign, sign, f.sign?.opacity ?? sign?['opacity'])) {
      same('sign icon', f.sign!.reason.signIcon, sign!['reason']);
      same('sign text', f.sign!.text, sign['text']);
      same('sign band', f.sign!.tone, _tones[sign['band']]);
      near('sign scale', f.sign!.scale, sign['scale'], scale);
      near('sign rot', f.sign!.rotation, sign['rot'], rotation);
      near('sign opacity', f.sign!.opacity, sign['opacity'], opacity);
    }
    banners(f.banners, g['banners'] as List<dynamic>);
    combos(f.combos, g['combos'] as List<dynamic>, reconnecting: reconnecting);

    final hud = g['hud'] as Map<String, dynamic>;
    near('my score bump', f.myScoreBump, hud['myBump'], scale);
    near(
      'opponent score bump',
      f.opponentScoreBump,
      hud['opponentBump'],
      scale,
    );
    near('my reps bump', f.myRepsBump, hud['myRepsBump'], scale);
    near(
      'opponent reps bump',
      f.opponentRepsBump,
      hud['opponentRepsBump'],
      scale,
    );
    near('fever', f.feverOpacity, hud['feverOpacity'], opacity);
    near('danger', f.dangerOpacity, hud['dangerOpacity'], opacity);
    final chip = BattleFx.chip(
      lead: (hud['myScore'] as int) - (hud['opponentScore'] as int),
      fever: fever,
      beforeStart: f.beforeStart,
    );
    same('chip', chip?.text, hud['chip']);
    same('chip fill', chip?.tone, _tones[hud['chipBg']]);

    final button = g['resultButton'] as Map<String, dynamic>?;
    if (both('result button', f.resultButton, button, null)) {
      near(
        'button opacity',
        f.resultButton!.opacity,
        button!['opacity'],
        opacity,
      );
      near('button scale', f.resultButton!.scale, button['scale'], scale);
      near('button scrim', f.resultButton!.scrim, button['scrim'], opacity);
    }
  }
}

const _endKinds = {
  'ko': BattleEndKind.knockout,
  'time': BattleEndKind.timeUp,
  'left': BattleEndKind.playerLeft,
};

const _sides = {'me': BattleSide.me, 'op': BattleSide.opponent};

BattleStageEvent _good(
  BattleSide side, {
  int combo = 1,
  bool knockout = false,
}) => _rep(side, GameGrade.good, points: 10, combo: combo, knockout: knockout);

void main() {
  final golden =
      jsonDecode(File(_goldenPath).readAsStringSync()) as Map<String, dynamic>;
  final meta = golden['meta'] as Map<String, dynamic>;
  final scenarios = (golden['scenarios'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  group('against the design prototype (fx_golden.json)', () {
    test('the file is the one the checks were written for', () {
      expect(meta['version'], '2.2');
      expect(meta['startMs'], _eventAt);
      expect(scenarios, hasLength(18));
      expect(
        scenarios.fold<int>(0, (n, s) => n + (s['samples'] as List).length),
        248,
      );
      expect(scenarios.map((s) => s['name']).toSet(), _scenarios.keys.toSet());
    });

    for (final scenario in scenarios) {
      final name = scenario['name'] as String;
      test('$name: every sample matches within the design tolerance', () {
        final play = _scenarios[name]!;
        final fx = BattleFxTimeline(share: _share(play.leadBefore))
          ..setScores(play.scoresBefore.$1, play.scoresBefore.$2);
        final steps = [...play.steps]..sort((a, b) => a.at.compareTo(b.at));
        final samples = (scenario['samples'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final problems = <String>[];
        var next = 0;
        for (final sample in samples) {
          final now = _eventAt + (sample['t'] as num);
          while (next < steps.length && steps[next].at <= now) {
            steps[next].run(fx, steps[next].at);
            next += 1;
          }
          final check =
              _Check(
                '$name t=${sample['t']}',
                meta['tolerance'] as Map<String, dynamic>,
              )..frame(
                fx.frame(now),
                sample,
                fever: play.fever,
                reconnecting: play.reconnecting,
              );
          problems.addAll(check.problems);
        }
        expect(next, steps.length, reason: 'every step was played');
        expect(problems, isEmpty, reason: problems.join('\n'));

        // The scenario was played to the scores and the ending the file
        // says it has afterwards.
        final after = scenario['after'] as Map<String, dynamic>;
        final lead =
            (after['myScore'] as int) - (after['opponentScore'] as int);
        expect(
          fx.frame(_eventAt + 60000).meetX,
          closeTo(BattleFx.meetX(_share(lead)), 1e-6),
          reason: 'the meeting point settles where a lead of $lead puts it',
        );
        expect(after['fever'], play.fever);
        final end = after['end'] as Map<String, dynamic>?;
        expect(fx.end?.kind, _endKinds[end?['kind']]);
        expect(fx.end?.winner, _sides[end?['win']]);
      });
    }
  });

  group('curves', () {
    test('seg runs from 0 at a to 1 at b and stays there outside', () {
      expect(BattleFx.seg(0, 10, 20), 0);
      expect(BattleFx.seg(15, 10, 20), 0.5);
      expect(BattleFx.seg(99, 10, 20), 1);
    });

    test('easeOut and back start at 0, end at 1, and back overshoots', () {
      expect(BattleFx.easeOut(0), 0);
      expect(BattleFx.easeOut(1), 1);
      expect(BattleFx.easeOut(2), 1);
      expect(BattleFx.easeOut(0.5), 0.875);
      expect(BattleFx.back(0), closeTo(0, 1e-9));
      expect(BattleFx.back(1), 1);
      expect(BattleFx.back(0.8), greaterThan(1));
    });

    test('a pop is half size at first, full for its middle, gone after', () {
      expect(BattleFx.pop(-1, 700), isNull);
      expect(BattleFx.pop(0, 700)!.scale, closeTo(0.5, 1e-9));
      expect(BattleFx.pop(300, 700), (scale: 1.0, opacity: 1.0));
      expect(BattleFx.pop(640, 700)!.opacity, 0.5);
      expect(BattleFx.pop(701, 700), isNull);
    });

    test('a harder blow stops longer, shakes more and has a bigger star', () {
      final powers = [
        BattleFx.powerOf(GameGrade.average),
        BattleFx.powerOf(GameGrade.good),
        BattleFx.powerOf(GameGrade.excellent),
      ];
      expect(powers, [0.5, 1, 1.6]);
      expect(BattleFx.powerOf(null), 0);
      expect(powers.map(BattleFx.hitStop), [40, 90, 120]);
      expect(powers.map(BattleFx.shakeSize), [1.5, 4.5, 11]);
      expect(powers.map(BattleFx.starSize), [42, 84, 130]);
      expect(BattleFx.shakeSize(2.4), 16);
      expect(BattleFx.starSize(2.4), 170);
    });

    test('the meeting point puts the loser on the bar end at a KO lead', () {
      expect(BattleFx.meetX(battleRules.barShare(0)), 180);
      expect(
        BattleFx.meetX(battleRules.barShare(battleRules.koLead)) +
            BattleFx.reach,
        336,
      );
      expect(
        BattleFx.meetX(battleRules.barShare(-battleRules.koLead)) -
            BattleFx.reach,
        24,
      );
    });
  });

  group('the chip beside the clock', () {
    test('says who leads by how much, level, or fever', () {
      ({String text, BattleFxTone tone})? chip(
        int lead, {
        bool fever = false,
      }) => BattleFx.chip(lead: lead, fever: fever, beforeStart: false);
      expect(chip(15), (text: '+15 앞섬', tone: BattleFxTone.me));
      expect(chip(-65), (text: '−65 추격 중', tone: BattleFxTone.opponent));
      expect(chip(0), (text: '동점', tone: BattleFxTone.plain));
      expect(chip(15, fever: true), (
        text: 'FEVER ×2',
        tone: BattleFxTone.fever,
      ));
    });

    test('is hidden before the start, and takes the rules\' multiplier', () {
      expect(BattleFx.chip(lead: 0, fever: false, beforeStart: true), isNull);
      expect(
        BattleFx.chip(
          lead: 0,
          fever: true,
          beforeStart: false,
          feverMultiplier: 3,
        )!.text,
        'FEVER ×3',
      );
    });
  });

  group('grade words and points (spec v2.1)', () {
    List<String> texts(BattleFxTimeline fx, double now) =>
        fx.frame(now).banners.map((b) => b.text).toList();

    test('the word comes as the blow lands, its points follow and overlap '
        'it for 50 ms', () {
      final fx = BattleFxTimeline()..rep(_good(BattleSide.me), 0);
      expect(texts(fx, 79), isEmpty);
      expect(texts(fx, 80), ['GOOD']);
      expect(texts(fx, 429), ['GOOD']);
      expect(texts(fx, 460), ['GOOD', '+10']);
      expect(texts(fx, 481), ['+10']);
      // Faded out over its last 120 ms: gone at its very end.
      expect(texts(fx, 80 + 350 + 870), ['+10']);
      expect(texts(fx, 80 + 350 + 880), isEmpty);
    });

    test('Excellent is the largest and stays the longest', () {
      final fx = BattleFxTimeline()
        ..rep(
          _rep(BattleSide.me, GameGrade.excellent, points: 20, combo: 2),
          0,
        );
      final word = fx.frame(300).banners.single;
      expect((word.text, word.textSize, word.top), ('EXCELLENT', 84, 153));
      expect(word.scaleX, closeTo(0.54, 1e-9));
      expect(texts(fx, 80 + 469), ['EXCELLENT']);
      expect(texts(fx, 80 + 500), ['EXCELLENT', '+20']);
      expect(texts(fx, 80 + 521), ['+20']);
      final points = fx.frame(80 + 700).banners.single;
      expect((points.textSize, points.top, points.dx), (104, 152, 34));
    });

    test('an average rep: amber AVERAGE, then a smaller amber +5', () {
      final fx = BattleFxTimeline()
        ..rep(
          _rep(
            BattleSide.me,
            GameGrade.average,
            points: 5,
            reason: RejectReason.insufficientDepth,
          ),
          0,
        );
      final word = fx.frame(300).banners.single;
      expect(
        (word.text, word.tone, word.textSize),
        ('AVERAGE', BattleFxTone.average, 48),
      );
      expect(word.scaleX, closeTo(0.68, 1e-9));
      final points = fx.frame(800).banners.single;
      expect(
        (points.text, points.tone, points.textSize, points.top),
        ('+5', BattleFxTone.average, 72, 165),
      );
      expect(texts(fx, 80 + 350 + 710), ['+5']);
      expect(texts(fx, 80 + 350 + 720), isEmpty);
    });

    test('the opponent\'s are pink and lean and move the other way; '
        'their average is amber too', () {
      final good = BattleFxTimeline()..rep(_good(BattleSide.opponent), 0);
      final word = good.frame(300).banners.single;
      expect((word.tone, word.rotation), (BattleFxTone.opponent, 4));
      final points = good.frame(700).banners.single;
      expect(
        (points.tone, points.rotation, points.dx),
        (BattleFxTone.opponent, 4, -34),
      );
      final average = BattleFxTimeline()
        ..rep(_rep(BattleSide.opponent, GameGrade.average, points: 5), 0);
      expect(average.frame(300).banners.single.tone, BattleFxTone.average);
      expect(average.frame(300).sign, isNull);
    });

    test('my word leans the other way from theirs and is drawn over it', () {
      final fx = BattleFxTimeline()
        ..rep(_good(BattleSide.opponent), 0)
        ..rep(_good(BattleSide.me), 100);
      final bands = fx.frame(300).banners;
      expect(bands.map((b) => (b.text, b.tone)), [
        ('GOOD', BattleFxTone.opponent),
        ('GOOD', BattleFxTone.me),
      ]);
      expect(bands.map((b) => b.rotation), [4, -4]);
    });

    test('the points are the rep\'s own: combo and fever included', () {
      final fx = BattleFxTimeline()
        ..rep(
          _rep(
            BattleSide.me,
            GameGrade.good,
            points: 30,
            combo: 2,
            fever: true,
          ),
          0,
        );
      expect(texts(fx, 700), ['+30']);
    });

    test('the next rep of the same side takes its bands down at once', () {
      final fx = BattleFxTimeline()..rep(_good(BattleSide.me), 0);
      expect(texts(fx, 499), ['+10']);
      fx.rep(_good(BattleSide.me, combo: 2), 500);
      expect(texts(fx, 500), isEmpty);
      expect(texts(fx, 580), ['GOOD']);
      // The other side's bands stay.
      final both = BattleFxTimeline()
        ..rep(_good(BattleSide.opponent), 0)
        ..rep(_good(BattleSide.me), 500);
      expect(texts(both, 520), ['+10']);
    });

    test('a miss takes the same side\'s word and points down at once and '
        'shows its own MISS; a second miss replaces the first', () {
      final fx = BattleFxTimeline()..rep(_good(BattleSide.me), 0);
      expect(texts(fx, 599), ['+10']);
      fx.rep(_rep(BattleSide.me, null, reason: RejectReason.kneesDown), 600);
      expect(texts(fx, 600), isEmpty);
      expect(texts(fx, 720), ['MISS']);
      fx.rep(_rep(BattleSide.me, null, reason: RejectReason.phoneMoved), 1600);
      expect(texts(fx, 1600), isEmpty);
      expect(texts(fx, 1720), ['MISS']);
      expect(fx.frame(1720).banners.single.scaleY, lessThan(1));
    });

    test('a time-up or a player leaving lets the bands play out; only a '
        'knockout clears them', () {
      final timeUp = BattleFxTimeline()
        ..rep(_good(BattleSide.me), 0)
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.timeUp,
            winner: BattleSide.me,
          ),
          500,
        );
      expect(texts(timeUp, 900), ['+10', 'TIME!']);
      final left = BattleFxTimeline()
        ..rep(_good(BattleSide.me), 0)
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.playerLeft,
            winner: BattleSide.me,
          ),
          500,
        );
      expect(texts(left, 1000), ['+10', '상대가 나가서 이겼어요']);
    });

    test('a knockout takes the blow\'s bands down 300 ms after it lands', () {
      final fx = BattleFxTimeline()
        ..rep(_good(BattleSide.me, knockout: true), 0);
      expect(texts(fx, 80 + 300), ['GOOD']);
      expect(texts(fx, 80 + 301), isEmpty);
    });
  });

  group('reps', () {
    test(
      'the opponent\'s miss swings and shows MISS on their side, no sign',
      () {
        final fx = BattleFxTimeline()..rep(_rep(BattleSide.opponent, null), 0);
        final frame = fx.frame(200);
        expect(frame.opponent.pose, BattlePose.attack);
        expect(frame.opponent.rotation, lessThan(0));
        expect(frame.me.pose, BattlePose.idle);
        expect(frame.sign, isNull);
        final miss = frame.banners.single;
        expect(miss.text, 'MISS');
        expect(miss.dx, 56);
        expect(miss.rotation, -7);
      },
    );

    test('a combo of two or more shows N HIT until a rep misses', () {
      final fx = BattleFxTimeline()
        ..rep(_good(BattleSide.me), 0)
        ..rep(_good(BattleSide.me, combo: 2), 1000);
      expect(fx.frame(1500).combos.map((c) => c.text), ['2 HIT']);
      // Over the camera, not on the stage.
      expect(
        fx.frame(1500).banners.map((b) => b.text),
        isNot(contains('2 HIT')),
      );
      fx.rep(_rep(BattleSide.me, null, reason: RejectReason.kneesDown), 1600);
      expect(fx.frame(1650).combos, isEmpty);
    });

    test('each side has its own combo mark; the inner end rises', () {
      final fx = BattleFxTimeline()
        ..rep(_good(BattleSide.me, combo: 2), 0)
        ..rep(_good(BattleSide.opponent, combo: 3), 100);
      final marks = fx.frame(500).combos;
      // The opponent's first: mine is drawn over theirs.
      expect(marks.map((c) => (c.side, c.text)), [
        (BattleSide.opponent, '3 HIT'),
        (BattleSide.me, '2 HIT'),
      ]);
      expect(marks.map((c) => c.rotation), [6, -6]);
      expect(marks.map((c) => c.scaleX), [0.72, 0.72]);
    });

    test('the opponent\'s rep that did not count takes only their mark '
        'down', () {
      final fx = BattleFxTimeline()
        ..rep(_good(BattleSide.me, combo: 2), 0)
        ..rep(_good(BattleSide.opponent, combo: 2), 0)
        ..rep(_rep(BattleSide.opponent, null), 300);
      expect(fx.frame(400).combos.map((c) => c.side), [BattleSide.me]);
    });

    test('the combo mark sits under the line, lower under the reconnect '
        'band', () {
      expect(BattleFx.comboTop(reconnecting: false), 404);
      expect(BattleFx.comboTop(reconnecting: true), 438);
    });

    test('a three-digit score shrinks a tenth when it bumps; a shorter one '
        'grows a fifth', () {
      BattleFxFrame at220(int mine, int theirs) =>
          (BattleFxTimeline()
                ..setScores(mine, theirs)
                ..rep(_good(BattleSide.me), 0)
                ..rep(_good(BattleSide.opponent), 0))
              .frame(80 + 140);
      expect(at220(99, 100).myScoreBump, closeTo(1.2, 1e-9));
      expect(at220(99, 100).opponentScoreBump, closeTo(0.9, 1e-9));
      expect(at220(100, 99).myScoreBump, closeTo(0.9, 1e-9));
      expect(at220(100, 99).opponentScoreBump, closeTo(1.2, 1e-9));
      final calm = BattleFxTimeline()..setScores(245, 310);
      expect(calm.frame(500).myScoreBump, 1);
      expect(calm.frame(500).opponentScoreBump, 1);
    });

    test('only a counted rep bumps the valid count, when it lands', () {
      final fx = BattleFxTimeline()
        ..rep(
          _rep(
            BattleSide.me,
            GameGrade.average,
            points: 5,
            reason: RejectReason.insufficientDepth,
          ),
          0,
        );
      expect(fx.frame(210).myRepsBump, 1);
      expect(fx.frame(210).myScoreBump, greaterThan(1));
      fx.rep(_good(BattleSide.me), 1000);
      expect(fx.frame(1079).myRepsBump, 1);
      expect(fx.frame(1210).myRepsBump, closeTo(1.3, 1e-9));
    });

    test('a new rejected rep replaces the sign instead of stacking', () {
      final fx = BattleFxTimeline()
        ..rep(_rep(BattleSide.me, null, reason: RejectReason.kneesDown), 0)
        ..rep(_rep(BattleSide.me, null, reason: RejectReason.phoneMoved), 400);
      final sign = fx.frame(400).sign!;
      expect(sign.reason, RejectReason.phoneMoved);
      expect(sign.scale, closeTo(0.6, 1e-9));
      expect(sign.tone, BattleFxTone.danger);
    });

    test('an average rep\'s sign gives the reason only, in amber', () {
      final fx = BattleFxTimeline()
        ..rep(
          _rep(
            BattleSide.me,
            GameGrade.average,
            points: 10,
            fever: true,
            reason: RejectReason.shallowSquat,
          ),
          0,
        );
      final sign = fx.frame(300).sign!;
      expect(sign.text, '더 앉기');
      expect(sign.tone, BattleFxTone.average);
    });

    test('in fever the shake and the star are one and a half times as big', () {
      BattleFxFrame at90(bool fever) =>
          (BattleFxTimeline()..rep(
                _rep(
                  BattleSide.me,
                  GameGrade.good,
                  points: 10,
                  combo: 1,
                  fever: fever,
                ),
                0,
              ))
              .frame(90);
      final plain = at90(false);
      final fever = at90(true);
      expect(fever.star!.diameter, closeTo(plain.star!.diameter * 1.5, 1e-9));
      expect(fever.shakeX, closeTo(plain.shakeX * 1.5, 1e-9));
    });

    test('nothing plays after the battle has ended', () {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.playerLeft,
            winner: BattleSide.me,
          ),
          0,
        )
        ..rep(_good(BattleSide.opponent), 100);
      final frame = fx.frame(200);
      expect(frame.me.pose, BattlePose.idle);
      expect(frame.star, isNull);
    });
  });

  group('the meeting point', () {
    test('follows a new share with a 110 ms time constant', () {
      final fx = BattleFxTimeline()..setShare(1, 0);
      expect(fx.frame(0).meetX, 180);
      expect(fx.frame(110).meetX, closeTo(280 - 100 / 2.718281828, 1e-6));
      expect(fx.frame(5000).meetX, closeTo(280, 1e-6));
    });

    test('keeps gliding from where it is when the share changes again', () {
      final fx = BattleFxTimeline()..setShare(1, 0);
      final midway = fx.frame(110).meetX;
      fx.setShare(0.5, 110);
      expect(fx.frame(110).meetX, closeTo(midway, 1e-9));
      expect(fx.frame(9000).meetX, closeTo(180, 1e-6));
    });

    test('a share outside 0 to 1 stops at the bar ends', () {
      final fx = BattleFxTimeline()..setShare(7, 0);
      expect(fx.frame(9000).meetX, closeTo(280, 1e-6));
    });
  });

  group('fever and danger', () {
    test('turning fever off takes the background and the aura away', () {
      final fx = BattleFxTimeline()..setFever(true, 0);
      expect(fx.frame(500).feverOpacity, 1);
      expect(fx.frame(500).me.glow, isTrue);
      fx.setFever(false, 600);
      expect(fx.frame(700).feverOpacity, 0);
      expect(fx.frame(700).me.glow, isFalse);
      expect(fx.frame(700).banners, isEmpty);
    });

    test('the danger edge is off before the start and after the end', () {
      final fx = BattleFxTimeline()
        ..danger = true
        ..setSetup(active: true);
      expect(fx.frame(0).dangerOpacity, 0);
      fx.setSetup(active: false);
      expect(fx.frame(0).dangerOpacity, 0.3);
      expect(fx.frame(240).dangerOpacity, 0.95);
      fx.finish(
        const BattleStageEnd(kind: BattleEndKind.timeUp, winner: BattleSide.me),
        300,
      );
      expect(fx.frame(480).dangerOpacity, 0);
    });
  });

  group('before the start', () {
    test('both ready shows two ready tags and no band', () {
      final fx = BattleFxTimeline()
        ..setSetup(active: true, meReady: true, opponentReady: true);
      final frame = fx.frame(0);
      expect(frame.myTag!.text, '준비 완료');
      expect(frame.myTag!.tone, BattleFxTone.me);
      expect(frame.opponentTag!.tone, BattleFxTone.opponent);
      expect(frame.banners, isEmpty);
      expect(frame.beforeStart, isTrue);
    });

    test('more than 3 s before the start: ready tags, no number yet', () {
      final fx = BattleFxTimeline()
        ..setSetup(active: true)
        ..countDown(5000, 0);
      final early = fx.frame(1000);
      expect(early.myTag!.text, '준비 완료');
      expect(early.opponentTag!.text, '준비 완료');
      expect(early.banners, isEmpty);
      final late = fx.frame(2500);
      expect(late.myTag, isNull);
      expect(late.banners.single.text, '3');
      expect(fx.frame(5000).beforeStart, isFalse);
    });

    test('a disconnected opponent has no tag once the battle has ended', () {
      final fx = BattleFxTimeline()..opponentGone = true;
      expect(fx.frame(0).opponentTag!.text, '연결 끊김');
      fx.finish(
        const BattleStageEnd(
          kind: BattleEndKind.playerLeft,
          winner: BattleSide.me,
        ),
        100,
      );
      expect(fx.frame(200).opponentTag, isNull);
    });
  });

  group('endings', () {
    test('a draw at time-up shows DRAW on white and nobody celebrates', () {
      final fx = BattleFxTimeline()
        ..finish(const BattleStageEnd(kind: BattleEndKind.timeUp), 0);
      final frame = fx.frame(1500);
      final verdict = frame.banners.single;
      expect(verdict.text, 'DRAW');
      expect(verdict.tone, BattleFxTone.plain);
      expect(frame.me.pose, BattlePose.idle);
      expect(frame.opponent.pose, BattlePose.idle);
    });

    test('a loss at time-up shows LOSE on pink and my fighter hit', () {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.timeUp,
            winner: BattleSide.opponent,
          ),
          0,
        );
      final frame = fx.frame(1500);
      expect(frame.banners.single.text, 'LOSE');
      expect(frame.banners.single.tone, BattleFxTone.opponent);
      expect(frame.me.pose, BattlePose.hit);
      expect(frame.opponent.pose, BattlePose.win);
    });

    test('time-up without the result yet: TIME!, then nothing, no button', () {
      const waiting = BattleStageEnd(
        kind: BattleEndKind.timeUp,
        decided: false,
      );
      final fx = BattleFxTimeline()..finish(waiting, 0);
      expect(fx.frame(500).banners.single.text, 'TIME!');
      final late = fx.frame(4000);
      expect(late.banners, isEmpty);
      expect(late.resultButton, isNull);
      expect(late.me.pose, BattlePose.idle);
      expect(fx.resultButtonUp(4000), isFalse);
    });

    test('the verdict and the button follow a result that comes late', () {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(kind: BattleEndKind.timeUp, decided: false),
          0,
        )
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.timeUp,
            winner: BattleSide.me,
          ),
          3000,
        );
      expect(fx.frame(3000).banners, isEmpty);
      final verdict = fx.frame(3010).banners.single;
      expect(verdict.text, 'WIN!');
      expect(verdict.scaleX, greaterThan(1.6));
      expect(fx.frame(3010).me.pose, BattlePose.win);
      expect(fx.resultButtonUp(3799), isFalse);
      expect(fx.resultButtonUp(3800), isTrue);
    });

    test('a late result that I lost by my connection plays as that ending', () {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(kind: BattleEndKind.timeUp, decided: false),
          0,
        )
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.playerLeft,
            winner: BattleSide.opponent,
          ),
          5000,
        );
      expect(fx.end!.kind, BattleEndKind.playerLeft);
      final frame = fx.frame(5500);
      expect(frame.banners.single.text, '연결이 끊겨서 졌어요');
      expect(frame.me.opacity, 0);
      expect(frame.opponent.pose, BattlePose.win);
      expect(fx.resultButtonUp(6799), isFalse);
      expect(fx.resultButtonUp(6800), isTrue);
    });

    test('a late knockout result plays the ring-out, not WIN! or LOSE', () {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(kind: BattleEndKind.timeUp, decided: false),
          0,
        )
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.knockout,
            winner: BattleSide.me,
          ),
          300,
        );
      expect(fx.end!.kind, BattleEndKind.knockout);
      expect(fx.frame(400).banners, isEmpty);
      expect(fx.frame(300 + 1300).banners.single.text, 'K.O.');
    });

    test('a second undecided time-up changes nothing', () {
      const waiting = BattleStageEnd(
        kind: BattleEndKind.timeUp,
        decided: false,
      );
      final fx = BattleFxTimeline()
        ..finish(waiting, 0)
        ..finish(waiting, 600);
      expect(fx.frame(700).banners.single.text, 'TIME!');
      expect(fx.frame(1100).banners, isEmpty);
    });

    test('a result that comes within the TIME! second waits for it', () {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(kind: BattleEndKind.timeUp, decided: false),
          0,
        )
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.timeUp,
            winner: BattleSide.me,
          ),
          200,
        );
      expect(fx.frame(900).banners.single.text, 'TIME!');
      expect(fx.frame(1010).banners.single.text, 'WIN!');
      expect(fx.resultButtonUp(1800), isTrue);
    });

    test('a second ending does not replace a decided one', () {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.knockout,
            winner: BattleSide.me,
          ),
          0,
        )
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.timeUp,
            winner: BattleSide.opponent,
          ),
          100,
        );
      expect(fx.end!.kind, BattleEndKind.knockout);
      expect(fx.end!.winner, BattleSide.me);
    });

    test('losing by my own lost connection mirrors the opponent leaving', () {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.playerLeft,
            winner: BattleSide.opponent,
          ),
          0,
        );
      final frame = fx.frame(500);
      expect(frame.me.opacity, 0);
      expect(frame.opponent.pose, BattlePose.win);
      expect(frame.puff!.centerX, frame.meetX - BattleFx.reach);
      final band = frame.banners.single;
      expect(band.text, '연결이 끊겨서 졌어요');
      expect(band.tone, BattleFxTone.opponent);
      expect(band.font, BattleFxFont.display);
    });

    test('a knockout by the opponent twinkles at the left edge', () {
      final fx = BattleFxTimeline()
        ..rep(_good(BattleSide.opponent, knockout: true), 0);
      expect(fx.frame(80 + 1800).twinkle!.centerX, 40);
    });

    test('a knockout the server reports later still rings the loser out', () {
      final fx = BattleFxTimeline()
        ..rep(_good(BattleSide.me), 0)
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.knockout,
            winner: BattleSide.me,
          ),
          300,
        );
      final frame = fx.frame(300 + 1500);
      expect(frame.opponent.opacity, 0);
      expect(frame.me.pose, BattlePose.win);
      expect(frame.banners.single.text, 'K.O.');
      expect(fx.resultButtonUp(300 + 2199), isFalse);
      expect(fx.resultButtonUp(300 + 2200), isTrue);
    });

    test('a knockout clears a MISS band still on screen', () {
      final fx = BattleFxTimeline()
        ..rep(_rep(BattleSide.opponent, null), 0)
        ..rep(_good(BattleSide.me, knockout: true), 100);
      expect(fx.frame(400).banners.map((b) => b.text), contains('MISS'));
      expect(fx.frame(181 + 300).banners, isEmpty);
    });
  });

  group('reduced motion', () {
    test(
      'keeps poses, bands and the sign; drops shake, flash and breathing',
      () {
        final fx = BattleFxTimeline()
          ..rep(_rep(BattleSide.me, null, reason: RejectReason.kneesDown), 0)
          ..rep(_good(BattleSide.opponent, combo: 2), 300);
        final lively = fx.frame(400);
        final calm = fx.frame(400, reducedMotion: true);
        expect(lively.shakeY, isNot(0));
        expect(lively.me.flash, isTrue);
        expect(calm.shakeX, 0);
        expect(calm.shakeY, 0);
        expect(calm.me.flash, isFalse);
        expect(calm.me.pose, BattlePose.hit);
        expect(calm.opponent.pose, BattlePose.attack);
        expect(calm.sign!.reason, RejectReason.kneesDown);
        expect(calm.combos.map((c) => c.text), ['2 HIT']);
        expect(calm.stripeShift, 0);
        expect(fx.frame(3000, reducedMotion: true).me.scaleY, 1);
        expect(fx.frame(3000).me.scaleY, isNot(1));
      },
    );

    test('drops the count bump, the zoom, the puff and the growing', () {
      final ko = BattleFxTimeline()
        ..rep(_good(BattleSide.me, knockout: true), 0);
      expect(ko.frame(210).myRepsBump, greaterThan(1));
      expect(ko.frame(210, reducedMotion: true).myRepsBump, 1);
      expect(ko.frame(400).zoom, greaterThan(1));
      expect(ko.frame(400, reducedMotion: true).zoom, 1);
      expect(ko.frame(80 + 2210).resultButton!.scale, lessThan(1));
      expect(ko.frame(80 + 2210, reducedMotion: true).resultButton!.scale, 1);

      final left = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.playerLeft,
            winner: BattleSide.me,
          ),
          0,
        );
      expect(left.frame(200).puff, isNotNull);
      expect(left.frame(200, reducedMotion: true).puff, isNull);

      final count = BattleFxTimeline()..countDown(3000, 0);
      expect(count.frame(0).banners.single.scaleX, 1.5);
      expect(count.frame(0, reducedMotion: true).banners.single.scaleX, 1);
    });
  });

  group('rules the design samples do not reach', () {
    test('the opponent\'s rejected rep never raises the sign', () {
      final fx = BattleFxTimeline()
        ..rep(_rep(BattleSide.opponent, null, reason: RejectReason.tooFast), 0);
      expect(fx.frame(200).sign, isNull);
    });

    test('the opponent\'s average rep lands a weak blow without a sign', () {
      final fx = BattleFxTimeline()
        ..rep(
          _rep(
            BattleSide.opponent,
            GameGrade.average,
            points: 5,
            reason: RejectReason.insufficientDepth,
          ),
          0,
        );
      final frame = fx.frame(100);
      expect(frame.sign, isNull);
      expect(frame.me.pose, BattlePose.hit);
      expect(frame.star!.centerX, frame.meetX - 34);
    });

    test('N HIT is not drawn once the battle has ended', () {
      final fx = BattleFxTimeline()..rep(_good(BattleSide.me, combo: 2), 0);
      expect(fx.frame(400).combos.map((c) => c.text), ['2 HIT']);
      fx.finish(
        const BattleStageEnd(kind: BattleEndKind.timeUp, winner: BattleSide.me),
        500,
      );
      expect(fx.frame(600).combos, isEmpty);
      expect(fx.frame(600).banners.map((b) => b.text), contains('TIME!'));
    });

    test('N HIT stays 1700 ms and fades over its last 200', () {
      final fx = BattleFxTimeline()..rep(_good(BattleSide.me, combo: 2), 0);
      BattleFxCombo? hit(double now) => fx.frame(now).combos.firstOrNull;
      expect(hit(0)!.scaleY, closeTo(0.6, 1e-9));
      expect(hit(1500)!.opacity, 1);
      expect(hit(1600)!.opacity, closeTo(0.5, 1e-9));
      expect(hit(1690)!.opacity, closeTo(0.05, 1e-9));
      expect(hit(1700), isNull);
    });

    test('the numbers start exactly 3 s before the start', () {
      final fx = BattleFxTimeline()..countDown(5000, 0);
      final before = fx.frame(1999);
      expect(before.banners, isEmpty);
      expect(before.myTag!.text, '준비 완료');
      final at = fx.frame(2000);
      expect(at.banners.single.text, '3');
      expect(at.myTag, isNull);
      expect(at.opponentTag, isNull);
    });

    test('a blow that lands takes the same side\'s MISS away', () {
      final fx = BattleFxTimeline()
        ..rep(_rep(BattleSide.me, null, reason: RejectReason.kneesDown), 0);
      expect(fx.frame(300).banners.map((b) => b.text), ['MISS']);
      fx.rep(_good(BattleSide.me), 300);
      // Gone at once, before the blow's own word comes up.
      expect(fx.frame(301).banners, isEmpty);
      expect(fx.frame(400).banners.map((b) => b.text), ['GOOD']);
    });

    test('two MISS bands show at once, one on each side, mine drawn last', () {
      final fx = BattleFxTimeline()
        ..rep(_rep(BattleSide.me, null, reason: RejectReason.kneesDown), 0)
        ..rep(_rep(BattleSide.opponent, null), 50);
      final misses = fx.frame(400).banners;
      expect(misses.map((b) => b.text), ['MISS', 'MISS']);
      expect(misses.map((b) => b.dx), [56, -56]);
    });

    test('MISS stays where it pops up: it does not rise', () {
      final fx = BattleFxTimeline()..rep(_rep(BattleSide.me, null), 0);
      for (final now in const [120.0, 400.0, 800.0]) {
        expect(fx.frame(now).banners.single.dy, 0);
        expect(fx.frame(now).banners.single.top, 155);
      }
    });

    test('K.O. lands on the half the winner left empty, the winner\'s end '
        'higher', () {
      BattleFxBanner koBand(BattleSide winner) {
        final fx = BattleFxTimeline()..rep(_good(winner, knockout: true), 0);
        return fx.frame(80 + 1250 + 200).banners.single;
      }

      final won = koBand(BattleSide.me);
      expect((won.text, won.tone), ('K.O.', BattleFxTone.me));
      expect((won.dx, won.rotation, won.scaleX), (-102, -7, 0.6));
      final lost = koBand(BattleSide.opponent);
      expect((lost.text, lost.tone), ('K.O.', BattleFxTone.opponent));
      expect((lost.dx, lost.rotation, lost.scaleX), (102, 7, 0.6));
    });

    test('FEVER ×2 crosses on a white band under the score bands', () {
      final fx = BattleFxTimeline()..setFever(true, 0);
      final band = fx.frame(600).banners.single;
      expect(
        (band.text, band.tone, band.top),
        ('FEVER ×2', BattleFxTone.plain, 263),
      );
      expect(band.rotation, -4);
    });
  });

  group('the countdown', () {
    test('setting up again stops it: no number and no GO!', () {
      final fx = BattleFxTimeline()
        ..setSetup(active: true, meReady: true, opponentReady: true)
        ..countDown(3000, 0);
      expect(fx.frame(500).banners.single.text, '3');
      fx.setSetup(active: true, opponentReady: true);
      final again = fx.frame(1500);
      expect(again.banners.single.text, '자세 세팅 중');
      expect(again.myTag!.text, '세팅 중');
      final later = fx.frame(3000);
      expect(later.banners.single.text, '자세 세팅 중');
      expect(later.beforeStart, isTrue);
    });

    test('starts over after it was stopped', () {
      final fx = BattleFxTimeline()
        ..countDown(3000, 0)
        ..setSetup(active: true)
        ..countDown(3000, 4000);
      expect(fx.frame(4000).banners.single.text, '3');
      expect(fx.frame(7000).banners.single.text, 'GO!');
      expect(fx.frame(7000).beforeStart, isFalse);
    });

    test('asked again after the start does not pop GO! a second time', () {
      final fx = BattleFxTimeline()
        ..countDown(3000, 0)
        ..countDown(0, 3400);
      expect(fx.frame(3500).banners.single.text, 'GO!');
      expect(fx.frame(3800).banners, isEmpty);
    });

    test('keeps its clock for a small correction, follows a real move', () {
      final fx = BattleFxTimeline()
        ..countDown(3000, 0)
        ..countDown(2860, 100);
      expect(fx.frame(2990).beforeStart, isTrue);
      expect(fx.frame(3000).beforeStart, isFalse);
      fx.countDown(4000, 1000);
      expect(fx.frame(3000).banners.single.text, '2');
      expect(fx.frame(5000).beforeStart, isFalse);
    });
  });

  group('inputs the game should not send', () {
    test('a miss cannot knock out, and leaves the last blow as it was', () {
      final fx = BattleFxTimeline()..rep(_good(BattleSide.me), 0);
      final star = fx.frame(200).star!.diameter;
      fx.rep(_rep(BattleSide.opponent, null, knockout: true), 150);
      expect(fx.end, isNull);
      expect(fx.frame(200).star!.diameter, star);
    });

    test('my rejected rep without a reason takes the older sign down', () {
      final fx = BattleFxTimeline()
        ..rep(_rep(BattleSide.me, null, reason: RejectReason.kneesDown), 0);
      expect(fx.frame(300).sign, isNotNull);
      fx.rep(_rep(BattleSide.me, null), 300);
      expect(fx.frame(400).sign, isNull);
    });

    test('a starting share outside 0 to 1 starts at the bar end', () {
      expect(BattleFxTimeline(share: 2).frame(0).meetX, 280);
      expect(BattleFxTimeline(share: -1).frame(0).meetX, 80);
    });
  });

  group('small things', () {
    test('the aura breathes between 5 and 13 around 9', () {
      final fx = BattleFxTimeline();
      expect(fx.frame(0).glowRadius, 9);
      expect(
        fx.frame(120 * 3.141592653589793 / 2).glowRadius,
        closeTo(13, 1e-9),
      );
      expect(
        fx.frame(120 * 3.141592653589793 * 1.5).glowRadius,
        closeTo(5, 1e-9),
      );
    });

    test('the fever stripes drift 0.09 a millisecond and wrap at 61.8', () {
      final fx = BattleFxTimeline();
      expect(fx.frame(100).stripeShift, closeTo(9, 1e-9));
      expect(fx.frame(1000).stripeShift, closeTo(90 - 61.8, 1e-9));
    });

    test('a disconnected opponent who then leaves fades from 0.45', () {
      final fx = BattleFxTimeline()
        ..opponentGone = true
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.playerLeft,
            winner: BattleSide.me,
          ),
          0,
        );
      expect(fx.frame(0).opponent.opacity, 0.45);
      expect(fx.frame(200).opponent.opacity, closeTo(0.45 * 0.125, 1e-9));
    });

    test('fever told twice keeps its first moment', () {
      final fx = BattleFxTimeline()
        ..setFever(true, 0)
        ..setFever(true, 1000);
      expect(fx.frame(1500).banners, isEmpty);
      expect(fx.frame(1500).feverOpacity, 1);
    });

    test('reduced motion keeps the score bump', () {
      final fx = BattleFxTimeline()..rep(_good(BattleSide.me), 0);
      expect(fx.frame(220, reducedMotion: true).myScoreBump, greaterThan(1.1));
    });
  });

  group('cues', () {
    const left = BattleStageEnd(
      kind: BattleEndKind.playerLeft,
      winner: BattleSide.me,
    );

    test('a blow is one hit cue, when it lands and not before', () {
      final fx = BattleFxTimeline()..rep(_good(BattleSide.me), 1000);
      expect(fx.takeCues(1079), isEmpty);
      expect(fx.takeCues(1080), [
        const BattleStageCue(
          BattleCueKind.hit,
          side: BattleSide.me,
          grade: GameGrade.good,
        ),
      ]);
      expect(fx.takeCues(5000), isEmpty, reason: 'each cue once');
    });

    test('a miss is a cue at once, with who swung', () {
      final fx = BattleFxTimeline()..rep(_rep(BattleSide.opponent, null), 1000);
      expect(fx.takeCues(1000), [
        const BattleStageCue(BattleCueKind.miss, side: BattleSide.opponent),
      ]);
    });

    test('the knockout blow is a knockout cue, not a hit, when it lands', () {
      final fx = BattleFxTimeline()
        ..rep(
          _rep(
            BattleSide.me,
            GameGrade.excellent,
            points: 15,
            combo: 1,
            knockout: true,
          ),
          0,
        );
      expect(fx.takeCues(79), isEmpty);
      expect(fx.takeCues(80), [
        const BattleStageCue(
          BattleCueKind.knockout,
          side: BattleSide.me,
          grade: GameGrade.excellent,
        ),
      ]);
    });

    test('a knockout the server reports is a cue with the winner', () {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.knockout,
            winner: BattleSide.opponent,
          ),
          500,
        );
      expect(fx.takeCues(500), [
        const BattleStageCue(BattleCueKind.knockout, side: BattleSide.opponent),
      ]);
    });

    test('time-up is one cue, also when its result comes later', () {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(kind: BattleEndKind.timeUp, decided: false),
          0,
        );
      expect(fx.takeCues(0), [const BattleStageCue(BattleCueKind.timeUp)]);
      fx.finish(
        const BattleStageEnd(kind: BattleEndKind.timeUp, winner: BattleSide.me),
        2000,
      );
      // No second time-up: only the verdict that the result brings.
      expect(fx.takeCues(4000), [
        const BattleStageCue(BattleCueKind.verdict, side: BattleSide.me),
      ]);
    });

    test('a late result that a player left is its own cue after time-up', () {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(kind: BattleEndKind.timeUp, decided: false),
          0,
        );
      fx.takeCues(100);
      fx.finish(left, 3000);
      expect(fx.takeCues(3000), [
        const BattleStageCue(BattleCueKind.playerLeft, side: BattleSide.me),
      ]);
    });

    test('the countdown gives 3, 2, 1 and the start, each as it shows', () {
      final fx = BattleFxTimeline()..countDown(5000, 0);
      expect(fx.takeCues(1999), isEmpty, reason: 'more than 3 s left');
      expect(fx.takeCues(2000), [
        const BattleStageCue(BattleCueKind.countdown, number: 3),
      ]);
      expect(fx.takeCues(2900), isEmpty);
      expect(fx.takeCues(3000), [
        const BattleStageCue(BattleCueKind.countdown, number: 2),
      ]);
      expect(fx.takeCues(4001), [
        const BattleStageCue(BattleCueKind.countdown, number: 1),
      ]);
      expect(fx.takeCues(5000), [const BattleStageCue(BattleCueKind.go)]);
      expect(fx.takeCues(9000), isEmpty);
    });

    test('a number that was skipped is not said late', () {
      final fx = BattleFxTimeline()..countDown(3000, 0);
      expect(fx.takeCues(1500), [
        const BattleStageCue(BattleCueKind.countdown, number: 2),
      ]);
      expect(fx.takeCues(3500), [const BattleStageCue(BattleCueKind.go)]);
    });

    test('a countdown that was stopped gives no start; the next one counts '
        'from 3 again', () {
      final fx = BattleFxTimeline()..countDown(3000, 0);
      expect(fx.takeCues(1200).single.number, 2);
      fx.setSetup(active: true);
      expect(fx.takeCues(4000), isEmpty);
      fx.countDown(3000, 5000);
      expect(fx.takeCues(5000).single.number, 3);
      expect(fx.takeCues(8000), [const BattleStageCue(BattleCueKind.go)]);
    });

    test('a small clock correction does not repeat a number', () {
      final fx = BattleFxTimeline()..countDown(3000, 0);
      expect(fx.takeCues(1100).single.number, 2);
      fx.countDown(1950, 1100);
      expect(fx.takeCues(1150), isEmpty);
    });

    test('cues come in the order of their moments', () {
      final fx = BattleFxTimeline()
        ..rep(_good(BattleSide.me), 0)
        ..rep(_rep(BattleSide.opponent, null), 40);
      expect(fx.takeCues(100).map((c) => c.kind), [
        BattleCueKind.miss,
        BattleCueKind.hit,
      ]);
    });

    test('a rep after the end gives no cue', () {
      final fx = BattleFxTimeline()..finish(left, 0);
      fx.takeCues(0);
      fx.rep(_good(BattleSide.opponent), 100);
      expect(fx.takeCues(1000), isEmpty);
    });
  });

  group('the verdict cue', () {
    test('comes once, when WIN!, LOSE or DRAW shows after TIME!', () {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.timeUp,
            winner: BattleSide.opponent,
          ),
          0,
        );
      expect(fx.takeCues(1000), [const BattleStageCue(BattleCueKind.timeUp)]);
      expect(fx.takeCues(1001), [
        const BattleStageCue(BattleCueKind.verdict, side: BattleSide.opponent),
      ]);
      expect(fx.takeCues(9000), isEmpty);
    });

    test('a draw has no side', () {
      final fx = BattleFxTimeline()
        ..finish(const BattleStageEnd(kind: BattleEndKind.timeUp), 0);
      expect(fx.takeCues(2000), [
        const BattleStageCue(BattleCueKind.timeUp),
        const BattleStageCue(BattleCueKind.verdict),
      ]);
    });

    test('waits for a result that comes late', () {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(kind: BattleEndKind.timeUp, decided: false),
          0,
        );
      expect(fx.takeCues(5000), [const BattleStageCue(BattleCueKind.timeUp)]);
      fx.finish(
        const BattleStageEnd(kind: BattleEndKind.timeUp, winner: BattleSide.me),
        6000,
      );
      expect(fx.takeCues(6000), isEmpty);
      expect(fx.takeCues(6001), [
        const BattleStageCue(BattleCueKind.verdict, side: BattleSide.me),
      ]);
    });

    test('a knockout or a player leaving has no verdict cue of its own', () {
      final fx = BattleFxTimeline()
        ..finish(
          const BattleStageEnd(
            kind: BattleEndKind.playerLeft,
            winner: BattleSide.me,
          ),
          0,
        );
      expect(fx.takeCues(9000).map((c) => c.kind), [BattleCueKind.playerLeft]);
    });
  });

  group('a knockout reported before its blow', () {
    const reported = BattleStageEnd(
      kind: BattleEndKind.knockout,
      winner: BattleSide.me,
    );

    test('the blow still plays, and the ring-out starts when it lands', () {
      final fx = BattleFxTimeline()..finish(reported, 1000);
      expect(fx.rep(_good(BattleSide.me, knockout: true), 1000), isTrue);
      final lunge = fx.frame(1040);
      expect(lunge.me.pose, BattlePose.attack);
      expect(lunge.opponent.pose, BattlePose.idle);
      final landed = fx.frame(1090);
      expect(landed.opponent.pose, BattlePose.hit);
      expect(landed.star, isNotNull);
      // 1250 after the blow lands at 1080, not after the report.
      expect(fx.frame(1080 + 1249).banners, isEmpty);
      expect(fx.frame(1080 + 1250).banners.single.text, 'K.O.');
      expect(fx.resultButtonUp(1080 + 2199), isFalse);
      expect(fx.resultButtonUp(1080 + 2200), isTrue);
    });

    test('gives one knockout cue, the blow\'s, when it lands', () {
      final fx = BattleFxTimeline()
        ..finish(reported, 1000)
        ..rep(_good(BattleSide.me, knockout: true), 1000);
      expect(fx.takeCues(1079), isEmpty);
      expect(fx.takeCues(5000), [
        const BattleStageCue(
          BattleCueKind.knockout,
          side: BattleSide.me,
          grade: GameGrade.good,
        ),
      ]);
    });

    test('gives no second cue when the report\'s was already given', () {
      final fx = BattleFxTimeline()..finish(reported, 1000);
      expect(fx.takeCues(1010).single.kind, BattleCueKind.knockout);
      fx.rep(_good(BattleSide.me, knockout: true), 1016);
      expect(fx.takeCues(5000), isEmpty);
    });

    test('only that blow is played: not the loser\'s rep, not a rep that is '
        'no knockout, not a miss, not one that comes much later', () {
      BattleFxTimeline ended() => BattleFxTimeline()..finish(reported, 1000);
      expect(
        ended().rep(_good(BattleSide.opponent, knockout: true), 1000),
        isFalse,
      );
      expect(ended().rep(_good(BattleSide.me), 1000), isFalse);
      expect(
        ended().rep(_rep(BattleSide.me, null, knockout: true), 1000),
        isFalse,
      );
      expect(ended().rep(_good(BattleSide.me, knockout: true), 1300), isFalse);
      // And never twice.
      final fx = ended()..rep(_good(BattleSide.me, knockout: true), 1000);
      expect(fx.rep(_good(BattleSide.me, knockout: true), 1010), isFalse);
    });

    test('the blow may come a little after the report, within a quarter '
        'of a second', () {
      final fx = BattleFxTimeline()..finish(reported, 1000);
      expect(fx.rep(_good(BattleSide.me, knockout: true), 1100), isTrue);
      expect(fx.frame(1140).me.pose, BattlePose.attack);
      // The ring-out starts over from this blow, which lands at 1180.
      expect(fx.frame(1180 + 1249).banners, isEmpty);
      expect(fx.frame(1180 + 1250).banners.single.text, 'K.O.');
      expect(
        BattleFxTimeline()
          ..finish(reported, 1000)
          ..rep(_good(BattleSide.me, knockout: true), 1250),
        isA<BattleFxTimeline>(),
      );
      final late = BattleFxTimeline()..finish(reported, 1000);
      expect(late.rep(_good(BattleSide.me, knockout: true), 1250), isTrue);
      final tooLate = BattleFxTimeline()..finish(reported, 1000);
      expect(tooLate.rep(_good(BattleSide.me, knockout: true), 1251), isFalse);
    });

    test('a blow flagged as a knockout is dropped after any other ending', () {
      for (final end in const [
        BattleStageEnd(kind: BattleEndKind.timeUp, winner: BattleSide.me),
        BattleStageEnd(kind: BattleEndKind.playerLeft, winner: BattleSide.me),
      ]) {
        final fx = BattleFxTimeline()..finish(end, 1000);
        expect(
          fx.rep(_good(BattleSide.me, knockout: true), 1000),
          isFalse,
          reason: '${end.kind}',
        );
        expect(fx.end!.kind, end.kind);
      }
    });

    test('a rep says whether it was played', () {
      final fx = BattleFxTimeline();
      expect(fx.rep(_good(BattleSide.me), 0), isTrue);
      fx.finish(const BattleStageEnd(kind: BattleEndKind.timeUp), 100);
      expect(fx.rep(_good(BattleSide.me), 200), isFalse);
    });
  });

  group('the characters (W3 spec 6)', () {
    final rig = CharacterRig.standard;

    /// The rig's values for [me] against [opponent].
    BattleFxCast cast(String me, String opponent) => BattleFxCast(
      meIdle: rig.art(me).idleMotion,
      opponentIdle: rig.art(opponent).idleMotion,
      opponentIdleOffsetMs: rig.idleOpponentOffsetMs,
      hitStarDx: rig.hitStarDx,
      hitStarUp: rig.hitStarUp,
    );

    test('without characters both fighters breathe in step as in W2 and the '
        'star sits 34 px over, 76 px up', () {
      final fx = BattleFxTimeline();
      for (final now in [0.0, 333.0, 1234.5, 20000.0]) {
        final frame = fx.frame(now);
        for (final f in [frame.me, frame.opponent]) {
          expect(f.scaleY, closeTo(1 + 0.02 * math.sin(now / 280), 1e-12));
          expect(f.scaleX.abs(), 1);
          expect(f.footY, BattleFx.groundY);
          expect(f.rotation, 0);
        }
      }
      fx.rep(_good(BattleSide.me), 1000);
      final star = fx.frame(1080).star!;
      expect(star.centerX, fx.frame(1080).meetX + 34);
      expect(star.centerY, BattleFx.groundY - 76);
    });

    test('a hop lifts the idle fighter, a stretch sizes it about the feet', () {
      final fx = BattleFxTimeline()..cast = cast('kangaroo', 'seal');
      const t = 300.0;
      final frame = fx.frame(t);
      final up = 6 * math.sin(math.pi * t / 460).abs();
      expect(frame.me.footY, closeTo(BattleFx.groundY - up, 1e-9));
      expect(frame.me.rotation, 0);
      expect(frame.me.scaleX, 1);
      expect(frame.me.scaleY, 1);
      final breath = math.sin(2 * math.pi * (t + 230) / 1100);
      expect(frame.opponent.footY, BattleFx.groundY);
      expect(frame.opponent.scaleX, closeTo(-(1 - 0.03 * breath), 1e-12));
      expect(frame.opponent.scaleY, closeTo(1 + 0.03 * breath, 1e-12));
    });

    test('a rock leans each fighter toward the one it faces', () {
      final fx = BattleFxTimeline()..cast = cast('penguin', 'penguin');
      const t = 200.0;
      final frame = fx.frame(t);
      expect(
        frame.me.rotation,
        closeTo(4 * math.sin(2 * math.pi * t / 1300), 1e-9),
      );
      expect(
        frame.opponent.rotation,
        closeTo(-4 * math.sin(2 * math.pi * (t + 230) / 1300), 1e-9),
      );
    });

    test('the opponent idles 230 ms later than me', () {
      final fx = BattleFxTimeline()..cast = cast('mouse', 'mouse');
      for (final t in [0.0, 50.0, 410.0, 1777.0]) {
        expect(
          fx.frame(t).opponent.footY,
          closeTo(fx.frame(t + 230).me.footY, 1e-9),
          reason: '$t',
        );
      }
      expect(fx.frame(90).opponent.footY, isNot(fx.frame(90).me.footY));
    });

    test('only the idle pose moves: the attack and the hit stand as without '
        'characters', () {
      final plain = BattleFxTimeline()..rep(_good(BattleSide.me), 1000);
      final drawn = BattleFxTimeline()
        ..cast = cast('kangaroo', 'bear')
        ..rep(_good(BattleSide.me), 1000);
      // The blow lands 80 ms after the lunge starts.
      for (final now in [1080.0, 1200.0]) {
        final a = plain.frame(now);
        final b = drawn.frame(now);
        expect(b.me.pose, BattlePose.attack);
        expect(b.opponent.pose, BattlePose.hit);
        for (final (x, y) in [(a.me, b.me), (a.opponent, b.opponent)]) {
          expect(
            (y.footX, y.footY, y.rotation, y.scaleX, y.scaleY),
            (x.footX, x.footY, x.rotation, x.scaleX, x.scaleY),
            reason: '$now',
          );
        }
      }
      // Back in the idle pose the hop is back.
      expect(drawn.frame(3000).me.pose, BattlePose.idle);
      expect(drawn.frame(3100).me.footY, lessThan(BattleFx.groundY));
    });

    test('while I am about to lose the danger sway replaces my rock; my hop '
        'stays', () {
      final fx = BattleFxTimeline()
        ..cast = const BattleFxCast(
          meIdle: CharacterIdleMotion(
            hopAmp: 3,
            hopPeriodMs: 320,
            rockDeg: 4,
            rockPeriodMs: 1300,
          ),
        )
        ..danger = true;
      const t = 500.0;
      final me = fx.frame(t).me;
      expect(me.rotation, closeTo(-7 + math.sin(t / 85) * 6, 1e-9));
      expect(
        me.footY,
        closeTo(BattleFx.groundY - 3 * math.sin(math.pi * t / 320).abs(), 1e-9),
      );
    });

    test('with reduced motion nobody idles', () {
      final fx = BattleFxTimeline()..cast = cast('kangaroo', 'penguin');
      final frame = fx.frame(300, reducedMotion: true);
      for (final f in [frame.me, frame.opponent]) {
        expect(f.footY, BattleFx.groundY);
        expect(f.rotation, 0);
        expect(f.scaleY, 1);
        expect(f.scaleX.abs(), 1);
      }
    });

    test('the hit star sits where the blow lands: (xm ± 48, 288)', () {
      for (final side in BattleSide.values) {
        final fx = BattleFxTimeline()
          ..cast = cast('mouse', 'bot')
          ..rep(_good(side), 1000);
        final frame = fx.frame(1090);
        final toward = side == BattleSide.me ? 1 : -1;
        expect(frame.star!.centerX, frame.meetX + toward * 48, reason: '$side');
        expect(frame.star!.centerY, 288);
      }
    });
  });
}
