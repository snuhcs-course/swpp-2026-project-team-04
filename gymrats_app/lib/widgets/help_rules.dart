import 'package:flutter/material.dart';

import '../models/battle_rules.dart';

/// One page of the rules screen. Its picture is drawn by the screen.
class HelpPage {
  const HelpPage({
    required this.title,
    required this.body,
    this.points = const [],
  });

  final String title;
  final String body;

  /// Short score tags under [body], e.g. "KO 100점 차".
  final List<String> points;
}

/// One row in the last page's picture: an icon, a title, and one line.
class HelpRule {
  const HelpRule({
    required this.icon,
    required this.title,
    required this.body,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Drawn in amber, like every warning in the app.
  final bool warning;
}

/// Everything the rules screen says about the battle, in one place.
///
/// The numbers are the proposal in docs/iteration-3/battle-rules.md (v0.1)
/// until the team settles them; change them here and the screen follows.
/// The battle length comes from [battleDuration].
abstract final class HelpRules {
  /// The last part of the battle, where every score counts double.
  static const feverSeconds = 10;
  static const feverMultiplier = 2;

  /// Points for a valid rep, by judgment.
  static const good = 10;
  static const excellent = 15;

  /// Extra points for a valid rep within [comboSeconds] of the last one.
  static const comboBonus = 5;
  static const comboSeconds = 1.5;

  /// A score lead that ends the battle at once.
  static const koLead = 100;

  /// A score deficit at which the screen edge flashes red.
  static const dangerLead = 60;

  static int get totalSeconds => battleDuration.inSeconds;
  static int get baseSeconds => totalSeconds - feverSeconds;

  /// The pages in order: the health bar, scoring, then winning safely.
  static List<HelpPage> get pages => [
    const HelpPage(
      title: '체력 바 줄다리기',
      body:
          '바 하나가 50:50에서 시작해요. 바른 자세로 한 동작마다 바가 상대 '
          '쪽으로 밀려요. $koLead점 차이로 끝까지 밀면 그 자리에서 KO 승리!',
      points: ['KO $koLead점 차'],
    ),
    HelpPage(
      title: '점수는 이렇게 쌓여요',
      body:
          '기준보다 훨씬 깊이 내려가면 Excellent, $comboSeconds초 안에 이어서 '
          '하면 콤보 보너스가 붙어요. 마지막 $feverSeconds초 피버 타임에는 '
          '모든 점수가 $feverMultiplier배!',
      points: ['$baseSeconds초부터 ×$feverMultiplier'],
    ),
    HelpPage(
      title: '끝까지, 안전하게',
      body:
          '$totalSeconds초가 끝나면 점수가 높은 쪽이 이겨요. 서두르지 않아도 '
          '되니 무리하지 말고 몸 상태를 살피며 플레이해 주세요.',
    ),
  ];

  /// The first page's picture: the score that pushes the bar.
  static const barScore = '+$good';

  /// The second page's tiles: the points over the judgment.
  static const scores = [
    ('+$good', 'Good'),
    ('+$excellent', 'Excellent'),
    ('+$comboBonus', '콤보'),
  ];

  /// The second page's timeline: the base part, then fever.
  static String get baseLabel => '기본 $baseSeconds초';
  static const feverLabel = 'FEVER ×$feverMultiplier';

  /// The last page's picture.
  static List<HelpRule> get reminders => [
    const HelpRule(
      icon: Icons.warning_amber_rounded,
      title: '위험 신호',
      // No color named: the edge's color is the game screen's to choose.
      body: '$dangerLead점 이상 뒤지면 화면 가장자리가 깜빡여요',
      warning: true,
    ),
    const HelpRule(
      icon: Icons.emoji_events_outlined,
      title: '승패',
      body: '점수가 높은 쪽 승리, 같으면 유효 횟수',
    ),
    const HelpRule(
      icon: Icons.health_and_safety_outlined,
      title: '안전하게',
      body: '자세가 무너진 동작은 세지 않아요',
    ),
  ];
}
