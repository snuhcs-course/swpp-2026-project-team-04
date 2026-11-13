import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/matchup.dart';
import '../theme/app_theme.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../widgets/accent_button.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/exit_game_button.dart';
import '../widgets/grid_background.dart';
import '../widgets/player_avatar.dart';
import '../widgets/safe_warning_dialog.dart';

/// Shows who battles whom, the rules, and the button to the pose setup.
///
/// It has no view model: everything it shows comes from [matchup], and its
/// only behavior is navigation. It opens with the safety warning before
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
  });

  final Matchup matchup;

  /// Live matches use the same presentation without the offline route logic.
  final Future<void> Function()? onStartSetup;
  final Future<void> Function()? onLeave;
  final Duration duration;

  /// Closes the safety warning by itself after this long. Online matches
  /// set it, since the server's time to get ready keeps running; null waits
  /// for 확인.
  final Duration? warningAutoClose;

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

  @override
  Widget build(BuildContext context) {
    final matchup = widget.matchup;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askToLeave();
      },
      child: Scaffold(
        body: GridBackground(
          child: Column(
            children: [
              _PlayerSide(
                matchup: matchup,
                onExit: _askToLeave,
                duration: widget.duration,
              ),
              const Expanded(child: _VsBand()),
              _OpponentSide(
                opponent: matchup.opponent,
                exercise: matchup.exercise,
                onStartSetup: _startSetup,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The top part, on the user's tint: the header, then the user. The tint
/// runs under the status bar; the content stays below it.
class _PlayerSide extends StatelessWidget {
  const _PlayerSide({
    required this.matchup,
    required this.onExit,
    required this.duration,
  });

  final Matchup matchup;
  final VoidCallback onExit;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _Tint.player,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            children: [
              _Header(
                exercise: matchup.exercise,
                onExit: onExit,
                duration: duration,
              ),
              const SizedBox(height: 16),
              _PlayerRow(name: matchup.playerName),
            ],
          ),
        ),
      ),
    );
  }
}

/// The band between the two parts: "VS" over the diagonal split.
class _VsBand extends StatelessWidget {
  const _VsBand();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _SplitPainter(),
      child: Center(
        child: FittedBox(fit: BoxFit.scaleDown, child: _VsMark()),
      ),
    );
  }
}

/// The bottom part, on the opponent's tint: the opponent, the rules, and
/// the button to the pose setup. The tint runs under the navigation bar.
class _OpponentSide extends StatelessWidget {
  const _OpponentSide({
    required this.opponent,
    required this.exercise,
    required this.onStartSetup,
  });

  final Opponent opponent;
  final ExerciseType exercise;
  final VoidCallback onStartSetup;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _Tint.opponent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            children: [
              _OpponentRow(opponent: opponent),
              const SizedBox(height: 32),
              _RulesCard(exercise: exercise),
              const SizedBox(height: 16),
              AccentButton(title: '자세 세팅 시작', onPressed: onStartSetup),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faint tints over the grid: lime on the user's half, pink on the
/// opponent's.
abstract final class _Tint {
  static final player = AppColors.accent.withValues(alpha: 0.05);
  static final opponent = AppColors.opponent.withValues(alpha: 0.05);
}

/// Splits the middle band diagonally, rising to the right: the user's tint
/// above the line, the opponent's below.
class _SplitPainter extends CustomPainter {
  const _SplitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rise = (size.width * 0.13).clamp(0.0, size.height / 2);
    final left = Offset(0, size.height / 2 + rise);
    final right = Offset(size.width, size.height / 2 - rise);
    canvas
      ..drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(right.dx, right.dy)
          ..lineTo(left.dx, left.dy)
          ..close(),
        Paint()..color = _Tint.player,
      )
      ..drawPath(
        Path()
          ..moveTo(left.dx, left.dy)
          ..lineTo(right.dx, right.dy)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
        Paint()..color = _Tint.opponent,
      )
      ..drawLine(
        left,
        right,
        Paint()
          ..color = AppColors.textSecondary.withValues(alpha: 0.5)
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(_SplitPainter oldDelegate) => false;
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

/// The user's avatar, then "나" over their name.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        PlayerAvatar(color: AppColors.accent, name: name),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Side(label: '나', color: AppColors.accent, mine: true),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.headlineMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mirror of [_PlayerRow] for the opponent: right aligned, pink, and with
/// an "AI" tag for a bot.
class _OpponentRow extends StatelessWidget {
  const _OpponentRow({required this.opponent});

  final Opponent opponent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const _Side(label: '상대', color: AppColors.opponent, mine: false),
              const SizedBox(height: 4),
              // English names, like RepBot, use the number font.
              Text(
                opponent.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.displaySmall?.copyWith(fontSize: 28),
              ),
              if (opponent.isBot) ...[
                const SizedBox(height: 8),
                const _AiTag(),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        PlayerAvatar(
          color: AppColors.opponent,
          name: opponent.name,
          isBot: opponent.isBot,
        ),
      ],
    );
  }
}

/// "나" or "상대" in ink beside a swatch of the player's [color]: the
/// user's swatch first, the opponent's last (palette B: the color marks,
/// the text is ink).
class _Side extends StatelessWidget {
  const _Side({required this.label, required this.color, required this.mine});

  final String label;
  final Color color;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final swatch = SizedBox.square(
      dimension: AppHighlight.swatchSize,
      child: DecoratedBox(decoration: AppHighlight.swatch(color)),
    );
    final text = Text(
      label,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: mine
          ? [swatch, const SizedBox(width: AppHighlight.swatchGap), text]
          : [text, const SizedBox(width: AppHighlight.swatchGap), swatch],
    );
  }
}

/// "AI" in ink on a pink pill.
class _AiTag extends StatelessWidget {
  const _AiTag();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppHighlight.chip(AppColors.opponent, strength: 0.3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Text(
          'AI',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontFamily: AppFonts.number,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

/// Big slanted "VS" with a lime and a pink shadow.
class _VsMark extends StatelessWidget {
  const _VsMark();

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Room for the shadows.
      padding: const EdgeInsets.all(8),
      child: Text(
        'VS',
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
          fontSize: 76,
          height: 1,
          fontStyle: FontStyle.italic,
          letterSpacing: -2,
          color: AppColors.textPrimary,
          shadows: const [
            Shadow(color: AppColors.accent, offset: Offset(-5, 3)),
            Shadow(color: AppColors.opponent, offset: Offset(5, -1)),
          ],
        ),
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
