import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A red edge around the screen that flashes while [active]: the user is
/// about to lose. It takes no taps.
///
/// It flashes slower than once a second. With the system's animations off it
/// stays lit.
class GameDangerEdge extends StatefulWidget {
  const GameDangerEdge({super.key, required this.active});

  final bool active;

  @override
  State<GameDangerEdge> createState() => _GameDangerEdgeState();
}

class _GameDangerEdgeState extends State<GameDangerEdge>
    with SingleTickerProviderStateMixin {
  static const _edgeWidth = 6.0;
  static const _glowDepth = 36.0;
  static const _dimmest = 0.25;

  late final AnimationController _flash = AnimationController(
    vsync: this,
    lowerBound: _dimmest,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(GameDangerEdge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      _flash.repeat(reverse: true);
    } else {
      _flash.stop();
      _flash.value = _flash.upperBound;
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        label: '위험, 곧 질 수 있어요',
        child: FadeTransition(
          opacity: _flash,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _glowDepth,
                child: _Glow(from: Alignment.topCenter),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _glowDepth,
                child: _Glow(from: Alignment.bottomCenter),
              ),
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _glowDepth,
                child: _Glow(from: Alignment.centerLeft),
              ),
              const Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: _glowDepth,
                child: _Glow(from: Alignment.centerRight),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.danger,
                    width: _edgeWidth,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Red that fades away from the side [from] towards the inside.
class _Glow extends StatelessWidget {
  const _Glow({required this.from});

  final Alignment from;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: from,
          end: -from,
          colors: [
            AppColors.danger.withValues(alpha: 0.5),
            AppColors.danger.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
