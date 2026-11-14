import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/exercise_type_korean.dart';
import '../models/game_score.dart';
import '../models/match_record.dart';
import '../theme/app_theme.dart';
import 'archive_chart.dart';
import 'match_record_card.dart';

/// One battle in the archive (BArchive): the exercise's icon, "푸쉬업 · KO
/// 승", when and against whom, the user's score, and a lime "↑55" chip
/// when the battle raised the exercise's best. Tappable when [onTap] is set.
class ArchiveMatchRow extends StatelessWidget {
  const ArchiveMatchRow({
    super.key,
    required this.match,
    required this.now,
    this.bestGain,
    this.onTap,
  });

  final MatchRecord match;

  /// For "오늘" and "어제".
  final DateTime now;

  /// How much the battle beat the earlier best; null for no chip.
  final int? bestGain;
  final VoidCallback? onTap;

  static const minHeight = 56.0;
  static const _iconBox = 36.0;
  static const _iconBoxRadius = 10.0;
  static const _iconSize = 22.0;

  /// "푸쉬업 · KO 승", and " · 상대 나감" after a battle the opponent left.
  static String resultLine(MatchRecord match) {
    final ko = match.gameEnd == GameEnd.ko;
    final outcome = switch (match.outcome) {
      MatchOutcome.win => ko ? 'KO 승' : '승리',
      MatchOutcome.lose => ko ? 'KO 패' : '패배',
      MatchOutcome.draw => '무승부',
    };
    final left = match.opponentLeft ? ' · 상대 나감' : '';
    return '${match.exercise.koreanName} · $outcome$left';
  }

