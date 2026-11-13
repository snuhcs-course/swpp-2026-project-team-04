import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/user/character_store.dart';
import 'package:gymrats_app/viewmodels/character_viewmodel.dart';

void main() {
  late MemoryCharacterStore store;
  late CharacterViewModel viewModel;
  late int notified;

  setUp(() {
    store = MemoryCharacterStore();
    viewModel = CharacterViewModel(store: store);
    notified = 0;
    viewModel.addListener(() => notified++);
  });

  tearDown(() => viewModel.dispose());

  test('is the mouse before any account signs in', () {
    expect(viewModel.characterId, 'mouse');
    expect(viewModel.art.name, 'GYM마우스');
  });

  test('a login reads the account\'s saved character', () async {
    store.values[7] = 'seal';
    await viewModel.load(7);
    expect(viewModel.characterId, 'seal');
    expect(viewModel.art.name, '물렁범');
    expect(notified, 2, reason: 'once as the read starts, once as it ends');
  });

  test('loading the same account again reads nothing new', () async {
    store.values[7] = 'seal';
    await viewModel.load(7);
    store.values[7] = 'bear';
    await viewModel.load(7);
    expect(viewModel.characterId, 'seal');
  });

  test('another account starts from the mouse, then shows its own', () async {
    store.values[7] = 'seal';
    await viewModel.load(7);
    final reading = viewModel.load(8);
    expect(viewModel.characterId, 'mouse', reason: 'not the last account\'s');
    await reading;
    expect(viewModel.characterId, 'mouse');
    store.values[8] = 'kangaroo';
    viewModel.clear();
    await viewModel.load(8);
    expect(viewModel.characterId, 'kangaroo');
  });

  test('a logout puts the mouse back', () async {
    store.values[7] = 'bear';
    await viewModel.load(7);
    viewModel.clear();
    expect(viewModel.characterId, 'mouse');
  });

  test('choosing saves for the signed-in account and shows at once', () async {
    await viewModel.load(7);
    expect(await viewModel.choose('penguin'), isTrue);
    expect(viewModel.characterId, 'penguin');
    expect(store.values, {7: 'penguin'});
  });

  test('RepBot or an unknown id cannot be chosen', () async {
    await viewModel.load(7);
    notified = 0;
    expect(await viewModel.choose('bot'), isFalse);
    expect(await viewModel.choose('rabbit'), isFalse);
    expect(viewModel.characterId, 'mouse');
    expect(store.values, isEmpty);
    expect(notified, 0);
  });

  test('choosing while signed out shows it but saves nothing', () async {
    expect(await viewModel.choose('bear'), isFalse);
    expect(viewModel.characterId, 'bear');
    expect(store.values, isEmpty);
  });

  test('a failed save keeps the choice for now', () async {
    final failing = CharacterViewModel(store: _FailingStore());
    addTearDown(failing.dispose);
    await failing.load(7);
    expect(await failing.choose('seal'), isFalse);
    expect(failing.characterId, 'seal');
  });

  test('a slow read does not undo a choice made meanwhile', () async {
    final slow = _SlowStore();
    final vm = CharacterViewModel(store: slow);
    addTearDown(vm.dispose);
    final reading = vm.load(7);
    await vm.choose('bear');
    slow.answer.complete('seal');
    await reading;
    expect(vm.characterId, 'bear');
  });

  group('loading', () {
    test('is not loading and ready for no one before a login', () {
      expect(viewModel.loading, isFalse);
      expect(viewModel.isReadyFor(7), isFalse);
      expect(viewModel.isReadyFor(null), isFalse);
    });

    test('loads from a login until the read ends, and says so both times, '
        'even when the saved character is the default', () async {
      final slow = _SlowStore();
      final vm = CharacterViewModel(store: slow);
      addTearDown(vm.dispose);
      var calls = 0;
      vm.addListener(() => calls++);
      final reading = vm.load(7);
      expect(vm.loading, isTrue);
      expect(vm.isReadyFor(7), isFalse);
      expect(calls, 1);
      slow.answer.complete('mouse');
      await reading;
      expect(vm.loading, isFalse);
      expect(vm.isReadyFor(7), isTrue);
      expect(vm.isReadyFor(8), isFalse);
      expect(calls, 2);
    });

    test('a choice made while reading ends the loading and wins', () async {
      final slow = _SlowStore();
      final vm = CharacterViewModel(store: slow);
      addTearDown(vm.dispose);
      final reading = vm.load(7);
      await vm.choose('bear');
      expect(vm.loading, isFalse);
      expect(vm.isReadyFor(7), isTrue);
      slow.answer.complete('seal');
      await reading;
      expect(vm.characterId, 'bear');
      expect(vm.loading, isFalse);
    });

    test('a logout while reading ends the loading', () {
      final slow = _SlowStore();
      final vm = CharacterViewModel(store: slow);
      addTearDown(vm.dispose);
      unawaited(vm.load(7));
      vm.clear();
      expect(vm.loading, isFalse);
      expect(vm.isReadyFor(7), isFalse);
    });

    test('another account loads again; the first one\'s late read does not '
        'end it', () async {
      final store = _OneAnswerPerReadStore();
      final vm = CharacterViewModel(store: store);
      addTearDown(vm.dispose);
      final first = vm.load(7);
      vm.clear();
      final second = vm.load(8);
      store.answers[0].complete('seal');
      await first;
      expect(vm.loading, isTrue);
      expect(vm.isReadyFor(8), isFalse);
      expect(vm.characterId, 'mouse');
      store.answers[1].complete('bear');
      await second;
      expect(vm.isReadyFor(8), isTrue);
      expect(vm.characterId, 'bear');
    });

    test('a read that fails reads as the mouse and ends the loading', () async {
      final vm = CharacterViewModel(store: _UnreadableStore());
      addTearDown(vm.dispose);
      await vm.load(7);
      expect(vm.characterId, 'mouse');
      expect(vm.loading, isFalse);
      expect(vm.isReadyFor(7), isTrue);
    });
  });

  test(
    'a read that ends after the view model is gone changes nothing',
    () async {
      final slow = _SlowStore();
      final vm = CharacterViewModel(store: slow);
      final reading = vm.load(7);
      vm.dispose();
      slow.answer.complete('seal');
      await reading;
      expect(vm.characterId, 'mouse');
    },
  );
}

class _FailingStore implements CharacterStore {
  @override
  Future<String> read(int accountId) async => 'mouse';

  @override
  Future<void> write(int accountId, String characterId) =>
      Future.error(StateError('no storage'));
}

/// Each read waits for its own entry in [answers], in the order read.
class _OneAnswerPerReadStore implements CharacterStore {
  final answers = <Completer<String>>[];

  @override
  Future<String> read(int accountId) {
    final answer = Completer<String>();
    answers.add(answer);
    return answer.future;
  }

  @override
  Future<void> write(int accountId, String characterId) async {}
}

class _UnreadableStore implements CharacterStore {
  @override
  Future<String> read(int accountId) =>
      Future.error(StateError('storage unreadable'));

  @override
  Future<void> write(int accountId, String characterId) async {}
}

class _SlowStore implements CharacterStore {
  final answer = Completer<String>();

  @override
  Future<String> read(int accountId) => answer.future;

  @override
  Future<void> write(int accountId, String characterId) async {}
}
