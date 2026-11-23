import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/arcade_catalog.dart';
import '../models/arcade_stage.dart';
import '../models/battle_result.dart';
import '../viewmodels/arcade_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'arcade_boss_screen.dart';
import 'arcade_result_screen.dart';
import 'result_screen.dart';

/// How the arcade's screens lead into one another (P16 spec 2): from the
/// map into a stage, from a battle to its result, and back to the map.
///
/// Every way out of a stage (아케이드로, a battle's leave button, the boss
/// match's back) goes back to the map, not to the app's home (spec 6
/// "나가기"); leaving keeps no stars.
abstract final class ArcadeFlow {
  /// Whether [route] is the map's.
  static bool isMap(Route<dynamic> route) =>
      route.settings.name == GymRatsApp.arcadeRoute;

  /// Closes every screen above the map; without a map below, above home.
  static void toMap(BuildContext context) =>
      Navigator.popUntil(context, (route) => isMap(route) || route.isFirst);

  /// Leaves a stage for the map: a boss match being played is over.
  static void leave(BuildContext context) {
    _arcade(context)?.endBossRun();
    toMap(context);
  }

  /// The user's name on the versus and battle screens: the account's
  /// nickname.
  static String playerName(BuildContext context) =>
      Provider.of<AuthViewModel?>(context, listen: false)?.account?.nickname ??
      '';

  /// Opens fight [stage]'s versus screen (after its sheet's 도전).
  static void openFight(BuildContext context, ArcadeFightStage stage) =>
      Navigator.pushNamed(
        context,
        GymRatsApp.versusRoute,
        arguments: ArcadeMatchups.fight(stage, playerName: playerName(context)),
      );

  /// Opens boss match [stage]'s intro.
  static void openBoss(BuildContext context, ArcadeBossStage stage) {
    _arcade(context)?.endBossRun();
    Navigator.push(context, ArcadeBossScreen.route(stage: stage));
  }

  /// Back to the map, which then opens stage [number]: 다음 스테이지 and
  /// "{n}층으로" (P16 spec 6 and 7).
  static void next(BuildContext context, int number) {
    _arcade(context)?.request(number);
    leave(context);
  }

  /// Stage [number] again from its start, over the map: a fight from its
  /// versus screen, a boss match from its intro (P16 spec 13.4).
  static void replay(BuildContext context, int number) {
    final stage = ArcadeCatalog.stage(number);
    bool keep(Route<dynamic> route) => isMap(route) || route.isFirst;
    _arcade(context)?.endBossRun();
    switch (stage) {
      case ArcadeFightStage():
        Navigator.pushNamedAndRemoveUntil(
          context,
          GymRatsApp.versusRoute,
          keep,
          arguments: ArcadeMatchups.fight(
            stage,
            playerName: playerName(context),
          ),
        );
      case ArcadeBossStage():
        Navigator.pushAndRemoveUntil(
          context,
          ArcadeBossScreen.route(stage: stage),
          keep,
        );
      case ArcadeHoldStage():
        toMap(context);
    }
  }

  /// The battle's report on top. Its 홈으로 and back go to the map, and its
  /// 다시 대결 plays the stage again (P16 spec 13.4, `ResultScreen`).
  static void openReport(BuildContext context, BattleResult result) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => ResultScreen(result: result)),
      );

  /// After an arcade battle [result] (P16 spec 6 and 7): the app's arcade
  /// works out what it came to ([ArcadeViewModel.finishBattle]), and this
  /// opens it in the battle's place: a stage's clear or fail, or a boss
  /// match's break. Without the arcade, or when the match counts as left,
  /// back to the map.
  static void afterBattle(
    BuildContext context,
    BattleResult result, {
    required double passDepth,
  }) {
    final outcome = _arcade(context)
        ?.finishBattle(result, passDepth: passDepth);
    final Widget next;
    switch (outcome) {
      case ArcadeStageEnded(:final stage, :final rounds, :final stars):
        next = ArcadeResultScreen(stage: stage, rounds: rounds, stars: stars);
      case ArcadeBossBreak(:final stage, :final first):
        next = ArcadeBossScreen(stage: stage, first: first);
      case ArcadeBattleLeft() || null:
        toMap(context);
        return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => next),
    );
  }

  static ArcadeViewModel? _arcade(BuildContext context) =>
      Provider.of<ArcadeViewModel?>(context, listen: false);
}
