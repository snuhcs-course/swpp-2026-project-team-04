import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Asks before leaving the match flow: an ink exit icon on a faint pink
/// circle when upright, [title] over [message], a big lime 계속하기 button
/// with an ink edge and an ink [leaveLabel] one (palette B: color only
/// fills, text is ink).
///
/// Pops true for [leaveLabel], false for 계속하기.
class ExitDialog extends StatelessWidget {
  const ExitDialog({
    super.key,
    required this.title,
    required this.message,
    required this.leaveLabel,
  });

  /// For leaving a found match, on the versus and setup screens.
  ExitDialog.game({super.key, required String opponentName})
    : title = '게임에서 나갈까요?',
      message = gameMessage(opponentName),
      leaveLabel = '게임 나가기';

  /// For leaving the search, on the matching screen.
  const ExitDialog.matching({super.key})
    : title = '매칭을 취소할까요?',
      message = '상대 찾기를 멈추고\n홈으로 돌아가요.',
      leaveLabel = '매칭 취소';

  final String title;

  /// Line breaks are written into it: Korean would otherwise break inside
  /// a word.
  final String message;

  final String leaveLabel;

  /// The first and last Hangul syllables in Unicode.
  static const _firstSyllable = 0xAC00;
  static const _lastSyllable = 0xD7A3;

  /// Syllables per first and middle letter: one with no final letter, then
  /// one for each final letter.
  static const _finalLetters = 28;

  /// The most [_lineWidth] may read for a line to stay whole. The dialog has
  /// 248 for its text on a 360 wide phone: this keeps a margin.
  static const _lineRoom = 240.0;

  /// What leaving a found match does, for an opponent called [opponentName].
  /// A name that would push the first line past the dialog's width gets a line
  /// of its own, so the line does not break inside a word. That holds for an
  /// ASCII or Hangul name of up to 12 letters, on a phone at least 360 wide at
  /// the default text size: with larger text, on a narrower phone, or with a
  /// name of many emoji, a line can still wrap.
  static String gameMessage(String opponentName) {
    final named = '${_withParticle(opponentName)}의';
    const cancelled = '대결이 취소되고';
    const home = '홈으로 돌아가요.';
    return _lineWidth('$named $cancelled') <= _lineRoom
        ? '$named $cancelled\n$home'
        : '$named\n$cancelled\n$home';
  }

  /// About how wide [line] is in the message's text style.
  static double _lineWidth(String line) =>
      line.runes.fold(0, (width, letter) => width + _letterWidth(letter));

  /// The widest letter of [letter]'s group, measured in the app's font, so a
  /// line reads a little wider than it is. An emoji's width depends on the
  /// phone: the last number is a guess on the wide side.
  static double _letterWidth(int letter) {
    final text = String.fromCharCode(letter);
    if (" !',.ijl".contains(text)) return 5.1;
    if ('()-:;[]{}|/\\ftrI·'.contains(text)) return 7.5;
    if ('mwMW@%'.contains(text)) return 15.5;
    if (letter >= 0x61 && letter <= 0x7A) return 9.8;
    if (letter >= 0x30 && letter <= 0x39) return 10.2;
    if (letter < 0x7F) return 12;
    return letter >= _firstSyllable && letter <= _lastSyllable ? 14.8 : 21;
  }

  /// [name] with its particle. Only a Hangul syllable tells which one fits:
  /// 초보와, 진영과. Any other ending takes 님, which always fits 과: Mike 님과.
  /// No name is the opponent: 상대와.
  static String _withParticle(String name) {
    if (name.isEmpty) return '상대와';
    final last = name.codeUnitAt(name.length - 1);
    if (last < _firstSyllable || last > _lastSyllable) return '$name 님과';
    return (last - _firstSyllable) % _finalLetters == 0 ? '$name와' : '$name과';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final buttonText = text.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        side: BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        // Phone sized even when setup turns the screen sideways.
        constraints: const BoxConstraints(maxWidth: 360),
        // Scrolls rather than overflow on a short landscape screen.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A sideways screen is short: without the icon, both answers
              // show at once.
              if (MediaQuery.orientationOf(context) ==
                  Orientation.portrait) ...[
                const _ExitIcon(),
                const SizedBox(height: 18),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.leaveDialogTitle,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context, false),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    side: BorderSide(color: AppColors.ink, width: 2),
                  ),
                  textStyle: buttonText,
                ),
                child: const Text('계속하기'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppColors.ink,
                  textStyle: buttonText,
                ),
                child: Text(leaveLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The exit icon in ink on a faint pink circle.
class _ExitIcon extends StatelessWidget {
  const _ExitIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.opponent.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.logout_rounded, size: 26, color: AppColors.ink),
      ),
    );
  }
}

/// Shows [dialog]. True only for its leave button: the stay button, a tap
/// outside, or back while it is open all mean stay.
Future<bool> confirmExit(BuildContext context, ExitDialog dialog) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (_) => dialog,
  );
  return leave ?? false;
}

/// Leaves the matching flow: closes every screen above home.
///
/// These are plain pops, which `PopScope(canPop: false)` does not stop; it
/// only hears about them, with `didPop` true.
void popToHome(BuildContext context) =>
    Navigator.popUntil(context, (route) => route.isFirst);