  /// "오늘 14:30", "어제 21:05", or "10월 15일 21:30", in the phone's time.
  static String whenLine(DateTime playedAt, DateTime now) {
    final time = playedAt.toLocal();
    final today = now.toLocal();
    final day = DateTime(time.year, time.month, time.day);
    String two(int n) => n.toString().padLeft(2, '0');
    final clock = '${two(time.hour)}:${two(time.minute)}';
    if (day == DateTime(today.year, today.month, today.day)) {
      return '오늘 $clock';
    }
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return '어제 $clock';
    }
    return formatPlayedAt(time);
  }

  /// "온라인 vs 닉네임" for an online battle, "vs RepBot 고수" otherwise
  /// (also when the server did not say which it was).
  static String opponentLine(MatchRecord match) => match.isOnline == true
      ? '온라인 vs ${match.opponentName}'
      : 'vs ${match.opponentName}';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final playedAt = match.playedAt;
    final quiet = text.bodySmall?.copyWith(color: AppColors.textMuted);
    final gain = bestGain;
    final opponent = Text(
      opponentLine(match),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: quiet,
    );
    // One node for a screen reader: the row's words and its tap.
    return MergeSemantics(
      child: Material(
        color: AppColors.card,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
          side: BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s4,
              ),
              child: Row(
                children: [
                  Container(
                    width: _iconBox,
                    height: _iconBox,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.facetLight,
                      borderRadius: BorderRadius.all(
                        Radius.circular(_iconBoxRadius),
                      ),
                    ),
                    child: ArchiveExerciseIcon(match.exercise, size: _iconSize),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          resultLine(match),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.lobbyRowTitle,
                        ),
                        if (playedAt == null)
                          opponent
                        else
                          ArchiveWhenAndOpponent(
                            time: Text(
                              whenLine(playedAt, now),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: quiet,
                            ),
                            dot: Text(' · ', maxLines: 1, style: quiet),
                            opponent: opponent,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Score(match: match),
                      if (gain != null) ...[
                        const SizedBox(height: AppSpacing.s4),
                        _GainChip(gain: gain),
                      ],
                    ],
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

/// The user's score; a battle saved before scores were kept shows its reps,
/// with a unit so they do not read as points.
class _Score extends StatelessWidget {
  const _Score({required this.match});

  final MatchRecord match;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = text.archiveScore.copyWith(color: AppColors.ink);
    final score = match.myScore;
    if (score != null) {
      return Text('$score', semanticsLabel: '$score점', style: style);
    }
    return Text.rich(
      TextSpan(
        text: '${match.myReps}',
        children: [
          TextSpan(
            text: '회',
            style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      style: style,
    );
  }
}

/// "↑55" in ink on a lime band: the battle set a new best by 55 points.
class _GainChip extends StatelessWidget {
  const _GainChip({required this.gain});

  final int gain;

  static const _radius = 6.0;
  static const _arrowSize = 12.0;
  static const _strength = 0.6;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '최고 기록 $gain점 경신',
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: const ValueKey('archive-gain-chip'),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: _strength),
            borderRadius: const BorderRadius.all(Radius.circular(_radius)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_upward_rounded,
                  size: _arrowSize,
                  color: AppColors.ink,
                ),
                Text(
                  '$gain',
                  style: Theme.of(context).textTheme.archiveRowGain
                      .copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "오늘 14:30 · vs RepBot 고수": the time, a dot and the opponent on one line
/// when they fit; otherwise the opponent goes under the time and the dot is
/// left out, so no line ends in it. Each is cut with "…" only when it alone
/// is wider than the line.
///
/// A render object rather than a [LayoutBuilder], so the archive's page can
/// still measure its height ([IntrinsicHeight] in [LobbyPage]).
class ArchiveWhenAndOpponent extends MultiChildRenderObjectWidget {
  ArchiveWhenAndOpponent({
    super.key,
    required Widget time,
    required Widget dot,
    required Widget opponent,
  }) : super(children: [time, dot, opponent]);

  @override
  RenderArchiveWhenAndOpponent createRenderObject(BuildContext context) =>
      RenderArchiveWhenAndOpponent();
}

class _PartParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays out [ArchiveWhenAndOpponent]'s three parts.
class RenderArchiveWhenAndOpponent extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PartParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PartParentData> {
  /// Whether the last layout put the opponent under the time.
  bool get split => _split;
  bool _split = false;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PartParentData) {
      child.parentData = _PartParentData();
    }
  }

  /// The time, the dot and the opponent.
  List<RenderBox> get _parts => getChildrenAsList();

  double _oneLineWidth(double height) =>
      _parts.fold(0, (sum, part) => sum + part.getMaxIntrinsicWidth(height));

  bool _fits(double width) => _oneLineWidth(double.infinity) <= width;

  @override
  double computeMinIntrinsicWidth(double height) {
    final [time, _, opponent] = _parts;
    return math.max(
      time.getMinIntrinsicWidth(height),
      opponent.getMinIntrinsicWidth(height),
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) => _oneLineWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => _heightFor(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _heightFor(width);

  double _heightFor(double width) {
    final [time, dot, opponent] = _parts;
    if (_fits(width)) {
      return [
        for (final part in [time, dot, opponent])
          part.getMaxIntrinsicHeight(width),
      ].reduce(math.max);
    }
    return time.getMaxIntrinsicHeight(width) +
        opponent.getMaxIntrinsicHeight(width);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final [time, dot, opponent] = _parts;
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);
    if (_fits(constraints.maxWidth)) {
      final sizes = [
        for (final part in [time, dot, opponent]) part.getDryLayout(loose),
      ];
      return constraints.constrain(
        Size(
          sizes.fold(0, (sum, size) => sum + size.width),
          sizes.map((size) => size.height).reduce(math.max),
        ),
      );
    }
    final top = time.getDryLayout(loose);
    final bottom = opponent.getDryLayout(loose);
    return constraints.constrain(
      Size(math.max(top.width, bottom.width), top.height + bottom.height),
    );
  }

  @override
  void performLayout() {
    final [time, dot, opponent] = _parts;
    final width = constraints.maxWidth;
    _split = !_fits(width);
    if (_split) {
      final loose = BoxConstraints(maxWidth: width);
      time.layout(loose, parentUsesSize: true);
      dot.layout(loose);
      opponent.layout(loose, parentUsesSize: true);
      _place(time, Offset.zero);
      _place(dot, Offset.zero);
      _place(opponent, Offset(0, time.size.height));
      size = constraints.constrain(
        Size(
          math.max(time.size.width, opponent.size.width),
          time.size.height + opponent.size.height,
        ),
      );
      return;
    }
    var x = 0.0;
    var height = 0.0;
    for (final part in [time, dot, opponent]) {
      part.layout(
        BoxConstraints(maxWidth: math.max(0, width - x)),
        parentUsesSize: true,
      );
      _place(part, Offset(x, 0));
      x += part.size.width;
      height = math.max(height, part.size.height);
    }
    size = constraints.constrain(Size(x, height));
  }

  static void _place(RenderBox part, Offset offset) =>
      (part.parentData! as _PartParentData).offset = offset;

  /// The dot only shows on one line.
  bool _shows(RenderBox part) => !_split || part != childAfter(firstChild!);

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final part in _parts) {
      if (!_shows(part)) continue;
      context.paintChild(
        part,
        (part.parentData! as _PartParentData).offset + offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    for (final part in _parts) {
      if (_shows(part)) visitor(part);
    }
  }
}
