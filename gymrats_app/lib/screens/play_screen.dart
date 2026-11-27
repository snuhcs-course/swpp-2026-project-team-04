import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../services/friends/friend_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/arcade_play_card.dart';
import '../widgets/exercise_sheet.dart';
import '../widgets/friend_battle_card.dart';
import '../widgets/lobby_parts.dart';

/// 게임 시작, from home: 온라인 대결 and 아케이드 as two cards (P16 spec 3,
/// design `PlayX`), and 친구와의 대전 under them down to the page's bottom
/// margin (A11 spec 3; the rules open from home's ? and 환경설정). Reads
/// home's view model. The character is picked from home's 캐릭터 row (W4).
/// 친구와의 대전 (P9) opens the friends page, where a friend and then the
/// exercise are picked, with a sticker while a request or an invite waits.
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
        const SizedBox(height: AppSpacing.s12),
        // The rest of the screen, at least the card's least height.
        const Expanded(child: _FriendBattleRow()),
      ],
    );
  }
}

/// 친구와의 대전 (P9, A11): opens the friends page with home's profile (for
/// its exercise sheet's bests), with the "수락 대기!" sticker while a
/// friend request or a battle invite waits for an answer. The sticker reads
/// the app's [FriendRepository], when there is one: on opening, every
/// [refreshEvery] while this page is on top, and on coming back.
class _FriendBattleRow extends StatefulWidget {
  const _FriendBattleRow();

  /// As the friends page reads its lists.
  static const refreshEvery = Duration(seconds: 5);

  @override
  State<_FriendBattleRow> createState() => _FriendBattleRowState();
}

class _FriendBattleRowState extends State<_FriendBattleRow> {
  bool _waiting = false, _checking = false;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
    _refresh = Timer.periodic(_FriendBattleRow.refreshEvery, (_) {
      // Not while another page is on top (coming back reads it anyway) or
      // the app is in the background.
      // Unknown (before the first report) counts as in front.
      final state = WidgetsBinding.instance.lifecycleState;
      final inFront = state == null || state == AppLifecycleState.resumed;
      if (inFront && (ModalRoute.of(context)?.isCurrent ?? false)) {
        unawaited(_check());
      }
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  /// Reads whether something waits; one read at a time, so an older answer
  /// never lands after a newer one.
  Future<void> _check() async {
    if (_checking) return;
    final FriendRepository friends;
    try {
      friends = context.read<FriendRepository>();
    } on ProviderNotFoundException {
      return;
    }
    _checking = true;
    try {
      final overview = await friends.fetchOverview();
      if (!mounted) return;
      setState(
        () => _waiting =
            overview.incoming.isNotEmpty || overview.invites.isNotEmpty,
      );
    } on Object {
      // No sticker without the server; the friends page says why.
    } finally {
      _checking = false;
    }
  }

  /// Opens the friends page with home's profile as its route argument.
  Future<void> _open() async {
    await Navigator.pushNamed(
      context,
      GymRatsApp.friendsRoute,
      arguments: context.read<HomeViewModel>().state.profile,
    );
    if (mounted) unawaited(_check());
  }

  @override
  Widget build(BuildContext context) =>
      FriendBattleCard(waiting: _waiting, onTap: () => unawaited(_open()));
}
