import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/character_idle_motion.dart';
import '../models/character_rig.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/matchup.dart';
import '../theme/app_theme.dart';
import '../viewmodels/character_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../widgets/accent_button.dart';
import '../widgets/battle_fighter.dart';
import '../widgets/battle_fx_motion.dart';
import '../widgets/battle_stage_model.dart';
import '../widgets/character_figure.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/exit_game_button.dart';
import '../widgets/grid_background.dart';
import '../widgets/safe_warning_dialog.dart';

/// Shows who battles whom, the rules, and the button to the pose setup.
///
/// Who battles whom is one board (W2b 2-A3): the user's lime cell over the
/// opponent's pink one, each player's character on a pedestal beside their
/// name, and "VS" between them.
///
/// It has no view model: everything it shows comes from [matchup] and the
/// two characters ([characters], or the app's [CharacterViewModel] choice
/// against RepBot), and its only behavior is navigation. It opens with the safety warning before
/// every match while 환경설정's '매 경기 안전 안내' is on; off, only until the
/// warning was seen once ([SettingsViewModel.safetyNotice]). The setup
/// button works once the warning has closed, or at once without it. Back
/// and the 게임 나가기 button at the top left both ask before going home. The setup
/// button opens the battle screen, which starts with the pose setup, in
/// this one's place, so going back from the battle leads home.
class VersusScreen extends StatefulWidget {
  const VersusScreen({
    super.key,
    required this.matchup,
    this.onStartSetup,
    this.onLeave,
    this.duration = battleDuration,
    this.warningAutoClose,
    this.characters,
  });

  final Matchup matchup;

  /// The two players' characters (W3). Null takes the user's from the
  /// app's choice ([CharacterViewModel]; the default character without
  /// one), and RepBot for a bot opponent. The online lobby gives both: the
  /// one sent and the one the server passed on for the opponent.
  final BattleCharacters? characters;

  /// Live matches use the same presentation without the offline route logic.
  final Future<void> Function()? onStartSetup;
  final Future<void> Function()? onLeave;
  final Duration duration;

  /// Closes the safety warning by itself after this long. Online matches
  /// set it, since the server's time to get ready keeps running; null waits
  /// for 확인.
  final Duration? warningAutoClose;

  /// The size a player's character and pedestal are drawn at, around the
  /// feet, in a color cell [cellHeight] tall: full size from 189 up (8
  /// above the highest a character reaches, 151 over its feet, and the 30
  /// under them), then smaller with the cell, down to 0.6.
  static double characterScale(double cellHeight) =>
      ((cellHeight - _belowFeet - _aboveHead) / _characterReach).clamp(
        _smallest,
        1.0,
      );
  static const _belowFeet = 30.0;
  static const _aboveHead = 8.0;
  static const _characterReach = 151.0;
  static const _smallest = 0.6;

  @override
  State<VersusScreen> createState() => _VersusScreenState();
}

class _VersusScreenState extends State<VersusScreen> {
  /// Set once the setup button opened the battle (or, online, while the
  /// lobby's setup runs), so a second tap does nothing.
  bool _settingUp = false;

  /// Set once the safety warning has closed; the setup waits for it.
  bool _warned = false;

  /// Set once the warning has been scheduled, so it opens once per screen.
  bool _warningScheduled = false;

