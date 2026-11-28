import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/battle_result.dart';
import '../models/character_rig.dart';
import '../models/exercise_type.dart';
import '../models/game_score.dart';
import '../models/match_record.dart';
import '../models/matchup.dart';
import '../models/ranking_ladder.dart';
import '../screens/result_screen.dart';
import '../services/rankings/rankings_repository.dart';
import '../services/user/character_store.dart';
import '../theme/app_theme.dart';
import '../viewmodels/character_viewmodel.dart';
import '../widgets/victory_scene.dart';

/// Opens the battle report with a result chosen on the phone, to see its
/// scene (A7: a loss's red cut-in, a draw's lime and pink one; the wins as
/// before) without playing a battle, since a real draw is rare:
/// `flutter run --release -t lib/demo/result_scene_demo.dart`.
///
/// Pick the result, my character and the opponent's, then 리포트 열기: the
/// app's own result screen opens with a made-up online battle. Back returns
/// here to play it again. "애니메이션 줄이기" opens it as the phone's reduced
/// motion setting would. It installs as the app does (the same package), so
/// install the app again after the check.
void main() {
  runApp(const ResultSceneDemo());
}

/// The demo app: the picker, with my character kept in a
/// [CharacterViewModel] as the app keeps it.
class ResultSceneDemo extends StatefulWidget {
  const ResultSceneDemo({super.key});

  @override
  State<ResultSceneDemo> createState() => _ResultSceneDemoState();
}

class _ResultSceneDemoState extends State<ResultSceneDemo> {
  final _characters = CharacterViewModel(store: MemoryCharacterStore());

  @override
  void dispose() {
    _characters.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider<CharacterViewModel>.value(
        value: _characters,
        child: MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: const ResultScenePicker(),
          // The report's 다시 대결 and the like lead nowhere here.
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(
              appBar: AppBar(),
              body: Center(child: Text('데모에서는 열지 않아요: ${settings.name}')),
            ),
          ),
        ),
      );
}

/// The opponent choices: each character, RepBot, and an opponent whose
/// character is not known (null).
const _opponents = <String?>[
  'mouse',
  'kangaroo',
  'bear',
  'penguin',
  'seal',
  CharacterRig.botId,
  null,
];

/// The words of each result.
const _resultWords = {
  VictoryResult.koWin: 'KO 승리',
  VictoryResult.timeWin: '판정승',
  VictoryResult.leftWin: '기권승',
  VictoryResult.lose: '패배',
  VictoryResult.draw: '무승부',
};

/// Picks the result and the characters, and opens the report.
class ResultScenePicker extends StatefulWidget {
  const ResultScenePicker({super.key});

  /// The made-up battle for [result] against [opponentId] (null: not
  /// known): an online battle against a person, RepBot a bot.
  static BattleResult battleOf(VictoryResult result, String? opponentId) {
    final (outcome, end, departure) = switch (result) {
      VictoryResult.koWin => (MatchOutcome.win, GameEnd.ko, null),
      VictoryResult.timeWin => (MatchOutcome.win, GameEnd.timeUp, null),
      VictoryResult.leftWin => (
        MatchOutcome.win,
        GameEnd.timeUp,
        BattleDeparture.opponentLeft,
      ),
      VictoryResult.lose => (MatchOutcome.lose, GameEnd.timeUp, null),
      VictoryResult.draw => (MatchOutcome.draw, GameEnd.timeUp, null),
    };
    final (mine, theirs) = switch (outcome) {
      MatchOutcome.win => (180, 120),
      MatchOutcome.lose => (120, 180),
      MatchOutcome.draw => (150, 150),
    };
    final bot = opponentId == CharacterRig.botId;
    return BattleResult(
      matchup: Matchup(
        exercise: ExerciseType.pushUp,
        playerName: '나',
        opponent: Opponent(
          name: bot ? 'RepBot' : '상대',
          isBot: bot,
          characterId: bot ? null : opponentId,
        ),
      ),
      myReps: mine ~/ 15,
      myInvalidReps: 1,
      opponentReps: theirs ~/ 15,
      myScore: mine,
      opponentScore: theirs,
      end: end,
      decidedOutcome: outcome,
      endedAt: DateTime.now(),
      roundLength: const Duration(seconds: 30),
      departure: departure ?? BattleDeparture.none,
    );
  }

