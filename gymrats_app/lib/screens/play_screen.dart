import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/arcade_play_card.dart';
import '../widgets/exercise_sheet.dart';
import '../widgets/lobby_parts.dart';

/// 게임 시작, from home: 온라인 대결 and 아케이드 as two cards (P16 spec 3,
/// design `PlayX`), and the rules. Reads home's view model. The character
/// is picked from home's 캐릭터 row (W4).
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LobbyPage(
      behind: const LobbyWatermark('PLAY', left: 150),
      children: [
        const LobbyPageHeader(tag: '01 / PLAY', title: '게임 시작'),
        const SizedBox(height: ArcadePlayCard.topGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: ArcadePlayCard.online(onTap: () => _startOnline(context)),
            ),
            const SizedBox(width: AppSpacing.s12),
            Flexible(
              child: ArcadePlayCard.arcade(
                onTap: () =>
                    Navigator.pushNamed(context, GymRatsApp.arcadeRoute),
              ),
            ),
          ],
        ),
        const Spacer(),
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
}
