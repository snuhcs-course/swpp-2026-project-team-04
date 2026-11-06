import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'lobby_parts.dart';

/// One of home's menu entries: a small tag over a huge slanted title, with a
/// line above. The [main] entry has a lime block behind its title and a
/// dark arrow chip; the others end in a chevron.
class LobbyMenuItem extends StatelessWidget {
  const LobbyMenuItem({
    super.key,
    required this.tag,
    required this.title,
    required this.onTap,
    this.main = false,
    this.last = false,
  });

  /// e.g. "01 / PLAY".
  final String tag;

  /// e.g. "게임 시작".
  final String title;
  final VoidCallback onTap;
  final bool main;

  /// The bottom entry, with less room under it.
  final bool last;

  /// The arrow chip and the chevron's box.
  static const _endSize = 48.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final titleText = LobbySkew(
      degrees: 8,
      child: Text(
        title,
        maxLines: 1,
        softWrap: false,
        style: text.lobbyMenuTitle.copyWith(
          color: main ? AppColors.ink : AppColors.textPrimary,
        ),
      ),
    );
    return Semantics(
      button: true,
      label: title,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.only(
            top: AppSpacing.s16,
            bottom: last ? AppSpacing.s4 : AppSpacing.s16,
          ),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LobbyTag(
                      tag,
                      color: main
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    // Shrinks rather than overflow with a large text size.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: main ? _LimeBlock(child: titleText) : titleText,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              if (main)
                const LobbyArrowChip(size: _endSize)
              else
                const SizedBox.square(
                  dimension: _endSize,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A slanted lime block behind [child], reaching a little past its left
/// edge.
class _LimeBlock extends StatelessWidget {
  const _LimeBlock({required this.child});

  final Widget child;

  /// How far the block starts left of the column.
  static const _overhang = 8.0;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-_overhang, 0),
      child: Stack(
        children: [
          const Positioned.fill(
            child: LobbySkew(
              degrees: 12,
              alignment: Alignment.center,
              child: ColoredBox(color: AppColors.accent),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s8,
              AppSpacing.s4,
              AppSpacing.s16,
              0,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}
