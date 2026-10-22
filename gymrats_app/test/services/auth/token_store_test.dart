// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/auth_session.dart';
import 'package:gymrats_app/services/auth/token_store.dart';

/// Keeps values in a map, like the Keystore would. Only read, write, and
/// delete are used by SecureTokenStore; any other call fails the test.
class _FakeSecureStorage implements FlutterSecureStorage {
  final values = <String, String>{};
  bool failDelete = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String;
    switch (invocation.memberName) {
      case #read:
        return Future<String?>.value(values[key]);
      case #write:
        final value = invocation.namedArguments[#value] as String?;
        value == null ? values.remove(key) : values[key] = value;
        return Future<void>.value();
      case #delete:
        if (failDelete) return Future<void>.error(Exception('keystore'));
        values.remove(key);
        return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

const _session = AuthSession(
  token: 'secret-token',
  account: Account(id: 3, loginId: 'woohyun', nickname: '우현'),
);

void main() {
  late _FakeSecureStorage storage;
  late SecureTokenStore store;

  setUp(() {
    storage = _FakeSecureStorage();
    store = SecureTokenStore(storage);
  });

  test('nothing saved: logged out', () async {
    expect(await store.read(), isNull);
  });

  test('a written session reads back the same', () async {
    await store.write(_session);
    final read = await store.read();
    expect(read!.token, 'secret-token');
    expect(read.account.id, 3);
    expect(read.account.loginId, 'woohyun');
    expect(read.account.nickname, '우현');
  });

  test('clear forgets the session', () async {
    await store.write(_session);
    await store.clear();
    expect(await store.read(), isNull);
    expect(storage.values, isEmpty);
  });

  test('an unreadable value is cleared and starts logged out', () async {
    storage.values['gymrats.session'] = 'not json';
    expect(await store.read(), isNull);
    expect(storage.values, isEmpty);
  });

  test('a value of the wrong shape is cleared too', () async {
    storage.values['gymrats.session'] = '{"token": 1}';
    expect(await store.read(), isNull);
    expect(storage.values, isEmpty);
  });

  test('a failing delete does not throw', () async {
    storage.failDelete = true;
    await store.clear();
  });
}
