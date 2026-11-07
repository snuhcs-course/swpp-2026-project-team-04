import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'lobby_parts.dart';

/// One kind of battle on the 게임 시작 page: a lime or pink band with the
/// two players facing off, then the battle's tag, name, a short line, what
/// it offers, and an arrow chip. The band takes the card's spare height.
class BattleModeCard extends StatelessWidget {
  const BattleModeCard({
    super.key,
    required this.tag,
    required this.title,
    required this.line,
    required this.offer,
    required this.color,
    required this.shade,
    required this.picture,
    required this.onTap,
    this.shadeRises = true,
  });

  /// e.g. "ONLINE 1V1".
  final String tag;

  /// e.g. "온라인 1v1".
  final String title;

  /// A short line; may hold a line break.
  final String line;

  /// What it offers, e.g. "푸쉬업 · 스쿼트".
  final String offer;

  /// The band's color, also the arrow's; [shade] is its slanted lower half.
  final Color color;
  final Color shade;

  /// Whether the slant rises to the right (else it falls).
  final bool shadeRises;

  final Widget picture;
  final VoidCallback onTap;

  /// The band's least height, when the screen is short.
  static const _bandMinHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // One sentence for a screen reader, which also loses the InkWell's tap.
    return Semantics(
      button: true,
      label: '$title, ${line.replaceAll('\n', ' ')}, $offer',
      onTap: onTap,
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _bandMinHeight),
                  child: CustomPaint(
                    painter: _BandPainter(color, shade, rises: shadeRises),
                    child: Center(child: picture),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s12,
                  AppSpacing.s16,
                  AppSpacing.s12,
                  AppSpacing.s12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag,
                      style: text.lobbyMiniTag.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: LobbySkew(
                        degrees: 10,
                        child: Text(title, style: text.lobbyCardTitle),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      line,
                      style: text.lobbyCardLine.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            offer,
                            style: text.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        LobbyArrowChip(color: color),
                      ],
                    ),
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

/// [color] with a slanted [shade] over its lower part.
class _BandPainter extends CustomPainter {
  const _BandPainter(this.color, this.shade, {required this.rises});

  final Color color;
  final Color shade;
  final bool rises;

  /// Where the slant meets the left and right edges, as shares of the
  /// height: the low end, then the high end.
  static const _low = 0.62;
  static const _high = 0.30;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final (left, right) = rises ? (_low, _high) : (_high, _low);
    canvas.drawPath(
      Path()..addPolygon([
        Offset(0, size.height * left),
        Offset(size.width, size.height * right),
        Offset(size.width, size.height),
        Offset(0, size.height),
      ], true),
      Paint()..color = shade,
    );
  }

  @override
  bool shouldRepaint(_BandPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.shade != shade ||
      oldDelegate.rises != rises;
}

/// The user facing the opponent across "VS", drawn in ink on the band.
class BattleModePicture extends StatelessWidget {
  const BattleModePicture._(this.opponent);

  /// Another person.
  const BattleModePicture.online() : this._(Icons.person_outline_rounded);

  /// RepBot.
  const BattleModePicture.bot() : this._(Icons.smart_toy_outlined);

  final IconData opponent;

  static const _iconSize = 46.0;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_outline_rounded,
            size: _iconSize,
            color: AppColors.ink,
          ),
          const SizedBox(width: AppSpacing.s4),
          LobbySkew(
            degrees: 10,
            alignment: Alignment.center,
            child: Text(
              'VS',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          Icon(opponent, size: _iconSize, color: AppColors.ink),
        ],
      ),
    );
  }
}
