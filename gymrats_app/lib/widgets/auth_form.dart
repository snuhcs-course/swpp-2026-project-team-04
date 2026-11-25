import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A labeled text field of the login and sign-up forms, with its error
/// (amber, from the theme) or [helper] underneath.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.error,
    this.helper,
    this.obscure = false,
    this.autofillHints,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? error;
  final String? helper;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      enableSuggestions: !obscure,
      autocorrect: false,
      autofillHints: autofillHints,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: text.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        helperText: helper,
        helperStyle: text.bodySmall?.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}

/// A problem with the whole form, e.g. a wrong password or no network: an
/// amber icon and message.
class FormErrorMessage extends StatelessWidget {
  const FormErrorMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.warning),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.warning),
          ),
        ),
      ],
    );
  }
}

/// The back arrow and a title at the top of a pushed screen.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.onBack,
    this.showBack = true,
  });

  final String title;

  /// Defaults to popping this screen.
  final VoidCallback? onBack;

  // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
  /// False for a tab's own title, which has nothing to go back to.
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: showBack ? AppSpacing.s8 : AppSpacing.s20,
      ),
      child: Row(
        children: [
          // AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
          if (showBack) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: '뒤로',
              color: AppColors.textPrimary,
              onPressed: onBack ?? () => Navigator.maybePop(context),
            ),
            const SizedBox(width: AppSpacing.s4),
          ] else
            // Same height as the back button, so the title sits alike.
            const SizedBox(height: kMinInteractiveDimension),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// A centered message with an optional retry, like the home and matching
/// load-failed screens (1-2, 2-2).
class CenteredMessage extends StatelessWidget {
  const CenteredMessage({
    super.key,
    required this.title,
    this.detail,
    this.onRetry,
  });

  final String title;
  final String? detail;

  /// Shows a "다시 시도" button when set.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final detail = this.detail;
    final onRetry = this.onRetry;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: text.titleMedium),
            if (detail != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.s16),
              FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ],
        ),
      ),
    );
  }
}

/// The login screens' icons (P8), drawn from the design's 24 x 24 strokes.
enum AuthGlyph {
  /// The "!" of an error box (LoginS failBox).
  alert,

  /// The "!" of a field's error line, a little longer and thicker.
  fieldAlert,

  /// The circled "i" of the cancel line.
  info,
  close,
  arrow,
  back,
}

/// An [AuthGlyph] [size] wide in [color].
class AuthIcon extends StatelessWidget {
  const AuthIcon(
    this.glyph, {
    super.key,
    required this.size,
    this.color = AppColors.ink,
  });

  final AuthGlyph glyph;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _GlyphPainter(glyph, color),
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final AuthGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final (width, path) = switch (glyph) {
      AuthGlyph.alert => (
        2.8,
        Path()
          ..moveTo(12, 6)
          ..lineTo(12, 14)
          ..moveTo(12, 18)
          ..lineTo(12, 18.5),
      ),
      AuthGlyph.fieldAlert => (
        3.4,
        Path()
          ..moveTo(12, 5)
          ..lineTo(12, 14)
          ..moveTo(12, 19)
          ..lineTo(12, 19.5),
      ),
      AuthGlyph.info => (
        2.2,
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 9))
          ..moveTo(12, 11)
          ..lineTo(12, 16)
          ..moveTo(12, 7.5)
          ..lineTo(12, 8),
      ),
      AuthGlyph.close => (
        2.6,
        Path()
          ..moveTo(6, 6)
          ..lineTo(18, 18)
          ..moveTo(18, 6)
          ..lineTo(6, 18),
      ),
      AuthGlyph.arrow => (
        2.6,
        Path()
          ..moveTo(5, 12)
          ..lineTo(19, 12)
          ..moveTo(13, 6)
          ..lineTo(19, 12)
          ..lineTo(13, 18),
      ),
      AuthGlyph.back => (
        2.6,
        Path()
          ..moveTo(15, 6)
          ..lineTo(9, 12)
          ..lineTo(15, 18),
      ),
    };
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

