import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../services/audio/background_music.dart';
import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/lobby_menu_item.dart';
import '../widgets/lobby_parts.dart';
import '../widgets/lobby_rep_bot.dart';
import '../widgets/sound_cues.dart';
import 'play_screen.dart';
import 'settings_screen.dart';

/// First screen after login: the game lobby. RepBot does push-ups over a
/// menu of 게임 시작, 캐릭터, 기록보관소 and 환경설정; '?' opens the rules
/// and the profile chip opens 환경설정 too.
///
/// The lobby fits the screen: RepBot takes the height the rest leaves,
/// between [repBotMinScale] and [repBotMaxScale] of its design size, and
/// the page scrolls only when RepBot at its least still does not fit.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.createViewModel, this.onLogOut});

  /// The least share of [LobbyRepBot.designSize] RepBot shrinks to on a
  /// short screen or with a large text size, before the page scrolls.
  static const repBotMinScale = 0.6;

  /// The largest share RepBot grows to on a tall screen.
  static const repBotMaxScale = 1.2;

  /// Builds the view model; replaces the default one in tests.
  final HomeViewModel Function()? createViewModel;

  /// Logs out, from 환경설정 after the user confirms. No logout when null.
  final Future<void> Function()? onLogOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  late final HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.createViewModel?.call() ??
        HomeViewModel(repository: context.read<UserRepository>());
    _viewModel.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    GymRatsApp.routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  /// Home shows again after a battle, history or settings: the latest
  /// battle and the bests may have changed.
  @override
  void didPopNext() => _viewModel.load();

  @override
  void dispose() {
    GymRatsApp.routeObserver.unsubscribe(this);
    _viewModel.dispose();
    super.dispose();
  }

  /// 게임 시작 shares home's view model: the profile, the latest setup and
  /// what the AI 1v1 page chose.
  void _openPlay() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider<HomeViewModel>.value(
        value: _viewModel,
        child: const PlayScreen(),
      ),
    ),
  );

  /// 캐릭터 선택; what it saves is the app's character, not home's.
  void _openCharacter() =>
      Navigator.pushNamed(context, GymRatsApp.characterRoute);

  /// The battle history as its own page, with a back button.
  void _openArchive() => Navigator.pushNamed(context, GymRatsApp.historyRoute);

  /// The switches there are the app's; the nickname is the profile's.
  void _openSettings() {
    final name = _viewModel.state.profile!.name;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            SettingsScreen(nickname: name, onLogOut: widget.onLogOut),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>.value(
      value: _viewModel,
      child: Consumer<HomeViewModel>(
        builder: (context, vm, _) => switch (vm.state.phase) {
          HomePhase.loading => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          HomePhase.failed => Scaffold(
            body: _LoadFailed(message: vm.state.errorMessage, onRetry: vm.load),
          ),
          HomePhase.ready => LobbyPage.fill(
            behind: const SoundCues(
              music: MusicCue.menu,
              child: LobbyBackdrop(),
            ),
            above: [
              _TopBar(name: vm.state.profile!.name, onProfile: _openSettings),
              const SizedBox(height: AppSpacing.s16),
              const _Title(),
              if (vm.state.profile!.unsentMatches > 0) ...[
                const SizedBox(height: AppSpacing.s8),
                _UnsentNote(count: vm.state.profile!.unsentMatches),
              ],
            ],
            fill: const _RepBotSlot(),
            fillMinHeight:
                LobbyRepBot.designSize.height * HomeScreen.repBotMinScale,
            below: [
              LobbyMenuItem(tag: '01 / PLAY', title: '게임 시작', onTap: _openPlay),
              LobbyMenuItem(
                tag: '02 / CHARACTER',
                title: '캐릭터',
                onTap: _openCharacter,
              ),
              LobbyMenuItem(
                tag: '03 / ARCHIVE',
                title: '기록보관소',
                onTap: _openArchive,
              ),
              LobbyMenuItem(
                tag: '04 / SETTINGS',
                title: '환경설정',
                last: true,
                onTap: _openSettings,
              ),
            ],
          ),
        },
      ),
    );
  }
}

/// '?' on the left, the profile chip on the right.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.name, required this.onProfile});

  final String name;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        LobbySquareButton(
          icon: Icons.help_outline_rounded,
          tooltip: '게임 규칙',
          onPressed: () => Navigator.pushNamed(context, GymRatsApp.helpRoute),
        ),
        const SizedBox(width: AppSpacing.s12),
        // The chip ends at the right edge and may take all the room left.
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _ProfileChip(name: name, onTap: onProfile),
          ),
        ),
      ],
    );
  }
}

/// The user's nickname by a round avatar mark; opens 환경설정.
class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  /// The design's 44, raised to the least tap height a finger needs.
  static const _height = 48.0;
  static const _markSize = 34.0;
  static const _markEdge = 1.5;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$name 프로필, 환경설정 열기',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: AppColors.card,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: _height,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4,
                0,
                AppSpacing.s12,
                0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: _markSize,
                    height: _markSize,
                    // The user's lime with an ink edge, the icon in ink.
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.ink,
                        width: _markEdge,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.ink,
                      size: _markSize / 2,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.lobbyRowTitle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A slanted lime bar, "GYMMOUSE" (the app's name), and what the game is in
/// one line.
class _Title extends StatelessWidget {
  const _Title();

  static const _barWidth = 12.0;
  static const _barHeight = 40.0;
  static const _barEdge = 1.5;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LobbySkew(
              degrees: 14,
              alignment: Alignment.center,
              child: Container(
                width: _barWidth,
                height: _barHeight,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  border: Border.all(color: AppColors.ink, width: _barEdge),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: LobbySkew(
                  degrees: 10,
                  child: Text('GYMMOUSE', style: text.lobbyLogo),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Text('1V1', style: text.lobbyBadge),
            const SizedBox(width: AppSpacing.s8),
            Flexible(
              child: Text(
                '${battleDuration.inSeconds}초 실시간 운동 대결',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// RepBot at the bottom left of the room above the menu, as large as that
/// room allows but at most [HomeScreen.repBotMaxScale] of its design size,
/// keeping its shape; it sinks a little behind the menu's top line.
class _RepBotSlot extends StatelessWidget {
  const _RepBotSlot();

  static const _sink = 6.0;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Transform.translate(
        offset: const Offset(0, _sink),
        child: ConstrainedBox(
          constraints: BoxConstraints.loose(
            LobbyRepBot.designSize * HomeScreen.repBotMaxScale,
          ),
          child: AspectRatio(
            aspectRatio: LobbyRepBot.designSize.aspectRatio,
            child: const LobbyRepBot(),
          ),
        ),
      ),
    );
  }
}

/// Battles that are not on the server yet, as an amber chip with ink text:
/// they are retried on the next load, so the user knows the record is not
/// lost.
class _UnsentNote extends StatelessWidget {
  const _UnsentNote({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: AppHighlight.chip(AppColors.warning),
        child: Padding(
          padding: AppHighlight.chipPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppColors.ink),
              const SizedBox(width: AppSpacing.s8),
              Flexible(
                child: Text(
                  '저장하지 못한 경기 $count개 · 연결되면 다시 저장해요',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  /// Why loading failed; null for no extra line.
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('정보를 불러오지 못했어요', style: Theme.of(context).textTheme.titleMedium),
          if (message case final message?) ...[
            const SizedBox(height: AppSpacing.s8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s16),
          FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
