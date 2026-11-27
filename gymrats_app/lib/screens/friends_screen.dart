import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/battle_rules.dart';
import '../models/exercise_type.dart';
import '../models/user_profile.dart';
import '../services/friends/friend_repository.dart';
import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/friends_viewmodel.dart';
import '../widgets/arcade_parts.dart';
import '../widgets/exercise_sheet.dart';
import '../widgets/friend_invite_parts.dart';
import '../widgets/lobby_parts.dart';

/// 친구와의 대전 (P9, A11 spec 4), from 게임 시작's friend card: battle
/// invites to me (each a card with the inviter's character and the time
/// left), friend requests to me, my friends (each with 대결), the requests
/// I sent, then my friend code and a friend request by code. A friend's 대결
/// asks for the exercise on the online battle's sheet and opens the waiting
/// room; an accepted invite opens it at once. The page's route argument is
/// home's profile, for the sheet's bests.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({
    super.key,
    required this.createViewModel,
    this.refreshEvery = const Duration(seconds: 5),
    this.pickExercise,
  });

  final FriendsViewModel Function() createViewModel;

  /// How often the lists are read again while open, so a new invite shows
  /// up within its minute.
  final Duration refreshEvery;

  /// Asks for the exercise of a battle with a friend; null shows the
  /// online battle's exercise sheet ([showExerciseSheet]).
  final Future<ExerciseType?> Function(BuildContext context, FriendPerson)?
  pickExercise;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late final FriendsViewModel _vm = widget.createViewModel();
  final _code = TextEditingController();
  Timer? _refresh;
  bool _profileTaken = false;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_changed);
    unawaited(_vm.load());
    _refresh = Timer.periodic(widget.refreshEvery, (_) {
      // Not while a battle opened from here is on top.
      if (ModalRoute.of(context)?.isCurrent ?? false) unawaited(_vm.load());
    });
  }

  /// Once: home's profile from the route, and the app's [UserRepository]
  /// to read it with when there is none, or again after a battle.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileTaken) return;
    _profileTaken = true;
    final given = ModalRoute.of(context)?.settings.arguments;
    _vm.useProfile(
      given is UserProfile ? given : null,
      users: Provider.of<UserRepository?>(context, listen: false),
    );
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _vm
      ..removeListener(_changed)
      ..dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (await _vm.addFriend(_code.text)) _code.clear();
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('친구 코드를 복사했어요')));
  }

  Future<void> _challenge(FriendPerson friend) async {
    final exercise = await (widget.pickExercise ?? _pickExercise)(
      context,
      friend,
    );
    if (exercise == null || !mounted) return;
    await _open(FriendBattle(friend: friend, exercise: exercise));
  }

  Future<void> _accept(BattleInvite invite) async {
    final accepted = await _vm.acceptInvite(invite);
    if (accepted == null) return;
    // Another battle (or page) opened over this one while accepting: open
    // no second lobby, and take the accept back.
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) {
      unawaited(_vm.takeBack(accepted));
      return;
    }
    await _open(
      FriendBattle(
        friend: accepted.from,
        exercise: accepted.exercise,
        accepted: accepted,
      ),
    );
  }

  Future<void> _open(FriendBattle battle) async {
    await Navigator.pushNamed(
      context,
      GymRatsApp.onlineBattleRoute,
      arguments: battle,
    );
    if (!mounted) return;
    unawaited(_vm.load());
    // The battle may have set new bests for the next exercise sheet.
    unawaited(_vm.refreshProfile());
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final overview = _vm.overview;
    return LobbyPage(
      behind: const LobbyWatermark('1V1', left: 150),
      children: [
        const LobbyPageHeader(tag: '01 / PLAY · FRIENDS', title: '친구와의 대전'),
        if (overview == null) ...[
          const SizedBox(height: AppSpacing.s16),
          _vm.loadError == null
              ? const Center(child: CircularProgressIndicator())
              : _Notice(_vm.loadError!, onRetry: () => unawaited(_vm.load())),
        ] else ...[
          if (_vm.actionError case final error?) ...[
            const SizedBox(height: AppSpacing.s16),
            _Notice(error),
          ],
          if (overview.invites.isNotEmpty) ...[
            const _GroupLabel('받은 대결 신청'),
            for (final (index, invite) in overview.invites.indexed) ...[
              if (index > 0) const SizedBox(height: AppSpacing.s8),
              FriendInviteCard(
                invite: invite,
                secondsLeft: _vm.secondsLeft(invite),
                busy: _vm.busy.contains(invite.id),
                onAccept: () => unawaited(_accept(invite)),
                onDecline: () => unawaited(_vm.declineInvite(invite.id)),
              ),
            ],
          ],
          if (overview.incoming.isNotEmpty)
            _Group(
              label: '받은 친구 요청',
              rows: [
                for (final request in overview.incoming)
                  _PersonRow(
                    person: request.person,
                    actions: _answers(
                      request.id,
                      onAccept: () => unawaited(_vm.acceptRequest(request.id)),
                      onDecline: () =>
                          unawaited(_vm.declineRequest(request.id)),
                    ),
                  ),
              ],
            ),
          _Group(
            label: '친구 ${overview.friends.length}',
            rows: [
              if (overview.friends.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Text(
                    '아직 친구가 없어요. 친구 코드를 받아 요청해 보세요.',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              for (final friend in overview.friends)
                _FriendRow(
                  friend: friend,
                  onChallenge: () => unawaited(_challenge(friend)),
                ),
            ],
          ),
          if (overview.outgoing.isNotEmpty)
            _Group(
              label: '보낸 친구 요청',
              rows: [
                for (final request in overview.outgoing)
                  _PersonRow(
                    person: request.person,
                    line: '수락을 기다리는 중',
                    restyled: false,
                  ),
              ],
            ),
          const _GroupLabel('친구 추가'),
          _AddFriend(
            code: overview.code,
            onCopy: () => _copy(overview.code),
            controller: _code,
            busy: _vm.adding,
            error: _vm.addError,
            notice: _vm.addNotice,
            onSubmit: () => unawaited(_add()),
          ),
        ],
      ],
    );
  }

  List<Widget> _answers(
    int id, {
    required VoidCallback onAccept,
    required VoidCallback onDecline,
  }) {
    final busy = _vm.busy.contains(id);
    return [
      TextButton(
        onPressed: busy ? null : onDecline,
        style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        child: const Text('거절'),
      ),
      const SizedBox(width: AppSpacing.s4),
      OutlinedButton(
        onPressed: busy ? null : onAccept,
        child: const Text('수락'),
      ),
    ];
  }

  /// The online battle's exercise sheet for a battle with [friend], with
  /// the bests of the profile held (A11 spec 1); null when closed, or when
  /// no profile can be had ([FriendsViewModel.actionError] says why).
  Future<ExerciseType?> _pickExercise(
    BuildContext context,
    FriendPerson friend,
  ) async {
    final profile = await _vm.profileForSheet();
    if (profile == null || !context.mounted) return null;
    return showExerciseSheet(
      context,
      subtitle: '${friend.nickname}님과 친구 1v1 · ${battleDuration.inSeconds}초',
      profile: profile,
    );
  }
}

/// A group's name: bold gray, 20 above it and 8 under it.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.s20, bottom: AppSpacing.s8),
    child: Semantics(
      header: true,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

/// The add-friend card (A11 spec 4): 내 친구 코드 with a copy button, a
/// line, then the code field and 요청; the last request's answer under it.
class _AddFriend extends StatelessWidget {
  const _AddFriend({
    required this.code,
    required this.onCopy,
    required this.controller,
    required this.busy,
    required this.onSubmit,
    this.error,
    this.notice,
  });

  final String code;
  final VoidCallback onCopy;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;
  final String? error, notice;

  static const _codePadding = EdgeInsets.fromLTRB(
    AppSpacing.s16,
    _rowOver,
    AppSpacing.s8,
    _rowOver,
  );
  static const _fieldPadding = EdgeInsets.fromLTRB(
    AppSpacing.s12,
    _rowOver,
    _rowOver,
    _rowOver,
  );
  static const _rowOver = 10.0;
  static const _copy = 44.0;
  static const _copyIcon = 22.0;
  static const _control = 44.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tag = code.lastIndexOf('#');
    final fieldEdge = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.small),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: _codePadding,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('내 친구 코드', style: text.friendCodeLabel),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: tag < 0 ? code : code.substring(0, tag),
                                ),
                                if (tag >= 0)
                                  TextSpan(
                                    text: code.substring(tag),
                                    style: text.friendCodeTag,
                                  ),
                              ],
                            ),
                            style: text.friendCode,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onCopy,
                      tooltip: '친구 코드 복사',
                      color: AppColors.line,
                      iconSize: _copyIcon,
                      constraints: const BoxConstraints.tightFor(
                        width: _copy,
                        height: _copy,
                      ),
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: FriendColors.quiet),
              Padding(
                padding: _fieldPadding,
                child: Row(
                  children: [
                    Expanded(
                      // The field's name for a screen reader: it shows no
                      // label of its own, only the hint.
                      child: Semantics(
                        label: '친구 코드로 추가',
                        child: TextField(
                          controller: controller,
                          enabled: !busy,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => onSubmit(),
                          style: text.friendCodeInput,
                          decoration: InputDecoration(
                            hintText: '닉네임#0000',
                            hintStyle: text.friendCodeInput.copyWith(
                              color: AppColors.textMuted,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.cardHigh,
                            constraints: const BoxConstraints(
                              minHeight: _control,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s12,
                              vertical: AppSpacing.s12,
                            ),
                            border: fieldEdge,
                            enabledBorder: fieldEdge,
                            disabledBorder: fieldEdge,
                            focusedBorder: fieldEdge.copyWith(
                              borderSide: const BorderSide(
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    FilledButton(
                      onPressed: busy ? null : onSubmit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, _control),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                        ),
                        backgroundColor: AppColors.ink,
                        foregroundColor: AppColors.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        textStyle: text.friendButton,
                      ),
                      child: const Text('요청'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: Text(
              error,
              style: text.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ),
        if (notice case final notice?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: Text(
              notice,
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// A group's [label] over a card of [rows] with quiet lines between them.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.rows});

  final String label;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _GroupLabel(label),
      Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (index, row) in rows.indexed) ...[
              if (index > 0)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: FriendColors.quiet,
                ),
              row,
            ],
          ],
        ),
      ),
    ],
  );
}

/// A friend in the list (A11 spec 4): the nickname over the friend code,
/// and the lime 대결 at the right; at least 64 high.
class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.onChallenge});

  final FriendPerson friend;
  final VoidCallback onChallenge;

  static const _height = 64.0;
  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.s16,
    AppSpacing.s4,
    AppSpacing.s12,
    AppSpacing.s4,
  );
  static const _button = 40.0;
  static const _buttonPadding = EdgeInsets.fromLTRB(
    _buttonStart,
    0,
    AppSpacing.s12,
    0,
  );
  static const _buttonStart = 14.0;
  static const _edge = 2.0;
  static const _arrow = 16.0;
  static const _arrowStroke = 2.8;
  static const _arrowGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _height),
      child: Padding(
        padding: _padding,
        child: Row(
          children: [
            Expanded(
              child: _PersonWords(
                nickname: friend.nickname,
                line: friend.code,
                restyled: true,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            OutlinedButton(
              onPressed: onChallenge,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, _button),
                padding: _buttonPadding,
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.ink, width: _edge),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                textStyle: text.friendChallenge,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('대결'),
                  SizedBox(width: _arrowGap),
                  ArcadeGlyphIcon(
                    ArcadeGlyph.arrow,
                    size: _arrow,
                    color: AppColors.ink,
                    strokeWidth: _arrowStroke,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A person's nickname and code (or [line]), then [actions] at the right:
/// friend requests both ways. Requests to me take the friend rows' words
/// ([restyled], A11 spec 4); the ones I sent keep theirs.
class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    this.line,
    this.actions = const [],
    this.restyled = true,
  });

  final FriendPerson person;
  final String? line;
  final List<Widget> actions;
  final bool restyled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          Expanded(
            child: _PersonWords(
              nickname: person.nickname,
              line: line ?? person.code,
              restyled: restyled,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A [nickname] over its [line], in the friend rows' words when
/// [restyled], else in the rows' old words.
class _PersonWords extends StatelessWidget {
  const _PersonWords({
    required this.nickname,
    required this.line,
    required this.restyled,
  });

  final String nickname, line;
  final bool restyled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nickname,
          style: restyled ? text.friendRowName : text.lobbyRowTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          line,
          style: restyled
              ? text.friendRowCode
              : text.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// An amber band with [message], and 다시 시도 when [onRetry] is set.
class _Notice extends StatelessWidget {
  const _Notice(this.message, {this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: AppHighlight.band(AppColors.warning),
    child: Padding(
      padding: AppHighlight.bandPadding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.ink),
            ),
          ),
          if (onRetry case final retry?)
            TextButton(
              onPressed: retry,
              style: TextButton.styleFrom(foregroundColor: AppColors.ink),
              child: const Text('다시 시도'),
            ),
        ],
      ),
    ),
  );
}

/// Which named routes are open, for [FriendInviteOverlay]: the alert hides
/// while a battle (online or AI), its setup, or the friends page is open.
class FriendInviteRouteWatch extends NavigatorObserver with ChangeNotifier {
  /// Routes during which no invite may interrupt: the online lobby and
  /// battle above it, and the AI battle's search, versus, setup and battle.
  static const busyRoutes = {
    GymRatsApp.onlineBattleRoute,
    GymRatsApp.matchingRoute,
    GymRatsApp.versusRoute,
    GymRatsApp.matchSetupRoute,
    GymRatsApp.battleRoute,
    GymRatsApp.setupRoute,
    GymRatsApp.arcadeSheetRoute,
    GymRatsApp.arcadeHoldRoute,
    GymRatsApp.arcadeBossRoute,
    GymRatsApp.arcadeBreakRoute,
    GymRatsApp.arcadeResultRoute,
  };

  final _open = <Route<dynamic>>[];

  /// Whether the alert should hide now: a busy route is open anywhere, or
  /// the topmost named route is the friends page (a sheet over it, such as
  /// its exercise picker, has no name and keeps it hidden).
  bool get hides {
    final names = _open.map((r) => r.settings.name).nonNulls.toList();
    return names.any(busyRoutes.contains) ||
        (names.isNotEmpty && names.last == GymRatsApp.friendsRoute);
  }

  void _changed(void Function() change) {
    final before = hides;
    change();
    if (hides != before) notifyListeners();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed(() => _open.add(route));

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed(() => _open.remove(route));

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed(() => _open.remove(route));

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _changed(() {
        final at = oldRoute == null ? -1 : _open.indexOf(oldRoute);
        if (at >= 0 && newRoute != null) {
          _open[at] = newRoute;
        } else {
          if (oldRoute != null) _open.remove(oldRoute);
          if (newRoute != null) _open.add(newRoute);
        }
      });
}

/// The app-wide alert of a friend's battle invite (P9), above every page:
/// "deadlift님이 스쿼트 대결을 신청했어요" with the inviter's character, the
/// time left, 거절 and 수락 (A11 spec 6). 수락 opens the waiting room
/// through [navigator]. It follows [routes] (hidden during a battle and on
/// the friends page) and the app's lifecycle.
class FriendInviteOverlay extends StatefulWidget {
  const FriendInviteOverlay({
    super.key,
    required this.viewModel,
    required this.routes,
    required this.navigator,
    required this.child,
  });

  final FriendInviteAlertViewModel viewModel;
  final FriendInviteRouteWatch routes;
  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  @override
  State<FriendInviteOverlay> createState() => _FriendInviteOverlayState();
}

class _FriendInviteOverlayState extends State<FriendInviteOverlay>
    with WidgetsBindingObserver {
  /// How long a failed answer's words stay.
  static const _errorFor = Duration(seconds: 4);
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.viewModel.addListener(_changed);
    widget.routes.addListener(_routesChanged);
    _routesChanged();
  }

  /// Only a hidden app counts as gone: `inactive` is also the notification
  /// shade or a system dialog over the app, which must not drop a 수락.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      widget.viewModel.setForeground(switch (state) {
        AppLifecycleState.resumed || AppLifecycleState.inactive => true,
        AppLifecycleState.hidden ||
        AppLifecycleState.paused ||
        AppLifecycleState.detached => false,
      });

  void _routesChanged() => widget.viewModel.setHidden(widget.routes.hides);

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (widget.viewModel.error != null && _errorTimer == null) {
      _errorTimer = Timer(_errorFor, () {
        _errorTimer = null;
        widget.viewModel.clearError();
      });
    }
  }

  Future<void> _accept() async {
    final accepted = await widget.viewModel.accept();
    if (accepted == null || !mounted) return;
    unawaited(
      widget.navigator.currentState?.pushNamed(
        GymRatsApp.onlineBattleRoute,
        arguments: FriendBattle(
          friend: accepted.from,
          exercise: accepted.exercise,
          accepted: accepted,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.viewModel.removeListener(_changed);
    widget.routes.removeListener(_routesChanged);
    // Nothing shows it any more: stop reading.
    widget.viewModel.setHidden(true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final invite = vm.current;
    return Stack(
      children: [
        widget.child,
        if (vm.visible)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s12),
                // A Material for the buttons' ink, over any page.
                child: Material(
                  type: MaterialType.transparency,
                  child: invite == null
                      ? FriendAlertErrorCard(line: vm.error!)
                      : FriendInviteAlertCard(
                          invite: invite,
                          secondsLeft: vm.secondsLeft,
                          busy: vm.answering,
                          onDecline: () => unawaited(vm.decline()),
                          onAccept: () => unawaited(_accept()),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
