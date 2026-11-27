import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/battle_result.dart';
import '../models/character_rig.dart';
import '../models/exercise_type.dart';
import '../models/game_score.dart';
import '../models/match_record.dart';
import '../models/matchup.dart';
import '../screens/result_screen.dart';
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
