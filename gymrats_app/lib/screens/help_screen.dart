import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/accent_button.dart';
import '../widgets/auth_form.dart';
import '../widgets/grid_background.dart';
import '../widgets/help_pictures.dart';
import '../widgets/help_rules.dart';

/// The battle rules in three pages, turned by swiping or 다음: the health
/// bar, scoring with fever, then the danger edge, the winner and safety.
/// The texts come from [HelpRules].
///
/// Opens once before home for an account that signed up on this phone:
/// then [onStart] is set, there is no back arrow, and 건너뛰기 or the last
/// page's 시작하기 calls it. Opened from '?' on home, [onStart] is null:
/// back or the last page's 확인 returns home.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, this.onStart});

  final VoidCallback? onStart;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static const _turn = Duration(milliseconds: 300);

  /// One per page of [HelpRules.pages], in order.
  static const _pictures = [
    HelpBarPicture(),
    HelpScorePicture(),
    HelpReminderPicture(),
  ];

  final _pager = PageController();
  int _page = 0;

  bool get _onLastPage => _page == _pictures.length - 1;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _next() {
    if (!_onLastPage) {
      _pager.nextPage(duration: _turn, curve: Curves.easeOut);
      return;
    }
    final onStart = widget.onStart;
    if (onStart != null) {
      onStart();
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final onStart = widget.onStart;
    final pages = HelpRules.pages;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TopBar(title: '게임 규칙', showBack: onStart == null),
                  ),
                  if (onStart != null && !_onLastPage)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.s8),
                      child: TextButton(
                        onPressed: onStart,
                        child: Text(
                          '건너뛰기',
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: PageView(
                  controller: _pager,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: [
                    for (final (index, page) in pages.indexed)
                      _Page(page: page, picture: _pictures[index]),
                  ],
                ),
              ),
              _PageDots(count: pages.length, current: _page),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s20,
                  0,
                  AppSpacing.s20,
                  AppSpacing.s24,
                ),
                child: AccentButton(
                  title: !_onLastPage
                      ? '다음'
                      : onStart == null
                      ? '확인'
                      : '시작하기',
                  hint: _onLastPage && onStart != null
                      ? '규칙은 홈의 ? 버튼으로 다시 볼 수 있어요'
                      : null,
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One page: its picture on a card, then the title, the text and the
/// score tags. Scrolls on a short screen.
class _Page extends StatelessWidget {
  const _Page({required this.page, required this.picture});

  final HelpPage page;
  final Widget picture;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s16,
        AppSpacing.s20,
        AppSpacing.s16,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: picture,
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        Text(page.title, style: text.headlineLarge),
        const SizedBox(height: AppSpacing.s8),
        Text(
          page.body,
          style: text.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
        if (page.points.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s16),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [for (final point in page.points) _PointTag(point)],
          ),
        ],
      ],
    );
  }
}

/// A score tag such as "KO 100점 차": bold lime text on a faint lime box.
class _PointTag extends StatelessWidget {
  const _PointTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s4,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.accent),
        ),
      ),
    );
  }
}

/// Which page is showing: a long lime dot for it, short gray ones for the
/// rest.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count장 중 ${current + 1}장',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < count; index++) ...[
                if (index > 0) const SizedBox(width: AppSpacing.s8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: index == current ? AppSpacing.s24 : AppSpacing.s8,
                  height: AppSpacing.s8,
                  decoration: ShapeDecoration(
                    color: index == current
                        ? AppColors.accent
                        : AppColors.border,
                    shape: const StadiumBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
