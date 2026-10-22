// AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/auth_session.dart';

const _json = {
  'token': 'secret-token',
  'user': {'id': 3, 'login_id': 'woohyun', 'nickname': '우현'},
};

void main() {
  test('reads the server answer', () {
    final session = AuthSession.fromJson(_json);
    expect(session.token, 'secret-token');
    expect(session.account.id, 3);
    expect(session.account.loginId, 'woohyun');
    expect(session.account.nickname, '우현');
  });

  test('writes the same shape it reads, so a saved session restores', () {
    final session = AuthSession.fromJson(_json);
    expect(session.toJson(), _json);
    final restored = AuthSession.fromJson(session.toJson());
    expect(restored.token, session.token);
    expect(restored.account.toJson(), session.account.toJson());
  });

  test('a missing field is an error, not a half-filled session', () {
    expect(
      () => AuthSession.fromJson({'token': 'x'}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => Account.fromJson({'id': 1, 'login_id': 'a'}),
      throwsA(isA<TypeError>()),
    );
  });

  test('never prints the token', () {
    expect('${AuthSession.fromJson(_json)}', isNot(contains('secret-token')));
  });
}
