import 'package:flutter/material.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../models/matchup.dart';
import '../theme/app_theme.dart';
import '../widgets/accent_button.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/exit_game_button.dart';
import '../widgets/grid_background.dart';
import '../widgets/player_avatar.dart';

/// Shows who battles whom, the rules, and the button to the pose setup.
///
/// It has no view model: everything it shows comes from [matchup], and its
/// only behavior is navigation. Back and the 게임 나가기 button at the top
/// left both ask before going home. When setup finishes, the battle screen
/// replaces this one, so going back from the battle leads home.
class VersusScreen extends StatefulWidget {
  const VersusScreen({super.key, required this.matchup});

  final Matchup matchup;

  @override
  State<VersusScreen> createState() => _VersusScreenState();
}

class _VersusScreenState extends State<VersusScreen> {
  /// Set while the setup screen is open, so a second tap does nothing.
  bool _settingUp = false;

  /// Opens the pose setup. MatchSetupScreen returns the exercise when the
  /// user is ready, or null if it closes without one; then this screen
  /// stays. (Its 게임 나가기 closes this screen as well.)
  Future<void> _startSetup() async {
    if (_settingUp) return;
    _settingUp = true;
    final exercise = await Navigator.pushNamed<ExerciseType>(
      context,
      GymRatsApp.matchSetupRoute,
      arguments: widget.matchup,
    );
    if (!mounted) return;
    if (exercise == null) {
      _settingUp = false;
      return;
    }
    Navigator.pushReplacementNamed(
      context,
      GymRatsApp.battleRoute,
      arguments: widget.matchup,
    );
  }

  /// Asks before leaving, on a back attempt or the 게임 나가기 button.
  Future<void> _askToLeave() async {
    final leave = await confirmExit(
      context,
      ExitDialog.game(opponentName: widget.matchup.opponent.name),
    );
    if (!mounted) return;
    if (leave) popToHome(context);
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
              _PlayerSide(matchup: matchup, onExit: _askToLeave),
              const Expanded(child: _VsBand()),
              _OpponentSide(
                opponent: matchup.opponent,
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
  const _PlayerSide({required this.matchup, required this.onExit});

  final Matchup matchup;
  final VoidCallback onExit;

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
              _Header(exercise: matchup.exercise, onExit: onExit),
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
  const _OpponentSide({required this.opponent, required this.onStartSetup});

  final Opponent opponent;
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
              const _RulesCard(),
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
  static final player = AppColors.accent.withValues(alpha: 0.04);
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
  const _Header({required this.exercise, required this.onExit});

  final ExerciseType exercise;
  final VoidCallback onExit;

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
              Text(
                'MATCH FOUND',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.displaySmall?.copyWith(
                  fontSize: 15,
                  letterSpacing: 3,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${exercise.koreanName} · ${battleDuration.inSeconds}초',
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
              Text(
                '나',
                style: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
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
              Text(
                '상대',
                style: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.opponent,
                ),
              ),
              const SizedBox(height: 4),
              // English names, like RepBot, use the number font.
              Text(
                opponent.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.displaySmall?.copyWith(fontSize: 28),
              ),
              if (opponent.isBot) ...[const SizedBox(height: 8), const _AiTag()],
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

/// "AI" in pink on a faint pink pill.
class _AiTag extends StatelessWidget {
  const _AiTag();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.opponent.withValues(alpha: 0.14),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Text(
          'AI',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontFamily: AppFonts.number,
            fontWeight: FontWeight.w700,
            color: AppColors.opponent,
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
  const _RulesCard();

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
        Icon(icon, size: 22, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(rule, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
