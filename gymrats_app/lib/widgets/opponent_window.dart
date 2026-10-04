import 'package:flutter/material.dart';

import '../models/matchup.dart';
import '../theme/app_theme.dart';
import 'opponent_mannequin.dart';

/// The opponent's small window in the battle: the mannequin over their
/// name, an AI tag for a bot, and a LIVE light.
class OpponentWindow extends StatelessWidget {
  const OpponentWindow({
    super.key,
    required this.opponent,
    required this.moves,
    required this.live,
    this.scale = 1,
  });

  final Opponent opponent;

  /// How many reps the opponent has made; the mannequin dips for each.
  final int moves;

  /// Whether the round is on; the LIVE light blinks meanwhile.
  final bool live;

  /// 1 on a phone like the design's; smaller with a short camera.
  final double scale;

  static const _width = 142.0;
  static const _radius = BorderRadius.all(Radius.circular(18));

  /// The design's near-black pink: a trace of pink over the background.
  static final _surface = Color.alphaBlend(
    AppColors.opponent.withValues(alpha: 0.05),
    AppColors.background,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width * scale,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.background.withValues(alpha: 0.45),
            offset: const Offset(0, 10),
            blurRadius: 28,
          ),
        ],
      ),
      // In front, so the mannequin does not paint over the edge.
      foregroundDecoration: BoxDecoration(
        borderRadius: _radius,
        border: Border.all(color: AppColors.opponent.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 142 / 128,
            child: OpponentMannequin(moves: moves),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.opponent.withValues(alpha: 0.25),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          opponent.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (opponent.isBot) ...[
                        const SizedBox(width: 6),
                        const _AiTag(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  _LiveLight(live: live),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "AI" in light pink on a pink pill.
class _AiTag extends StatelessWidget {
  const _AiTag();

  /// The design's light pink: the opponent's pink toward white.
  static final _lightPink = Color.lerp(
    AppColors.opponent,
    AppColors.textPrimary,
    0.3,
  )!;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.opponent.withValues(alpha: 0.18),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        child: Text(
          'AI',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _lightPink,
          ),
        ),
      ),
    );
  }
}

/// "LIVE" after a pink dot that blinks while the opponent plays.
class _LiveLight extends StatefulWidget {
  const _LiveLight({required this.live});

  final bool live;

  @override
  State<_LiveLight> createState() => _LiveLightState();
}

class _LiveLightState extends State<_LiveLight>
    with SingleTickerProviderStateMixin {
  /// Half a blink: the dot brightens, then dims on the way back.
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  late final Animation<double> _opacity = Tween(
    begin: 0.3,
    end: 1.0,
  ).chain(CurveTween(curve: Curves.easeInOut)).animate(_blink);

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(_LiveLight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.live != oldWidget.live) _follow();
  }

  /// Blinks while live; otherwise stays lit and still.
  void _follow() {
    if (widget.live) {
      _blink.repeat(reverse: true);
    } else {
      _blink.value = 1;
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _opacity,
          child: const SizedBox.square(
            dimension: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.opponent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          'LIVE',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
