import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/bot_difficulty.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/matchup.dart';
import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/battle_mode_card.dart';
import '../widgets/exercise_sheet.dart';
import '../widgets/lobby_parts.dart';
import 'ai_setup_screen.dart';

/// 게임 시작, from home: online 1v1 and AI 1v1 as two big cards, the latest
/// setup to play again in one tap, and the rules. Reads home's view model.
class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  /// Asks for the exercise, then opens the online lobby. Closing the sheet
  /// stays here.
  Future<void> _startOnline(BuildContext context) async {
    final exercise = await showExerciseSheet(
      context,
      subtitle: '온라인 1v1 · ${battleDuration.inSeconds}초',
      profile: context.read<HomeViewModel>().state.profile!,
    );
    if (exercise == null || !context.mounted) return;
    Navigator.pushNamed(
      context,
      GymRatsApp.onlineBattleRoute,
      arguments: exercise,
    );
  }

  void _openBotSetup(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider<HomeViewModel>.value(
        value: context.read<HomeViewModel>(),
        child: const AiSetupScreen(),
      ),
    ),
  );

  /// Starts [setup] straight away, without asking again.
  void _playAgain(BuildContext context, BattleSetup setup) {
    if (setup.difficulty case final difficulty?) {
      Navigator.pushNamed(
        context,
        GymRatsApp.matchingRoute,
        arguments: BotMatchRequest(
          exercise: setup.exercise,
          difficulty: difficulty,
        ),
      );
    } else {
      Navigator.pushNamed(
        context,
        GymRatsApp.onlineBattleRoute,
        arguments: setup.exercise,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final last = context.watch<HomeViewModel>().state.lastSetup;
    return LobbyPage(
      behind: const LobbyWatermark('PLAY', left: 150),
      children: [
        const LobbyPageHeader(tag: '01 / PLAY', title: '게임 시작'),
        const SizedBox(height: AppSpacing.s24),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: BattleModeCard(
                  tag: 'ONLINE 1V1',
                  title: '온라인 1v1',
                  line: '다른 사람과\n실시간으로 대결',
                  offer: _exercises,
                  color: AppColors.accent,
                  shade: AppColors.accentDeep,
                  picture: const BattleModePicture.online(),
                  onTap: () => _startOnline(context),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: BattleModeCard(
                  tag: 'AI 1V1',
                  title: 'AI 1v1',
                  line: 'RepBot과\n난이도별 대결',
                  offer: BotDifficulty.values
                      .map((level) => level.label)
                      .join(' · '),
                  color: AppColors.opponent,
                  shade: AppColors.opponentDeep,
                  shadeRises: false,
                  picture: const BattleModePicture.bot(),
                  onTap: () => _openBotSetup(context),
                ),
              ),
            ],
          ),
        ),
        if (last != null) ...[
          const SizedBox(height: AppSpacing.s12),
          _PlayAgain(setup: last, onTap: () => _playAgain(context, last)),
        ],
        const SizedBox(height: AppSpacing.s16),
        Row(
          children: [
            Expanded(
              child: Text(
                '${battleDuration.inSeconds}초 · 점수 높은 쪽 승리',
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, GymRatsApp.helpRoute),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
              ),
              child: Text('규칙 보기', style: text.lobbyLink),
            ),
          ],
        ),
      ],
    );
  }

  static final _exercises = ExerciseType.values
      .map((exercise) => exercise.koreanName)
      .join(' · ');
}

/// "최근 설정으로 다시 하기" with the setup in one line under it.
class _PlayAgain extends StatelessWidget {
  const _PlayAgain({required this.setup, required this.onTap});

  final BattleSetup setup;
  final VoidCallback onTap;

  static const _chipSize = 34.0;

  String get _summary => [
    setup.exercise.koreanName,
    if (setup.difficulty case final level?) ...[
      'AI 1v1',
      level.label,
    ] else
      '온라인 1v1',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '최근 설정으로 다시 하기, $_summary',
      onTap: onTap,
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Row(
              children: [
                const LobbyArrowChip(size: _chipSize, icon: Icons.bolt_rounded),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('최근 설정으로 다시 하기', style: text.lobbyRowTitle),
                      Text(
                        _summary,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