/// The turning ring of a login in progress (LoginS spin): a [track] circle
/// with an ink quarter on it, one turn a second; still when the device asks
/// for less motion.
class AuthSpinner extends StatefulWidget {
  const AuthSpinner({super.key, this.track = AppColors.border});

  final Color track;

  @override
  State<AuthSpinner> createState() => _AuthSpinnerState();
}

class _AuthSpinnerState extends State<AuthSpinner>
    with SingleTickerProviderStateMixin {
  late final _turns = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _turns.stop();
    } else if (!_turns.isAnimating) {
      _turns.repeat();
    }
  }

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _turns,
    child: CustomPaint(
      size: const Size.square(AuthLayout.spinner),
      painter: _SpinnerPainter(widget.track),
    ),
  );
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.track);

  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final ring = Rect.fromCircle(center: const Offset(12, 12), radius: 9);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(ring, paint..color = track);
    canvas.drawArc(
      ring,
      -math.pi / 2,
      math.pi / 2,
      false,
      paint..color = AppColors.ink,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) => oldDelegate.track != track;
}

/// The white "Google로 시작하기" button with its "G" (LoginB), or the
/// spinner while [busy]. Null [onPressed] greys its words and ignores taps.
class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ink = onPressed == null ? AuthColors.busyText : AppColors.ink;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.card,
        disabledBackgroundColor: AppColors.card,
        foregroundColor: AppColors.ink,
        disabledForegroundColor: AuthColors.busyText,
        minimumSize: const Size.fromHeight(AuthLayout.googleHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        side: const BorderSide(color: AppColors.ink, width: AuthLayout.edge),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AuthLayout.googleRadius),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: AuthLayout.markBox,
            child: Center(
              child: busy
                  ? const AuthSpinner()
                  : ExcludeSemantics(
                      child: Text(
                        'G',
                        style: text.authMark.copyWith(color: ink),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AuthLayout.gap),
          Flexible(
            child: AuthWords(
              label,
              textAlign: TextAlign.center,
              style: text.authButton.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// An underlined link ("아이디로 로그인", "처음이신가요? 회원가입"), grey
/// and lighter when [onPressed] is null.
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = AuthLayout.linkHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? AuthColors.busyLink
        : AppColors.textSecondary;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size.fromHeight(height),
        foregroundColor: AppColors.textSecondary,
        disabledForegroundColor: AuthColors.busyLink,
      ),
      child: AuthWords(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.authLink
            .copyWith(color: color, decorationColor: color),
      ),
    );
  }
}

