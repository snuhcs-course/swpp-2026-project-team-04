import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_theme.dart';

/// Slants [child] like italics by [degrees], pivoting on its bottom-left
/// corner (the design's `skewX(-deg)` with `transform-origin: left bottom`).
class LobbySkew extends StatelessWidget {
  const LobbySkew({
    super.key,
    required this.degrees,
    required this.child,
    this.alignment = Alignment.bottomLeft,
  });

  final double degrees;
  final Widget child;

  /// The point that stays put.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Transform(
    alignment: alignment,
    transform: Matrix4.skewX(-degrees * math.pi / 180),
    child: child,
  );
}

/// The frame of a game-style page: [behind] fills the screen under the
/// content, which stays clear of the status bar and the navigation bar.
/// When the screen is too short for [children], the page scrolls; otherwise
/// a child in an [Expanded] takes the room left.
class LobbyPage extends StatelessWidget {
  const LobbyPage({super.key, this.behind, required this.children})
    : fill = null,
      fillMinHeight = 0,
      below = const [];

  /// Home's frame: [above], then [fill], then [below]. [fill] takes the
  /// height the others leave on the screen, but at least [fillMinHeight];
  /// only when even that does not fit, the page scrolls ([LobbyFillColumn]).
  const LobbyPage.fill({
    super.key,
    this.behind,
    required List<Widget> above,
    required Widget this.fill,
    required this.fillMinHeight,
    required this.below,
  }) : children = above;

  final Widget? behind;

  /// Top to bottom; with [fill], the ones above it.
  final List<Widget> children;

  /// What takes the room left, between [children] and [below]; null for a
  /// plain column.
  final Widget? fill;

  /// The least height [fill] gets.
  final double fillMinHeight;

  /// The ones under [fill].
  final List<Widget> below;

  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.s20,
    AppSpacing.s4,
    AppSpacing.s20,
    AppSpacing.s24,
  );

  @override
  Widget build(BuildContext context) {
    final behind = this.behind;
    final fill = this.fill;
    return Scaffold(
      body: Stack(
        children: [
          ?behind,
          SafeArea(
            // The height left under the status bar, above the navigation
            // bar and any bar the page sits on.
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: _padding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, box.maxHeight - _padding.vertical),
                  ),
                  child: fill == null
                      ? IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: children,
                          ),
                        )
                      : LobbyFillColumn(
                          above: children,
                          fill: fill,
                          fillMinHeight: fillMinHeight,
                          below: below,
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

/// [above], [fill] and [below] top to bottom, each as wide as the column.
/// [fill] takes what the others leave of the least height the column is
/// given (on a page, the screen's), but at least [fillMinHeight]; when even
/// that does not fit, the column grows past it, so put it where it may grow,
/// such as in a scroll view.
///
/// It measures the others by laying them out. An [Expanded] under an
/// [IntrinsicHeight] would be given too much room: a [FittedBox] that
/// shrinks a title on a narrow screen or with large text still reports its
/// unshrunk height there, and the page would scroll with room to spare.
class LobbyFillColumn extends MultiChildRenderObjectWidget {
  LobbyFillColumn({
    super.key,
    List<Widget> above = const [],
    required Widget fill,
    required this.fillMinHeight,
    List<Widget> below = const [],
  }) : fillIndex = above.length,
       super(children: [...above, fill, ...below]);

  /// The least height the fill gets.
  final double fillMinHeight;

  /// Where the fill is among [children].
  final int fillIndex;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLobbyFillColumn(fillIndex, fillMinHeight);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderLobbyFillColumn)
      ..fillIndex = fillIndex
      ..fillMinHeight = fillMinHeight;
  }
}

class _FillParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderLobbyFillColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FillParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FillParentData> {
  _RenderLobbyFillColumn(this._fillIndex, this._fillMinHeight);

  int get fillIndex => _fillIndex;
  int _fillIndex;
  set fillIndex(int value) {
    if (value == _fillIndex) return;
    _fillIndex = value;
    markNeedsLayout();
  }