  @override
  State<ResultScenePicker> createState() => _ResultScenePickerState();
}

class _ResultScenePickerState extends State<ResultScenePicker> {
  var _result = VictoryResult.lose;
  String? _opponent = 'penguin';
  var _still = false;

  void _open(BuildContext context) {
    final battle = ResultScenePicker.battleOf(_result, _opponent);
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations:
                _still || MediaQuery.of(context).disableAnimations,
          ),
          child: ResultScreen(result: battle),
        ),
      ),
    );
  }

  Widget _chips<T>(
    String title,
    List<T> values,
    T selected,
    String Function(T) words,
    ValueChanged<T> onSelected,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            for (final value in values)
              ChoiceChip(
                label: Text(words(value)),
                selected: value == selected,
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final rig = CharacterRig.standard;
    final characters = context.watch<CharacterViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('리포트 연출 데모')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s20),
        children: [
          _chips<VictoryResult>(
            '결과',
            VictoryResult.values,
            _result,
            (result) => _resultWords[result]!,
            (result) => setState(() => _result = result),
          ),
          _chips<String>(
            '내 캐릭터',
            [for (final art in rig.selectable) art.id],
            characters.characterId,
            (id) => rig.art(id).name,
            characters.choose,
          ),
          _chips<String?>(
            '상대 캐릭터',
            _opponents,
            _opponent,
            (id) => id == null ? '정보 없음' : rig.art(id).name,
            (id) => setState(() => _opponent = id),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('애니메이션 줄이기'),
            value: _still,
            onChanged: (value) => setState(() => _still = value),
          ),
          const SizedBox(height: AppSpacing.s8),
          FilledButton(
            onPressed: () => _open(context),
            child: const Text('리포트 열기'),
          ),
        ],
      ),
    );
  }
}

/// The rank ladder's cases (A15 SPEC 7, the design `SpScene.dc.html` E's
/// `SCN`) as the server would give them: the global weekly push-up ranking
/// before and after the battle, ordered and ranked as the server does
/// (points high first, then nickname, then id; equal points share a rank),
/// its top [listSize] rows, and my row. The ladder made from them is the
/// design's for every case and result (`ranking_ladder_test.dart`).
///
/// Players above the design's shown list ([ScoreLadderCase.above]) are
/// filled in with points far above it; 'enter' and 'big' start outside the
/// list with the ranks the design gives, and 'enter' and 'big' end outside
/// it when the design does.
class ScoreLadderCase {
  const ScoreLadderCase._({
    required this.above,
    required this.others,
    required this.old,
    this.oldRank,
    this.outRanks = const {},
  });

  /// The cases by the design's `sc`. 'late' and 'none' have base's
  /// ranking: late's ranking comes confirmed only after the scene has
  /// chosen its path, none's battle does not count.
  static const all = {
    'base': ScoreLadderCase._(above: 0, others: _base, old: 19),
    'mid': ScoreLadderCase._(
      above: 13,
      others: [
        ('스쿼트킹', 53),
        ('하루백개', 47),
        ('근육곰', 45),
        ('새벽러너', 44),
        ('오늘도출석', 42),
        ('푸시푸시', 41),
        ('초보쥐', 38),
      ],
      old: 40,
    ),
    'enter': ScoreLadderCase._(
      above: 46,
      others: [('팔굽혀', 21), ('근성맨', 14), ('꾸준히', 13), ('오늘만산다', 12)],
      old: 9,
      oldRank: 63,
      outRanks: {
        VictoryResult.koWin: 61,
        VictoryResult.timeWin: 61,
        VictoryResult.leftWin: 61,
        VictoryResult.draw: 61,
        VictoryResult.lose: 61,
      },
    ),
    'big': ScoreLadderCase._(
      above: 49,
      others: [('꾸준히', 24)],
      old: 3,
      oldRank: 1204,
      outRanks: {
        VictoryResult.koWin: 803,
        VictoryResult.timeWin: 1012,
        VictoryResult.leftWin: 1012,
        VictoryResult.draw: 1098,
        VictoryResult.lose: 1177,
      },
    ),
    'first': ScoreLadderCase._(above: 0, others: _base, old: null),
    'solo': ScoreLadderCase._(above: 0, others: [], old: null),
    'top': ScoreLadderCase._(above: 0, others: _base, old: 26),
    'king': ScoreLadderCase._(
      above: 0,
      others: [('근육왕', 298), ('스쿼트킹', 287), ('하루백개', 254), ('새벽러너', 231)],
      old: 312,
    ),
    'late': ScoreLadderCase._(above: 0, others: _base, old: 19),
    'none': ScoreLadderCase._(above: 0, others: _base, old: 19),
  };

