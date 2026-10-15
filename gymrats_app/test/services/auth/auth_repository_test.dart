import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/auth_session.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/auth/auth_repository.dart';
import 'package:gymrats_app/services/auth/in_memory_auth_repository.dart';
import 'package:gymrats_app/services/auth/token_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _user = {'id': 3, 'login_id': 'woohyun', 'nickname': '우현'};

http.Response _json(Object? body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late MemoryTokenStore store;
  late List<http.Request> requests;
  late http.Response Function(http.Request) answer;
  late ApiClient api;
  late ServerAuthRepository repository;

  setUp(() {
    store = MemoryTokenStore();
    requests = [];
    answer = (_) => _json({'token': 'new-token', 'user': _user}, 200);
    api = ApiClient(
      httpClient: MockClient((request) async {
        requests.add(request);
        return answer(request);
      }),
      baseUrl: Uri.parse('http://server.test'),
    );
    repository = ServerAuthRepository(api: api, store: store);
  });

  test('sign-up sends the fields, keeps the session, and saves it', () async {
    final session = await repository.signUp(
      nickname: '우현',
      loginId: 'woohyun',
      password: 'password1',
    );
    expect(requests.single.url.path, '/auth/signup');
    expect(jsonDecode(requests.single.body), {
      'nickname': '우현',
      'login_id': 'woohyun',
      'password': 'password1',
    });
    expect(session.token, 'new-token');
    expect(session.account.nickname, '우현');
    expect(repository.session, same(session));
    expect(api.token, 'new-token');
    expect(store.session!.token, 'new-token');
  });

  test('a taken login id throws LoginIdTakenException', () async {
    answer = (_) => _json({'detail': 'login_id_taken'}, 409);
    await expectLater(
      repository.signUp(
        nickname: 'a',
        loginId: 'woohyun',
        password: 'password1',
      ),
      throwsA(isA<LoginIdTakenException>()),
    );
    expect(repository.session, isNull);
    expect(store.session, isNull);
  });

  test('login keeps and saves the session', () async {
    await repository.logIn(loginId: 'woohyun', password: 'password1');
    expect(requests.single.url.path, '/auth/login');
    expect(requests.single.headers.containsKey('Authorization'), isFalse);
    expect(repository.session!.account.loginId, 'woohyun');
    expect(store.session, isNotNull);
  });

  test('wrong credentials throw InvalidCredentialsException', () async {
    answer = (_) => _json({'detail': 'invalid_credentials'}, 401);
    await expectLater(
      repository.logIn(loginId: 'woohyun', password: 'nope'),
      throwsA(isA<InvalidCredentialsException>()),
    );
    expect(repository.session, isNull);
  });

  test('network failures pass through as ApiException', () async {
    answer = (_) => _json({}, 503);
    await expectLater(
      repository.logIn(loginId: 'woohyun', password: 'password1'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.server),
      ),
    );
  });

  test('an unreadable login answer is a server error', () async {
    answer = (_) => _json({'token': 'x'}, 200);
    await expectLater(
      repository.logIn(loginId: 'woohyun', password: 'password1'),
      throwsA(isA<ApiException>()),
    );
    expect(repository.session, isNull);
  });

  test('restore loads the saved session and sets the token', () async {
    store.session = AuthSession.fromJson({'token': 'saved', 'user': _user});
    final session = await repository.restoreSession();
    expect(session!.token, 'saved');
    expect(api.token, 'saved');
  });

  test('restore without a saved session stays logged out', () async {
    expect(await repository.restoreSession(), isNull);
    expect(api.token, isNull);
  });

  test('logout forgets the session everywhere', () async {
    await repository.logIn(loginId: 'woohyun', password: 'password1');
    await repository.logOut();
    expect(repository.session, isNull);
    expect(api.token, isNull);
    expect(store.session, isNull);
  });

  test('a rejected token clears the session and reports it', () async {
    await repository.logIn(loginId: 'woohyun', password: 'password1');
    var expired = 0;
    repository.sessionExpired.listen((_) => expired++);
    answer = (_) => _json({'detail': 'invalid_token'}, 401);
    await expectLater(api.get('/users/me'), throwsA(isA<ApiException>()));
    await pumpEventQueue();
    expect(expired, 1);
    expect(repository.session, isNull);
    expect(store.session, isNull);
  });

  test('the session never prints its token', () {
    final session = AuthSession.fromJson({'token': 'secret', 'user': _user});
    expect('$session', isNot(contains('secret')));
  });

  group('InMemoryAuthRepository', () {
    test('follows the same rules as the server', () async {
      final repository = InMemoryAuthRepository();
      await repository.signUp(
        nickname: '우현',
        loginId: 'woohyun',
        password: 'password1',
      );
      await expectLater(
        repository.signUp(
          nickname: '다른',
          loginId: 'woohyun',
          password: 'password2',
        ),
        throwsA(isA<LoginIdTakenException>()),
      );
      await repository.logOut();
      await expectLater(
        repository.logIn(loginId: 'woohyun', password: 'wrong-pass'),
        throwsA(isA<InvalidCredentialsException>()),
      );
      await expectLater(
        repository.logIn(loginId: 'nobody', password: 'password1'),
        throwsA(isA<InvalidCredentialsException>()),
      );
      final session = await repository.logIn(
        loginId: 'woohyun',
        password: 'password1',
      );
      expect(session.account.nickname, '우현');
    });
  });
}
