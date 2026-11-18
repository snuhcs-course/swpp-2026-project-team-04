import 'package:flutter/material.dart';

import '../services/feedback/coach_script.dart';
import '../theme/app_theme.dart';
import 'lobby_parts.dart';

/// The character's name on a slanted lime band with an ink edge inside
/// (A10 spec 2 and 3): Do Hyeon on the report's card ([small]) and over
/// the dialog box.
class CoachNameTag extends StatelessWidget {
  const CoachNameTag({super.key, required this.name, this.small = false});

  final String name;

  /// The report card's tag: 28 high, a 2 edge, 19 letters; else 40, 3 and
  /// 25.
  final bool small;

  static const bandLean = 12.0;
  static const _height = 40.0;
  static const _smallHeight = 28.0;
  static const _edge = 3.0;
  static const _smallEdge = 2.0;
  static const _padding = 18.0;
  static const _smallPadding = AppSpacing.s12;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = small ? text.coachCardName : text.coachName;
    final scale =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) /
        style.fontSize!;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: (small ? _smallHeight : _height) * scale,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: LobbySkew(
              degrees: bandLean,
              alignment: Alignment.center,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  border: Border.all(
                    color: AppColors.ink,
                    width: small ? _smallEdge : _edge,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: small ? _smallPadding : _padding,
            ),
            child: Text(name, maxLines: 1, softWrap: false, style: style),
          ),
        ],
      ),
    );
  }
}

/// [pieces] as one paragraph whose marked runs are bold on the lime
/// highlighter: lime behind the lower 42% of the letters, as the design's
/// `linear-gradient(transparent 58%, lime 58%)`. Lines break only between
/// words (`word-break: keep-all`).
class CoachMarkedText extends StatelessWidget {
  const CoachMarkedText({super.key, required this.pieces, required this.style});

  final List<CoachPiece> pieces;
  final TextStyle style;

  /// Where the lime starts, from the top of a line's letters.
  static const markFrom = 0.58;

  /// [text] with a word joiner between the letters of each word, so a line
  /// breaks only at the spaces. A screen reader is given the plain text.
  static String keepWords(String text) {
    final out = StringBuffer();
    String? last;
    for (final rune in text.runes) {
      final letter = String.fromCharCode(rune);
      if (last != null && last != ' ' && letter != ' ') out.write(_joiner);
      out.write(letter);
      last = letter;
    }
    return out.toString();
  }

  static const _joiner = '⁠';

  @override
  Widget build(BuildContext context) {
    final marked = style.copyWith(fontWeight: FontWeight.w700);
    final spans = <TextSpan>[];
    String? before;
    for (final piece in pieces) {
      if (piece.text.isEmpty) continue;
      var shown = keepWords(piece.text);
      // A joiner between two pieces too, so a mark inside a word keeps the
      // word whole.
      if (before != null &&
          !before.endsWith(' ') &&
          !piece.text.startsWith(' ')) {
        shown = '$_joiner$shown';
      }
      spans.add(TextSpan(text: shown, style: piece.marked ? marked : null));
      before = piece.text;
    }
    final span = TextSpan(style: style, children: spans);
    return CustomPaint(
      painter: _MarkPainter(
        span: span,
        marks: _ranges(spans),
        scaler: MediaQuery.textScalerOf(context),
      ),
      child: Text.rich(span),
    );
  }

  /// The letters of each marked span, as offsets into the paragraph.
  static List<TextRange> _ranges(List<TextSpan> spans) {
    final ranges = <TextRange>[];
    var at = 0;
    for (final span in spans) {
      final text = span.text ?? '';
      if (span.style != null && text.isNotEmpty) {
        ranges.add(TextRange(start: at, end: at + text.length));
      }
      at += text.length;
    }
    return ranges;
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.span, required this.marks, required this.scaler});

  final TextSpan span;
  final List<TextRange> marks;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    if (marks.isEmpty) return;
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: size.width);
    final paint = Paint()..color = AppColors.accent;
    for (final range in marks) {
      for (final box in painter.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
      )) {
        final rect = box.toRect();
        canvas.drawRect(
          Rect.fromLTRB(
            rect.left,
            rect.top + rect.height * CoachMarkedText.markFrom,
            rect.right,
            rect.bottom,
          ),
          paint,
        );
      }
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.span != span || old.scaler != scaler || old.marks != marks;
}

/// One dot per page of the talk: the page now a 20 ink bar, the pages
/// before it 8 gray, the ones after 8 light (A10 spec 3).
class CoachPageDots extends StatelessWidget {
  const CoachPageDots({super.key, required this.count, required this.current});

  final int count;
  final int current;

  static const height = 8.0;
  static const _wide = 20.0;
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          Container(
            key: ValueKey('coach-dot-$i'),
            width: i == current ? _wide : height,
            height: height,
            decoration: BoxDecoration(
              color: i == current
                  ? AppColors.ink
                  : i < current
                  ? AppColors.textMuted
                  : AppColors.border,
              borderRadius: const BorderRadius.all(Radius.circular(height / 2)),
            ),
          ),
        ],
      ],
    );
  }
}

/// A goal the character offers: a white button with an ink edge, an empty
/// round mark, the title and its line under it; '사양할래' ([decline]) is
/// a quieter button without the mark (A10 spec 3).
class CoachChoiceButton extends StatelessWidget {
  const CoachChoiceButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.subtitle,
    this.decline = false,
  });

  final String title;
  final String? subtitle;
  final bool decline;
  final VoidCallback onPressed;

  static const _minHeight = 58.0;
  static const _declineHeight = 44.0;
  static const _edge = 2.5;
  static const _declineEdge = 1.5;
  static const _radius = 18.0;
  static const _markSize = 20.0;
  static const _markGap = 10.0;
  static const _rightPadding = 14.0;
  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.s12,
    AppSpacing.s8,
    _rightPadding,
    AppSpacing.s8,
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitle = this.subtitle;
    return Semantics(
      button: true,
      label: [title, ?subtitle].join(', '),
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: decline ? AppColors.facetLight : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(_radius)),
          side: BorderSide(
            color: decline ? AppColors.textMuted : AppColors.ink,
            width: decline ? _declineEdge : _edge,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: decline ? _declineHeight : _minHeight,
            ),
            child: Padding(
              padding: _padding,
              child: Row(
                children: [
                  if (!decline) ...[
                    Container(
                      width: _markSize,
                      height: _markSize,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ink, width: _edge),
                      ),
                    ),
                    const SizedBox(width: _markGap),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: text.coachChoice),
                        if (subtitle != null && subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: text.coachSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
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

/// The lime target icon of the goal tag (the design's three rings).
class CoachTargetIcon extends StatelessWidget {
  const CoachTargetIcon({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _TargetPainter()),
  );
}

class _TargetPainter extends CustomPainter {
  const _TargetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // The design's 24 box: rings of 8.5 and 4.5 and a dot of 0.8, stroke 2.4.
    final unit = size.width / 24;
    final center = size.center(Offset.zero);
    final stroke = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * unit;
    canvas
      ..drawCircle(center, 8.5 * unit, stroke)
      ..drawCircle(center, 4.5 * unit, stroke)
      ..drawCircle(center, 0.8 * unit, stroke);
  }

  @override
  bool shouldRepaint(_TargetPainter oldDelegate) => false;
}
