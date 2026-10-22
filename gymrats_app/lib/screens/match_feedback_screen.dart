// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_record.dart';
import '../services/feedback/form_report_store.dart';
import '../services/user/user_repository.dart';
import '../viewmodels/feedback_viewmodel.dart';
import '../widgets/auth_form.dart';
import '../widgets/grid_background.dart';
import 'feedback_screen.dart';

/// The form feedback of a past battle, opened from home's "최근 경기" or the
/// 기록 tab. Loads the battle's stored report, then shows the same
/// [FeedbackScreen] the user saw right after the battle.
class MatchFeedbackScreen extends StatefulWidget {
  const MatchFeedbackScreen({
    super.key,
    required this.match,
    this.createViewModel,
  });

  final MatchRecord match;

  /// Builds the view model; replaces the default one in tests.
  final FeedbackViewModel Function()? createViewModel;

  @override
  State<MatchFeedbackScreen> createState() => _MatchFeedbackScreenState();
}

class _MatchFeedbackScreenState extends State<MatchFeedbackScreen> {
  late final FeedbackViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.createViewModel?.call() ??
        FeedbackViewModel(
          match: widget.match,
          repository: context.read<UserRepository>(),
          phoneReports: context.read<FormReportStore>(),
        );
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FeedbackViewModel>.value(
      value: _viewModel,
      child: Consumer<FeedbackViewModel>(
        builder: (context, vm, _) {
          final state = vm.state;
          if (state.phase == FeedbackPhase.ready) {
            return FeedbackScreen(report: state.report!);
          }
          return Scaffold(
            body: GridBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    const TopBar(title: '자세 피드백'),
                    Expanded(
                      child: switch (state.phase) {
                        FeedbackPhase.failed => CenteredMessage(
                          title: '피드백을 불러오지 못했어요',
                          detail: state.errorMessage,
                          onRetry: vm.load,
                        ),
                        FeedbackPhase.missing => const CenteredMessage(
                          title: '피드백 없음',
                          detail: '이 경기는 자세 피드백이 저장되지 않았어요.',
                        ),
                        _ => const Center(child: CircularProgressIndicator()),
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The tap handler for [match]'s row: opens its feedback, or null (the row
/// is not tappable) when the battle has none.
VoidCallback? feedbackTap(BuildContext context, MatchRecord match) =>
    match.hasFeedback && match.id != null
    ? () => Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => MatchFeedbackScreen(match: match)),
      )
    : null;
