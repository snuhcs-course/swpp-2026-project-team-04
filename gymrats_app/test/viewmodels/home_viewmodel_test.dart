import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/viewmodels/home_viewmodel.dart';

import '../support/fakes.dart';

void main() {
  late FakeUserRepository repository;
  late HomeViewModel vm;

  setUp(() {
    repository = FakeUserRepository();
    vm = HomeViewModel(repository: repository);
  });

  test('starts loading with no profile', () {
    expect(vm.state.phase, HomePhase.loading);
    expect(vm.state.profile, isNull);
  });

  test('load shows the profile from the repository', () async {
    await vm.load();
    expect(vm.state.phase, HomePhase.ready);
    expect(vm.state.profile, same(repository.profile));
  });

  test('a failed load shows the failed state and can be retried', () async {
    repository.error = Exception('offline');
    await vm.load();
    expect(vm.state.phase, HomePhase.failed);
    repository.error = null;
    await vm.load();
    expect(vm.state.phase, HomePhase.ready);
    expect(vm.state.profile, same(repository.profile));
  });

  test('load while loading fetches only once', () async {
    repository.gate = Completer();
    final first = vm.load();
    final second = vm.load();
    repository.gate!.complete();
    await first;
    await second;
    expect(repository.fetchCount, 1);
    expect(vm.state.phase, HomePhase.ready);
  });

  test('a profile arriving after dispose is dropped', () async {
    repository.gate = Completer();
    final loading = vm.load();
    vm.dispose();
    repository.gate!.complete();
    // Notifying a disposed view model would throw here.
    await expectLater(loading, completes);
    expect(vm.state.profile, isNull);
  });
}
