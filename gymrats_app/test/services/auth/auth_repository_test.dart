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

  group('Google (P7)', () {
    test('Google sends the ID token and keeps the new session', () async {
      answer = (_) =>
          _json({'token': 'g-token', 'user': _user, 'created': true}, 201);
      final result = await repository.signInWith(
        SocialProvider.google,
        'id',
        nickname: '우현',
      );
      expect(requests.single.url.path, '/auth/google');
      expect(jsonDecode(requests.single.body), {
        'id_token': 'id',
        'nickname': '우현',
      });
      expect(requests.single.headers['Authorization'], isNull);
      expect(result.isNewAccount, isTrue);
      expect(result.session.token, 'g-token');
      expect(repository.session, same(result.session));
      expect(store.session!.token, 'g-token');
      expect(api.token, 'g-token');
    });

    test('an existing account sends no nickname and is not new', () async {
      answer = (_) =>
          _json({'token': 'g-token', 'user': _user, 'created': false}, 200);
      final result = await repository.signInWith(SocialProvider.google, 'id');
      expect(requests.single.url.path, '/auth/google');
      expect(jsonDecode(requests.single.body), {'id_token': 'id'});
      expect(result.isNewAccount, isFalse);
    });

    test('a new provider account answers signup_required', () async {
      answer = (_) => _json({'detail': 'signup_required', 'nickname': ''}, 404);
      await expectLater(
        repository.signInWith(SocialProvider.google, 'id'),
        throwsA(isA<SocialSignUpRequiredException>()),
      );
      expect(repository.session, isNull);
      // Another 404 stays an ApiException.
      answer = (_) => _json({'detail': 'not_found'}, 404);
      await expectLater(
        repository.signInWith(SocialProvider.google, 'id'),
        throwsA(isA<ApiException>()),
      );
    });

    test(
      'a refused token and an unavailable provider have their own errors',
      () async {
        answer = (_) => _json({'detail': 'invalid_social_token'}, 401);
        await expectLater(
          repository.signInWith(SocialProvider.google, 'id'),
          throwsA(isA<SocialTokenRejectedException>()),
        );
        answer = (_) => _json({'detail': 'social_login_unavailable'}, 503);
        await expectLater(
          repository.signInWith(SocialProvider.google, 'at'),
          throwsA(isA<SocialLoginUnavailableException>()),
        );
        answer = (_) => _json({'detail': 'x'}, 422);
        await expectLater(
          repository.signInWith(SocialProvider.google, 'at'),
          throwsA(isA<ApiException>()),
        );
        expect(repository.session, isNull);
        expect(store.session, isNull);
      },
    );

    test('a reply without the account is a server error', () async {
      answer = (_) => _json({'created': true}, 201);
      await expectLater(
        repository.signInWith(SocialProvider.google, 'id'),
        throwsA(isA<ApiException>()),
      );
    });

    test('body info is sent with consent and the login token', () async {
      await repository.logIn(loginId: 'woohyun', password: 'password1');
      answer = (_) => _json({'height_cm': 175.0, 'weight_kg': 70.5}, 200);
      await repository.saveBodyInfo(heightCm: 175, weightKg: 70.5);
      final request = requests.last;
      expect(request.method, 'POST');
      expect(request.url.path, '/users/me/body');
      expect(request.headers['Authorization'], 'Bearer new-token');
      expect(jsonDecode(request.body), {
        'height_cm': 175.0,
        'weight_kg': 70.5,
        'consent': true,
      });
    });

    test('in memory: one account per provider identity', () async {
      final memory = InMemoryAuthRepository();
      await expectLater(
        memory.signInWith(SocialProvider.google, 'sub-1'),
        throwsA(isA<SocialSignUpRequiredException>()),
      );
      final first = await memory.signInWith(
        SocialProvider.google,
        'sub-1',
        nickname: '우현',
      );
      expect(first.isNewAccount, isTrue);
      expect(first.session.account.loginId, 'g_sub-1');
      expect(first.session.account.nickname, '우현');
      final again = await memory.signInWith(SocialProvider.google, 'sub-1');
      expect(again.isNewAccount, isFalse);
      expect(again.session.account.id, first.session.account.id);
      final other = await memory.signInWith(
        SocialProvider.google,
        'sub-2',
        nickname: '현우',
      );
      expect(other.isNewAccount, isTrue);
      expect(other.session.account.id, isNot(first.session.account.id));
      await expectLater(
        memory.signInWith(SocialProvider.google, ''),
        throwsA(isA<SocialTokenRejectedException>()),
      );
    });

    test(
      'in memory: body info needs a login and is kept per account',
      () async {
        final memory = InMemoryAuthRepository();
        await expectLater(
          memory.saveBodyInfo(heightCm: 175, weightKg: 70),
          throwsStateError,
        );
        final session = (await memory.signInWith(
          SocialProvider.google,
          's',
          nickname: '우현',
        )).session;
        await memory.saveBodyInfo(heightCm: 175, weightKg: 70);
        expect(memory.bodyInfo[session.account.id], (
          heightCm: 175.0,
          weightKg: 70.0,
        ));
      },
    );
  });
}
