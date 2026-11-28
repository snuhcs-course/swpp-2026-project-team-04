import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'lobby_parts.dart';

/// This week on an ink banner (A13 design `RankD1`): the week's name in
/// lime ("11월 4주차") over its dates, the time left on an orange flag, and
/// how much of the week has gone by as a lime bar along the bottom.
///
/// Without a week ([weekName] null, while the ranking is read or could not
/// be), the banner keeps its place with an empty bar and no words.
///
/// Its words follow the system text size up to [maxTextScale]: past it the
/// flag would leave no room for the week on a narrow phone.
class WeeklyRankingsBanner extends StatelessWidget {
  const WeeklyRankingsBanner({
    super.key,
    this.weekName,
    this.dates,
    this.timeLeft,
    this.progress = 0,
  });

  final String? weekName;

  /// "11.23 (월) – 11.29 (일)".
  final String? dates;

  /// "1일 9시간 남음".
  final String? timeLeft;

  /// How much of the week has gone by, 0 to 1.
  final double progress;

  static const height = 62.0;
  static const barHeight = 5.0;
  static const _corner = 14.0;
  static const _top = 10.0;
  static const _left = 14.0;
  static const _right = AppSpacing.s12;

  /// Below the words, above the bar: room for a large system text size.
  static const _bottom = barHeight + AppSpacing.s4;
  static const _nameGap = 2.0;
  static const _trackShade = 0.14;

  /// The largest system text size the banner's words take.
  static const maxTextScale = 1.3;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: maxTextScale,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = weekName;
    final words = [name, dates, timeLeft].whereType<String>().join(', ');
    return Semantics(
      container: true,
      label: words.isEmpty ? null : words,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: height),
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.all(Radius.circular(_corner)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(_left, _top, _right, _bottom),
              child: name == null
                  ? const SizedBox(width: double.infinity)
                  : Row(
                      children: [
                        // The week gives way on a narrow phone; the time
                        // left keeps its size.
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LobbySkew(
                                  degrees: 8,
                                  child: Text(
                                    name,
                                    style: text.rankingWeekName.copyWith(
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: _nameGap),
                                if (dates case final dates?)
                                  Text(
                                    dates,
                                    style: text.rankingSmall.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.pictogramFloor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        if (timeLeft case final left?) WeeklyRankingsFlag(left),
                      ],
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: barHeight,
              child: ColoredBox(
                color: AppColors.card.withValues(alpha: _trackShade),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: const ColoredBox(color: AppColors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The time left on an orange flag slanted 8 px at both ends, a clock
/// before it.
class WeeklyRankingsFlag extends StatelessWidget {
  const WeeklyRankingsFlag(this.timeLeft, {super.key});

  final String timeLeft;

  static const height = 30.0;
  static const slant = 8.0;
  static const _side = AppSpacing.s12;
  static const _icon = 14.0;
  static const _gap = 5.0;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _FlagClipper(slant),
      child: Container(
        constraints: const BoxConstraints(minHeight: height),
        color: AppColors.warning,
        padding: const EdgeInsets.symmetric(horizontal: _side),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: _icon,
              color: AppColors.ink,
            ),
            const SizedBox(width: _gap),
            Text(
              timeLeft,
              maxLines: 1,
              style: Theme.of(context).textTheme.rankingExerciseTab
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// `polygon(8px 0, 100% 0, calc(100% - 8px) 100%, 0 100%)`.
class _FlagClipper extends CustomClipper<Path> {
  const _FlagClipper(this.slant);

  final double slant;

  @override
  Path getClip(Size size) => Path()
    ..addPolygon([
      Offset(slant, 0),
      Offset(size.width, 0),
      Offset(size.width - slant, size.height),
      Offset(0, size.height),
    ], true);

  @override
  bool shouldReclip(_FlagClipper oldClipper) => oldClipper.slant != slant;
}
