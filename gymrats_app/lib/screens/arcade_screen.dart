import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/arcade_catalog.dart';
import '../models/arcade_progress.dart';
import '../models/arcade_stage.dart';
import '../models/character_rig.dart';
import '../theme/app_theme.dart';
import '../viewmodels/arcade_viewmodel.dart';
import '../viewmodels/character_viewmodel.dart';
import '../widgets/arcade_map.dart';
import '../widgets/arcade_parts.dart';
import '../widgets/arcade_stage_sheet.dart';
import '../widgets/lobby_parts.dart';
import 'arcade_flow.dart';
import 'hold_stage_screen.dart';

/// The arcade's home (P16 spec 4, design `ArcMap`): the header with the
/// stars got out of 72, the building's map, and the bar with the stage to
/// play and 도전.
///
/// It draws the account's progress from the app's [ArcadeViewModel]; until
/// it has been read only the header shows (spec 9). It opens scrolled so
/// the stage to play is about the middle of the view, at the top once all
/// 24 are cleared. Coming back to it from a stage it reads the progress
/// again, scrolls to the stage to play now, and opens the stage a result
/// asked for (다음 스테이지).
///
/// A fight stage opens its sheet, a boss match its intro and a hold stage
/// A4's hold screen ([ArcadeFlow.openHold]); a locked stage does nothing.
/// 다음 스테이지 on a hold's result opens the stage after it here.
class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({super.key, this.openHold});

  /// Opens a hold stage and tells how it was left; null opens A4's
  /// screen ([ArcadeFlow.openHold]). Tests put a stand-in here.
  final Future<HoldStageExit?> Function(
    BuildContext context,
    ArcadeHoldStage stage,
  )?
  openHold;

  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen> with RouteAware {
  final _scroll = ScrollController();
  late final ArcadeViewModel _arcade;

  /// The stage the map last scrolled to; null until the first scroll.
  int? _scrolledTo;
  ModalRoute<void>? _route;

  @override
  void initState() {
    super.initState();
    _arcade = context.read<ArcadeViewModel>()..addListener(_onProgress);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onProgress());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void> && route != _route) {
      _route = route;
      GymRatsApp.routeObserver.subscribe(this, route);
    }
  }

  /// Back from a stage: the progress may have changed.
  @override
  void didPopNext() {
    unawaited(_arcade.refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRequested());
  }

  @override
  void dispose() {
    GymRatsApp.routeObserver.unsubscribe(this);
    _arcade.removeListener(_onProgress);
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls to the stage to play when it is new: at once the first time,
  /// smoothly after a stage (at once with reduced motion).
  void _onProgress() {
    final progress = _arcade.progress;
    if (!mounted || progress == null) return;
    final marked = progress.currentStage;
    final target = marked ?? 0;
    if (_scrolledTo == target) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final first = _scrolledTo == null;
      _scrolledTo = target;
      final scale = context.size == null
          ? 1.0
          : context.size!.width / ArcadeMapLayout.width;
      final position = _scroll.position;
      final offset =
          (ArcadeMapLayout.scrollFor(
                    marked == null ? null : ArcadeCatalog.stage(marked),
                    position.viewportDimension / scale,
                  ) *
                  scale)
              .clamp(0.0, position.maxScrollExtent);
      if (first || MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(offset);
      } else {
        unawaited(
          _scroll.animateTo(
            offset,
            duration: _scrollTime,
            curve: Curves.easeInOut,
          ),
        );
      }
    });
  }

  static const _scrollTime = Duration(milliseconds: 450);

  /// Opens the stage a result asked for, once the map shows again.
  void _openRequested() {
    if (!mounted) return;
    final number = _arcade.takeRequest();
    if (number == null) return;
    _open(ArcadeCatalog.stage(number));
  }

  /// A tap on stage [stage], or 도전 for it.
  void _open(ArcadeStage stage) {
    final progress = _arcade.progress;
    if (progress == null || !progress.isOpen(stage.number)) return;
    switch (stage) {
      case ArcadeFightStage():
        unawaited(
          ArcadeStageSheet.show(
            context,
            stage: stage,
            best: progress.bestOf(stage.number),
            onChallenge: () => ArcadeFlow.openFight(context, stage),
            routeName: GymRatsApp.arcadeSheetRoute,
          ),
        );
      case ArcadeBossStage():
        ArcadeFlow.openBoss(context, stage);
      case ArcadeHoldStage():
        unawaited(_playHold(stage));
    }
  }

  /// Hold stage [stage], then, after its 다음 스테이지, the stage after it
  /// with the progress the hold kept.
  Future<void> _playHold(ArcadeHoldStage stage) async {
    final exit = await (widget.openHold ?? ArcadeFlow.openHold)(context, stage);
    if (!mounted || exit != HoldStageExit.nextStage) return;
    await _arcade.refresh();
    if (!mounted) return;
    _open(ArcadeCatalog.stage(stage.number + 1));
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ArcadeViewModel>().progress;
    final character =
        context.watch<CharacterViewModel?>()?.characterId ??
        CharacterRig.defaultId;
    final current = progress?.currentStage;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(stars: progress?.totalStars),
          Expanded(
            child: progress == null
                ? const SizedBox.expand()
                : LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      controller: _scroll,
                      child: ArcadeMap(
                        progress: progress,
                        myCharacter: character,
                        width: constraints.maxWidth,
                        scroll: _scroll,
                        onStage: _open,
                      ),
                    ),
                  ),
          ),
          if (current != null)
            _Bar(
              stage: ArcadeCatalog.stage(current),
              onChallenge: () => _open(ArcadeCatalog.stage(current)),
            ),
        ],
      ),
    );
  }
}

