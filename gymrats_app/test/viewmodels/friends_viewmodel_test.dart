import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/models/exercise_type.dart';
import 'package:gymrats_app/models/user_profile.dart';
import 'package:gymrats_app/services/api/api_client.dart';
import 'package:gymrats_app/services/friends/friend_repository.dart';
import 'package:gymrats_app/viewmodels/friends_viewmodel.dart';

import '../support/fakes.dart';

const _me = FriendPerson(id: 1, nickname: '쥐돌이', code: '쥐돌이#0001');
const _friend = FriendPerson(id: 2, nickname: '헬창', code: '헬창#0002');

/// The in-memory repository, which can be told to fail its next calls.
class _Repo extends InMemoryFriendRepository {
  _Repo({super.now}) : super(me: _me, people: const [_friend]);

  Object? failWith;
  int fetches = 0, cancels = 0;
  Completer<void>? holdInvite, holdAccept;

  void _maybeFail() {
    if (failWith case final error?) throw error;
  }

  /// While set, reading the overview waits for it.
  Completer<void>? holdFetch;

  @override
  Future<FriendsOverview> fetchOverview() async {
    fetches++;
    await holdFetch?.future;
    _maybeFail();
    return super.fetchOverview();
  }

  @override
  Future<FriendAddOutcome> addFriend(String code) async {
    _maybeFail();
    return super.addFriend(code);
  }

  /// Called with each invite as soon as it is made, as the friend's app.
  void Function(BattleInvite made)? onInvited;

  /// The `character` of each invite sent, in order.
  final sentCharacters = <String?>[];

  @override
  Future<BattleInvite> invite(
    int friendId,
    ExerciseType exercise, {
    String? character,
  }) async {
    sentCharacters.add(character);
    await holdInvite?.future;
    _maybeFail();
    final made = await super.invite(friendId, exercise, character: character);
    onInvited?.call(made);
    return made;
  }

  @override
  Future<BattleInvite> acceptInvite(int inviteId) async {
    await holdAccept?.future;
    _maybeFail();
    return super.acceptInvite(inviteId);
  }

  @override
  Future<BattleInvite> fetchInvite(int inviteId) async {
    _maybeFail();
    return super.fetchInvite(inviteId);
  }

  /// The `ifPending` of each cancel, in order.
  final cancelledIfPending = <bool>[];

  @override
  Future<void> cancelInvite(int inviteId, {bool ifPending = false}) async {
    cancels++;
    cancelledIfPending.add(ifPending);
    _maybeFail();
    return super.cancelInvite(inviteId, ifPending: ifPending);
  }
}

ApiException _refused(String code) =>
    ApiException(ApiErrorKind.rejected, statusCode: 400, code: code);

