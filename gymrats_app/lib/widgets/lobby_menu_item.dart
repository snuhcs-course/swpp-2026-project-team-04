import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'lobby_parts.dart';

/// One of home's menu entries: a small gray tag over a huge slanted title in
/// ink, with a line above and a gray chevron at the end. Every entry looks
/// the same (user, 2026-11-08).
///
/// The design's 76 high row (2026-11-14): the 1 px line, 8 above the tag
/// (11 on a 14 line), a gap, the title (44 on a 44 line) and room under it;
/// the design's 3 and 6 are the token steps [AppSpacing.s4], so the row is
/// [height] high. The title keeps its size at any system text size; the tag
/// follows it.
class LobbyMenuItem extends StatelessWidget {
  const LobbyMenuItem({
    super.key,
    required this.tag,
    required this.title,
    required this.onTap,
  });

  /// e.g. "01 / PLAY".
  final String tag;

  /// e.g. "게임 시작".
  final String title;
  final VoidCallback onTap;

  /// The row's height at the default text size.
  static const height = 75.0;

  /// The chevron's box; the whole row is the tap area.
  static const _endSize = 40.0;
  static const _chevronSize = 24.0;

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
          padding: const EdgeInsets.only(
            top: AppSpacing.s8,
            bottom: AppSpacing.s4,
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
                    Text(
                      tag,
                      style: text.lobbyMenuTag.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    // Shrinks rather than overflow on a narrow screen.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: LobbySkew(
                        degrees: 8,
                        child: Text(
                          title,
                          maxLines: 1,
                          softWrap: false,
                          textScaler: TextScaler.noScaling,
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
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.line,
                  size: _chevronSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