  static const _base = [
    ('펭귄짱', 31),
    ('헬스쿼카', 23),
    ('그루맨', 22),
    ('스쿼트왕', 16),
    ('아침운동', 16),
  ];

  /// The server's global list length.
  static const listSize = 50;

  /// My id and name.
  static const myId = 9000;
  static const myName = '쥐돌이';

  /// My battles this week before this one, when I had any.
  static const myBattles = 4;

  /// How many players are above the design's shown list.
  final int above;

  /// The design's listed players: name and week's points.
  final List<(String, int)> others;

  /// My points before the battle; null before my first of the week.
  final int? old;

  /// My rank before the battle when I am outside the list (the server's).
  final int? oldRank;

  /// My rank after the battle when I end outside the list, by result.
  final Map<VictoryResult, int> outRanks;

  /// The battle's weekly points for [result], as the server counts them.
  static int pointsOf(VictoryResult result) => switch (result) {
    VictoryResult.koWin => RankingPoints.koWin,
    VictoryResult.timeWin || VictoryResult.leftWin => RankingPoints.win,
    VictoryResult.draw => RankingPoints.draw,
    VictoryResult.lose => RankingPoints.loss,
  };

  /// The ranking before the battle.
  RankingSnapshot get before =>
      _snapshot(old, old == null ? 0 : myBattles, oldRank);

  /// The ranking after a battle ending in [result]: my points and battles
  /// one battle on, outside the list when my points stay below its last row.
  RankingSnapshot after(VictoryResult result) {
    final now = (old ?? 0) + pointsOf(result);
    final cut = before.entries.length < listSize
        ? null
        : before.entries.last.points;
    final outside = cut != null && now < cut;
    return _snapshot(
      now,
      (old == null ? 0 : myBattles) + 1,
      outside ? outRanks[result] : null,
    );
  }

  /// The server's answer with my [points] and [battles]; [outsideRank] puts
  /// me outside the list at that rank.
  RankingSnapshot _snapshot(int? points, int battles, int? outsideRank) {
    final rows =
        <({int userId, String nickname, int points})>[
          for (var i = 0; i < above; i++)
            (userId: 100 + i, nickname: '랭커${i + 1}', points: 900 - i),
          for (final (i, (name, score)) in others.indexed)
            (userId: 1 + i, nickname: name, points: score),
          if (points != null && outsideRank == null)
            (userId: myId, nickname: myName, points: points),
        ]..sort((a, b) {
          final byPoints = b.points.compareTo(a.points);
          if (byPoints != 0) return byPoints;
          final byName = a.nickname.compareTo(b.nickname);
          return byName != 0 ? byName : a.userId.compareTo(b.userId);
        });
    LadderEntry entry(({int userId, String nickname, int points}) row) => (
      userId: row.userId,
      nickname: row.nickname,
      points: row.points,
      rank: 1 + rows.where((o) => o.points > row.points).length,
      battles: row.userId == myId ? battles : 3,
    );
    final entries = [for (final row in rows.take(listSize)) entry(row)];
    final LadderEntry? me = points == null
        ? null
        : outsideRank != null
        ? (
            userId: myId,
            nickname: myName,
            points: points,
            rank: outsideRank,
            battles: battles,
          )
        : entry(rows.singleWhere((row) => row.userId == myId));
    return RankingSnapshot(entries: entries, me: me);
  }
}
