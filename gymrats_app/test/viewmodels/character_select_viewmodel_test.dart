import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/services/user/character_store.dart';
import 'package:gymrats_app/viewmodels/character_select_viewmodel.dart';
import 'package:gymrats_app/viewmodels/character_viewmodel.dart';

void main() {
  late MemoryCharacterStore store;
  late CharacterViewModel account;
  late CharacterSelectViewModel viewModel;

  setUp(() async {
    store = MemoryCharacterStore()..values[7] = 'bear';
    account = CharacterViewModel(store: store);
    await account.load(7);
    viewModel = CharacterSelectViewModel(account: account);
  });

  tearDown(() {
    viewModel.dispose();
    account.dispose();
  });

  test('starts on the account\'s character', () {
    expect(viewModel.selected, 'bear');
    expect(viewModel.selectedArt.name, '곰탱이');
  });

  test('offers the five characters a person may pick, in order', () {
    expect(viewModel.options.map((art) => art.id), [
      'mouse',
      'kangaroo',
      'bear',
      'penguin',
      'seal',
    ]);
  });

  test('says each one as its animal and a few words (spec 7)', () {
    expect(
      {for (final art in viewModel.options) art.id: viewModel.captionOf(art)},
      {
        'mouse': '쥐 · 대표 캐릭터',
        'kangaroo': '캥거루 · 키 큰 점프 선수',
        'bear': '곰 · 가장 큰 덩치',
        'penguin': '펭귄 · 지느러미로 때려요',
        'seal': '물범 · 가장 통통해요',
      },
    );
  });

  test('picking changes only the preview, not the account', () {
    var notified = 0;
    viewModel.addListener(() => notified++);
    viewModel.select('penguin');
    expect(viewModel.selected, 'penguin');
    expect(account.characterId, 'bear');
    expect(store.values[7], 'bear');
    expect(notified, 1);
    viewModel.select('penguin');
    expect(notified, 1, reason: 'the same cell again changes nothing');
  });

  test('RepBot or an unknown id cannot be picked', () {
    viewModel
      ..select('bot')
      ..select('rabbit');
    expect(viewModel.selected, 'bear');
  });

  test('confirming saves the pick for the account', () async {
    viewModel.select('seal');
    final saving = viewModel.confirm();
    expect(viewModel.saving, isTrue);
    await saving;
    expect(viewModel.saving, isFalse);
    expect(account.characterId, 'seal');
    expect(store.values[7], 'seal');
  });

  test('a second confirm while saving does nothing', () async {
    final slow = _SlowStore();
    final slowAccount = CharacterViewModel(store: slow);
    addTearDown(slowAccount.dispose);
    await slowAccount.load(7);
    final vm = CharacterSelectViewModel(account: slowAccount)..select('seal');
    addTearDown(vm.dispose);
    final first = vm.confirm();
    final second = vm.confirm();
    slow.written.complete();
    await Future.wait([first, second]);
    expect(slow.writes, 1);
  });

  test(
    'a confirm that ends after the screen is gone does not notify',
    () async {
      final slow = _SlowStore();
      final slowAccount = CharacterViewModel(store: slow);
      addTearDown(slowAccount.dispose);
      await slowAccount.load(7);
      final vm = CharacterSelectViewModel(account: slowAccount)..select('seal');
      final saving = vm.confirm();
      vm.dispose();
      slow.written.complete();
      await expectLater(saving, completes);
    },
  );
}

class _SlowStore implements CharacterStore {
  final written = Completer<void>();
  int writes = 0;

  @override
  Future<String> read(int accountId) async => 'mouse';

  @override
  Future<void> write(int accountId, String characterId) {
    writes++;
    return written.future;
  }
}
