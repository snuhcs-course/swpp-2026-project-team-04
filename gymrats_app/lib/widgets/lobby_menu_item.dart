import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'lobby_parts.dart';

/// One of home's menu entries: a small gray tag over a huge slanted title in
/// ink, with a line above and a gray chevron at the end. Every entry looks
/// the same (user, 2026-11-08).
class LobbyMenuItem extends StatelessWidget {
  const LobbyMenuItem({
    super.key,
    required this.tag,
    required this.title,
    required this.onTap,
    this.last = false,
  });

  /// e.g. "01 / PLAY".
  final String tag;

  /// e.g. "게임 시작".
  final String title;
  final VoidCallback onTap;

  /// The bottom entry, with less room under it.
  final bool last;

  /// The chevron's box.
  static const _endSize = 48.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
                    LobbyTag(tag),
                    const SizedBox(height: AppSpacing.s8),
                    // Shrinks rather than overflow with a large text size.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: LobbySkew(
                        degrees: 8,
                        child: Text(
                          title,
                          maxLines: 1,
                          softWrap: false,
                          style: text.lobbyMenuTitle.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              const SizedBox.square(
                dimension: _endSize,
                child: Icon(Icons.chevron_right_rounded, color: AppColors.line),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
