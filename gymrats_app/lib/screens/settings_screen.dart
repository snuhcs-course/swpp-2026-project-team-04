import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/lobby_parts.dart';

/// 환경설정, from home's menu and its profile chip: the nickname, the rules
/// again, the sound switches and logout, in groups. The switches are the
/// app's [SettingsViewModel], provided above every screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.nickname, this.onLogOut});

  /// The name other players see; shown only.
  final String nickname;

  /// Logs out after the user confirms. No 로그아웃 when null.
  final Future<void> Function()? onLogOut;

  Future<void> _confirmLogOut(
    BuildContext context,
    Future<void> Function() logOut,
  ) async {
    final confirmed = await confirmExit(
      context,
      const ExitDialog(
        title: '로그아웃할까요?',
        message: '다시 들어오려면\n아이디와 비밀번호가 필요해요.',
        leaveLabel: '로그아웃',
      ),
    );
    if (confirmed) await logOut();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final logOut = onLogOut;
    return LobbyPage(
      behind: const LobbyWatermark('SET', left: 138),
      children: [
        const LobbyPageHeader(
          tag: '03 / SETTINGS',
          title: '환경설정',
          tagColor: AppColors.textSecondary,
        ),
        const SizedBox(height: AppSpacing.s16),
        _Group(
          label: '프로필',
          rows: [
            _Row(
              title: '닉네임',
              line: '온라인 대결에서 상대에게 보여요',
              end: _Nickname(nickname),
            ),
            // Until the characters replace the avatars (W3).
            _Row(
              title: '아바타',
              onTap: () =>
                  Navigator.pushNamed(context, GymRatsApp.profileRoute),
              end: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.line,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        _Group(
          label: '게임',
          rows: [
            _Row(
              title: '게임 규칙 다시 보기',
              onTap: () => Navigator.pushNamed(context, GymRatsApp.helpRoute),
              end: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.line,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        _Group(
          label: '소리',
          rows: [
            _SwitchRow(
              title: '효과음',
              value: vm.state.soundEffectsOn,
              onChanged: vm.setSoundEffects,
            ),
            _SwitchRow(
              title: '음성 안내',
              line: '카운트다운 · 매칭 · 판정을 소리로',
              value: vm.state.voiceGuidanceOn,
              onChanged: vm.setVoiceGuidance,
            ),
          ],
        ),
        const Spacer(),
        if (logOut != null) ...[
          const SizedBox(height: AppSpacing.s24),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _confirmLogOut(context, logOut),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              icon: const Icon(Icons.logout_rounded),
              label: Text(
                '로그아웃',
                style: Theme.of(context).textTheme.lobbyRowTitle,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A bold gray [label] over a bordered card of [rows], with lines between
/// the rows.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.rows});

  final String label;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, row) in rows.indexed) ...[
                if (index > 0) const Divider(height: 1),
                row,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A row's bold [title] and its gray [line] under it, then [end] at the
/// right. Tappable when [onTap] is set.
class _Row extends StatelessWidget {
  const _Row({required this.title, this.line, this.end, this.onTap});

  final String title;
  final String? line;
  final Widget? end;
  final VoidCallback? onTap;

  /// A row with one line or two.
  static const _height = 54.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final line = this.line;
    final end = this.end;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _height),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.lobbyRowTitle),
                    if (line != null)
                      Text(
                        line,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (end != null) ...[const SizedBox(width: AppSpacing.s12), end],
            ],
          ),
        ),
      ),
    );
  }
}

/// The nickname at the right of its row, on one line. A long one at a large
/// text size ends in "…" instead of pushing the row past the screen; a
/// screen reader still reads it whole.
class _Nickname extends StatelessWidget {
  const _Nickname(this.nickname);

  final String nickname;

  /// The most of the screen's width the nickname takes, so the row's title
  /// and line keep the rest. A share of the screen, not of the row: the
  /// page measures its rows' heights, which a [LayoutBuilder] cannot give.
  static const _widthShare = 0.4;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * _widthShare,
      ),
      child: Text(
        nickname,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}

/// An on/off row. A screen reader reads it as one switch with its title.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.line,
  });

  final String title;
  final String? line;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: _Row(
        title: title,
        line: line,
        onTap: () => onChanged(!value),
        end: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}