/// The grey "로그인을 취소했어요" line (LoginS C2), told to a screen reader.
class AuthNotice extends StatelessWidget {
  const AuthNotice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AuthLayout.noticeBelow),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AuthIcon(
              AuthGlyph.info,
              size: AuthLayout.noticeIcon,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AuthLayout.iconGap),
            Flexible(
              child: AuthWords(
                message,
                style: Theme.of(context).textTheme.authLabel.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The first sentence of [message] and the rest; the rest is null for one
/// sentence.
(String, String?) splitFirstSentence(String message) {
  final match = RegExp(
    r'^(.+?[.!?])\s+(\S.*)$',
    dotAll: true,
  ).firstMatch(message.trim());
  if (match == null) return (message.trim(), null);
  return (match[1]!, match[2]!);
}

/// A failure above the button (LoginS F1): a white box with an amber "!",
/// the message's first sentence in bold and the rest small and grey, told
/// to a screen reader.
class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (first, rest) = splitFirstSentence(message);
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.all(
            Radius.circular(AuthLayout.errorRadius),
          ),
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.ink, width: AuthLayout.edge),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AuthLayout.errorPadV,
            horizontal: AuthLayout.errorPadH,
          ),
          child: Row(
            children: [
              const _AlertMark(
                box: AuthLayout.errorMark,
                radius: AuthLayout.errorMarkRadius,
                edge: AuthLayout.edge,
                glyph: AuthGlyph.alert,
                icon: AuthLayout.errorMarkIcon,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuthWords(first, style: text.authErrorTitle),
                    if (rest != null) ...[
                      const SizedBox(height: AuthLayout.errorLineGap),
                      AuthWords(rest, style: text.authSmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A field's or a form's problem on one line under it (LoginS iderr,
/// nickerr): a small amber "!" and ink words, told to a screen reader.
class AuthFieldError extends StatelessWidget {
  const AuthFieldError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AlertMark(
            box: AuthLayout.fieldMark,
            radius: AuthLayout.fieldMarkRadius,
            edge: AuthLayout.thinEdge,
            glyph: AuthGlyph.fieldAlert,
            icon: AuthLayout.fieldMarkIcon,
          ),
          const SizedBox(width: AuthLayout.iconGap),
          Expanded(
            child: AuthWords(
              message,
              style: Theme.of(context).textTheme.authLabel
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertMark extends StatelessWidget {
  const _AlertMark({
    required this.box,
    required this.radius,
    required this.edge,
    required this.glyph,
    required this.icon,
  });

  final double box;
  final double radius;
  final double edge;
  final AuthGlyph glyph;
  final double icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.ink, width: edge),
        ),
      ),
      child: AuthIcon(glyph, size: icon),
    );
  }
}

/// The lime button with an arrow (로그인, 시작하기); while [busy] it turns
/// pale with a spinner and [busyLabel], and does nothing.
class AuthLimeButton extends StatelessWidget {
  const AuthLimeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
  });

  final String label;
  final VoidCallback onPressed;
  final bool busy;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        disabledBackgroundColor: AuthColors.busyLime,
        foregroundColor: AppColors.ink,
        disabledForegroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(AuthLayout.limeHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        side: const BorderSide(color: AppColors.ink, width: AuthLayout.edge),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy) ...[
            const AuthSpinner(track: AppColors.card),
            const SizedBox(width: AppSpacing.s8),
          ],
          Flexible(
            child: AuthWords(
              busy ? busyLabel ?? label : label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.authLime,
            ),
          ),
          if (!busy) ...[
            const SizedBox(width: AuthLayout.iconGap),
            const AuthIcon(AuthGlyph.arrow, size: AuthLayout.limeIcon),
          ],
        ],
      ),
    );
  }
}

/// A white round button with a stroke icon: the sign-up screen's back
/// (44) and the id sheet's close (40). The tap area stays the app's 48.
class AuthRoundButton extends StatelessWidget {
  const AuthRoundButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
    required this.size,
    required this.icon,
  });

  final AuthGlyph glyph;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;
  final double icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.card,
        fixedSize: Size.square(size),
        minimumSize: Size.square(size),
        padding: EdgeInsets.zero,
        side: const BorderSide(
          color: AppColors.ink,
          width: AuthLayout.thinEdge,
        ),
        shape: const CircleBorder(),
      ),
      icon: AuthIcon(glyph, size: icon),
    );
  }
}

/// A field's name above it (아이디, 비밀번호, 닉네임); the field itself
/// tells a screen reader.
class AuthLabel extends StatelessWidget {
  const AuthLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AuthWords(text, style: Theme.of(context).textTheme.authLabel),
  );
}

/// The design's text field: a white box with an ink edge, the typed text
/// at 17, and an optional [trailing] (the nickname's count). [label] names
/// it for a screen reader; the screen shows it with [AuthLabel].
class AuthInputField extends StatelessWidget {
  const AuthInputField({
    super.key,
    required this.controller,
    required this.label,
    this.height = AuthLayout.fieldHeight,
    this.obscure = false,
    this.autofillHints,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
  });

