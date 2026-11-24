import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/bot_difficulty.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../services/friends/friend_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/battle_mode_card.dart';
import '../widgets/exercise_sheet.dart';
import '../widgets/lobby_parts.dart';
import 'ai_setup_screen.dart';

/// 게임 시작, from home: online 1v1 and AI 1v1 as two big cards, 친구와의
/// 대전 under them, and the rules. Reads home's view model. The character
/// is picked from home's 캐릭터 row (W4). Online is the main match: the
/// exercise, then the lobby. 친구와의 대전 (P9) opens the friends page, where
/// a friend and then the exercise are picked, with a dot while a request or
/// an invite waits.
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
        const SizedBox(height: AppSpacing.s12),
        const _FriendBattleRow(),
        const SizedBox(height: AppSpacing.s16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
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

/// 친구와의 대전 (P9): opens the friends page, with a dot while a friend request
/// or a battle invite waits for an answer. The dot reads the app's
/// [FriendRepository], when there is one, on opening and on coming back.
class _FriendBattleRow extends StatefulWidget {
  const _FriendBattleRow();

  @override
  State<_FriendBattleRow> createState() => _FriendBattleRowState();
}

class _FriendBattleRowState extends State<_FriendBattleRow> {
  bool _waiting = false;

  /// The dot's size, and the icon chip's: larger than a list row's, so the
  /// row stands out under the two cards.
  static const _dot = 12.0, _chip = 48.0;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    final FriendRepository friends;
    try {
      friends = context.read<FriendRepository>();
    } on ProviderNotFoundException {
      return;
    }
    try {
      final overview = await friends.fetchOverview();
      if (!mounted) return;
      setState(
        () => _waiting =
            overview.incoming.isNotEmpty || overview.invites.isNotEmpty,
      );
    } on Object {
      // No dot without the server; the friends page says why.
    }
  }

  Future<void> _open() async {
    await Navigator.pushNamed(context, GymRatsApp.friendsRoute);
    if (mounted) unawaited(_check());
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final line = _waiting ? '새 친구 요청이나 대결 신청이 있어요' : '친구 코드로 추가하고 대결 신청';
    return Semantics(
      button: true,
      label: '친구와의 대전, $line',
      onTap: () => unawaited(_open()),
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(_open()),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s20,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const LobbyArrowChip(
                      size: _chip,
                      icon: Icons.group_rounded,
                    ),
                    if (_waiting)
                      const Positioned(
                        top: -AppSpacing.s4,
                        right: -AppSpacing.s4,
                        child: SizedBox.square(
                          dimension: _dot,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.opponent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('친구와의 대전', style: text.titleLarge),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        line,
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.line),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