  /// Opens the warning once this screen is on top. Online, a match can be
  /// found while the lobby's "cancel matching?" dialog is open; the warning
  /// then waits until that dialog has closed, and does not open at all if
  /// the user cancels. Being on top again re-runs this method.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_warningScheduled || !(ModalRoute.isCurrentOf(context) ?? true)) {
      return;
    }
    _warningScheduled = true;
    // After the frame, so the warning opens over this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _warn());
  }

  /// The open safety warning, so that closing this screen closes it too.
  Route<bool>? _warning;

  /// Shows the safety warning until it is seen, unless the settings say
  /// this match goes without it. Back on it asks whether to leave, as back
  /// on this screen does; staying shows it again. Removed any other way (a
  /// logout closes every screen), it asks nothing. Seen to its end (확인,
  /// or online by itself), it counts as seen in the settings.
  Future<void> _warn() async {
    if (!mounted) return;
    // The app's settings; without them (some tests, demos) it always shows.
    final settings = context.read<SettingsViewModel?>();
    if (settings != null && !settings.safetyNotice.showsBeforeMatch) {
      _warned = true;
      return;
    }
    while (true) {
      if (!mounted) return;
      final route = safeWarningRoute(
        context,
        autoClose: widget.warningAutoClose,
      );
      _warning = route;
      final seen = await Navigator.of(context, rootNavigator: true).push(route);
      _warning = null;
      if (!mounted) return;
      if (seen == true) {
        _warned = true;
        settings?.markSafetyNoticeSeen();
        return;
      }
      if (seen == null || !(ModalRoute.of(context)?.isActive ?? false)) return;
      // Leaving starts closing this screen, but it is still mounted until
      // the route has gone, so stop here rather than check mounted.
      if (await _askToLeave()) return;
    }
  }

  /// Online, a cancelled match rebuilds the lobby without this screen while
  /// the warning may still be open over it: close the warning too, after
  /// the frame, since the navigator may not change during a build.
  @override
  void dispose() {
    final warning = _warning;
    final navigator = warning?.navigator;
    if (warning != null && navigator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (warning.isActive) navigator.removeRoute(warning);
      });
    }
    super.dispose();
  }

  /// Opens the pose setup: the battle screen, which sets up on its stage
  /// before the round, in this screen's place.
  Future<void> _startSetup() async {
    if (_settingUp || !_warned) return;
    _settingUp = true;
    if (widget.onStartSetup case final start?) {
      try {
        await start();
      } finally {
        _settingUp = false;
      }
      return;
    }
    Navigator.pushReplacementNamed(
      context,
      GymRatsApp.battleRoute,
      arguments: widget.matchup,
    );
  }

  /// Asks before leaving, on a back attempt or the 게임 나가기 button. True
  /// when the user chose to leave.
  Future<bool> _askToLeave() async {
    final leave = await confirmExit(
      context,
      ExitDialog.game(opponentName: widget.matchup.opponent.name),
    );
    if (!mounted) return leave;
    if (leave) {
      if (widget.onLeave case final leaveMatch?) {
        await leaveMatch();
      } else {
        popToHome(context);
      }
    }
    return leave;
  }

  /// Who stands on the board: as given, or the user's choice against
  /// RepBot (or the default character for an opponent of unknown choice).
  BattleCharacters _characters(BuildContext context) =>
      widget.characters ??
      BattleCharacters(
        me:
            context.watch<CharacterViewModel?>()?.characterId ??
            CharacterRig.defaultId,
        opponent: widget.matchup.opponent.isBot
            ? CharacterRig.botId
            : CharacterRig.defaultId,
      );

  @override
  Widget build(BuildContext context) {
    final matchup = widget.matchup;
    final characters = _characters(context);
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askToLeave();
      },
      child: Scaffold(
        body: GridBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AppSpacing.s12,
                AppSpacing.s20,
                AppSpacing.s24,
              ),
              child: Column(
                children: [
                  _Header(
                    exercise: matchup.exercise,
                    onExit: _askToLeave,
                    duration: widget.duration,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  // Takes all the height the rules leave, so longer rules
                  // (push-ups) make it lower.
                  Expanded(
                    child: _MatchupBoard(
                      matchup: matchup,
                      characters: characters,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  _RulesCard(exercise: matchup.exercise),
                  const SizedBox(height: AppSpacing.s16),
                  AccentButton(title: '자세 세팅 시작', onPressed: _startSetup),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 게임 나가기 button on the left; "MATCH FOUND" over the exercise and
/// length on the right.
class _Header extends StatelessWidget {
  const _Header({
    required this.exercise,
    required this.onExit,
    required this.duration,
  });

  final ExerciseType exercise;
  final VoidCallback onExit;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        ExitGameButton(onPressed: onExit),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Ink on a slanted lime band, slanted with it (palette B).
              Transform(
                transform: AppHighlight.slant,
                alignment: Alignment.center,
                child: DecoratedBox(
                  decoration: AppHighlight.band(AppColors.accent),
                  child: Padding(
                    padding: AppHighlight.tightBandPadding,
                    child: Text(
                      'MATCH FOUND',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.displaySmall?.copyWith(
                        fontSize: 15,
                        letterSpacing: 3,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${exercise.koreanName} · ${duration.inSeconds}초',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The two players face to face (W2b 2-A3): the user on a lime cell above,
/// the opponent on a pink one below, an ink line between them and a white
/// "VS" disc over its middle, all inside one ink-edged box.
///
/// The characters move from the moment the board appears, each with its
/// own idle motion and the opponent's running the rig's 230 ms later, as on
/// the stage ([BattleCharacters.cast]), also under the safety warning; with
/// the system's reduced motion they stand still.
class _MatchupBoard extends StatefulWidget {
  const _MatchupBoard({required this.matchup, required this.characters});

  final Matchup matchup;
  final BattleCharacters characters;

  @override
  State<_MatchupBoard> createState() => _MatchupBoardState();
}

class _MatchupBoardState extends State<_MatchupBoard>
    with SingleTickerProviderStateMixin {
  /// Milliseconds since the board appeared, while the characters move.
  final _clock = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _clock.value = elapsed.inMicroseconds / 1000,
  );
  bool _still = false;

  /// The box's ink edge, and the ink line between the cells.
  static const _edge = 2.0;
  static const _divider = 3.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchup = widget.matchup;
    final opponent = matchup.opponent;
    final characters = widget.characters;
    final cast = characters.cast;
    const corners = BorderRadius.all(Radius.circular(AppRadius.sheet));
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: const BoxDecoration(
        borderRadius: corners,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.ink, width: _edge),
        ),
      ),
      child: ClipRRect(
        borderRadius: corners,
        child: Padding(
          padding: const EdgeInsets.all(_edge),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  Expanded(
                    child: _PlayerCell(
                      side: BattleSide.me,
                      name: matchup.playerName,
                      characterId: characters.me,
                      cast: cast,
                      clock: _clock,
                      still: _still,
                    ),
                  ),
                  const SizedBox(
                    height: _divider,
                    width: double.infinity,
                    child: ColoredBox(color: AppColors.ink),
                  ),
                  Expanded(
                    child: _PlayerCell(
                      side: BattleSide.opponent,
                      name: opponent.name,
                      bot: opponent.isBot,
                      characterId: characters.opponent,
                      cast: cast,
                      clock: _clock,
                      still: _still,
                    ),
                  ),
                ],
              ),
              // Over both cells and the characters.
              const Center(child: _VsDisc()),
            ],
          ),
        ),
      ),
    );
  }
}

/// One player's color cell: their character on a white pedestal in the
/// cell's outer bottom corner (the user's on the left facing right, the
/// opponent's on the right facing left), and beside it "나" or "상대" over
/// the name, then "AI" for a bot. In a cell too low for the character the
/// character and its pedestal shrink around the feet
/// ([VersusScreen.characterScale]) and the words follow the character's
/// shrinking side, staying as far from it as at full size times the scale
/// (the user's choice of 2026-11-13: the spec's "146 x scale" would put
/// the words over a character shrunk around its feet).
class _PlayerCell extends StatelessWidget {
  const _PlayerCell({
    required this.side,
    required this.name,
    this.bot = false,
    required this.characterId,
    required this.cast,
    required this.clock,
    required this.still,
  });

  final BattleSide side;
  final String name;
  final bool bot;
  final String characterId;
  final BattleFxCast cast;
  final ValueListenable<double> clock;
  final bool still;

  /// The room the character takes beside the words, at full size.
  static const _characterRoom = 146.0;

  @override
  Widget build(BuildContext context) {
    final mine = side == BattleSide.me;
    return ColoredBox(
      color: mine ? AppColors.accent : AppColors.opponent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = VersusScreen.characterScale(constraints.maxHeight);
          // The feet stay where they are; the rest of the room shrinks.
          const feet = _VersusCharacter.foot;
          final room = feet.dx + (_characterRoom - feet.dx) * scale;
          return Stack(
            children: [
              Positioned(
                left: mine ? 0 : null,
                right: mine ? null : 0,
                bottom: _Figure.bottom,
                child: Transform.scale(
                  scale: scale,
                  alignment: _Figure.feet,
                  child: _Figure(
                    side: side,
                    characterId: characterId,
                    cast: cast,
                    clock: clock,
                    still: still,
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: mine ? room : AppSpacing.s16,
                    right: mine ? AppSpacing.s16 : room,
                  ),
                  child: _PlayerWords(side: side, name: name, bot: bot),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "나" or "상대" on a white pill, the name on one line under it (cut with
/// "…"), and for a bot "AI" on a pill under that; to the left for the
/// user, to the right for the opponent, in the middle of the cell's height.
/// A screen reader reads them as one: "나, 우현", "상대, RepBot, AI", with
/// the whole name.
class _PlayerWords extends StatelessWidget {
  const _PlayerWords({
    required this.side,
    required this.name,
    required this.bot,
  });

  final BattleSide side;
  final String name;
  final bool bot;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final mine = side == BattleSide.me;
    final align = mine ? Alignment.centerLeft : Alignment.centerRight;
    final label = mine ? '나' : '상대';
    return Semantics(
      container: true,
      label: [label, name, if (bot) 'AI'].join(', '),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: align,
          // A cell too low for the words (very large system text on a small
          // phone) shrinks them rather than let them overflow.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: align,
            child: SizedBox(
              width: constraints.maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  _Pill(
                    label: label,
                    style: text.versusSide,
                    inside: AppHighlight.tightBandPadding,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    name,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: text.versusName,
                  ),
                  if (bot) ...[
                    const SizedBox(height: AppSpacing.s4),
                    _Pill(
                      label: 'AI',
                      style: text.versusAiTag,
                      inside: AppHighlight.tagPadding,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [label] in ink on a white pill with an ink edge, [inside] the room
/// around it within the edge.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.style, required this.inside});

  final String label;
  final TextStyle style;
  final EdgeInsets inside;

  static const _edge = 1.5;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: AppColors.card,
        shape: StadiumBorder(
          side: BorderSide(color: AppColors.ink, width: _edge),
        ),
      ),
      child: Padding(
        padding: inside + const EdgeInsets.all(_edge),
        child: Text(label, style: style),
      ),
    );
  }
}

/// "VS" in ink on a white disc with a thick ink edge. Decoration only.
class _VsDisc extends StatelessWidget {
  const _VsDisc();

  static const _size = 80.0;
  static const _edge = 3.6;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _size,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.ink, width: _edge),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(_edge),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'VS',
                  style: Theme.of(context).textTheme.versusMark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A player's character standing on a white pedestal, at full size: the
/// character's box ([_VersusCharacter.size]) with the feet
/// ([_VersusCharacter.foot]) on the middle of the pedestal's top. The
/// character has a white edge ([_WhiteOutline]) that moves with it, drawn
/// over the pedestal's ink edge; the pedestal stays still and has none. The
/// opponent's character is mirrored to face left. [clock] runs its idle
/// motion as [cast] says for its [side]; it stands still when [still].
class _Figure extends StatelessWidget {
  const _Figure({
    required this.side,
    required this.characterId,
    required this.cast,
    required this.clock,
    required this.still,
  });

  final BattleSide side;
  final String characterId;
  final BattleFxCast cast;
  final ValueListenable<double> clock;
  final bool still;

  /// The character's box over the pedestal's lower part.
  static const _size = Size(140, 166);

  /// The pedestal's bottom above the cell's bottom.
  static const bottom = 14.0;

  /// The feet in [_size], as a fraction of it: the point the cell shrinks
  /// the figure around.
  static final feet = FractionalOffset(
    _VersusCharacter.foot.dx / _size.width,
    _VersusCharacter.foot.dy / _size.height,
  );

  static const _pedestal = Size(116, 16);
  static const _pedestalEdge = 3.0;

  @override
  Widget build(BuildContext context) {
    const foot = _VersusCharacter.foot;
    const character = _VersusCharacter.size;
    return SizedBox.fromSize(
      size: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: foot.dx - _pedestal.width / 2,
            top: foot.dy,
            width: _pedestal.width,
            height: _pedestal.height,
            child: const DecoratedBox(
              decoration: ShapeDecoration(
                color: AppColors.card,
                shape: StadiumBorder(
                  side: BorderSide(color: AppColors.ink, width: _pedestalEdge),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: character.width,
            height: character.height,
            // The feet are in the middle of the box, so mirroring around
            // the middle keeps them on the pedestal.
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(
                side == BattleSide.me ? 1 : -1,
                1,
                1,
              ),
              child: RepaintBoundary(
                child: ValueListenableBuilder<double>(
                  valueListenable: clock,
                  builder: (context, ms, _) => _WhiteOutline(
                    child: _VersusCharacter(
                      characterId: characterId,
                      side: side,
                      idle: still ? IdleSample.rest : cast.idleAt(side, ms),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [child] with a white edge [width] wide around its shape, as the design
/// draws it: the child turned all white and laid eight times, [width] away
/// in each direction and diagonal, under the child itself.
class _WhiteOutline extends StatelessWidget {
  const _WhiteOutline({required this.child});

  final Widget child;

  static const width = 2.5;

  /// The eight places the white copies lie.
  static final directions = [
    for (final dx in const [-width, 0.0, width])
      for (final dy in const [-width, 0.0, width])
        if (dx != 0 || dy != 0) Offset(dx, dy),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // One white layer for all eight copies.
        ExcludeSemantics(
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              AppColors.card,
              BlendMode.srcIn,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final offset in directions)
                  Transform.translate(offset: offset, child: child),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// The one place this screen draws a player's character (W3): the
/// character [characterId] in its idle pose and [side]'s team color, in
/// its [size] box facing right with the feet at [foot], moved about the
/// feet by its idle motion [idle] as on the stage (up, rock, stretch).
/// [_Figure] mirrors the opponent's, edges it white and stands it on its
/// pedestal. A screen reader reads it as a picture with the character's
/// name.
class _VersusCharacter extends StatelessWidget {
  const _VersusCharacter({
    required this.characterId,
    required this.side,
    required this.idle,
  });

  final String characterId;
  final BattleSide side;
  final IdleSample idle;

  /// The rig's box and feet, the stage fighters' (W3 spec 3).
  static const size = BattleFighter.size;
  static const foot = BattleFighter.foot;

  /// How [idle] moves a character facing right, about its feet: as the
  /// stage moves the user's (`BattleFxTimeline.frame`).
  static Matrix4 motion(IdleSample idle) =>
      Matrix4.translationValues(0, -idle.up, 0)
          .multiplied(Matrix4.rotationZ(idle.rockDeg * math.pi / 180))
          .multiplied(Matrix4.diagonal3Values(idle.scaleX, idle.scaleY, 1));

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: CharacterRig.standard.art(characterId).name,
      child: Transform(
        origin: foot,
        transform: motion(idle),
        child: CharacterFigure(characterId: characterId, side: side),
      ),
    );
  }
}

/// How a rep counts, and that each one beeps.
class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.exercise});

  final ExerciseType exercise;

  static const _bold = TextStyle(fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '경기 규칙',
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            if (exercise == ExerciseType.squat)
              const _RuleRow(
                icon: Icons.check_rounded,
                rule: TextSpan(text: '엉덩이를 무릎 가까이 내렸다가 일어서면 1회로 인정돼요.'),
              )
            else
              const _RuleRow(
                icon: Icons.check_rounded,
                rule: TextSpan(
                  children: [
                    TextSpan(text: '가슴을 '),
                    TextSpan(text: '충분히 내렸다가', style: _bold),
                    TextSpan(text: ' 팔을 '),
                    TextSpan(text: '끝까지 펴야', style: _bold),
                    TextSpan(text: ' 1회로 인정돼요.'),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            const _RuleRow(
              icon: Icons.volume_up_outlined,
              rule: TextSpan(text: '1회 인정될 때마다 효과음이 울려요.'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.icon, required this.rule});

  final IconData icon;
  final TextSpan rule;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.ink),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(rule, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
