// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:flutter/foundation.dart';

import '../models/form_report.dart';
import '../models/match_record.dart';
import '../services/api/api_client.dart';
import '../services/feedback/form_report_store.dart';
import '../services/user/user_repository.dart';
import 'login_viewmodel.dart';

/// What the stored-feedback screen is showing.
enum FeedbackPhase {
  /// Loading the battle's report.
  loading,

  /// The report is loaded; the feedback screen shows it.
  ready,

  /// The battle has no stored report.
  missing,

  /// Loading failed and the phone has no copy; the user can retry.
  failed,
}

/// Immutable state rendered by the stored-feedback screen.
class FeedbackState {
  const FeedbackState({
    this.phase = FeedbackPhase.loading,
    this.report,
    this.fromPhone = false,
    this.errorMessage,
  });

  final FeedbackPhase phase;

  /// The battle's full form report, for the ready phase.
  final FormReport? report;

  /// The report is the copy kept on this phone, because the server could
  /// not be reached.
  final bool fromPhone;

  /// Why loading failed, for the failed phase.
  final String? errorMessage;
}

/// Loads the form report of one past battle, so the same feedback screen
/// the user saw after it can be shown again.
///
/// The server's copy comes first, so it works on any phone. When the server
/// cannot be reached, the copy this phone kept after the battle is used. A
/// phone report matches a battle when its end time equals the battle's
/// [MatchRecord.playedAt] (bot battles store the report's end time, online
/// ones the server's, which the report also uses).
class FeedbackViewModel extends ChangeNotifier {
  FeedbackViewModel({
    required this.match,
    required this._repository,
    this._phoneReports,
  });

  final MatchRecord match;
  final UserRepository _repository;
  final FormReportStore? _phoneReports;

  FeedbackState _state = const FeedbackState();
  bool _loading = false;
  bool _disposed = false;

  FeedbackState get state => _state;

  /// Loads the report. Does nothing while a load is running, so a double
  /// tap on retry sends one request.
  Future<void> load() async {
    if (_disposed || _loading) return;
    _loading = true;
    _setState(const FeedbackState());
    try {
      final id = match.id;
      final report = id == null ? null : await _repository.fetchFeedback(id);
      _setState(
        report == null
            ? const FeedbackState(phase: FeedbackPhase.missing)
            : FeedbackState(phase: FeedbackPhase.ready, report: report),
      );
    } on Exception catch (e) {
      final copy = await _phoneCopy();
      _setState(
        copy != null
            ? FeedbackState(
                phase: FeedbackPhase.ready,
                report: copy,
                fromPhone: true,
              )
            : FeedbackState(
                phase: FeedbackPhase.failed,
                errorMessage: e is ApiException
                    ? e.message
                    : genericErrorMessage,
              ),
      );
    } finally {
      _loading = false;
    }
  }

  Future<FormReport?> _phoneCopy() async {
    final store = _phoneReports, playedAt = match.playedAt;
    if (store == null || playedAt == null) return null;
    try {
      final reports = await store.list();
      return reports
          .where(
            (r) =>
                r.endedAt.millisecondsSinceEpoch ==
                playedAt.millisecondsSinceEpoch,
          )
          .firstOrNull;
    } on Exception {
      return null;
    }
  }

  void _setState(FeedbackState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