  double get fillMinHeight => _fillMinHeight;
  double _fillMinHeight;
  set fillMinHeight(double value) {
    if (value == _fillMinHeight) return;
    _fillMinHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FillParentData) {
      child.parentData = _FillParentData();
    }
  }

  /// Lays out every child with [layoutChild] (or only measures them, for a
  /// dry layout) and returns the column's size.
  Size _layout(BoxConstraints constraints, ChildLayouter layoutChild) {
    assert(constraints.hasBoundedWidth);
    final width = constraints.maxWidth;
    final others = BoxConstraints.tightFor(width: width);
    var othersHeight = 0.0;
    RenderBox? fill;
    var index = 0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (index++ == fillIndex) {
        fill = child;
      } else {
        othersHeight += layoutChild(child, others).height;
      }
    }
    if (fill == null) return constraints.constrain(Size(width, othersHeight));
    // The column's height first, then the fill gets the rest: adding the
    // rest back to the others could land a rounding step past the least
    // height, and a page that fits would scroll by it.
    final height = math.max(
      othersHeight + fillMinHeight,
      constraints.minHeight,
    );
    layoutChild(
      fill,
      BoxConstraints.tightFor(width: width, height: height - othersHeight),
    );
    return constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild);

  @override
  void performLayout() {
    size = _layout(constraints, ChildLayoutHelper.layoutChild);
    var top = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      (child.parentData! as _FillParentData).offset = Offset(0, top);
      top += child.size.height;
    }
  }

  /// The children's heights for [width] added up; the fill counts as its
  /// least height.
  double _heights(double Function(RenderBox child) heightOf) {
    var sum = 0.0;
    var index = 0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      sum += index++ == fillIndex ? fillMinHeight : heightOf(child);
    }
    return sum;
  }

  double _widest(double Function(RenderBox child) widthOf) {
    var widest = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      widest = math.max(widest, widthOf(child));
    }
    return widest;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _widest((child) => child.getMinIntrinsicWidth(double.infinity));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _widest((child) => child.getMaxIntrinsicWidth(double.infinity));

  @override
  double computeMinIntrinsicHeight(double width) =>
      _heights((child) => child.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _heights((child) => child.getMaxIntrinsicHeight(width));

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// Home's backdrop: two large slanted facets in the top right, one lighter
/// and one darker than the screen.
class LobbyBackdrop extends StatelessWidget {
  const LobbyBackdrop({super.key});

  @override
  Widget build(BuildContext context) =>
      const Positioned.fill(child: CustomPaint(painter: _BackdropPainter()));
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // The design's polygons, as shares of the screen's width and height.
    Offset at(double x, double y) => Offset(x * size.width, y * size.height);
    canvas
      ..drawPath(
        Path()..addPolygon([
          at(0.34, 0),
          at(1, 0),
          at(1, 0.30),
          at(0.66, 0.19),
        ], true),
        Paint()..color = AppColors.facetLight,
      )
      ..drawPath(
        Path()..addPolygon([at(0.66, 0.19), at(1, 0.30), at(1, 0.54)], true),
        Paint()..color = AppColors.facetDark,
      );
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => false;
}

/// A page's name as a huge faint word in the top right, running off the
/// edge, e.g. "PLAY". Only decoration: a screen reader skips it.
class LobbyWatermark extends StatelessWidget {
  const LobbyWatermark(this.word, {super.key, required this.left});

  final String word;

  /// Where the word starts, from the screen's left edge.
  final double left;

  /// From the top of the screen, status bar included.
  static const _top = 62.0;
  static const _height = 120.0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: _top,
      height: _height,
      child: ExcludeSemantics(
        child: LobbySkew(
          degrees: 10,
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.fitHeight,
            child: Text(
              word,
              maxLines: 1,
              softWrap: false,
              style: Theme.of(context).textTheme.lobbyWatermark
                  .copyWith(color: AppColors.facetDark),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 44-point square button with a border and one icon: back, or '?'. Its
/// tap area reaches 48 points, the least a finger needs.
class LobbySquareButton extends StatelessWidget {
  const LobbySquareButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;

  /// Also what a screen reader says.
  final String tooltip;
  final VoidCallback onPressed;

  /// What shows; the tap area is larger.
  static const size = 44.0;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      color: AppColors.line,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(size),
        minimumSize: const Size.square(size),
        tapTargetSize: MaterialTapTargetSize.padded,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      icon: Icon(icon),
    );
  }
}

/// A small spaced-out label such as "01 / PLAY", in [color].
class LobbyTag extends StatelessWidget {
  const LobbyTag(this.text, {super.key, this.color = AppColors.textSecondary});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.lobbyTag.copyWith(color: color),
  );
}

/// The top of a page opened from home: a back button and the page's tag,
/// then its slanted [title].
class LobbyPageHeader extends StatelessWidget {
  const LobbyPageHeader({
    super.key,
    required this.tag,
    required this.title,
    this.tagColor = AppColors.textPrimary,
  });

  final String tag;
  final String title;
  final Color tagColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LobbySquareButton(
              icon: Icons.chevron_left_rounded,
              tooltip: '뒤로',
              onPressed: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: AppSpacing.s12),
            Flexible(child: LobbyTag(tag, color: tagColor)),
          ],
        ),
        const SizedBox(height: AppSpacing.s20),
        Semantics(
          header: true,
          child: LobbySkew(
            degrees: 10,
            child: Text(
              title,
              style: Theme.of(context).textTheme.lobbyPageTitle,
            ),
          ),
        ),
      ],
    );
  }
}

/// A rounded square of [color] with an ink edge and an ink arrow: "this
/// starts something". Color fills, the arrow stays ink (palette B).
class LobbyArrowChip extends StatelessWidget {
  const LobbyArrowChip({
    super.key,
    this.color = AppColors.accent,
    this.size = defaultSize,
    this.icon = Icons.arrow_forward_rounded,
  });

  /// The fill: lime for the user's things, pink for the AI's.
  final Color color;
  final double size;
  final IconData icon;

  static const defaultSize = 32.0;
  static const _edge = 1.5;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
        border: Border.all(color: AppColors.ink, width: _edge),
      ),
      child: Icon(icon, color: AppColors.ink, size: size / 2),
    );
  }
}
