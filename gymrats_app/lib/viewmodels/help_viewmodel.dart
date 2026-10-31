import 'package:flutter/foundation.dart';

import '../services/user/rules_seen_store.dart';

/// What GymRatsApp shows for the logged-in account.
enum HelpGate {
  /// Reading the account's flag from the device.
  checking,

  /// The battle rules, before home.
  rules,

  /// Home.
  home,
}

/// Decides whether the battle rules open before home: once for an account
/// that signed up on this phone, until its 시작하기, and never for a normal
/// login. The flag is kept per account on the device ([RulesSeenStore]).
///
/// One for the whole app: sign-up marks the new account here, and
/// GymRatsApp asks [gateFor] which screen to show.
class HelpViewModel extends ChangeNotifier {
  HelpViewModel({required this._store});

  final RulesSeenStore _store;

  /// The account [_gate] belongs to; null before the first login.
  int? _accountId;
  HelpGate _gate = HelpGate.checking;
  bool _disposed = false;

  /// [HelpGate.checking] until [load] or [signedUp] ran for [accountId].
  /// No account (null) means home.
  HelpGate gateFor(int? accountId) {
    if (accountId == null) return HelpGate.home;
    return accountId == _accountId ? _gate : HelpGate.checking;
  }

  /// Reads the saved flag after a login. An account decided earlier in
  /// this run keeps its decision; a flag that cannot be read counts as
  /// seen, so the user still gets home.
  Future<void> load(int accountId) async {
    if (accountId == _accountId) return;
    _accountId = accountId;
    _gate = HelpGate.checking;
    bool seen;
    try {
      seen = await _store.read(accountId);
    } on Object {
      seen = true;
    }
    // Another account logged in, or sign-up decided, while reading.
    if (accountId != _accountId || _gate != HelpGate.checking) return;
    _set(seen ? HelpGate.home : HelpGate.rules);
  }

  /// A new account on this phone: the rules show before its first home,
  /// also after a restart until 시작하기. The screen switches before the
  /// first await, so a slow save never shows home first.
  Future<void> signedUp(int accountId) async {
    _accountId = accountId;
    _set(HelpGate.rules);
    try {
      await _store.write(accountId, seen: false);
    } on Object {
      // Not saved: the rules still show now, just not after a restart.
    }
  }

  /// 시작하기 on the rules: home now and on every later login.
  Future<void> markSeen() async {
    final accountId = _accountId;
    if (accountId == null || _gate != HelpGate.rules) return;
    _set(HelpGate.home);
    try {
      await _store.write(accountId, seen: true);
    } on Object {
      // Not saved: the rules show once more after a restart.
    }
  }

  void _set(HelpGate gate) {
    if (_disposed) return;
    _gate = gate;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