/// The map's header: back to 게임 시작, "PLAY / ARCADE" over "아케이드",
/// and the stars got out of 72 (until the progress is read, none). It does
/// not scroll with the map.
class _Header extends StatelessWidget {
  const _Header({required this.stars});

  final int? stars;

  static const _side = AppSpacing.s16;
  static const _below = 26.0;
  static const _edge = 2.0;
  static const _titleGap = 2.0;
  static const _pillTop = AppSpacing.s8;
  static const _pillHeight = 30.0;
  static const _pillSide = 10.0;
  static const _pillCorners = 10.0;
  static const _pillGap = 5.0;
  static const _star = 17.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stars = this.stars;
    return Container(
      padding: EdgeInsets.fromLTRB(
        _side,
        MediaQuery.paddingOf(context).top,
        _side,
        _below,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.ink, width: _edge),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LobbySquareButton(
            icon: Icons.chevron_left_rounded,
            tooltip: '게임 시작으로',
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PLAY / ARCADE', style: text.arcadeTag),
                const SizedBox(height: _titleGap),
                LobbySkew(
                  degrees: 8,
                  child: Semantics(
                    header: true,
                    child: Text('아케이드', style: text.arcadeTitle),
                  ),
                ),
              ],
            ),
          ),
          if (stars != null)
            Padding(
              padding: const EdgeInsets.only(top: _pillTop),
              child: Semantics(
                label: '별 $stars개, 72개 중',
                excludeSemantics: true,
                child: Container(
                  height: _pillHeight,
                  padding: const EdgeInsets.symmetric(horizontal: _pillSide),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(_pillCorners),
                    border: Border.all(color: AppColors.ink, width: _edge),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ArcadeGlyphIcon(ArcadeGlyph.star, size: _star),
                      const SizedBox(width: _pillGap),
                      Text('$stars', style: text.arcadeStarSum),
                      const SizedBox(width: _pillGap),
                      Text(
                        '/ ${ArcadeProgress.maxStars}',
                        style: text.arcadeStarMax,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The bar under the map: the stage to play's face, "STAGE 8 · 2F", its
/// title, and 도전, which opens it as a tap on its cell does. Gone once all
/// 24 are cleared.
class _Bar extends StatelessWidget {
  const _Bar({required this.stage, required this.onChallenge});

  final ArcadeStage stage;
  final VoidCallback onChallenge;

  static const _edge = 2.0;
  static const _top = 14.0;
  static const _side = AppSpacing.s16;
  static const _bottom = 22.0;
  static const _face = 50.0;
  static const _faceEdge = 2.5;
  static const _faceScale = 0.6;
  static const _buttonHeight = 52.0;
  static const _buttonGap = 6.0;
  static const _titleGap = 1.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        _side,
        _top,
        _side,
        _bottom + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(
          top: BorderSide(color: AppColors.ink, width: _edge),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: _face,
            height: _face,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: _faceEdge),
            ),
            child: ClipOval(
              child: ArcadeFace(
                id: stage.character,
                size: _face - 2 * _faceEdge,
                scale: _faceScale,
                owner: stage.kind == ArcadeStageKind.hold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ArcadeWords.stageTag(stage), style: text.arcadeBarTag),
                const SizedBox(height: _titleGap),
                Text(
                  ArcadeWords.title(stage),
                  style: text.arcadeBarTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          ArcadeDarkButton(
            label: '도전',
            onPressed: onChallenge,
            height: _buttonHeight,
            gap: _buttonGap,
            padding: AppSpacing.s16,
          ),
        ],
      ),
    );
  }
}
