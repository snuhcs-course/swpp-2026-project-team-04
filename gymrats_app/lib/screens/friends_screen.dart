import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/exercise_type.dart';
import '../models/exercise_type_korean.dart';
import '../services/friends/friend_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/friends_viewmodel.dart';
import '../widgets/lobby_parts.dart';

/// 친구와의 대전 (P9), from 게임 시작's 친구와의 대전 row: my friend code to share, a
/// friend request by code, battle invites and friend requests to answer,
/// and my friends, each with 대결. A friend's 대결 asks for the exercise and
/// opens the waiting room; an accepted invite opens it at once.
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
  /// screen's own two-choice sheet.
  final Future<ExerciseType?> Function(BuildContext context, FriendPerson)?
  pickExercise;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late final FriendsViewModel _vm = widget.createViewModel();
  final _code = TextEditingController();
  Timer? _refresh;

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
    if (accepted == null || !mounted) return;
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
    if (mounted) unawaited(_vm.load());
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final overview = _vm.overview;
    return LobbyPage(
      behind: const LobbyWatermark('1V1', left: 150),
      children: [
        const LobbyPageHeader(tag: '01 / PLAY · FRIENDS', title: '친구와의 대전'),
        const SizedBox(height: AppSpacing.s16),
        if (overview == null)
          _vm.loadError == null
              ? const Center(child: CircularProgressIndicator())
              : _Notice(_vm.loadError!, onRetry: () => unawaited(_vm.load()))
        else ...[
          _MyCode(code: overview.code, onCopy: () => _copy(overview.code)),
          const SizedBox(height: AppSpacing.s12),
          _AddFriend(
            controller: _code,
            busy: _vm.adding,
            error: _vm.addError,
            notice: _vm.addNotice,
            onSubmit: () => unawaited(_add()),
          ),
          if (_vm.actionError case final error?) ...[
            const SizedBox(height: AppSpacing.s12),
            _Notice(error),
          ],
          if (overview.invites.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s16),
            _Group(
              label: '받은 대결 신청',
              rows: [
                for (final invite in overview.invites)
                  _PersonRow(
                    person: invite.from,
                    line: '${invite.exercise.koreanName} 대결 · 1분 안에 수락',
                    actions: _answers(
                      invite.id,
                      onAccept: () => unawaited(_accept(invite)),
                      onDecline: () => unawaited(_vm.declineInvite(invite.id)),
                    ),
                  ),
              ],
            ),
          ],
          if (overview.incoming.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s16),
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
          ],
          const SizedBox(height: AppSpacing.s16),
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
                _PersonRow(
                  person: friend,
                  actions: [
                    OutlinedButton(
                      onPressed: () => unawaited(_challenge(friend)),
                      child: const Text('대결'),
                    ),
                  ],
                ),
            ],
          ),
          if (overview.outgoing.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s16),
            _Group(
              label: '보낸 친구 요청',
              rows: [
                for (final request in overview.outgoing)
                  _PersonRow(person: request.person, line: '수락을 기다리는 중'),
              ],
            ),
          ],
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

  /// 푸시업 or 스쿼트 for a battle with [friend]; null when closed.
  static Future<ExerciseType?> _pickExercise(
    BuildContext context,
    FriendPerson friend,
  ) => showModalBottomSheet<ExerciseType>(
    context: context,
    backgroundColor: AppColors.card,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          0,
          AppSpacing.s20,
          AppSpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${friend.nickname}님과 무엇으로 대결할까요?',
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s12),
            for (final exercise in ExerciseType.values) ...[
              OutlinedButton(
                onPressed: () => Navigator.pop(sheet, exercise),
                child: Text(exercise.koreanName),
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
          ],
        ),
      ),
    ),
  );
}

/// 내 친구 코드, with a copy button.
class _MyCode extends StatelessWidget {
  const _MyCode({required this.code, required this.onCopy});

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s12,
          AppSpacing.s8,
          AppSpacing.s12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '내 친구 코드',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SelectableText(code, style: text.titleLarge),
                ],
              ),
            ),
            IconButton(
              onPressed: onCopy,
              tooltip: '친구 코드 복사',
              color: AppColors.line,
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// The code field and 요청, with the last request's answer under them.
class _AddFriend extends StatelessWidget {
  const _AddFriend({
    required this.controller,
    required this.busy,
    required this.onSubmit,
    this.error,
    this.notice,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;
  final String? error, notice;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !busy,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  labelText: '친구 코드로 추가',
                  hintText: '닉네임#0000',
                  errorText: error,
                  errorMaxLines: 2,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            FilledButton(
              onPressed: busy ? null : onSubmit,
              child: const Text('요청'),
            ),
          ],
        ),
        if (notice case final notice?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s4),
            child: Text(
              notice,
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// A bold gray [label] over a card of [rows] with lines between them.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.rows});

  final String label;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.s8),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (index, row) in rows.indexed) ...[
              if (index > 0) const Divider(height: 1),
              row,
            ],
          ],
        ),
      ),
    ],
  );
}

/// A person's nickname and code (or [line]), then [actions] at the right.
class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, this.line, this.actions = const []});

  final FriendPerson person;
  final String? line;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.nickname,
                  style: text.lobbyRowTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  line ?? person.code,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
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
/// "deadlift님이 스쿼트 대결을 신청했어요" with 거절 and 수락. 수락 opens the
/// waiting room through [navigator]. It follows [routes] (hidden during a
/// battle and on the friends page) and the app's lifecycle.
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
                child: invite == null
                    ? _AlertCard(line: vm.error!)
                    : _AlertCard(
                        line:
                            '${invite.from.nickname}님이 '
                            '${invite.exercise.koreanName} 대결을 신청했어요',
                        busy: vm.answering,
                        onDecline: () => unawaited(vm.decline()),
                        onAccept: () => unawaited(_accept()),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The alert's card: an icon, [line], and 거절 · 수락 when given.
class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.line,
    this.busy = false,
    this.onDecline,
    this.onAccept,
  });

  final String line;
  final bool busy;
  final VoidCallback? onDecline, onAccept;

  /// The icon chip's size, and the card's lift above the page.
  static const _chip = 40.0, _elevation = 6.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final onAccept = this.onAccept, onDecline = this.onDecline;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: AppColors.card,
        elevation: _elevation,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
          side: BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Row(
            children: [
              const LobbyArrowChip(size: _chip, icon: Icons.group_rounded),
              const SizedBox(width: AppSpacing.s12),
              Expanded(child: Text(line, style: text.lobbyRowTitle)),
              if (onDecline != null) ...[
                const SizedBox(width: AppSpacing.s4),
                TextButton(
                  onPressed: busy ? null : onDecline,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('거절'),
                ),
              ],
              if (onAccept != null)
                OutlinedButton(
                  onPressed: busy ? null : onAccept,
                  child: const Text('수락'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
