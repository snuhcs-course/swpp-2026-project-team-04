// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:flutter/foundation.dart';

import '../models/battle_rules.dart';
import '../models/form_report.dart';
import '../models/match_record.dart';
import '../services/api/api_client.dart';
import '../services/feedback/feedback_stats.dart';
import '../services/feedback/form_analyzer.dart';
import '../services/feedback/form_report_store.dart';
import '../services/feedback/report_metrics.dart';
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

  /// The findings to fix, in the analyzer's order.
  List<FormFinding> get issues => [
    for (final f in findings)
      if (f.kind == FindingKind.issue) f,
  ];

  /// The findings that went well.
  List<FormFinding> get goods => [
    for (final f in findings)
      if (f.kind == FindingKind.good) f,
  ];

  /// The report's 코치 한마디: how to fix the first issue, else the first
  /// thing done well, else a plain line.
  String get coachLine {
    final issue = issues.firstOrNull;
    if (issue != null) return issue.fix ?? issue.detail;
    return goods.firstOrNull?.title ?? '다음 대결에서 더 많은 횟수를 노려 봐요.';
  }
}

/// Immutable state rendered by the stored-feedback screen.
class FeedbackState {
  const FeedbackState({
    this.phase = FeedbackPhase.loading,
    this.report,
    this.form,
    this.fromPhone = false,
    this.errorMessage,
    this.metrics,
    this.history = ReportHistory.none,
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

  /// The post-game report's numbers of [report] (P14); set with it.
  final ReportMetrics? metrics;

  /// [report] against the recent battles kept on this phone; empty until
  /// they are read, and when there are none.
  final ReportHistory history;
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
    this.weightKg,
  }) : _profiles = _repository;

  /// Ready at once with [report] on [weightKg]. [load] then reads the
  /// recent battles kept on the phone for the comparisons and, without
  /// [weightKg], the body weight from [profiles]; it does nothing without
  /// either.
  FeedbackViewModel.fromReport(
    FormReport report, {
    this.analyzer = const FormAnalyzer(),
    this._phoneReports,
    this.weightKg,
    this._profiles,
  }) : match = null,
       _repository = null,
       _state = _ready(report, analyzer, weightKg: weightKg);

  /// The past battle whose report is loaded; null for [fromReport].
  final MatchRecord? match;
  final UserRepository? _repository;
  final FormReportStore? _phoneReports;

  /// Where the body weight is read when [weightKg] is not given.
  final UserRepository? _profiles;

  /// The rules the feedback is computed with.
  final FormAnalyzer analyzer;

  /// The user's body weight for the estimates when known up front; null
  /// reads it from the profile, and without one there the report uses
  /// [ReportMetrics.defaultWeightKg] and says it is assumed.
  final double? weightKg;

  /// The weight the numbers use: [weightKg], else the profile's once read.
  double? _weight;

  /// How long a loaded report waits for the profile's body weight.
  static const weightWait = Duration(seconds: 2);

  FeedbackState _state = const FeedbackState();
  bool _loading = false;
  bool _disposed = false;

  FeedbackState get state => _state;

  static FeedbackState _ready(
    FormReport report,
    FormAnalyzer analyzer, {
    bool fromPhone = false,
    double? weightKg,
    List<FormReport> kept = const [],
  }) => FeedbackState(
    phase: FeedbackPhase.ready,
    report: report,
    form: FormFeedback.of(report, analyzer: analyzer),
    fromPhone: fromPhone,
    metrics: ReportMetrics.of(report, weightKg: weightKg, analyzer: analyzer),
    history: ReportHistory.of(
      report,
      kept,
      weightKg: weightKg,
      analyzer: analyzer,
    ),
  );

  /// Loads the report, then compares it with the recent battles kept on
  /// this phone. Does nothing while a load is running, so a double tap on
  /// retry sends one request. For [fromReport] it only reads the recent
  /// battles, once.
  Future<void> load() async {
    final match = this.match, repository = _repository;
    if (_disposed || _loading) return;
    if (match == null || repository == null) {
      await _compareFromReport();
      return;
    }
    _loading = true;
    _setState(const FeedbackState());
    // Asked alongside the report. The profile read first sends any queued
    // battles, so it gets a short limit and then the default weight is used.
    final weight = _readWeight().timeout(weightWait, onTimeout: () => null);
    try {
      final id = match.id;
      final report = id == null ? null : await repository.fetchFeedback(id);
      _setState(
        report == null
            ? const FeedbackState(phase: FeedbackPhase.missing)
            : _ready(
                report,
                analyzer,
                weightKg: await weight,
                kept: await _kept(),
              ),
      );
    } on Exception catch (e) {
      final kept = await _kept();
      final copy = _phoneCopy(kept);
      _setState(
        copy != null
            ? _ready(
                copy,
                analyzer,
                fromPhone: true,
                weightKg: await weight,
                kept: kept,
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

  bool _compared = false;

  Future<void> _compareFromReport() async {
    final report = _state.report;
    if (_compared || report == null) return;
    if (_phoneReports == null && (weightKg != null || _profiles == null)) {
      return;
    }
    _compared = true;
    final reading = _readWeight();
    final kept = await _kept();
    final weight = await reading;
    if (kept.isEmpty && weight == weightKg) return;
    _setState(
      _ready(
        report,
        analyzer,
        fromPhone: _state.fromPhone,
        weightKg: weight,
        kept: kept,
      ),
    );
  }

  /// [weightKg], else the body weight in the user's profile; null when the
  /// profile has none or cannot be read, so the report assumes the default.
  Future<double?> _readWeight() async {
    final known = weightKg ?? _weight;
    final profiles = _profiles;
    if (known != null || profiles == null) return known;
    try {
      return _weight = (await profiles.fetchProfile()).weightKg;
    } on Exception {
      return null;
    }
  }

  /// The reports kept on this phone; none when there is no store or it
  /// cannot be read.
  /// The battles kept on this phone that are the signed-in account's.
  ///
  /// The phone keeps every account's reports in one place, so a phone
  /// shared by testers would compare one account with another's battles
  /// (phone check, 2026-11-26). A kept report counts only when the
  /// account's own battles on the server ([FeedbackStatsSource]) have one
  /// that ended at the same moment. Without that list (no source, offline,
  /// or past [weightWait]) every kept report counts, as before.
  Future<List<FormReport>> _kept() async {
    final store = _phoneReports;
    if (store == null) return const [];
    final reading = _accountBattles();
    List<FormReport> kept;
    try {
      kept = await store.list();
    } on Exception {
      return const [];
    }
    final mine = await reading;
    if (mine == null) return kept;
    return [
      for (final r in kept)
        if (mine.contains(r.endedAt.millisecondsSinceEpoch)) r,
    ];
  }

  /// When the signed-in account's battles ended, in milliseconds; null
  /// when they cannot be read.
  Future<Set<int>?> _accountBattles() async {
    final source = _profiles;
    if (source is! FeedbackStatsSource) return null;
    try {
      final points = await (source as FeedbackStatsSource)
          .fetchStatsPoints()
          .timeout(weightWait);
      return {for (final p in points) p.playedAt.millisecondsSinceEpoch};
    } on Object {
      return null;
    }
  }

  FormReport? _phoneCopy(List<FormReport> kept) {
    final playedAt = match?.playedAt;
    if (playedAt == null) return null;
    return kept
        .where(
          (r) =>
              r.endedAt.millisecondsSinceEpoch ==
              playedAt.millisecondsSinceEpoch,
        )
        .firstOrNull;
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
