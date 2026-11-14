// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:flutter/foundation.dart';

import '../models/battle_rules.dart';
import '../models/form_report.dart';
import '../models/match_record.dart';
import '../services/api/api_client.dart';
import '../services/feedback/form_analyzer.dart';
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

/// What the feedback screen shows of one form report, computed once by the
/// view model with the analyzer's own rules, so the cards and the chart
/// sentences never disagree. Numbers stay in their own units; the screen
/// rounds them and adds the words.
class FormFeedback {
  const FormFeedback({
    required this.findings,
    required this.meanDepth,
    required this.depthTrend,
    required this.armBalance,
    required this.paceBuckets,
    required this.sliceSeconds,
    required this.repsPerSecond,
  });

  /// The feedback of [report] by [analyzer]'s rules.
  factory FormFeedback.of(
    FormReport report, {
    FormAnalyzer analyzer = const FormAnalyzer(),
  }) {
    final depths = [
      for (final r in report.reps)
        if (r.valid && r.maxDepth != null) r.maxDepth!,
    ];
    final roundSeconds = report.roundLength.inMilliseconds / 1000;
    final slice = roundSeconds <= 0 ? 5.0 : roundSeconds / battleTimeSlices;
    final buckets = List<int>.filled(battleTimeSlices, 0);
    for (final rep in report.reps) {
      if (!rep.valid) continue;
      // A rep closing as time runs out, or just after, still scored: it
      // goes in the last slice rather than off the chart.
      final index = (rep.at.inMilliseconds / 1000 / slice).floor();
      buckets[index.clamp(0, battleTimeSlices - 1)]++;
    }
    return FormFeedback(
      findings: analyzer.analyze(report),
      meanDepth: depths.isEmpty
          ? null
          : depths.reduce((a, b) => a + b) / depths.length,
      depthTrend: analyzer.depthTrend(report),
      armBalance: analyzer.armBalance(report),
      paceBuckets: List.unmodifiable(buckets),
      sliceSeconds: slice,
      repsPerSecond: roundSeconds <= 0 ? 0 : report.validReps / roundSeconds,
    );
  }

  /// The rule findings: issues first, then good points, then notes.
  final List<FormFinding> findings;

  /// Mean depth of the counted reps (push-up: head drop in shoulder widths;
  /// squat: share of the standing thigh); null when none had a depth.
  final double? meanDepth;

  /// Whether the counted reps kept their depth to the end.
  final DepthTrend depthTrend;

  /// Which arm bent more; [ArmBalance.unknown] for a squat or too little data.
  final ArmBalance armBalance;

  /// Counted reps in each of the round's [battleTimeSlices] equal slices;
  /// they add up to [FormReport.validReps] (a rep at or after the end is in
  /// the last slice).
  final List<int> paceBuckets;

  /// Seconds in one slice: 5 for a 30 s round, less for a KO round.
  final double sliceSeconds;

  /// Counted reps per second of the round played.
  final double repsPerSecond;
}

/// Immutable state rendered by the stored-feedback screen.
class FeedbackState {
  const FeedbackState({
    this.phase = FeedbackPhase.loading,
    this.report,
    this.form,
    this.fromPhone = false,
    this.errorMessage,
  });

  final FeedbackPhase phase;

  /// The battle's full form report, for the ready phase.
  final FormReport? report;

  /// What the screen shows of [report]; set with it in the ready phase.
  final FormFeedback? form;

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
///
/// [FeedbackViewModel.fromReport] shows a report already in hand (the result
/// and the online result), so all three ways in give the same state.
class FeedbackViewModel extends ChangeNotifier {
  FeedbackViewModel({
    required MatchRecord this.match,
    required UserRepository this._repository,
    this._phoneReports,
    this.analyzer = const FormAnalyzer(),
  });

  /// Ready at once with [report]; [load] then does nothing.
  FeedbackViewModel.fromReport(
    FormReport report, {
    this.analyzer = const FormAnalyzer(),
  }) : match = null,
       _repository = null,
       _phoneReports = null,
       _state = _ready(report, analyzer);

  /// The past battle whose report is loaded; null for [fromReport].
  final MatchRecord? match;
  final UserRepository? _repository;
  final FormReportStore? _phoneReports;

  /// The rules the feedback is computed with.
  final FormAnalyzer analyzer;

  FeedbackState _state = const FeedbackState();
  bool _loading = false;
  bool _disposed = false;

  FeedbackState get state => _state;

  static FeedbackState _ready(
    FormReport report,
    FormAnalyzer analyzer, {
    bool fromPhone = false,
  }) => FeedbackState(
    phase: FeedbackPhase.ready,
    report: report,
    form: FormFeedback.of(report, analyzer: analyzer),
    fromPhone: fromPhone,
  );

  /// Loads the report. Does nothing while a load is running, so a double
  /// tap on retry sends one request, and nothing for [fromReport].
  Future<void> load() async {
    final match = this.match, repository = _repository;
    if (_disposed || _loading || match == null || repository == null) return;
    _loading = true;
    _setState(const FeedbackState());
    try {
      final id = match.id;
      final report = id == null ? null : await repository.fetchFeedback(id);
      _setState(
        report == null
            ? const FeedbackState(phase: FeedbackPhase.missing)
            : _ready(report, analyzer),
      );
    } on Exception catch (e) {
      final copy = await _phoneCopy();
      _setState(
        copy != null
            ? _ready(copy, analyzer, fromPhone: true)
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
    final store = _phoneReports, playedAt = match?.playedAt;
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