void main() {
  group('friendErrorMessage', () {
    test('says each server refusal in words', () {
      final codes = {
        'invalid_code': '닉네임#0000',
        'user_not_found': '그런 친구 코드가 없어요',
        'cannot_add_self': '내 친구 코드예요',
        'already_friends': '이미 친구예요',
        'already_requested': '이미 요청을 보냈어요',
        'not_friends': '친구에게만',
        'invite_expired': '시간이 지났어요',
        'invite_closed': '이미 끝난',
        'invite_busy': '이미 진행 중인 친구 대결',
        'request_not_found': '이미 처리된',
        'invite_not_found': '이미 처리된',
      };
      for (final MapEntry(:key, :value) in codes.entries) {
        expect(friendErrorMessage(_refused(key)), contains(value), reason: key);
      }
    });

    test('falls back to the API message, or a general one', () {
      expect(
        friendErrorMessage(const ApiException(ApiErrorKind.network)),
        const ApiException(ApiErrorKind.network).message,
      );
      expect(friendErrorMessage(StateError('x')), contains('다시 시도'));
    });
  });

  group('FriendsViewModel', () {
    late _Repo repo;
    late FriendsViewModel vm;

    setUp(() {
      repo = _Repo();
      vm = FriendsViewModel(repository: repo);
    });

    tearDown(() => vm.dispose());

    test('takeBack cancels an accepted invite, quietly even when it fails '
        'and after the page is gone', () async {
      final sent = repo.receiveInvite(_friend, ExerciseType.squat);
      final accepted = await repo.acceptInvite(sent.id);
      var notified = 0;
      vm.addListener(() => notified++);
      repo.failWith = const ApiException(ApiErrorKind.network);
      await vm.takeBack(accepted);
      expect(notified, 0);
      expect(vm.actionError, isNull);
      repo.failWith = null;
      expect((await repo.fetchInvite(sent.id)).status, InviteStatus.accepted);
      final gone = FriendsViewModel(repository: repo)..dispose();
      await gone.takeBack(accepted);
      expect((await repo.fetchInvite(sent.id)).status, InviteStatus.cancelled);
    });

    test('load reads the overview, and says why when it cannot', () async {
      await vm.load();
      expect(vm.overview!.code, '쥐돌이#0001');
      expect(vm.loadError, isNull);
      repo.failWith = const ApiException(ApiErrorKind.network);
      await vm.load();
      expect(vm.loadError, contains('서버에 연결하지 못했어요'));
      // The last overview stays on screen.
      expect(vm.overview, isNotNull);
      repo.failWith = null;
      await vm.load();
      expect(vm.loadError, isNull);
    });

    test('a load already under way is not started twice', () async {
      final first = vm.load(), second = vm.load();
      await Future.wait([first, second]);
      expect(repo.fetches, 1);
    });

    test('addFriend sends the request and reloads', () async {
      expect(await vm.addFriend(' 헬창#0002 '), isTrue);
      expect(vm.addNotice, '친구 요청을 보냈어요.');
      expect(vm.addError, isNull);
      expect(vm.overview!.outgoing.single.person, _friend);
    });

    test('addFriend accepting their request says so', () async {
      repo.incoming.add(const FriendRequestItem(id: 9, person: _friend));
      expect(await vm.addFriend('헬창#0002'), isTrue);
      expect(vm.addNotice, contains('바로 친구가 됐어요'));
      expect(vm.overview!.friends, [_friend]);
    });

    test(
      'addFriend refuses an empty code and shows a server refusal',
      () async {
        expect(await vm.addFriend('   '), isFalse);
        expect(vm.addError, '친구 코드를 넣어 주세요.');
        expect(await vm.addFriend('헬창#0002'), isTrue);
        expect(await vm.addFriend('헬창#0002'), isFalse);
        expect(vm.addError, contains('이미 요청을 보냈어요'));
        expect(vm.addNotice, isNull);
        expect(vm.adding, isFalse);
      },
    );

    test('a second add while one is under way is ignored', () async {
      final first = vm.addFriend('헬창#0002');
      expect(vm.adding, isTrue);
      expect(await vm.addFriend('헬창#0002'), isFalse);
      expect(await first, isTrue);
    });

    test('requests are answered, then the lists reload', () async {
      repo.incoming.addAll(const [
        FriendRequestItem(id: 10, person: _friend),
        FriendRequestItem(
          id: 11,
          person: FriendPerson(id: 3, nickname: '근육', code: '근육#0003'),
        ),
      ]);
      await vm.acceptRequest(10);
      await vm.declineRequest(11);
      expect(vm.overview!.friends, [_friend]);
      expect(vm.overview!.incoming, isEmpty);
      expect(vm.busy, isEmpty);
      await vm.acceptRequest(10);
      expect(vm.actionError, '이미 처리된 요청이에요.');
    });

    test('accepting an invite returns it accepted, or null with why', () async {
      final invite = repo.receiveInvite(_friend, ExerciseType.squat);
      final accepted = await vm.acceptInvite(invite);
      expect(accepted!.status, InviteStatus.accepted);
      expect(accepted.from, _friend);
      expect(await vm.acceptInvite(invite), isNull);
      expect(vm.actionError, contains('이미 끝난'));
      final other = repo.receiveInvite(_friend, ExerciseType.pushUp);
      await vm.declineInvite(other.id);
      expect(vm.overview!.invites, isEmpty);
    });

    test('two taps on 수락 accept the invite once', () async {
      final invite = repo.receiveInvite(_friend, ExerciseType.squat);
      final results = await Future.wait([
        vm.acceptInvite(invite),
        vm.acceptInvite(invite),
      ]);
      expect(results.whereType<BattleInvite>(), hasLength(1));
      expect(vm.actionError, isNull);
    });

    test('notifies listeners and stays quiet once disposed', () async {
      var heard = 0;
      final own = FriendsViewModel(repository: repo)
        ..addListener(() => heard++);
      final loading = own.load();
      own.dispose();
      await loading;
      expect(heard, 1);
    });
  });

  group('FriendBattle', () {
    test('inviting when there is no accepted invite', () {
      const mine = FriendBattle(friend: _friend, exercise: ExerciseType.pushUp);
      expect(mine.inviting, isTrue);
      final theirs = FriendBattle(
        friend: _friend,
        exercise: ExerciseType.pushUp,
        accepted: BattleInvite(
          id: 1,
          from: _friend,
          to: _me,
          exercise: ExerciseType.pushUp,
          status: InviteStatus.accepted,
          expiresAt: DateTime(2026),
        ),
      );
      expect(theirs.inviting, isFalse);
    });
  });

  group('FriendInviteWaitViewModel', () {
    late DateTime clock;
    late _Repo repo;

    setUp(() {
      clock = DateTime(2026, 11, 24, 12);
      repo = _Repo(now: () => clock)..friends.add(_friend);
    });

    FriendInviteWaitViewModel inviting({
      ExerciseType exercise = ExerciseType.squat,
    }) {
      final vm = FriendInviteWaitViewModel(
        repository: repo,
        battle: FriendBattle(friend: _friend, exercise: exercise),
        // The test reads by hand.
        pollEvery: const Duration(hours: 1),
        now: () => clock,
      );
      addTearDown(vm.dispose);
      return vm;
    }

    FriendInviteWaitViewModel invited(BattleInvite accepted) {
      final vm = FriendInviteWaitViewModel(
        repository: repo,
        battle: FriendBattle(
          friend: accepted.from,
          exercise: accepted.exercise,
          accepted: accepted,
        ),
        pollEvery: const Duration(hours: 1),
        now: () => clock,
      );
      addTearDown(vm.dispose);
      return vm;
    }

    test('inviting sends the invite for the friend and exercise', () async {
      final vm = inviting();
      await vm.start();
      expect(vm.invite!.to, _friend);
      expect(vm.invite!.exercise, ExerciseType.squat);
      expect(vm.ended, isNull);
      // A second start sends nothing more.
      await vm.start();
      expect(repo.invites, hasLength(1));
    });

    test('an invite that cannot be sent ends the wait at once', () async {
      repo.friends.clear();
      final vm = inviting();
      await vm.start();
      expect(vm.ended, contains('친구에게만'));
    });

    for (final (status, words) in [
      (InviteStatus.declined, '헬창님이 대결 신청을 거절했어요.'),
      (InviteStatus.cancelled, '헬창님이 대결을 취소했어요.'),
    ]) {
      test('a $status invite ends the wait', () async {
        final vm = inviting();
        var heard = 0;
        vm.addListener(() => heard++);
        await vm.start();
        repo.answer(vm.invite!.id, status);
        await vm.check();
        expect(vm.ended, words);
        expect(heard, 1);
        // Ended: further reads change nothing.
        repo.answer(vm.invite!.id, InviteStatus.accepted);
        await vm.check();
        expect(vm.ended, words);
      });
    }

    test('an invite left a minute without an answer ends the wait', () async {
      final vm = inviting();
      await vm.start();
      clock = clock.add(const Duration(seconds: 59));
      await vm.check();
      expect(vm.ended, isNull);
      clock = clock.add(const Duration(seconds: 1));
      await vm.check();
      expect(vm.ended, '헬창님이 1분 안에 수락하지 않았어요.');
    });

    test('past the minute the wait ends even without the server', () async {
      final vm = inviting();
      await vm.start();
      repo.failWith = const ApiException(ApiErrorKind.network);
      await vm.check();
      expect(vm.ended, isNull);
      clock = clock.add(const Duration(minutes: 1));
      await vm.check();
      expect(vm.ended, contains('1분 안에'));
    });

    test('accepted but not paired within 30 s: the wait ends and the invite '
        'is taken back', () async {
      final vm = inviting();
      await vm.start();
      repo.answer(vm.invite!.id, InviteStatus.accepted);
      await vm.check();
      expect(vm.ended, isNull);
      clock = clock.add(const Duration(seconds: 29));
      await vm.check();
      expect(vm.ended, isNull);
      clock = clock.add(const Duration(seconds: 1));
      await vm.check();
      expect(vm.ended, '헬창님과 연결하지 못했어요. 다시 신청해 주세요.');
      await Future<void>.delayed(Duration.zero);
      expect(repo.cancels, 1);
    });

    test('invited: holds the accepted invite and sends none', () async {
      final sent = repo.receiveInvite(_friend, ExerciseType.pushUp);
      final accepted = await repo.acceptInvite(sent.id);
      final vm = invited(accepted);
      await vm.start();
      expect(vm.invite!.id, sent.id);
      expect(repo.invites, hasLength(1));
      // The inviter left the waiting room.
      await repo.cancelInvite(sent.id);
      await vm.check();
      expect(vm.ended, '헬창님이 대결을 취소했어요.');
    });

    test('invited: the 30 s count starts at the accept', () async {
      final sent = repo.receiveInvite(_friend, ExerciseType.pushUp);
      final vm = invited(await repo.acceptInvite(sent.id));
      await vm.start();
      clock = clock.add(const Duration(seconds: 30));
      await vm.check();
      expect(vm.ended, contains('연결하지 못했어요'));
    });

    test(
      'paired: stop ends the reading, and leave takes nothing back',
      () async {
        final vm = inviting();
        await vm.start();
        repo.answer(vm.invite!.id, InviteStatus.accepted);
        vm.stop();
        repo.answer(vm.invite!.id, InviteStatus.cancelled);
        await vm.check();
        expect(vm.ended, isNull);
        await vm.leave();
        expect(repo.cancels, 0);
      },
    );

    test('paired while my invite is still open (both invited each other): '
        'it is taken back, once', () async {
      final vm = inviting();
      await vm.start();
      await vm.paired();
      await vm.paired();
      expect(repo.cancels, 1);
      expect(repo.cancelledIfPending, [true]);
      expect(
        (await repo.fetchInvite(vm.invite!.id)).status,
        InviteStatus.cancelled,
      );
      // And reading stopped.
      repo.answer(vm.invite!.id, InviteStatus.declined);
      await vm.check();
      expect(vm.ended, isNull);
    });

    test('paired just after the friend accepted, before my next read: the '
        'accept stays, so the friend is not told I cancelled', () async {
      final vm = inviting();
      await vm.start();
      // Accepted on the server; my copy still says pending.
      repo.answer(vm.invite!.id, InviteStatus.accepted);
      await vm.paired();
      expect(repo.cancelledIfPending, [true]);
      expect(vm.ended, isNull);
      expect(
        (await repo.fetchInvite(vm.invite!.id)).status,
        InviteStatus.accepted,
      );
    });

    test('paired through an accepted invite: nothing is taken back', () async {
      final vm = inviting();
      await vm.start();
      repo.answer(vm.invite!.id, InviteStatus.accepted);
      await vm.check();
      await vm.paired();
      expect(repo.cancels, 0);
    });

    test(
      "paired on the invited side: the friend's invite is left alone",
      () async {
        final sent = repo.receiveInvite(_friend, ExerciseType.pushUp);
        final vm = invited(await repo.acceptInvite(sent.id));
        await vm.start();
        await vm.paired();
        expect(repo.cancels, 0);
      },
    );

    test('the battle is over: the accepted invite is taken back once, so '
        'both players are free at once', () async {
      final sent = repo.receiveInvite(_friend, ExerciseType.pushUp);
      final vm = invited(await repo.acceptInvite(sent.id));
      await vm.start();
      await vm.paired();
      await vm.finished();
      await vm.finished();
      expect(repo.cancelledIfPending, [false]);
      expect((await repo.fetchInvite(sent.id)).status, InviteStatus.cancelled);
    });

    test('the invite made after the battle was over is taken back in any '
        'case', () async {
      repo.holdInvite = Completer<void>();
      repo.onInvited = (made) => repo.answer(made.id, InviteStatus.accepted);
      final vm = inviting();
      final starting = vm.start();
      await vm.paired();
      await vm.finished();
      repo.holdInvite!.complete();
      await starting;
      await Future<void>.delayed(Duration.zero);
      expect(repo.cancelledIfPending, [false]);
      expect(repo.invites.single.status, InviteStatus.cancelled);
    });

    test('finished before any invite was made takes nothing back', () async {
      repo.holdInvite = Completer<void>();
      final vm = inviting();
      unawaited(vm.start());
      await vm.finished();
      expect(repo.cancels, 0);
      repo.holdInvite!.complete();
    });

    test('leaving while waiting cancels an open or accepted invite', () async {
      final open = inviting();
      await open.start();
      await open.leave();
      expect(repo.cancels, 1);
      expect(
        (await repo.fetchInvite(open.invite!.id)).status,
        InviteStatus.cancelled,
      );

      final accepted = inviting();
      await accepted.start();
      repo.answer(accepted.invite!.id, InviteStatus.accepted);
      await accepted.check();
      await accepted.leave();
      expect(repo.cancels, 2);
    });

    test('a failed cancel on leaving is quiet', () async {
      final vm = inviting();
      await vm.start();
      repo.failWith = const ApiException(ApiErrorKind.network);
      await vm.leave();
      expect(repo.cancels, 1);
    });

    test('leaving before the invite is made takes it back once made', () async {
      repo.holdInvite = Completer<void>();
      final vm = inviting();
      final starting = vm.start();
      await vm.leave();
      repo.holdInvite!.complete();
      await starting;
      await Future<void>.delayed(Duration.zero);
      expect(repo.cancels, 1);
      expect(repo.cancelledIfPending, [false]);
      expect(vm.invite, isNull);
    });

    test('paired before the invite was made: once made, it is taken back '
        'only if still open', () async {
      repo.holdInvite = Completer<void>();
      final vm = inviting();
      final starting = vm.start();
      await vm.paired();
      // Nothing to take back yet.
      expect(repo.cancels, 0);
      repo.holdInvite!.complete();
      await starting;
      await Future<void>.delayed(Duration.zero);
      expect(repo.cancelledIfPending, [true]);
      expect(vm.invite, isNull);
    });

    test('paired before the invite was made, and the friend accepted it '
        'meanwhile: the accept stays', () async {
      repo.holdInvite = Completer<void>();
      // The friend accepts the moment the invite exists.
      repo.onInvited = (made) => repo.answer(made.id, InviteStatus.accepted);
      final vm = inviting();
      final starting = vm.start();
      await vm.paired();
      repo.holdInvite!.complete();
      await starting;
      await Future<void>.delayed(Duration.zero);
      expect(repo.cancelledIfPending, [true]);
      expect(repo.invites.single.status, InviteStatus.accepted);
    });

    test('reads the invite every pollEvery until it ends', () {
      fakeAsync((async) {
        var now = DateTime(2026, 11, 24, 12);
        final repo = _Repo(now: () => now)..friends.add(_friend);
        final vm = FriendInviteWaitViewModel(
          repository: repo,
          battle: const FriendBattle(
            friend: _friend,
            exercise: ExerciseType.pushUp,
          ),
          now: () => now,
        );
        unawaited(vm.start());
        async.flushMicrotasks();
        expect(vm.pollEvery, const Duration(seconds: 2));
        expect(vm.pairWithin, const Duration(seconds: 30));
        async.elapse(const Duration(seconds: 2));
        expect(vm.ended, isNull);
        repo.answer(vm.invite!.id, InviteStatus.declined);
        async.elapse(const Duration(seconds: 2));
        expect(vm.ended, contains('거절'));
        vm.dispose();
      });
    });
  });

  group('FriendInviteAlertViewModel', () {
    late _Repo repo;
    late FriendInviteAlertViewModel vm;

    setUp(() {
      repo = _Repo()..friends.add(_friend);
      vm = FriendInviteAlertViewModel(
        repository: repo,
        // The tests read by hand.
        pollEvery: const Duration(hours: 1),
      );
    });

    tearDown(() => vm.dispose());

    test('reads nothing until signed in', () async {
      repo.receiveInvite(_friend, ExerciseType.squat);
      await vm.check();
      expect(vm.current, isNull);
      expect(repo.fetches, 0);
      vm.setSignedIn(true);
      await pumpEventQueue();
      expect(vm.current!.from, _friend);
      expect(vm.current!.exercise, ExerciseType.squat);
      expect(vm.visible, isTrue);
    });

    test('offers the newest invite not answered here', () async {
      vm.setSignedIn(true);
      await pumpEventQueue();
      expect(vm.current, isNull);
      expect(vm.visible, isFalse);
      final older = repo.receiveInvite(_friend, ExerciseType.pushUp);
      final newer = repo.receiveInvite(_friend, ExerciseType.squat);
      await vm.check();
      expect(vm.current!.id, newer.id);
      await vm.decline();
      expect(vm.current, isNull);
      await vm.check();
      expect(vm.current!.id, older.id);
    });

    test('accept opens the battle with the accepted invite', () async {
      final sent = repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      final accepted = await vm.accept();
      expect(accepted!.id, sent.id);
      expect(accepted.status, InviteStatus.accepted);
      expect(vm.current, isNull);
      expect(vm.answering, isFalse);
      // Answered: not offered again.
      await vm.check();
      expect(vm.current, isNull);
    });

    test('a second friend battle accepted from another phone is busy: it '
        'says so and opens nothing', () async {
      repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      repo.failWith = const ApiException(
        ApiErrorKind.rejected,
        statusCode: 409,
        code: 'invite_busy',
      );
      expect(await vm.accept(), isNull);
      expect(vm.error, '이미 진행 중인 친구 대결이 있어요.');
      expect(vm.current, isNull);
    });

    test('an invite that ran out says so and is not offered again', () async {
      final sent = repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      repo.answer(sent.id, InviteStatus.cancelled);
      expect(await vm.accept(), isNull);
      expect(vm.error, '이미 끝난 대결 신청이에요.');
      expect(vm.visible, isTrue);
      vm.clearError();
      expect(vm.error, isNull);
      vm.clearError();
      expect(vm.visible, isFalse);
    });

    test('decline answers the server and hides at once', () async {
      final sent = repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      await vm.decline();
      expect(vm.current, isNull);
      expect(repo.invites.single.status, InviteStatus.declined);
      expect(sent.id, repo.invites.single.id);
      // Nothing to answer: both do nothing.
      await vm.decline();
      expect(await vm.accept(), isNull);
    });

    test('a decline the server refuses still hides it', () async {
      repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      repo.failWith = const ApiException(ApiErrorKind.network);
      await vm.decline();
      expect(vm.current, isNull);
    });

    test('hidden during a battle or in the background: no reading, no '
        'alert', () async {
      repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      expect(vm.visible, isTrue);
      vm.setHidden(true);
      expect(vm.visible, isFalse);
      final reads = repo.fetches;
      await vm.check();
      expect(repo.fetches, reads);
      vm.setHidden(false);
      await pumpEventQueue();
      expect(vm.visible, isTrue);
      vm.setForeground(false);
      expect(vm.visible, isFalse);
      vm.setForeground(true);
      expect(vm.visible, isTrue);
    });

    test('signing out forgets the invite and what was answered', () async {
      final sent = repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      await vm.decline();
      repo.answer(sent.id, InviteStatus.pending);
      vm.setSignedIn(false);
      expect(vm.current, isNull);
      expect(vm.visible, isFalse);
      vm.setSignedIn(true);
      await pumpEventQueue();
      // A new account on this phone sees what is open for it.
      expect(vm.current!.id, sent.id);
    });

    test('a second answer while one is on its way does nothing', () async {
      final sent = repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      repo.holdAccept = Completer<void>();
      final first = vm.accept();
      expect(vm.answering, isTrue);
      expect(await vm.accept(), isNull);
      await vm.decline();
      // A read meanwhile changes nothing either.
      final reads = repo.fetches;
      await vm.check();
      expect(repo.fetches, reads);
      repo.holdAccept!.complete();
      expect((await first)!.id, sent.id);
      expect(repo.invites.single.status, InviteStatus.accepted);
    });

    test('no newer invite is offered while an answer is on its way', () async {
      final first = repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      repo.holdAccept = Completer<void>();
      final accepting = vm.accept();
      repo.receiveInvite(_friend, ExerciseType.pushUp);
      await vm.check();
      expect(vm.current!.id, first.id);
      repo.holdAccept!.complete();
      await accepting;
      expect(vm.current, isNull);
      // Accepted: one friend battle at a time, so the newer invite was taken
      // back and is not offered on the next read either.
      await vm.check();
      expect(vm.current, isNull);
    });

    test('declined: a newer invite comes on the next read', () async {
      repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      await vm.decline();
      repo.receiveInvite(_friend, ExerciseType.pushUp);
      await vm.check();
      expect(vm.current!.exercise, ExerciseType.pushUp);
    });

    test('signed out while accepting: the late answer opens nothing and the '
        'invite is taken back', () async {
      final sent = repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      repo.holdAccept = Completer<void>();
      final accepting = vm.accept();
      vm.setSignedIn(false);
      repo.holdAccept!.complete();
      expect(await accepting, isNull);
      await pumpEventQueue();
      expect(repo.cancels, 1);
      expect((await repo.fetchInvite(sent.id)).status, InviteStatus.cancelled);
      expect(vm.current, isNull);
      expect(vm.answering, isFalse);
    });

    test('signed out and in again while accepting: still dropped', () async {
      repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      repo.holdAccept = Completer<void>();
      final accepting = vm.accept();
      vm
        ..setSignedIn(false)
        ..setSignedIn(true);
      repo.holdAccept!.complete();
      expect(await accepting, isNull);
      await pumpEventQueue();
      expect(vm.answering, isFalse);
      expect(repo.cancels, 1);
      // Taken back: nothing to offer, and reading goes on.
      await vm.check();
      expect(vm.current, isNull);
    });

    test('a failed accept after a sign-out leaves no error behind', () async {
      repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      repo.holdAccept = Completer<void>();
      final accepting = vm.accept();
      vm.setSignedIn(false);
      repo.failWith = const ApiException(ApiErrorKind.unauthorized);
      repo.holdAccept!.complete();
      expect(await accepting, isNull);
      expect(vm.error, isNull);
      repo.failWith = null;
      vm.setSignedIn(true);
      expect(vm.error, isNull);
    });

    test(
      'a read that comes back after a switch of account is dropped',
      () async {
        vm.setSignedIn(true);
        await pumpEventQueue();
        // Account A's read is on its way when A signs out and B signs in.
        repo.receiveInvite(_friend, ExerciseType.pushUp);
        repo.holdFetch = Completer<void>();
        final reading = vm.check();
        vm
          ..setSignedIn(false)
          ..setSignedIn(true);
        final reads = repo.fetches;
        final held = repo.holdFetch!;
        repo.holdFetch = Completer<void>();
        held.complete();
        await reading;
        // A's answer is dropped, and B's own read starts at once.
        expect(vm.current, isNull);
        expect(repo.fetches, reads + 1);
        repo.holdFetch!.complete();
        await pumpEventQueue();
        expect(vm.current, isNotNull);
      },
    );

    test('a battle opened while accepting: the late answer opens nothing '
        'and the invite is taken back', () async {
      final sent = repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      repo.holdAccept = Completer<void>();
      final accepting = vm.accept();
      vm.setHidden(true);
      repo.holdAccept!.complete();
      expect(await accepting, isNull);
      await pumpEventQueue();
      expect(repo.cancelledIfPending, [false]);
      expect((await repo.fetchInvite(sent.id)).status, InviteStatus.cancelled);
      expect(vm.current, isNull);
      expect(vm.error, isNull);
    });

    test('the app went to the background while accepting: nothing opens '
        'and the invite is taken back, also after coming back', () async {
      for (final comeBack in [false, true]) {
        final sent = repo.receiveInvite(_friend, ExerciseType.squat);
        vm.setSignedIn(true);
        await pumpEventQueue();
        expect(vm.current!.id, sent.id, reason: 'comeBack $comeBack');
        repo.holdAccept = Completer<void>();
        final accepting = vm.accept();
        vm.setForeground(false);
        if (comeBack) vm.setForeground(true);
        repo.holdAccept!.complete();
        repo.holdAccept = null;
        expect(await accepting, isNull, reason: 'comeBack $comeBack');
        expect(vm.current, isNull);
        expect(vm.error, isNull);
        await pumpEventQueue();
        expect(
          (await repo.fetchInvite(sent.id)).status,
          InviteStatus.cancelled,
        );
        vm.setForeground(true);
      }
    });

    test('hidden and shown again while accepting: still dropped', () async {
      repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      repo.holdAccept = Completer<void>();
      final accepting = vm.accept();
      vm
        ..setHidden(true)
        ..setHidden(false);
      repo.holdAccept!.complete();
      expect(await accepting, isNull);
      expect(vm.current, isNull);
    });

    test('no answer from the server (network): it says so and offers the '
        'invite again on the next read', () async {
      final sent = repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      repo.failWith = const ApiException(ApiErrorKind.network);
      expect(await vm.accept(), isNull);
      expect(vm.error, const ApiException(ApiErrorKind.network).message);
      expect(vm.current, isNull);
      repo.failWith = null;
      await vm.check();
      expect(vm.current!.id, sent.id);
      // And this time it goes through.
      expect((await vm.accept())!.status, InviteStatus.accepted);
    });

    test('a refusal from the server is final: not offered again', () async {
      final sent = repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      repo.failWith = _refused('invite_busy');
      expect(await vm.accept(), isNull);
      repo.failWith = null;
      await vm.check();
      expect(vm.current, isNull);
      expect(sent.status, InviteStatus.pending);
    });

    test('a failed read keeps what shows', () async {
      repo.receiveInvite(_friend, ExerciseType.squat);
      vm.setSignedIn(true);
      await pumpEventQueue();
      repo.failWith = const ApiException(ApiErrorKind.network);
      await vm.check();
      expect(vm.current, isNotNull);
    });

    test('reads again every pollEvery while shown', () {
      fakeAsync((async) {
        final repo = _Repo()..friends.add(_friend);
        final vm = FriendInviteAlertViewModel(repository: repo);
        vm.setSignedIn(true);
        async.flushMicrotasks();
        expect(vm.pollEvery, const Duration(seconds: 5));
        expect(vm.current, isNull);
        repo.receiveInvite(_friend, ExerciseType.pushUp);
        async.elapse(const Duration(seconds: 5));
        expect(vm.current, isNotNull);
        vm.dispose();
      });
    });
  });

  group('A11: time left from expires_at, the character, how a wait ended', () {
    final start = DateTime(2026, 11, 27, 12);

    group('FriendsViewModel', () {
      test(
        'counts an invite to me down from the server\'s expires_at',
        () async {
          var clock = start;
          final repo = _Repo(now: () => clock);
          final invite = repo.receiveInvite(_friend, ExerciseType.squat);
          final vm = FriendsViewModel(repository: repo, now: () => clock);
          addTearDown(vm.dispose);
          await vm.load();
          expect(vm.secondsLeft(invite), 60);
          clock = start.add(const Duration(milliseconds: 17200));
          expect(vm.secondsLeft(invite), 43);
          clock = start.add(const Duration(seconds: 75));
          expect(vm.secondsLeft(invite), 0);
        },
      );

      test('an invite whose time is up here leaves the list at the next tick '
          'and stays out, though the server still lists it', () {
        fakeAsync((async) {
          // The device's clock runs 10 s ahead of the server's.
          var server = start;
          final repo = _Repo(now: () => server);
          final vm = FriendsViewModel(
            repository: repo,
            now: () => server.add(const Duration(seconds: 10)),
          );
          var heard = 0;
          vm.addListener(() => heard++);
          final invite = repo.receiveInvite(_friend, ExerciseType.squat);
          unawaited(vm.load());
          async.flushMicrotasks();
          expect(vm.overview!.invites.single.id, invite.id);
          expect(vm.secondsLeft(invite), 50);
          heard = 0;
          server = server.add(const Duration(seconds: 3));
          async.elapse(const Duration(seconds: 1));
          expect(heard, 1, reason: 'one tick, one change');
          expect(vm.secondsLeft(vm.overview!.invites.single), 47);
          server = start.add(const Duration(seconds: 50));
          async.elapse(const Duration(seconds: 1));
          expect(vm.overview!.invites, isEmpty);
          // The server's minute is not over: it still lists the invite.
          unawaited(vm.load());
          async.flushMicrotasks();
          expect(vm.overview!.invites, isEmpty);
          vm.dispose();
        });
      });

      test('a normal clock: the card leaves when the count reaches 0 (user, '
          '2026-11-27)', () {
        fakeAsync((async) {
          var clock = start;
          final repo = _Repo(now: () => clock);
          final vm = FriendsViewModel(repository: repo, now: () => clock);
          repo.receiveInvite(_friend, ExerciseType.squat);
          unawaited(vm.load());
          async.flushMicrotasks();
          clock = start.add(const Duration(seconds: 59));
          async.elapse(const Duration(seconds: 1));
          expect(vm.secondsLeft(vm.overview!.invites.single), 1);
          clock = start.add(const Duration(seconds: 60));
          async.elapse(const Duration(seconds: 1));
          expect(vm.overview!.invites, isEmpty);
          vm.dispose();
        });
      });

      test('a clock over a minute ahead: an invite at 0 from the first sight '
          'stays listed at 0 while the server lists it, and goes with the '
          'next read that does not (user, 2026-11-27)', () {
        fakeAsync((async) {
          var server = start;
          final repo = _Repo(now: () => server);
          final vm = FriendsViewModel(
            repository: repo,
            now: () => server.add(const Duration(seconds: 61)),
          );
          final sent = repo.receiveInvite(_friend, ExerciseType.squat);
          unawaited(vm.load());
          async.flushMicrotasks();
          final shown = vm.overview!.invites.single;
          expect(shown.id, sent.id);
          expect(vm.secondsLeft(shown), 0);
          // Ticks and a read while the server still lists it: it stays.
          server = start.add(const Duration(seconds: 30));
          async.elapse(const Duration(seconds: 3));
          unawaited(vm.load());
          async.flushMicrotasks();
          expect(vm.overview!.invites.single.id, sent.id);
          // The server's minute is over: its list no longer has it.
          server = start.add(const Duration(seconds: 60));
          unawaited(vm.load());
          async.flushMicrotasks();
          expect(vm.overview!.invites, isEmpty);
          vm.dispose();
        });
      });

      test('ticks only while an invite to me is listed', () {
        fakeAsync((async) {
          var clock = start;
          final repo = _Repo(now: () => clock);
          final vm = FriendsViewModel(repository: repo, now: () => clock);
          var heard = 0;
          vm.addListener(() => heard++);
          unawaited(vm.load());
          async.flushMicrotasks();
          heard = 0;
          async.elapse(const Duration(seconds: 5));
          expect(heard, 0, reason: 'nothing to count');
          repo.receiveInvite(_friend, ExerciseType.pushUp);
          unawaited(vm.load());
          async.flushMicrotasks();
          heard = 0;
          clock = clock.add(const Duration(seconds: 3));
          async.elapse(const Duration(seconds: 3));
          expect(heard, 3);
          clock = clock.add(const Duration(minutes: 1));
          async.elapse(const Duration(seconds: 1));
          expect(vm.overview!.invites, isEmpty);
          heard = 0;
          async.elapse(const Duration(seconds: 5));
          expect(heard, 0, reason: 'the last invite went: no more ticks');
          vm.dispose();
          expect(async.periodicTimerCount, 0);
        });
      });

      test('a given profile is used as is; none given reads one', () async {
        final users = FakeUserRepository()
          ..profile = const UserProfile(name: '읽음');
        final given = FriendsViewModel(repository: _Repo());
        addTearDown(given.dispose);
        given.useProfile(const UserProfile(name: '넘김'), users: users);
        expect(given.profile!.name, '넘김');
        expect(users.fetchCount, 0);
        expect((await given.profileForSheet())!.name, '넘김');
        expect(users.fetchCount, 0);

        final none = FriendsViewModel(repository: _Repo());
        addTearDown(none.dispose);
        none.useProfile(null, users: users);
        await pumpEventQueue();
        expect(users.fetchCount, 1);
        expect(none.profile!.name, '읽음');
      });

      test(
        'refreshProfile reads again; a failed read keeps the profile held',
        () async {
          final users = FakeUserRepository();
          final vm = FriendsViewModel(repository: _Repo());
          addTearDown(vm.dispose);
          vm.useProfile(
            const UserProfile(name: '예전', bestReps: 3),
            users: users,
          );
          users.profile = const UserProfile(name: '새로', bestReps: 9);
          expect((await vm.refreshProfile())!.bestReps, 9);
          expect(vm.profile!.bestReps, 9);
          users.error = Exception('offline');
          expect((await vm.refreshProfile())!.bestReps, 9);
          expect(vm.profile!.name, '새로');
        },
      );

      test('one profile read at a time; none without a source', () async {
        final users = FakeUserRepository()..gate = Completer<void>();
        final vm = FriendsViewModel(repository: _Repo());
        addTearDown(vm.dispose);
        expect(await vm.profileForSheet(), isNull, reason: 'nothing to read');
        vm.useProfile(null, users: users);
        final second = vm.refreshProfile();
        expect(users.fetchCount, 1);
        users.gate!.complete();
        expect((await second)!.name, '우현');
        expect(users.fetchCount, 1);
      });
    });

    group('FriendInviteWaitViewModel', () {
      late DateTime clock;
      late _Repo repo;

      setUp(() {
        clock = start;
        repo = _Repo(now: () => clock)..friends.add(_friend);
      });

      FriendInviteWaitViewModel inviting({String? character}) {
        final vm = FriendInviteWaitViewModel(
          repository: repo,
          battle: const FriendBattle(
            friend: _friend,
            exercise: ExerciseType.squat,
          ),
          character: character,
          pollEvery: const Duration(hours: 1),
          now: () => clock,
        );
        addTearDown(vm.dispose);
        return vm;
      }

      test('my invite carries my character', () async {
        final vm = inviting(character: 'kangaroo');
        await vm.start();
        expect(repo.sentCharacters, ['kangaroo']);
        expect(vm.invite!.character, 'kangaroo');
      });

      test('without a character the invite goes as an older app\'s', () async {
        final vm = inviting();
        await vm.start();
        expect(repo.sentCharacters, [null]);
        expect(vm.invite!.character, '');
      });

      test('secondsLeft is the full minute until the invite is made, then '
          'counts from its expires_at, cut to 0..60', () async {
        repo.holdInvite = Completer<void>();
        final vm = inviting();
        final started = vm.start();
        expect(vm.secondsLeft, 60);
        clock = start.add(const Duration(seconds: 2));
        repo.holdInvite!.complete();
        await started;
        expect(vm.secondsLeft, 60, reason: 'made at +2 s, open for a minute');
        clock = start.add(const Duration(milliseconds: 44500));
        expect(vm.secondsLeft, 18);
        clock = start.add(const Duration(minutes: 3));
        expect(vm.secondsLeft, 0);
        // A device clock behind the server's never shows more than 60.
        clock = start.subtract(const Duration(minutes: 3));
        expect(vm.secondsLeft, 60);
      });

      test('endedBy is null while the wait goes on', () async {
        final vm = inviting();
        await vm.start();
        await vm.check();
        expect(vm.ended, isNull);
        expect(vm.endedBy, isNull);
      });

      test('declined → declined', () async {
        final vm = inviting();
        await vm.start();
        repo.answer(vm.invite!.id, InviteStatus.declined);
        await vm.check();
        expect(vm.endedBy, FriendWaitEnd.declined);
      });

      test('the server says expired → expired', () async {
        final vm = inviting();
        await vm.start();
        clock = clock.add(const Duration(minutes: 1));
        await vm.check();
        expect(vm.invite!.status, InviteStatus.expired);
        expect(vm.endedBy, FriendWaitEnd.expired);
      });

      test('the device clock says the minute is over (server not reached) → '
          'expired, though the invite still reads pending', () async {
        final vm = inviting();
        await vm.start();
        repo.failWith = const ApiException(ApiErrorKind.network);
        clock = clock.add(const Duration(minutes: 1));
        await vm.check();
        expect(vm.invite!.status, InviteStatus.pending);
        expect(vm.endedBy, FriendWaitEnd.expired);
      });

      test('cancelled, not paired in time, or not sent → other', () async {
        final cancelled = inviting();
        await cancelled.start();
        repo.answer(cancelled.invite!.id, InviteStatus.cancelled);
        await cancelled.check();
        expect(cancelled.endedBy, FriendWaitEnd.other);

        final sent = repo.receiveInvite(_friend, ExerciseType.squat);
        final accepted = await repo.acceptInvite(sent.id);
        final unpaired = FriendInviteWaitViewModel(
          repository: repo,
          battle: FriendBattle(
            friend: _friend,
            exercise: ExerciseType.squat,
            accepted: accepted,
          ),
          pollEvery: const Duration(hours: 1),
          now: () => clock,
        );
        addTearDown(unpaired.dispose);
        await unpaired.start();
        clock = clock.add(const Duration(seconds: 30));
        await unpaired.check();
        expect(unpaired.ended, contains('연결하지 못했어요'));
        expect(unpaired.endedBy, FriendWaitEnd.other);

        repo.friends.clear();
        final refused = inviting();
        await refused.start();
        expect(refused.ended, contains('친구에게만'));
        expect(refused.endedBy, FriendWaitEnd.other);
      });
    });

    group('FriendInviteAlertViewModel', () {
      test('secondsLeft counts the shown invite from its expires_at; 0 without '
          'one', () async {
        var clock = start;
        final repo = _Repo(now: () => clock);
        final vm = FriendInviteAlertViewModel(
          repository: repo,
          pollEvery: const Duration(hours: 1),
          now: () => clock,
        );
        addTearDown(vm.dispose);
        expect(vm.secondsLeft, 0);
        repo.receiveInvite(_friend, ExerciseType.squat, character: 'bear');
        vm.setSignedIn(true);
        await pumpEventQueue();
        expect(vm.current!.character, 'bear');
        expect(vm.secondsLeft, 60);
        clock = start.add(const Duration(seconds: 21));
        expect(vm.secondsLeft, 39);
      });

      test('at 0 the alert goes, and the invite is not offered again', () {
        fakeAsync((async) {
          var server = start;
          final repo = _Repo(now: () => server);
          // The device's clock runs 5 s ahead: the server still lists it.
          final vm = FriendInviteAlertViewModel(
            repository: repo,
            pollEvery: const Duration(hours: 1),
            now: () => server.add(const Duration(seconds: 5)),
          );
          repo.receiveInvite(_friend, ExerciseType.squat);
          vm.setSignedIn(true);
          async.flushMicrotasks();
          expect(vm.visible, isTrue);
          var heard = 0;
          vm.addListener(() => heard++);
          server = start.add(const Duration(seconds: 1));
          async.elapse(const Duration(seconds: 1));
          expect(heard, 1, reason: 'a tick tells the new count');
          expect(vm.secondsLeft, 54);
          server = start.add(const Duration(seconds: 55));
          async.elapse(const Duration(seconds: 1));
          expect(vm.current, isNull);
          expect(vm.visible, isFalse);
          unawaited(vm.check());
          async.flushMicrotasks();
          expect(vm.current, isNull, reason: 'over here, whatever the read');
          expect(async.periodicTimerCount, 1, reason: 'only the reading');
          vm.dispose();
        });
      });

      test('a normal clock: the alert goes when the count reaches 0 (user, '
          '2026-11-27)', () {
        fakeAsync((async) {
          var clock = start;
          final repo = _Repo(now: () => clock);
          final vm = FriendInviteAlertViewModel(
            repository: repo,
            pollEvery: const Duration(hours: 1),
            now: () => clock,
          );
          repo.receiveInvite(_friend, ExerciseType.squat);
          vm.setSignedIn(true);
          async.flushMicrotasks();
          expect(vm.secondsLeft, 60);
          clock = start.add(const Duration(seconds: 59));
          async.elapse(const Duration(seconds: 1));
          expect(vm.visible, isTrue);
          clock = start.add(const Duration(seconds: 60));
          async.elapse(const Duration(seconds: 1));
          expect(vm.current, isNull);
          expect(vm.visible, isFalse);
          vm.dispose();
        });
      });

      test('a clock over a minute ahead: an invite at 0 from the first sight '
          'shows 0:00 while the server lists it, and goes with the next read '
          'that does not (user, 2026-11-27)', () {
        fakeAsync((async) {
          var server = start;
          final repo = _Repo(now: () => server);
          final vm = FriendInviteAlertViewModel(
            repository: repo,
            pollEvery: const Duration(seconds: 5),
            now: () => server.add(const Duration(seconds: 61)),
          );
          final sent = repo.receiveInvite(_friend, ExerciseType.squat);
          vm.setSignedIn(true);
          async.flushMicrotasks();
          expect(vm.current!.id, sent.id);
          expect(vm.visible, isTrue);
          expect(vm.secondsLeft, 0);
          // Ticks and reads while the server still lists it: it stays.
          server = start.add(const Duration(seconds: 30));
          async.elapse(const Duration(seconds: 5));
          expect(vm.current!.id, sent.id);
          expect(vm.secondsLeft, 0);
          // The server's minute is over: its list no longer has it.
          server = start.add(const Duration(seconds: 60));
          async.elapse(const Duration(seconds: 5));
          expect(vm.current, isNull);
          expect(vm.visible, isFalse);
          vm.dispose();
        });
      });

      test(
        'a clock over a minute ahead: 수락 is the server\'s to judge',
        () async {
          final server = start;
          final repo = _Repo(now: () => server);
          final vm = FriendInviteAlertViewModel(
            repository: repo,
            pollEvery: const Duration(hours: 1),
            now: () => server.add(const Duration(seconds: 61)),
          );
          addTearDown(vm.dispose);
          final sent = repo.receiveInvite(_friend, ExerciseType.squat);
          vm.setSignedIn(true);
          await pumpEventQueue();
          expect(vm.secondsLeft, 0);
          final accepted = await vm.accept();
          expect(accepted!.id, sent.id);
          expect(accepted.status, InviteStatus.accepted);
        },
      );

      test('no ticking while hidden or with nothing to show', () {
        fakeAsync((async) {
          final repo = _Repo(now: () => start);
          final vm = FriendInviteAlertViewModel(
            repository: repo,
            pollEvery: const Duration(hours: 1),
            now: () => start,
          );
          var heard = 0;
          vm.addListener(() => heard++);
          vm.setSignedIn(true);
          async.flushMicrotasks();
          heard = 0;
          async.elapse(const Duration(seconds: 3));
          expect(heard, 0, reason: 'nothing to show');
          repo.receiveInvite(_friend, ExerciseType.squat);
          unawaited(vm.check());
          async.flushMicrotasks();
          vm.setHidden(true);
          heard = 0;
          async.elapse(const Duration(seconds: 3));
          expect(heard, 0, reason: 'hidden');
          vm.setHidden(false);
          async.flushMicrotasks();
          heard = 0;
          async.elapse(const Duration(seconds: 2));
          expect(heard, 2);
          vm.dispose();
          expect(async.periodicTimerCount, 0);
        });
      });

      test('an accept on its way is not cut off at 0: the server decides', () {
        fakeAsync((async) {
          var clock = start;
          final repo = _Repo(now: () => start);
          final vm = FriendInviteAlertViewModel(
            repository: repo,
            pollEvery: const Duration(hours: 1),
            now: () => clock,
          );
          repo.receiveInvite(_friend, ExerciseType.squat);
          vm.setSignedIn(true);
          async.flushMicrotasks();
          repo.holdAccept = Completer<void>();
          BattleInvite? accepted;
          unawaited(vm.accept().then((a) => accepted = a));
          async.flushMicrotasks();
          clock = start.add(const Duration(minutes: 1));
          async.elapse(const Duration(seconds: 1));
          expect(vm.current, isNotNull, reason: 'still answering');
          repo.holdAccept!.complete();
          async.flushMicrotasks();
          expect(accepted!.status, InviteStatus.accepted);
          vm.dispose();
        });
      });
    });

    test('the alert, the friends page and the waiting room count the same '
        'seconds from one expires_at (A11 spec 9.9)', () async {
      var clock = start;
      // The inviter's phone and mine, on the same server clock.
      final inviterRepo = InMemoryFriendRepository(
        me: _friend,
        people: const [_me],
        now: () => clock,
      )..friends.add(_me);
      final wait = FriendInviteWaitViewModel(
        repository: inviterRepo,
        battle: const FriendBattle(friend: _me, exercise: ExerciseType.squat),
        pollEvery: const Duration(hours: 1),
        now: () => clock,
      );
      addTearDown(wait.dispose);
      await wait.start();
      final repo = _Repo(now: () => clock);
      repo.invites.add(
        BattleInvite(
          id: wait.invite!.id,
          from: _friend,
          to: _me,
          exercise: ExerciseType.squat,
          status: InviteStatus.pending,
          expiresAt: wait.invite!.expiresAt,
        ),
      );
      final page = FriendsViewModel(repository: repo, now: () => clock);
      final alert = FriendInviteAlertViewModel(
        repository: repo,
        pollEvery: const Duration(hours: 1),
        now: () => clock,
      );
      addTearDown(page.dispose);
      addTearDown(alert.dispose);
      await page.load();
      alert.setSignedIn(true);
      await pumpEventQueue();
      for (final after in [0, 17, 42, 59]) {
        clock = start.add(Duration(seconds: after));
        final shown = page.overview!.invites.single;
        expect(
          [page.secondsLeft(shown), alert.secondsLeft, wait.secondsLeft],
          everyElement(60 - after),
          reason: '+$after s',
        );
      }
    });
  });
}