  final TextEditingController controller;
  final String label;
  final double height;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final trailing = this.trailing;
    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.all(Radius.circular(AuthLayout.fieldRadius)),
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.ink, width: AuthLayout.edge),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: label,
              child: TextField(
                controller: controller,
                obscureText: obscure,
                enableSuggestions: !obscure,
                autocorrect: false,
                autofillHints: autofillHints,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                inputFormatters: inputFormatters,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                style: obscure ? text.authSecret : text.authField,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.s8),
            trailing,
          ],
        ],
      ),
    );
  }
}

/// The word joiner (U+2060): no line break on either side, nothing drawn.
const _wordJoiner = '⁠';

/// [text] with a word joiner between the letters of each word, so a line
/// breaks only at a space. Without it Flutter breaks Korean between any
/// two syllables ("실패했어 / 요."). For drawing only: screen readers and
/// finders keep [text] (see [AuthWords]).
String keepWordsWhole(String text) {
  final out = StringBuffer();
  var previousIsLetter = false;
  for (final c in text.characters) {
    final isLetter = c.trim().isNotEmpty;
    if (previousIsLetter && isLetter) out.write(_wordJoiner);
    out.write(c);
    previousIsLetter = isLetter;
  }
  return out.toString();
}

/// [text] as drawn in [maxWidth], with words kept whole
/// ([keepWordsWhole]). When the words need exactly two lines, the break
/// goes at the space that makes the longer line the shortest (on a tie the
/// later space, as Flutter's own wrapping would), as CSS
/// `text-wrap: balance` does ("Google로 / 로그인하는 중…", not "Google로
/// 로그인하는 / 중…"). [widthOf] measures one line.
String authLines(
  String text, {
  required double maxWidth,
  required double Function(String line) widthOf,
}) {
  final words = text.split(' ');
  if (!maxWidth.isFinite || words.length < 2 || widthOf(text) <= maxWidth) {
    return keepWordsWhole(text);
  }
  // Lines at spaces, each as full as fits (Flutter's own wrapping).
  var lines = 1;
  var line = words.first;
  for (final word in words.skip(1)) {
    final longer = '$line $word';
    if (widthOf(longer) <= maxWidth) {
      line = longer;
    } else {
      lines++;
      line = word;
    }
  }
  if (lines != 2) return keepWordsWhole(text);
  String? best;
  var bestWidth = double.infinity;
  for (var i = 1; i < words.length; i++) {
    final first = words.sublist(0, i).join(' ');
    final second = words.sublist(i).join(' ');
    final wider = math.max(widthOf(first), widthOf(second));
    if (wider <= maxWidth && wider <= bestWidth) {
      bestWidth = wider;
      best = '${keepWordsWhole(first)}\n${keepWordsWhole(second)}';
    }
  }
  return best ?? keepWordsWhole(text);
}

/// The login screens' words: a [Text] whose lines break only at spaces,
/// two lines balanced ([authLines]). Its [data] stays as written, so a
/// screen reader reads the sentence and `find.text` finds it.
class AuthWords extends Text {
  const AuthWords(super.data, {super.key, super.style, super.textAlign});

  @override
  Widget build(BuildContext context) {
    final text = data!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        );
        // Measured as Text draws it, bold when the device asks for bold text.
        var lineStyle = DefaultTextStyle.of(context).style.merge(style);
        if (MediaQuery.boldTextOf(context)) {
          lineStyle = lineStyle.merge(
            const TextStyle(fontWeight: FontWeight.bold),
          );
        }
        final drawn = authLines(
          text,
          maxWidth: constraints.maxWidth,
          widthOf: (line) {
            painter
              ..text = TextSpan(text: line, style: lineStyle)
              ..layout();
            return painter.width;
          },
        );
        painter.dispose();
        return Text(
          drawn,
          style: style,
          textAlign: textAlign,
          semanticsLabel: semanticsLabel ?? text,
        ).build(context);
      },
    );
  }
}
