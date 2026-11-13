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
    expect(notified, 1);
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

class _SlowStore implements CharacterStore {
  final answer = Completer<String>();

  @override
  Future<String> read(int accountId) => answer.future;

  @override
  Future<void> write(int accountId, String characterId) async {}
}
