// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/form_report.dart';
import 'package:gymrats_app/models/match_record.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/feedback/form_report_store.dart';
import 'package:gymrats_app/viewmodels/feedback_viewmodel.dart';
import 'package:gymrats_app/viewmodels/login_viewmodel.dart';

import '../support/fakes.dart';
import '../support/form_report_fixtures.dart';

final _endedAt = DateTime.utc(2026, 10, 21, 3, 0, 5, 250);

MatchRecord _match({int? id = 7, DateTime? playedAt}) => MatchRecord(
  id: id,
  exercise: ExerciseType.pushUp,
  opponentName: 'RepBot',
  myReps: 3,
  opponentReps: 1,
  playedAt: playedAt ?? _endedAt.toLocal(),
);

/// A phone store whose reads fail.
class _BrokenStore implements FormReportStore {
  @override
  Future<List<FormReport>> list() => Future.error(Exception('disk'));

  @override
  Future<FormReport?> latest() => Future.error(Exception('disk'));

  @override
  Future<void> save(FormReport report) async {}
}

void main() {
  late FakeUserRepository repository;
  late InMemoryFormReportStore phone;

  setUp(() {
    repository = FakeUserRepository();
    phone = InMemoryFormReportStore();
  });

  FeedbackViewModel vm(MatchRecord match, {FormReportStore? store}) =>
      FeedbackViewModel(
        match: match,
        repository: repository,
        phoneReports: store ?? phone,
      );

  test('starts loading', () {
    expect(vm(_match()).state.phase, FeedbackPhase.loading);
  });

  test("loads the battle's report from the server", () async {
    final report = sampleReport(endedAt: _endedAt);
    repository.reports = {7: report};
    final model = vm(_match());
    await model.load();
    expect(repository.feedbackRequests, [7]);
    expect(model.state.phase, FeedbackPhase.ready);
    expect(model.state.report, same(report));
    expect(model.state.fromPhone, isFalse);
  });

  test('a battle without a stored report is missing', () async {
    final model = vm(_match());
    await model.load();
    expect(model.state.phase, FeedbackPhase.missing);
  });

  test('a battle with no server id is missing without a request', () async {
    final model = vm(_match(id: null));
    await model.load();
    expect(model.state.phase, FeedbackPhase.missing);
    expect(repository.feedbackRequests, isEmpty);
  });

  test("offline, the phone's copy of the same battle is shown", () async {
    final copy = sampleReport(endedAt: _endedAt);
    await phone.save(sampleReport(endedAt: DateTime.utc(2026, 10, 20)));
    await phone.save(copy);
    repository.feedbackError = const ApiException(ApiErrorKind.network);
    final model = vm(_match());
    await model.load();
    expect(model.state.phase, FeedbackPhase.ready);
    expect(model.state.report, same(copy));
    expect(model.state.fromPhone, isTrue);
  });

  test('offline without a phone copy fails with the reason', () async {
    await phone.save(sampleReport(endedAt: DateTime.utc(2026, 10, 20)));
    repository.feedbackError = const ApiException(ApiErrorKind.network);
    final model = vm(_match());
    await model.load();
    expect(model.state.phase, FeedbackPhase.failed);
    expect(
      model.state.errorMessage,
      const ApiException(ApiErrorKind.network).message,
    );
  });

  test('another failure, or an unreadable phone store, fails too', () async {
    repository.feedbackError = Exception('boom');
    final model = vm(_match(), store: _BrokenStore());
    await model.load();
    expect(model.state.phase, FeedbackPhase.failed);
    expect(model.state.errorMessage, genericErrorMessage);
  });

  test('a battle without a time has no phone copy to look for', () async {
    repository.feedbackError = Exception('boom');
    final model = FeedbackViewModel(
      match: const MatchRecord(
        id: 7,
        exercise: ExerciseType.pushUp,
        opponentName: 'RepBot',
        myReps: 1,
        opponentReps: 0,
      ),
      repository: repository,
    );
    await model.load();
    expect(model.state.phase, FeedbackPhase.failed);
  });

  test('retry after a failure loads again', () async {
    repository.feedbackError = Exception('boom');
    final model = vm(_match());
    await model.load();
    repository
      ..feedbackError = null
      ..reports = {7: sampleReport()};
    await model.load();
    expect(model.state.phase, FeedbackPhase.ready);
  });

  test('load while loading fetches only once', () async {
    repository.feedbackGate = Completer();
    final model = vm(_match());
    final first = model.load();
    final second = model.load();
    repository.feedbackGate!.complete();
    await Future.wait([first, second]);
    expect(repository.feedbackRequests, [7]);
  });

  test('a report arriving after dispose is dropped', () async {
    repository
      ..feedbackGate = Completer()
      ..reports = {7: sampleReport()};
    final model = vm(_match());
    final loading = model.load();
    model.dispose();
    repository.feedbackGate!.complete();
    await loading;
    expect(model.state.phase, FeedbackPhase.loading);
    await model.load();
    expect(repository.feedbackRequests, [7]);
  });
}
