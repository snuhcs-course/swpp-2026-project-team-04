import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'battle_fx_motion.dart';

/// 결과 보기: the only way on once the battle has ended. Lime with an ink
/// edge and a soft lime glow under it, as wide as its words need but at
/// least [size], and growing with the system text size. It comes up as the
/// effect math says ([look]): fading in and growing to its size.
///
/// The battle screen puts it in the middle of the screen's lower half,
/// where the camera was (W2b end screen, option A).
class BattleResultButton extends StatelessWidget {
  const BattleResultButton({
    super.key,
    required this.look,
    required this.onPressed,
  });

  /// How far it has come up.
  final BattleFxResultButton look;

  /// Opens the result.
  final VoidCallback? onPressed;

  /// Its least size, as designed.
  static const size = Size(240, 58);

  static const _arrowSize = 26.0;
  static const _edge = 2.0;
  static const _glow = 0.22;
  static const _glowBlur = 36.0;
  static const _glowDrop = 14.0;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.cameraResult;
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
      side: BorderSide(color: AppColors.ink, width: _edge),
    );
    return Opacity(
      opacity: look.opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: look.scale,
        child: Semantics(
          container: true,
          button: true,
          label: '결과 보기',
          onTap: onPressed,
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.card),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: _glow),
                    blurRadius: _glowBlur,
                    offset: const Offset(0, _glowDrop),
                  ),
                ],
              ),
              child: Material(
                color: AppColors.accent,
                shape: shape,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  // As wide as its words need, at least the design's width,
                  // and never wider than the room it has.
                  child: IntrinsicWidth(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: size.width,
                        minHeight: size.height,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s24,
                          vertical: AppSpacing.s8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text('결과 보기', maxLines: 1, style: style),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: _arrowSize,
                              color: AppColors.ink,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
