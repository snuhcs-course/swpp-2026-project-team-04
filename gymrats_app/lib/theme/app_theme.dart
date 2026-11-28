import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colors from the design prototype, light since the 2026-11-07 kickoff,
/// used as palette B ("형광펜", 2026-11-08):
/// - text is always ink: [textPrimary], or [textSecondary] / [textMuted]
///   for quieter lines, also on a color; the one exception is a dark fill
///   such as [ink], which takes white text ([onInk]) and may take a lime
///   icon;
/// - lime, pink, amber, cyan and red only fill: backgrounds, buttons, bars,
///   bands and chips, with ink text on them ([AppHighlight]);
/// - lines, icons and outlines that are not text are [line] or [ink]; a
///   mark told apart by its color is a colored fill with an ink edge.
/// Screens use these, never raw values.
abstract final class AppColors {
  /// The light gray ground of every screen.
  static const background = Color(0xFFE6E9F0);

  /// White cards, sheets and buttons on [background].
  static const card = Color(0xFFFFFFFF);

  /// A step off [card]: tiles and fields inside a white card or sheet.
  static const cardHigh = Color(0xFFF3F5F9);
  static const border = Color(0xFFD5DAE3);

  static const textPrimary = Color(0xFF141A26);
  static const textSecondary = Color(0xFF4A5366);

  /// Tags and hints; still readable on [background] and [card].
  static const textMuted = Color(0xFF586073);

  /// Lime fill: the main accent and the player. Never a text color.
  static const accent = Color(0xFFC6FF3D);

  /// Pink fill: the opponent and the AI. Never a text color.
  static const opponent = Color(0xFFFF4F81);

  /// Amber fill behind ink text, for warnings:
  /// - invalid reps: the "not counted" popup in the battle
  /// - the "needs improvement" posture label
  /// - the battle timer during its last 5 seconds
  static const warning = Color(0xFFFFB547);

  /// Cyan fill for fever time in the battle: behind the clock, the time bar
  /// until its last 5 seconds, and the fever chip.
  static const fever = Color(0xFF3DE8FF);

  /// Red fill, only for the battle's danger edge and its mark on the rules
  /// screen (the user is about to lose), the matching radar's blips (W2b
  /// 1-A: a laser pointer's dots, decoration), and on the battle's camera
  /// (A9) the status frame and the setup cue's icon box when the setup is
  /// not right or a rep earned nothing. Every other problem is [warning].
  static const danger = Color(0xFFFF3B30);

  /// Near-black of the game-style screens: edges and icons on a color fill,
  /// the 대결 시작 button, and drawings on a lime or pink band.
  static const ink = Color(0xFF141A26);

  /// A shade deeper than [accent] and [opponent], for the slanted half of
  /// a lime or pink band.
  static const accentDeep = Color(0xFFB4EC2C);
  static const opponentDeep = Color(0xFFF23E72);

  /// The lobby's backdrop: two large slanted facets over [background], one
  /// a step lighter and one a step darker. [facetDark] is also the color of
  /// a page's faint name behind it.
  static const facetLight = Color(0xFFEEF0F5);
  static const facetDark = Color(0xFFDCE0E8);

  /// Lines, icons, rings and outlines that are not text: the radar's
  /// circles, avatar rings, chevrons (3:1 or more on [background] and
  /// [card]).
  static const line = Color(0xFF586073);

  /// Behind a chosen option, with an [ink] edge.
  static const selectedFill = Color(0xFFF6FFE6);

  /// The floor line in the battle's reject pictograms: lighter than the
  /// gray figure standing on it.
  static const pictogramFloor = Color(0xFFB9C0CC);

  /// The dimming over the battle camera's picture around the setup's guide,
  /// where the push-up silhouette's box does not reach: the same black at
  /// 45% that the silhouette (`PoseSilhouetteGuide`) lays outside its
  /// outline, so the whole picture outside the outline is one shade.
  static const setupGuideScrim = Color(0x73000000);

  /// Text on an [ink] fill, such as the 대결 시작 button: the one exception
  /// to ink text, since a dark fill needs light text (palette B).
  static const onInk = Color(0xFFFFFFFF);

  /// Quiet marks that only fill or hint, never text: the result's bars of
  /// the earlier battles, and the dashed outline of a chart's days that
  /// have not come yet. Under 3:1 on white, so the archive's and the
  /// statistics' values use [chartBar].
  static const inactive = Color(0xFFA9B0BE);

  /// A chart's past values beside the one in [ink]: the archive's day bars
  /// and its graph's base line (3:1 on [card]).
  static const chartBar = Color(0xFF8A93A5);

  /// Status green on the battle's camera (A9): the frame, the setup cue's
  /// icon box and hold bar when the setup is right or a rep counted, the
  /// hip and shoulder lines at the bottom of a rep, and both setup
  /// silhouettes once the pose fits. A fill or a line, never a text color.
  static const statusGood = Color(0xFF1FC95B);

  // The arcade (P16 design `ArcMap`, `ArcResult`, `P16Boss`).

  /// The arcade map's floor bands and its side walls.
  static const arcadeBand = Color(0xFF2E3646);

  /// A star got, on the map, the stage sheet and the results.
  static const starOn = warning;

  /// A star not got; also a locked floor's rule chip.
  static const starOff = Color(0xFFE3E6EC);

  /// The edge of a locked stage and of its lock badge.
  static const lockedEdge = Color(0xFF8A93A5);

  /// The arcade's pink tags: "PLAY / ARCADE", "STAGE 6 · 1F BOSS".
  static const arcadeTag = Color(0xFFC4134F);

  /// "1F 체육관 관장" on the boss intro.
  static const bossRole = Color(0xFF2B3242);

  /// 5F 공사중: the wall, its beams and ledge, the cones, and the result's
  /// card.
  static const wipWall = Color(0xFFE9E4DA);
  static const wipBeam = Color(0xFFC9BFAE);
  static const wipLedge = Color(0xFFB9AE9C);
  static const wipCone = Color(0xFFFF8A3D);
  static const wipCard = Color(0xFFF3EEE4);

  /// A boss round not played: its dashed edge and its fill.
  static const roundLockedEdge = Color(0xFFB8BFCC);
  static const roundLockedFill = Color(0xFFF3F4F7);
}

/// RepBot, the robot doing push-ups in the lobby, as designed: its own
/// greys, the same in any theme. Its visor and glow are [AppColors.opponent].
/// The limb names are the design's: L is the far side, R the near one.
abstract final class RepBotColors {
  static const footL = Color(0xFFABB2C0);
  static const footR = Color(0xFFB0B7C4);
  static const shinL = Color(0xFFB7BDC9);
  static const shinR = Color(0xFFBCC2CE);
  static const thighL = Color(0xFFC9CED8);
  static const thighR = Color(0xFFCFD4DD);
  static const pelvis = Color(0xFFD6DAE2);
  static const handL = Color(0xFFDDE1E8);
  static const forearmL = Color(0xFFDEE1E8);
  static const torso = Color(0xFFE1E4EA);
  static const upperArmL = Color(0xFFE3E6EC);

  /// The near hand, forearm and the shoulders.
  static const near = Color(0xFFEBEEF3);
  static const upperArmR = Color(0xFFEFF1F6);
  static const neck = Color(0xFFF3F5F9);

  /// The streak of light along each limb, drawn see-through.
  static const shine = Color(0xFFFFFFFF);

  /// The head's shading, from its lit spot to its edge.
  static const headLight = Color(0xFFFFFFFF);
  static const headMid = Color(0xFFDDE2EA);
  static const headDark = Color(0xFF99A1B2);

  /// The thin line around the whole body.
  static const outline = Color(0xFF8C95A7);

  /// The soft shadow on the floor under the body.
  static const shadow = Color(0xFF141A26);
}

/// Font families declared in pubspec.yaml.
abstract final class AppFonts {
  /// Korean headings. The headline text styles use it.
  static const headline = 'BlackHanSans';

  /// Numbers and English, in bold (700) and extra bold (800). It has no
  /// Korean glyphs.
  static const number = 'Oxanium';

  /// Home's big menu titles (Do Hyeon), as designed.
  static const display = 'DoHyeon';

  /// Body text, regular to bold (400, 500, 600, 700). Also fills in glyphs
  /// the other fonts lack.
  static const body = 'IBMPlexSansKR';
}

/// The text styles of the game-style screens (home lobby, 게임 시작, AI 1v1,
/// 환경설정), made from the theme's styles. Screens change only their color
/// or weight, so a font decision changes this one place.
extension LobbyText on TextTheme {
  /// "GYMMOUSE" on home: Oxanium 800, 40 high (home's 76 px menu layout,
  /// 2026-11-14).
  TextStyle get lobbyLogo => displayMedium!.copyWith(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: 1,
    height: 1,
  );

  /// "1V1" beside home's one-line pitch, on its 18 high line.
  TextStyle get lobbyBadge => bodyMedium!.copyWith(
    fontFamily: AppFonts.number,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    height: 18 / 13,
  );

  /// Home's one-line pitch, "30초 실시간 운동 대결": 13 on an 18 high line.
  TextStyle get lobbyPitch =>
      bodyMedium!.copyWith(fontSize: 13, height: 18 / 13);

  /// "01 / PLAY": small spaced-out English capitals.
  TextStyle get lobbyTag => labelMedium!.copyWith(
    fontFamily: AppFonts.number,
    fontWeight: FontWeight.w700,
    letterSpacing: 3,
  );

  /// The smaller tags on cards and sections, e.g. "ONLINE 1V1", "LEVEL".
  TextStyle get lobbyMiniTag => labelSmall!.copyWith(
    fontFamily: AppFonts.number,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
  );

  /// Home's menu titles, e.g. "게임 시작": Do Hyeon 44 on a 44 high line.
  TextStyle get lobbyMenuTitle => displayLarge!.copyWith(
    fontFamily: AppFonts.display,
    fontSize: 44,
    fontWeight: FontWeight.w400,
    height: 1,
  );

  /// Home's menu tags, e.g. "01 / PLAY": 11 on a 14 high line, spaced out.
  /// The pages' own tags stay [lobbyTag].
  TextStyle get lobbyMenuTag => labelSmall!.copyWith(
    fontFamily: AppFonts.number,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 3,
    height: 14 / 11,
  );

  /// A page's name as a huge faint word behind it, e.g. "PLAY".
  TextStyle get lobbyWatermark =>
      displayLarge!.copyWith(fontWeight: FontWeight.w800, height: 1);

  /// A page's slanted title, e.g. "게임 시작" on its own page.
  TextStyle get lobbyPageTitle => displaySmall!.copyWith(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w600,
    letterSpacing: -1,
  );

  /// A card's or an option's slanted name, e.g. "온라인 1v1", "푸쉬업".
  TextStyle get lobbyCardTitle => headlineSmall!.copyWith(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w600,
  );

  /// A card's short line, which may take two lines.
  TextStyle get lobbyCardLine => bodySmall!.copyWith(height: 1.5);

  /// A row's bold label, e.g. "최근 설정으로 다시 하기".
  TextStyle get lobbyRowTitle =>
      titleSmall!.copyWith(fontWeight: FontWeight.w700);

  /// The label of a page's start button, e.g. "대결 시작".
  TextStyle get lobbyButton => titleLarge!.copyWith(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w600,
  );

  /// A text link, e.g. "규칙 보기".
  TextStyle get lobbyLink => bodyMedium!.copyWith(
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline,
  );
}

/// The text styles of the battle stage (the HUD, the bands, the tags and the
/// reject sign), in the stage's own 360 x 390 design points: the stage is
/// sized as a whole to fit the screen, so these do not follow the system
/// text size. All ink, on a light ground or a color fill.
///
/// Lines are spaced like the design's CSS: the extra height is split evenly
/// above and below the letters.
extension StageText on TextTheme {
  TextStyle _stage({
    required String family,
    required double size,
    required FontWeight weight,
    double? height,
    double spacing = 0,
    Color color = AppColors.ink,
  }) => bodyMedium!.copyWith(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A player's nickname beside their color swatch.
  TextStyle get stageName =>
      _stage(family: AppFonts.body, size: 14, weight: FontWeight.w700);

  /// The clock, e.g. "0:23".
  TextStyle get stageClock => _stage(
    family: AppFonts.number,
    size: 26,
    weight: FontWeight.w700,
    height: 1,
  );

  /// The chip beside the clock, e.g. "+15 앞섬", "FEVER ×2".
  TextStyle get stageChip =>
      _stage(family: AppFonts.number, size: 12, weight: FontWeight.w700);

  /// A player's game score.
  TextStyle get stageScore => _stage(
    family: AppFonts.number,
    size: 80,
    weight: FontWeight.w800,
    height: 0.92,
    spacing: -3,
  );

  /// "유효 횟수" over the two valid rep counts.
  TextStyle get stageCountLabel => _stage(
    family: AppFonts.body,
    size: 11,
    weight: FontWeight.w700,
    height: 14 / 11,
    color: AppColors.textSecondary,
  );

  /// A valid rep count, and the ":" between the two.
  TextStyle get stageCount => _stage(
    family: AppFonts.number,
    size: 18,
    weight: FontWeight.w700,
    height: 20 / 18,
  );

  /// "KO" under each end of the bar.
  TextStyle get stageBarEnd => _stage(
    family: AppFonts.number,
    size: 12,
    weight: FontWeight.w700,
    height: 1,
  );

  /// The pill over a fighter's head, e.g. "준비 완료".
  TextStyle get stageTag => _stage(
    family: AppFonts.body,
    size: 13,
    weight: FontWeight.w700,
    height: 16 / 13,
  );

  /// A band of numbers or English, e.g. "MISS", "K.O.", at [stageBandSize].
  /// A band takes its own size with `apply(fontSizeFactor:)`.
  TextStyle get stageBand => _stage(
    family: AppFonts.number,
    size: stageBandSize,
    weight: FontWeight.w800,
    height: 1,
    spacing: -1,
  );

  /// A band of Korean, e.g. "자세 세팅 중", at [stageBandSize].
  TextStyle get stageBandKorean => _stage(
    family: AppFonts.display,
    size: stageBandSize,
    weight: FontWeight.w400,
    height: 1.25,
  );

  /// The short label under the reject sign's pictogram, e.g. "더 깊게":
  /// large enough to read from 2.5 m (A9 spec 5).
  TextStyle get stageSignLabel => _stage(
    family: AppFonts.display,
    size: 66,
    weight: FontWeight.w400,
    height: 1.12,
  );

  /// The size [stageBand] and [stageBandKorean] are given at.
  static const double stageBandSize = 100;
}

/// The text styles of the match-found screen's two color cells (W2b 2-A3),
/// in ink. Like the rest of the app they follow the system text size.
extension VersusText on TextTheme {
  /// "나" or "상대" on its white pill: 13 bold on a 20 line.
  TextStyle get versusSide => bodySmall!.copyWith(
    fontFamily: AppFonts.body,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 20 / 13,
    letterSpacing: 0,
    color: AppColors.ink,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A player's nickname: Do Hyeon 28 on a 34 line, cut to one line.
  TextStyle get versusName => headlineSmall!.copyWith(
    fontFamily: AppFonts.display,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 34 / 28,
    letterSpacing: 0,
    color: AppColors.ink,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// "AI" on its white pill under a bot's name: Oxanium 14 on a 20 line.
  TextStyle get versusAiTag => bodyMedium!.copyWith(
    fontFamily: AppFonts.number,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 20 / 14,
    letterSpacing: 0,
    color: AppColors.ink,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// "VS" on the white disc between the cells: Oxanium 800 34.
  TextStyle get versusMark => displaySmall!.copyWith(
    fontFamily: AppFonts.number,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: -1,
    color: AppColors.ink,
  );
}

/// The text styles of the battle's camera area, under the stage: the hint
/// line, the buttons and the reconnect band. Unlike [StageText] these follow
/// the system text size, like the rest of the app.
extension BattleCameraText on TextTheme {
  /// A name on a line drawn over the camera (A9 spec 4), e.g. "엉덩이",
  /// "시작 높이": Plex 13 bold in ink, on a pill of the line's color. It is
  /// painted on the camera's canvas with the lines, so it is a constant and,
  /// like them, does not follow the system text size.
  static const cameraLineLabel = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1,
    color: AppColors.ink,
  );

  /// The one-line hint under the camera, e.g. "폰을 더 세워 주세요."
  TextStyle get cameraHint => bodyMedium!.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.ink,
  );

  /// A button's label on the camera, e.g. "준비".
  TextStyle get cameraButton => bodyMedium!.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  /// The setup cue's two short lines over the camera (A9 spec 2), e.g.
  /// "한 걸음 / 뒤로": each one line, all of a band's lines shrunk alike to
  /// fit its width. Read from where the user exercises, so it does not
  /// follow the system text size.
  TextStyle get cameraSetupCue => bodyMedium!.copyWith(
    fontFamily: AppFonts.display,
    fontSize: 76,
    fontWeight: FontWeight.w400,
    height: 0.98,
    letterSpacing: 0,
    color: AppColors.ink,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The large ready button's label while setting up (W2b 3-B), e.g. "준비".
  TextStyle get cameraSetupButton => bodyMedium!.copyWith(
    fontFamily: AppFonts.display,
    fontSize: 22,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.ink,
  );

  /// The reconnect band's line.
  TextStyle get cameraNotice => bodySmall!.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  /// "결과 보기" on the button that ends the battle screen.
  TextStyle get cameraResult => titleLarge!.copyWith(
    fontFamily: AppFonts.display,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 32 / 24,
    color: AppColors.ink,
  );

  /// The title of the dialog that asks before leaving, e.g. "게임에서
  /// 나갈까요?": Do Hyeon, as the battle design draws it, at the headline's
  /// size.
  TextStyle get leaveDialogTitle =>
      headlineSmall!.copyWith(fontFamily: AppFonts.display);
}

/// The text styles of the character selection screen (W3 spec 7,
/// ChSelectB), in ink.
extension CharacterText on TextTheme {
  /// "캐릭터 선택" at the top: Do Hyeon 30 on a 36 line.
  TextStyle get characterTitle => headlineSmall!.copyWith(
    fontFamily: AppFonts.display,
    fontSize: 30,
    fontWeight: FontWeight.w400,
    height: 36 / 30,
    color: AppColors.ink,
  );

  /// The picked character's name on the slanted band: Do Hyeon 30.
  TextStyle get characterName => headlineSmall!.copyWith(
    fontFamily: AppFonts.display,
    fontSize: 30,
    fontWeight: FontWeight.w400,
    height: 1.25,
    color: AppColors.ink,
  );

  /// The line under the band, e.g. "쥐 · 대표 캐릭터": 13 bold.
  TextStyle get characterCaption => bodySmall!.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 18 / 13,
    color: AppColors.ink,
  );

  /// A cell's name under its picture: 13 bold on a 16 line.
  TextStyle get characterCellName => bodySmall!.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 16 / 13,
    color: AppColors.ink,
  );
}

/// The text styles of the archive (기록보관소, BArchive) that the theme's
/// own sizes lack. Screens change only their color or weight.
extension ArchiveText on TextTheme {
  /// The last 7 days' reps, e.g. "123": Oxanium 800, 32.
  TextStyle get archiveTotal => displaySmall!.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.05,
  );

  /// The score's rise on the growth card, e.g. "160": Oxanium 800, 26.
  TextStyle get archiveGain => displaySmall!.copyWith(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1,
  );

  /// A battle's score in its row: Oxanium 800, 18.
  TextStyle get archiveScore => displaySmall!.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1,
  );

  /// The newest score at the graph's last point: Oxanium 800, 13.
  TextStyle get archiveChartValue => displaySmall!.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    height: 1,
  );

  /// The new-best chip in a battle's row, e.g. "55": Oxanium 700, 12.
  TextStyle get archiveRowGain =>
      displaySmall!.copyWith(fontSize: 12, fontWeight: FontWeight.w700);

  /// The small bold labels: the exercise tabs, "전체 보기", the "점" after
  /// the rise: 13 bold.
  TextStyle get archiveLabel =>
      bodyMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w700);
}

/// The text styles of the statistics screen (기간별 통계, W7-STATS) that the
/// theme's own sizes lack. Screens change only their color or weight.
extension StatsText on TextTheme {
  /// The average counted reps, e.g. "13.8": Oxanium 800, 40.
  TextStyle get statsAverage => displaySmall!.copyWith(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1,
  );

  /// The "회" after the average, and the 다시 시도 button: 15 bold.
  TextStyle get statsStrong =>
      bodyLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w700);

  /// The battles and the total reps beside the average: Oxanium 800, 20.
  TextStyle get statsCount => displaySmall!.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1,
  );

  /// A form issue's count: Oxanium 800, 15 on a 20 line.
  TextStyle get statsIssueCount => displaySmall!.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 20 / 15,
  );

  /// The reps over a bar: Oxanium 700, 11 on a 12 line.
  TextStyle get statsBarValue => displaySmall!.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 12 / 11,
  );

  /// The letters under the bars: 11 on a 14 line.
  TextStyle get statsAxis =>
      bodySmall!.copyWith(fontSize: 11, height: 14 / 11, letterSpacing: 0);

  /// The empty notice's second line: 13 on a 1.45 line.
  TextStyle get statsDetail => bodyMedium!.copyWith(fontSize: 13, height: 1.45);

  /// A small note under a card's content: the weeks' note, the failed
  /// card's last line: 12 on a 1.5 line.
  TextStyle get statsNote => bodySmall!.copyWith(height: 1.5);

  /// A sentence in a card: the form card's only line, the failed card's
  /// reason: 14 on a 1.5 line.
  TextStyle get statsSentence => bodyMedium!.copyWith(height: 1.5);

  /// A form issue's name: 14 on a 20 line.
  TextStyle get statsIssueName => bodyMedium!.copyWith(height: 20 / 14);

  /// The "!" in the failed card's circle: Oxanium 800, 22.
  TextStyle get statsMark => displaySmall!.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1,
  );
}

/// Padding and gap steps (Design Documentation 2.5.5). Screens use only
/// these for padding and gaps.
abstract final class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
}

/// Corner radii (Design Documentation 2.5.6). Pills use [StadiumBorder].
abstract final class AppRadius {
  /// Small boxes inside a card: tiles, tags, input fields.
  static const double small = 12;

  /// Cards, panels, and all buttons.
  static const double card = 18;

  /// Dialogs, bottom sheets, the top corners of a bottom panel.
  static const double sheet = 24;

  /// Tiny color marks: [AppHighlight.swatch].
  static const double mark = 3;

  /// The top of a chart's bar, and a small icon box inside a card.
  static const double bar = 6;
}

/// The text styles of the result report (BResult), at the design's sizes.
/// Screens change only their color or weight.
extension ReportText on TextTheme {
  /// The verdict, e.g. "KO 승리": semibold body letters, set tight; the
  /// screen slants it.
  TextStyle get reportHeadline => displayMedium!.copyWith(
    fontFamily: AppFonts.body,
    fontSize: 46,
    fontWeight: FontWeight.w600,
    letterSpacing: -1,
    height: 1.05,
  );

  /// The user's score, big.
  TextStyle get reportMyScore => displaySmall!.copyWith(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1,
  );

  /// The opponent's score, beside the user's.
  TextStyle get reportTheirScore => displaySmall!.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1,
  );

  /// The ":" between the scores.
  TextStyle get reportScoreColon => displaySmall!.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1,
  );

  /// A small line: the date, the sub line, a card's detail, the feedback
  /// link.
  TextStyle get reportLine => bodyMedium!.copyWith(fontSize: 13);

  /// A card's bold title, e.g. "개인 최고 기록 갱신".
  TextStyle get reportCardTitle =>
      bodyLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w700);

  /// The 다시 대결 button's label.
  TextStyle get reportButton =>
      titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w600);
}

/// Palette B's highlighter: color never carries text. It sits behind ink
/// text like a marker, or marks ink text as a small swatch. Screens take
/// these as they are. WIN, for example:
///
/// ```dart
/// Transform(
///   transform: AppHighlight.slant,
///   alignment: Alignment.center,
///   child: DecoratedBox(
///     decoration: AppHighlight.band(AppColors.accent),
///     child: Padding(
///       padding: AppHighlight.bandPadding,
///       child: Text('WIN', style: style.copyWith(color: AppColors.ink)),
///     ),
///   ),
/// )
/// ```
abstract final class AppHighlight {
  /// A flat band of [color] behind ink text: WIN on lime, LOSE on pink, a
  /// number or a word to stand out.
  static BoxDecoration band(Color color) => BoxDecoration(color: color);

  /// The room around the text on a [band].
  static const bandPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.s8,
    vertical: AppSpacing.s4,
  );

  /// The room around a short label on a tight [band], hugging the letters
  /// top and bottom: "MATCH FOUND" on the versus screen (BMatchFound).
  static const tightBandPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.s8,
    vertical: 1,
  );

  /// The room around a short tag on a white pill, inside its edge: "AI"
  /// under a bot's name on the match-found board (W2b 2-A3).
  static const tagPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.s12,
    vertical: 2,
  );

  /// The marker's slant, as the design draws WIN and LOSE. A new matrix each
  /// time, so no one changes another's.
  static Matrix4 get slant => Matrix4.skewX(-10 * math.pi / 180);

  /// The steeper slant of the battle stage's bands: behind the scores, the
  /// band texts and the reject sign's label. A new matrix each time.
  static Matrix4 get battleSlant => Matrix4.skewX(-12 * math.pi / 180);

  /// A soft pill of [color] behind ink text, for chips: points (lime),
  /// fever (cyan), warnings (amber), danger (red). [strength] is how much of
  /// the color shows; the design uses 0.75 for lime, 0.6 for amber, 0.45 for
  /// cyan and 0.35 for red. Ink text reads on any of them.
  static ShapeDecoration chip(Color color, {double strength = 0.6}) =>
      ShapeDecoration(
        color: color.withValues(alpha: strength),
        shape: const StadiumBorder(),
      );

  /// The room around the text on a [chip].
  static const chipPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.s8,
    vertical: AppSpacing.s4,
  );

  /// A small square of [color] with an ink edge, beside the ink text it
  /// marks, e.g. "나" with lime and "상대" with pink. Make it [swatchSize]
  /// square.
  static BoxDecoration swatch(Color color) => BoxDecoration(
    color: color,
    borderRadius: const BorderRadius.all(Radius.circular(AppRadius.mark)),
    border: Border.all(color: AppColors.ink, width: _swatchEdge),
  );

  static const double swatchSize = 10;

  /// The room between a [swatch] and the text it marks.
  static const double swatchGap = 6;
  static const _swatchEdge = 1.5;

  /// [style] in ink with a band of [color] right behind the letters, for a
  /// marked word inside a line of text.
  static TextStyle marked(TextStyle style, Color color) =>
      style.copyWith(color: AppColors.ink, backgroundColor: color);
}

/// Builds the app's [ThemeData] from [AppColors] and [AppFonts].
abstract final class AppTheme {
  static const double cardRadius = AppRadius.card;

  /// The app's only theme: always light, whatever the system setting
  /// (team kickoff 2026-11-07).
  static final ThemeData light = _build();

  /// The name from before the app turned light; the same theme as [light],
  /// kept so screens and tests that still say `dark` keep working.
  static final ThemeData dark = light;

  static ThemeData _build() {
    final base = ThemeData(
      colorScheme: _colorScheme(),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppFonts.body,
      // Oxanium has no Korean and Black Han Sans has no "·".
      fontFamilyFallback: const [AppFonts.body],
    );
    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      cardTheme: _cardTheme,
      inputDecorationTheme: _inputTheme(base.textTheme),
      switchTheme: _switchTheme,
      // Material paints these in the primary lime by default, which all but
      // disappears on the light screens.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ink,
        linearTrackColor: AppColors.border,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
      ),
      // A dialog covers the screen with ink, not black (palette B).
      dialogTheme: DialogThemeData(
        barrierColor: AppColors.ink.withValues(alpha: 0.54),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.ink,
        selectionHandleColor: AppColors.ink,
        selectionColor: AppColors.accent.withValues(alpha: 0.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.textMuted,
        ),
      ),
    );
  }

  /// fromSeed fills the roles the design leaves open (secondary, error, ...)
  /// with tones of the accent, and the design colors replace the rest.
  /// Pink and amber stay out so default widgets never paint with them.
  static ColorScheme _colorScheme() => ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.light,
    primary: AppColors.accent,
    onPrimary: AppColors.ink,
    surface: AppColors.background,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerLow: AppColors.card,
    surfaceContainer: AppColors.card,
    surfaceContainerHigh: AppColors.cardHigh,
    surfaceContainerHighest: AppColors.cardHigh,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
  );

  /// Colors [base], which already uses the body font, and gives the display
  /// and headline styles their fonts.
  static TextTheme _textTheme(TextTheme base) {
    final text = base.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
    TextStyle? asNumber(TextStyle? style) => style?.copyWith(
      fontFamily: AppFonts.number,
      fontWeight: FontWeight.w700,
    );
    TextStyle? asHeadline(TextStyle? style) =>
        style?.copyWith(fontFamily: AppFonts.headline);
    return text.copyWith(
      displayLarge: asNumber(text.displayLarge),
      displayMedium: asNumber(text.displayMedium),
      displaySmall: asNumber(text.displaySmall),
      // Small numbers, e.g. match history scores (Design Documentation 2.5.3).
      titleLarge: asNumber(text.titleLarge),
      headlineLarge: asHeadline(text.headlineLarge),
      headlineMedium: asHeadline(text.headlineMedium),
      headlineSmall: asHeadline(text.headlineSmall),
    );
  }

  /// Text fields: a card-colored box with radius [AppRadius.small], an ink
  /// outline while focused or wrong (as the design's fields), and an error
  /// line in ink on an amber band (2.5.2: every problem is amber; palette B:
  /// the amber sits behind the text).
  static InputDecorationTheme _inputTheme(TextTheme text) {
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadius.small),
          ),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.all(AppSpacing.s16),
      hintStyle: text.bodyLarge?.copyWith(color: AppColors.textMuted),
      labelStyle: text.bodyLarge?.copyWith(color: AppColors.textSecondary),
      floatingLabelStyle: text.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
      ),
      errorStyle: text.bodyMedium == null
          ? null
          : AppHighlight.marked(text.bodyMedium!, AppColors.warning),
      errorMaxLines: 2,
      border: outline(AppColors.border),
      enabledBorder: outline(AppColors.border),
      focusedBorder: outline(AppColors.ink, 2),
      errorBorder: outline(AppColors.ink),
      focusedErrorBorder: outline(AppColors.ink, 2),
    );
  }

  /// The design's switch: an ink track with a lime knob when on, a gray
  /// track with a white knob when off. The off track keeps a muted edge so
  /// it stands out from a white card.
  static final _switchTheme = SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.accent
          : AppColors.card,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? AppColors.ink
          : AppColors.border,
    ),
    trackOutlineColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? Colors.transparent
          : AppColors.textMuted,
    ),
  );

  static const _cardTheme = CardThemeData(
    color: AppColors.card,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
      side: BorderSide(color: AppColors.border),
    ),
  );
}

/// The text styles of the form feedback screen (BFeedback) that the theme
/// lacks, in ink or the quieter text colors. Like the rest of the app they
/// follow the system text size.
extension FeedbackText on TextTheme {
  /// "FORM" at the top of the screen.
  TextStyle get feedbackTag => bodySmall!.copyWith(
    fontFamily: AppFonts.number,
    fontWeight: FontWeight.w700,
    fontSize: 13,
    letterSpacing: 2.6,
    color: AppColors.textSecondary,
  );

  /// The battle line beside "FORM", and the unit after a stat's number.
  TextStyle get feedbackMeta =>
      bodySmall!.copyWith(fontSize: 13, color: AppColors.textSecondary);

  /// A stat's number: 인정, 무효, 평균 깊이.
  TextStyle get feedbackStat => displaySmall!.copyWith(
    fontSize: 24,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  /// The numbers along a chart's axes.
  TextStyle get feedbackAxis => bodySmall!.copyWith(
    fontSize: 10,
    height: 1.2,
    color: AppColors.textMuted,
  );

  /// A finding's numbers and its fix, and a note where a chart has nothing.
  TextStyle get feedbackBody => bodyMedium!.copyWith(height: 1.5);

  /// The sentence under a chart.
  TextStyle get feedbackCaption => bodySmall!.copyWith(height: 1.5);

  /// The "!" and "i" in a finding's round badge.
  TextStyle get feedbackBadgeMark => titleSmall!.copyWith(
    fontFamily: AppFonts.number,
    fontWeight: FontWeight.w700,
    height: 1,
  );
}

/// The text styles of the character's talk (A10: the report's character
/// card, the talk screen and its cards, UxDlg / UxGfx / UxGoal), in ink
/// unless a screen picks a quieter color. Like the rest of the app they
/// follow the system text size.
extension CoachText on TextTheme {
  /// The name tag over the dialog box: Do Hyeon 25 on a 40 band.
  TextStyle get coachName => headlineSmall!.copyWith(
    fontFamily: AppFonts.display,
    fontSize: 25,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.ink,
  );

  /// The name tag on the report's card: Do Hyeon 19 on a 28 band.
  TextStyle get coachCardName =>
      coachName.copyWith(fontSize: 19, height: 28 / 19);

  /// A line of the talk: 17.5, semibold, loose lines, a little tight.
  TextStyle get coachLine => bodyLarge!.copyWith(
    fontSize: 17.5,
    fontWeight: FontWeight.w600,
    height: 1.62,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  /// The report card's sentence: 15, semibold.
  TextStyle get coachCardLine => bodyLarge!.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.ink,
  );

  /// The pill at the top and the report card's link: 12, bold.
  TextStyle get coachSmallBold => bodySmall!.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  /// The hint under the dots and a card's small line: 12.
  TextStyle get coachSmall =>
      bodySmall!.copyWith(fontSize: 12, height: 1.35, color: AppColors.ink);

  /// A button's label: 건너뛰기 at the top, 이야기 듣기, the end buttons.
  TextStyle get coachButton => bodyMedium!.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  /// The report card's 건너뛰기: 13, bold, underlined.
  TextStyle get coachLink => bodySmall!.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline,
    color: AppColors.textSecondary,
  );

  /// A goal choice's title: 15, bold.
  TextStyle get coachChoice => bodyLarge!.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.ink,
  );

  /// A card's label, e.g. "이번 판 인정 횟수": 13, bold.
  TextStyle get coachCardLabel => bodySmall!.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  /// The axis and legend letters of a card: 11.
  TextStyle get coachAxis => bodySmall!.copyWith(
    fontSize: 11,
    height: 1.3,
    color: AppColors.textMuted,
  );

  /// The big count on the score card: Oxanium 800, 64.
  TextStyle get coachBigNumber => displayLarge!.copyWith(
    fontFamily: AppFonts.number,
    fontSize: 64,
    fontWeight: FontWeight.w800,
    height: 0.9,
    letterSpacing: -2,
    color: AppColors.ink,
  );

  /// A number on a chip or over a bar: Oxanium 700, 13.
  TextStyle get coachChipNumber => bodySmall!.copyWith(
    fontFamily: AppFonts.number,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 16 / 13,
    color: AppColors.ink,
  );

  /// The chip against the average on the score card, e.g. "+2회": Oxanium
  /// 700, 15.
  TextStyle get coachDifference =>
      coachChipNumber.copyWith(fontSize: 15, height: 1.3);

  /// The "회" after the big count on the score card: 18, bold.
  TextStyle get coachUnit => titleMedium!.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  /// "× 3" on the form card: Oxanium 800, 20.
  TextStyle get coachTimes => titleMedium!.copyWith(
    fontFamily: AppFonts.number,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  /// The rejection's short words on the form card: Do Hyeon 28.
  TextStyle get coachRejectWord =>
      coachName.copyWith(fontSize: 28, height: 1.2);

  /// A card's sentence: 13, loose lines.
  TextStyle get coachCardSentence => bodySmall!.copyWith(
    fontSize: 13,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  /// "6 HIT" on the combo card: Oxanium 800, 62.
  TextStyle get coachHit => displayLarge!.copyWith(
    fontFamily: AppFonts.number,
    fontSize: 62,
    fontWeight: FontWeight.w800,
    height: 74 / 62,
    letterSpacing: 1,
    color: AppColors.ink,
  );

  /// The goal's title on the goal card: Do Hyeon 32.
  TextStyle get coachGoalTitle =>
      coachName.copyWith(fontSize: 32, height: 1.15);
}

/// The text styles of the next battle's goal (A11: the game choice's
/// sticker and goal row, the match-found goal card, the battle's goal chip
/// and '미션 성공!' band; UxGoal / MsGoal scenes pick, found and battle), in ink
/// unless a screen picks a quieter color. The screens' styles follow the
/// system text size; the battle's two ([goalChip], [goalBand]) are in the
/// stage's design points, which does not.
extension GoalText on TextTheme {
  /// 12, bold: the base of [goalRowLabel] (the sticker itself is now
  /// [goalMissionSticker]).
  TextStyle get goalSticker => bodySmall!.copyWith(
    fontFamily: AppFonts.body,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 16 / 12,
    color: AppColors.ink,
  );

  /// "물렁범이 준 이번 판 미션" over the goal row's title: 12, bold.
  TextStyle get goalRowLabel =>
      goalSticker.copyWith(color: AppColors.textSecondary);

  /// The goal row's title, e.g. "스쿼트 20회 인정받기": Do Hyeon 22.
  TextStyle get goalRowTitle => headlineSmall!.copyWith(
    fontFamily: AppFonts.display,
    fontSize: 22,
    fontWeight: FontWeight.w400,
    height: 1.2,
    color: AppColors.ink,
  );

  /// "지난 18" at the goal row's end: Oxanium 700, 13.
  TextStyle get goalRowBaseline => bodySmall!.copyWith(
    fontFamily: AppFonts.number,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 16 / 13,
    color: AppColors.textSecondary,
  );

  /// "이번 판 미션!" on the match-found card's tag: Do Hyeon 24 on a 36 band.
  TextStyle get goalCardTag => goalRowTitle.copyWith(fontSize: 24, height: 1.5);

  /// The match-found card's title: Do Hyeon 32, tight lines.
  TextStyle get goalCardTitle =>
      goalRowTitle.copyWith(fontSize: 32, height: 1.12);

  /// The battle HUD's goal chip, e.g. "미션 12/20": 11, bold, on a 14 line.
  TextStyle get goalChip => bodySmall!.copyWith(
    fontFamily: AppFonts.body,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 14 / 11,
    letterSpacing: 0,
    color: AppColors.ink,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The battle's '미션 성공!' band: Do Hyeon 48 on a 64 line.
  TextStyle get goalBand => bodyMedium!.copyWith(
    fontFamily: AppFonts.display,
    fontSize: 48,
    fontWeight: FontWeight.w400,
    height: 64 / 48,
    letterSpacing: 0,
    color: AppColors.ink,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The mission sticker's "미션!" (MsGoal pick): Do Hyeon 19, tight.
  TextStyle get goalMissionSticker =>
      goalRowTitle.copyWith(fontSize: 19, height: 1);

  /// The goal's number on the talk's result card (UxGfx goalHit /
  /// goalMiss): Oxanium 800, 34, quieter.
  TextStyle get goalResultTarget => bodyMedium!.copyWith(
    fontFamily: AppFonts.number,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1,
    color: AppColors.textMuted,
  );

  /// This battle's number on the result card: Oxanium 800, 54.
  TextStyle get goalResultValue => bodyMedium!.copyWith(
    fontFamily: AppFonts.number,
    fontSize: 54,
    fontWeight: FontWeight.w800,
    height: 0.9,
    letterSpacing: -1,
    color: AppColors.ink,
  );

  /// The result card's stamp, "달성!": Do Hyeon 32.
  TextStyle get goalStamp => bodyMedium!.copyWith(
    fontFamily: AppFonts.display,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    height: 1.05,
    color: AppColors.ink,
  );

  /// The stamp of what was left, "1회 / 남음", on two lines: Do Hyeon 26.
  TextStyle get goalStampSmall => goalStamp.copyWith(fontSize: 26);
}

/// The text styles of the arcade (P16): 게임 시작's two cards, the map, the
/// stage sheet, the boss match and the arcade's results, with the design's
/// sizes. Ink unless a style says otherwise; lines are spaced like the
/// design's CSS, the extra height split above and below the letters.
extension ArcadeText on TextTheme {
  TextStyle _arcade({
    required String family,
    required double size,
    required FontWeight weight,
    double? height,
    double spacing = 0,
    Color color = AppColors.ink,
  }) => bodyMedium!.copyWith(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A 게임 시작 card's name, "온라인 대결", "아케이드": Do Hyeon 30 (A11,
  /// `FrPlay` nameSize; 26 before).
  TextStyle get arcadeCardName => _arcade(
    family: AppFonts.display,
    size: 30,
    weight: FontWeight.w400,
    height: 1,
  );

  /// "VS" on its ink chip between the online card's two players.
  TextStyle get arcadeVsChip => _arcade(
    family: AppFonts.number,
    size: 15,
    weight: FontWeight.w800,
    color: AppColors.onInk,
  );

  /// The pink tag over a title: "PLAY / ARCADE", "STAGE 6 · 1F BOSS".
  TextStyle get arcadeTag => _arcade(
    family: AppFonts.number,
    size: 11,
    weight: FontWeight.w700,
    spacing: 3,
    color: AppColors.arcadeTag,
  );

  /// The map's title, "아케이드": Do Hyeon 30.
  TextStyle get arcadeTitle => _arcade(
    family: AppFonts.display,
    size: 30,
    weight: FontWeight.w400,
    height: 1.05,
  );

  /// The stars got in all, "17", in the map's header.
  TextStyle get arcadeStarSum =>
      _arcade(family: AppFonts.number, size: 15, weight: FontWeight.w800);

  /// "/ 72" after it.
  TextStyle get arcadeStarMax => _arcade(
    family: AppFonts.body,
    size: 11,
    weight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// A floor's tag on its picture while its band is out of sight, "4F".
  TextStyle get arcadeFloorTag => _arcade(
    family: AppFonts.number,
    size: 11,
    weight: FontWeight.w800,
    spacing: 2,
    color: AppColors.textMuted,
  );

  /// "공사중" on 5F's sign: Do Hyeon 40.
  TextStyle get arcadeWipSign => _arcade(
    family: AppFonts.display,
    size: 40,
    weight: FontWeight.w400,
    height: 1.1,
  );

  /// A band's floor chip, "2F": ink on lime, amber on 5F's.
  TextStyle get arcadeBandFloor =>
      _arcade(family: AppFonts.number, size: 15, weight: FontWeight.w800);

  /// A band's floor name, white on the band: Do Hyeon 19.
  TextStyle get arcadeBandName => _arcade(
    family: AppFonts.display,
    size: 19,
    weight: FontWeight.w400,
    color: AppColors.onInk,
  );

  /// A floor's rule chip, "피버 15초부터", on the band.
  TextStyle get arcadeRuleChip =>
      _arcade(family: AppFonts.body, size: 12, weight: FontWeight.w700);

  /// "BOSS" and "HOLD" over a stage on the map.
  TextStyle get arcadeNodeTag => _arcade(
    family: AppFonts.number,
    size: 11,
    weight: FontWeight.w800,
    height: 1,
  );

  /// A stage's number under it on the map.
  TextStyle get arcadeNodeNumber => _arcade(
    family: AppFonts.number,
    size: 12,
    weight: FontWeight.w800,
    height: 1,
  );

  /// "나" beside the user's character on the map.
  TextStyle get arcadeMeTag => _arcade(
    family: AppFonts.body,
    size: 11,
    weight: FontWeight.w700,
    height: 18 / 11,
  );

  /// "STAGE 8 · 2F" in the map's bottom bar.
  TextStyle get arcadeBarTag => _arcade(
    family: AppFonts.number,
    size: 11,
    weight: FontWeight.w700,
    spacing: 2,
    color: AppColors.textMuted,
  );

  /// The stage's title in the bottom bar, "물렁범 · 스쿼트": Do Hyeon 21.
  TextStyle get arcadeBarTitle => _arcade(
    family: AppFonts.display,
    size: 21,
    weight: FontWeight.w400,
    height: 1.15,
  );

  /// A dark button's label, "도전", "다음 스테이지": white 17.
  TextStyle get arcadeAction => _arcade(
    family: AppFonts.body,
    size: 17,
    weight: FontWeight.w600,
    color: AppColors.onInk,
  );

  /// The stage sheet's "도전": white 18.
  TextStyle get arcadeSheetAction => arcadeAction.copyWith(fontSize: 18);

  /// The boss match's "자세 잡기": white 19.
  TextStyle get arcadeBossAction => arcadeAction.copyWith(fontSize: 19);

  /// A light button's label, "닫기", "리포트 보기": 14 bold.
  TextStyle get arcadeSecondary =>
      _arcade(family: AppFonts.body, size: 14, weight: FontWeight.w700);

  /// "STAGE 8" on its ink chip on the stage sheet, lime.
  TextStyle get arcadeStageChip => _arcade(
    family: AppFonts.number,
    size: 13,
    weight: FontWeight.w800,
    color: AppColors.accent,
  );

  /// "2F · AI LV 6" beside it.
  TextStyle get arcadeSheetMeta => _arcade(
    family: AppFonts.number,
    size: 10,
    weight: FontWeight.w700,
    spacing: 2,
    color: AppColors.textMuted,
  );

  /// The opponent's name on the stage sheet: Do Hyeon 32.
  TextStyle get arcadeSheetName => _arcade(
    family: AppFonts.display,
    size: 32,
    weight: FontWeight.w400,
    height: 1.05,
  );

  /// The stage sheet's chips, "스쿼트 · 30초", and "별 조건": 13 bold.
  TextStyle get arcadeSheetChip =>
      _arcade(family: AppFonts.body, size: 13, weight: FontWeight.w700);

  /// A star condition, "콤보 5 이상", on the stage sheet.
  TextStyle get arcadeGoal =>
      _arcade(family: AppFonts.body, size: 14, weight: FontWeight.w600);

  /// A star condition on the boss intro: 13.5.
  TextStyle get arcadeBossGoal => arcadeGoal.copyWith(fontSize: 13.5);

  /// The results' tag, "STAGE 8 · 2F".
  TextStyle get arcadeResultTag => _arcade(
    family: AppFonts.number,
    size: 12,
    weight: FontWeight.w700,
    spacing: 3,
    color: AppColors.textMuted,
  );

  /// The results' title on its band, "실패", "1층 클리어!": Do Hyeon 44.
  TextStyle get arcadeBanner => _arcade(
    family: AppFonts.display,
    size: 44,
    weight: FontWeight.w400,
    height: 1.1,
  );

  /// A fight's "클리어!": Do Hyeon 48.
  TextStyle get arcadeBannerLarge => arcadeBanner.copyWith(fontSize: 48);

  /// The break's "1라운드 승리!": Do Hyeon 40.
  TextStyle get arcadeBannerSmall => arcadeBanner.copyWith(fontSize: 40);

  /// A star's condition under it on the results, 12 bold.
  TextStyle get arcadeStarLabel => _arcade(
    family: AppFonts.body,
    size: 12,
    weight: FontWeight.w700,
    height: 1.3,
  );

  /// The results' scores: the bigger one 40, the other 28, and the colon.
  TextStyle get arcadeScoreBig => _arcade(
    family: AppFonts.number,
    size: 40,
    weight: FontWeight.w800,
    height: 1,
  );
  TextStyle get arcadeScoreSmall => arcadeScoreBig.copyWith(fontSize: 28);
  TextStyle get arcadeScoreColon => _arcade(
    family: AppFonts.number,
    size: 20,
    weight: FontWeight.w700,
    color: AppColors.textMuted,
  );

  /// "R1" on a boss round's row and on the battle's round pip.
  TextStyle get arcadeRoundTag => _arcade(
    family: AppFonts.number,
    size: 12,
    weight: FontWeight.w800,
    spacing: 1,
    color: AppColors.textMuted,
  );

  /// A round row's "푸쉬업 · 패배".
  TextStyle get arcadeRoundText => arcadeSecondary;

  /// A round row's score, "88 : 132".
  TextStyle get arcadeRoundScore =>
      _arcade(family: AppFonts.number, size: 15, weight: FontWeight.w800);

  /// The next stage card's "STAGE 9".
  TextStyle get arcadeNextTag => _arcade(
    family: AppFonts.body,
    size: 12,
    weight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  /// A next card's title, "펭뚱이 · 하이 플랭크", "시립 체육관": Do Hyeon 20.
  TextStyle get arcadeNextTitle => _arcade(
    family: AppFonts.display,
    size: 20,
    weight: FontWeight.w400,
    height: 1.2,
  );

  /// The next card's kind, "HOLD", and the next floor's "OPEN".
  TextStyle get arcadeNextKind => _arcade(
    family: AppFonts.number,
    size: 12,
    weight: FontWeight.w800,
    spacing: 1,
    color: AppColors.textSecondary,
  );

  /// The next floor's "체육관 관장 · 펭뚱이".
  TextStyle get arcadeNextOwner => _arcade(
    family: AppFonts.body,
    size: 12,
    weight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  /// The floor chip on a result's card, "2F", "5F".
  TextStyle get arcadeCardFloor =>
      _arcade(family: AppFonts.number, size: 14, weight: FontWeight.w800);

  /// "공사중" on the last floor's card: Do Hyeon 24.
  TextStyle get arcadeWipCard =>
      _arcade(family: AppFonts.display, size: 24, weight: FontWeight.w400);

  /// A text button under the results, "아케이드로", "그만하기".
  TextStyle get arcadeLink => _arcade(
    family: AppFonts.body,
    size: 13,
    weight: FontWeight.w700,
    color: AppColors.textSecondary,
  ).copyWith(decoration: TextDecoration.underline);

  /// The boss intro's title, "보스 매치": 28, slanted by the screen.
  TextStyle get arcadeBossTitle => _arcade(
    family: AppFonts.body,
    size: 28,
    weight: FontWeight.w600,
    height: 1.05,
    spacing: -0.5,
  );

  /// The boss card's "BOSS" tag.
  TextStyle get arcadeBossChip =>
      _arcade(family: AppFonts.number, size: 12, weight: FontWeight.w800);

  /// The boss's name on the intro: Do Hyeon 40.
  TextStyle get arcadeBossName => _arcade(
    family: AppFonts.display,
    size: 40,
    weight: FontWeight.w400,
    height: 1.05,
  );

  /// "1F 체육관 관장" under it.
  TextStyle get arcadeBossRole => _arcade(
    family: AppFonts.body,
    size: 13,
    weight: FontWeight.w600,
    color: AppColors.bossRole,
  );

  /// "AI LV 4" on its ink chip, white.
  TextStyle get arcadeLevelChip => _arcade(
    family: AppFonts.number,
    size: 11,
    weight: FontWeight.w800,
    spacing: 1,
    color: AppColors.onInk,
  );

  /// "ROUND 1", "NEXT · ROUND 2".
  TextStyle get arcadeRoundLabel => _arcade(
    family: AppFonts.number,
    size: 12,
    weight: FontWeight.w800,
    spacing: 2,
    color: AppColors.textMuted,
  );

  /// A round's exercise on the boss intro, "푸쉬업": 19, slanted by the
  /// screen.
  TextStyle get arcadeRoundName =>
      _arcade(family: AppFonts.body, size: 19, weight: FontWeight.w600);

  /// A round's length, "30초".
  TextStyle get arcadeRoundTime => _arcade(
    family: AppFonts.number,
    size: 13,
    weight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  /// The break's next round, "스쿼트 30초": 20, slanted by the screen.
  TextStyle get arcadeNextRound => arcadeRoundName.copyWith(fontSize: 20);

  /// "R2" on the break's round disc.
  TextStyle get arcadeRoundDisc =>
      _arcade(family: AppFonts.number, size: 16, weight: FontWeight.w800);
}

/// The arcade hold stage's own colors (A4: the P16Hold and ArcResult
/// designs), where the palette above has none of the value. The rest of
/// the stage uses [AppColors].
abstract final class HoldColors {
  /// "STAGE n · nF" over the briefing's title.
  static const stageTag = Color(0xFFC4134F);

  /// The owner's title and the warning rule on the briefing.
  static const softInk = Color(0xFF2B3242);

  /// A star time's tile on the briefing.
  static const tile = Color(0xFFF7F8FA);

  /// An unlit star, and the briefing's divider.
  static const starOff = Color(0xFFE3E6EC);

  /// The failed result's title band.
  static const failBand = AppColors.facetDark;

  /// The briefing's owner card.
  static const ownerCard = AppColors.facetLight;

  /// The camera box's figure, where the camera picture is not: the box, its
  /// floor, the figure, its feet, and the plank's body under the shoulders.
  static const cameraBox = Color(0xFFB4B9C2);
  static const cameraFloor = Color(0xFF9FA5AF);
  static const figure = Color(0xFF646A74);
  static const figureFeet = Color(0xFF585E68);
  static const figureBody = Color(0xFF7E848E);

  /// A failed hold's reason chip (the hold effects spec 5, `ArcResult`
  /// holdFail `why=list`).
  static const reasonChip = Color(0xFFFFE9E7);
}

/// The text styles of the arcade hold stage and its result (A4: P16Hold,
/// ArcResult), at the design's sizes. Screens change only their color.
extension HoldText on TextTheme {
  TextStyle _hold({
    required String family,
    required double size,
    required FontWeight weight,
    double? height,
    double spacing = 0,
    Color color = AppColors.ink,
  }) => bodyMedium!.copyWith(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The briefing's "STAGE 3 · 1F": Oxanium 700, 11, spaced.
  TextStyle get holdBriefTag => _hold(
    family: AppFonts.number,
    size: 11,
    weight: FontWeight.w700,
    spacing: 3,
    color: HoldColors.stageTag,
  );

  /// The briefing's title, "버티기": 28, semibold, slanted by the screen.
  TextStyle get holdBriefTitle => _hold(
    family: AppFonts.body,
    size: 28,
    weight: FontWeight.w600,
    height: 1.05,
    spacing: -0.5,
  );

  /// "COACH" on its ink tag: Oxanium 800, 12, lime.
  TextStyle get holdCoachTag => _hold(
    family: AppFonts.number,
    size: 12,
    weight: FontWeight.w800,
    spacing: 2,
    color: AppColors.accent,
  );

  /// The owner's name on the briefing: Do Hyeon 40.
  TextStyle get holdOwnerName => _hold(
    family: AppFonts.display,
    size: 40,
    weight: FontWeight.w400,
    height: 1.05,
  );

  /// "1F 체육관 관장" and "경고 2번이면 실패": 13, semibold.
  TextStyle get holdNote => _hold(
    family: AppFonts.body,
    size: 13,
    weight: FontWeight.w600,
    color: HoldColors.softInk,
  );

  /// The pose's name on the briefing: 21, semibold, slanted by the screen.
  TextStyle get holdPoseName => _hold(
    family: AppFonts.body,
    size: 21,
    weight: FontWeight.w600,
    height: 1.15,
  );

  /// "최대 30초": Oxanium 700, 13.
  TextStyle get holdMaxTime => _hold(
    family: AppFonts.number,
    size: 13,
    weight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  /// A star time's seconds on the briefing: Oxanium 800, 17.
  TextStyle get holdGoalSeconds =>
      _hold(family: AppFonts.number, size: 17, weight: FontWeight.w800);

  /// "판정", before the check chips: 12, bold.
  TextStyle get holdChecksLabel => _hold(
    family: AppFonts.body,
    size: 12,
    weight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  /// A check chip's words, e.g. "팔 펴기": 12, bold.
  TextStyle get holdCheck =>
      _hold(family: AppFonts.body, size: 12, weight: FontWeight.w700);

  /// The briefing's "자세 잡기": 19, semibold, white, slanted by the screen.
  TextStyle get holdStartButton => _hold(
    family: AppFonts.body,
    size: 19,
    weight: FontWeight.w600,
    color: AppColors.onInk,
  );

  /// "STAGE 3 · 1F" on its ink tag over the stage: Oxanium 800, 12, lime.
  TextStyle get holdStageTag => _hold(
    family: AppFonts.number,
    size: 12,
    weight: FontWeight.w800,
    color: AppColors.accent,
  );

  /// "버틴 시간" or "멈춤" over the clock: 11, bold.
  TextStyle get holdClockLabel => _hold(
    family: AppFonts.body,
    size: 11,
    weight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  /// The clock, e.g. "0:22": Oxanium 800, 46.
  TextStyle get holdClock => _hold(
    family: AppFonts.number,
    size: 46,
    weight: FontWeight.w800,
    height: 1,
    spacing: -1,
  );

  /// A star mark's seconds under the bar: Oxanium 700, 11.
  TextStyle get holdMarkSeconds => _hold(
    family: AppFonts.number,
    size: 11,
    weight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  /// The owner's "삐익!": Do Hyeon 34, red.
  TextStyle get holdWhistle => _hold(
    family: AppFonts.display,
    size: 34,
    weight: FontWeight.w400,
    height: 1.1,
    color: AppColors.danger,
  );

  /// The owner's start words after GO, in the whistle's bubble: Do Hyeon 30
  /// (the hold effects spec 3).
  TextStyle get holdStartBubble => _hold(
    family: AppFonts.display,
    size: 30,
    weight: FontWeight.w400,
    height: 1.1,
  );

  /// The owner's big cheer and "실패!": Do Hyeon 54 (effects spec 4, 5).
  TextStyle get holdBigBubble => _hold(
    family: AppFonts.display,
    size: 54,
    weight: FontWeight.w400,
    height: 1.05,
  );

  /// A failed hold's reason chip: Do Hyeon 20 (effects spec 5).
  TextStyle get holdReasonChip => _hold(
    family: AppFonts.display,
    size: 20,
    weight: FontWeight.w400,
    height: 1.1,
  );

  /// The warning's two big lines in the camera box: Do Hyeon 66.
  TextStyle get holdCue => _hold(
    family: AppFonts.display,
    size: 66,
    weight: FontWeight.w400,
    height: 0.98,
  );

  /// The result's "STAGE 9 · 2F": Oxanium 700, 12, spaced.
  TextStyle get holdResultTag => _hold(
    family: AppFonts.number,
    size: 12,
    weight: FontWeight.w700,
    spacing: 3,
    color: AppColors.textMuted,
  );

  /// The result's "클리어!" or "실패": Do Hyeon 44.
  TextStyle get holdResultTitle => _hold(
    family: AppFonts.display,
    size: 44,
    weight: FontWeight.w400,
    height: 1.1,
  );

  /// The result's "버틴 시간": 12, bold.
  TextStyle get holdResultTimeLabel => holdChecksLabel;

  /// The result's time: Oxanium 800, 48.
  TextStyle get holdResultTime => _hold(
    family: AppFonts.number,
    size: 48,
    weight: FontWeight.w800,
    height: 1,
  );

  /// A star's label under it on the result, e.g. "20초": 12, bold.
  TextStyle get holdStarLabel => _hold(
    family: AppFonts.body,
    size: 12,
    weight: FontWeight.w700,
    height: 1.3,
  );

  /// "경고 2번" on the failed result: 14, bold.
  TextStyle get holdStrikes =>
      _hold(family: AppFonts.body, size: 14, weight: FontWeight.w700);

  /// The next stage card's "STAGE 10": Oxanium 700, 11.
  TextStyle get holdNextTag => _hold(
    family: AppFonts.number,
    size: 11,
    weight: FontWeight.w700,
    spacing: 1,
    color: AppColors.textSecondary,
  );

  /// The next stage card's "곰탱이 · 푸쉬업": Do Hyeon 20.
  TextStyle get holdNextName => _hold(
    family: AppFonts.display,
    size: 20,
    weight: FontWeight.w400,
    height: 1.2,
  );

  /// The result's left button, e.g. "다시 하기": 14, bold.
  TextStyle get holdResultButton => holdStrikes;

  /// The result's right button, e.g. "다음 스테이지": 17, semibold, white,
  /// slanted by the screen.
  TextStyle get holdResultAction => _hold(
    family: AppFonts.body,
    size: 17,
    weight: FontWeight.w600,
    color: AppColors.onInk,
  );
}

/// The login and first sign-up screens' colors that the shared palette
/// lacks (P8, `LoginS.dc.html`). Everything else there is an [AppColors]
/// value.
abstract final class AuthColors {
  /// The Google button's words while it logs in, and a field's placeholder.
  static const busyText = Color(0xFF8A93A6);

  /// The "아이디로 로그인" link while a login runs.
  static const busyLink = Color(0xFFA3AABA);

  /// The lime button's fill while it works (계정을 만드는 중…).
  static const busyLime = Color(0xFFE3F7B0);

  /// The id sheet's handle.
  static const sheetHandle = Color(0xFFC9CED8);

  /// Over the screen behind the id sheet: ink at 45 %.
  static const scrim = Color(0x73141A26);
}

/// The login and first sign-up screens' sizes (P8, `LoginB.dc.html` and
/// `LoginS.dc.html`) that [AppSpacing] and [AppRadius] lack.
abstract final class AuthLayout {
  /// The logo's top under the status bar: 50 in the design, less its 24
  /// high status bar.
  static const double logoTop = 26;
  static const double logoRow = 50;
  static const double logoBarWidth = 13;
  static const double logoBarHeight = 42;

  /// The lime bar's and the logo's slant in degrees, top to the right
  /// (CSS skewX(-14deg), skewX(-10deg)).
  static const double logoBarSkew = 14;
  static const double logoSkew = 10;

  /// Between the logo and the line under it, and between the controls at
  /// the bottom.
  static const double gap = 10;

  /// Between "1V1" and the words after it; between an icon and its words.
  static const double tagGap = 8;
  static const double iconGap = 6;
  static const double googleHeight = 54;
  static const double googleRadius = 16;
  static const double markBox = 22;
  static const double linkHeight = 44;
  static const double sheetLinkHeight = 40;
  static const double edge = 2;
  static const double thinEdge = 1.5;
  static const double noticeIcon = 16;

  /// Under the cancel line, before the gap to the button.
  static const double noticeBelow = 2;
  static const double errorPadV = 10;
  static const double errorPadH = 12;
  static const double errorRadius = 14;
  static const double errorMark = 34;
  static const double errorMarkRadius = 10;
  static const double errorMarkIcon = 20;
  static const double errorLineGap = 1;
  static const double fieldMark = 18;
  static const double fieldMarkRadius = 6;
  static const double fieldMarkIcon = 12;
  static const double fieldHeight = 54;
  static const double nicknameHeight = 56;
  static const double fieldRadius = 14;
  static const double limeHeight = 58;
  static const double limeIcon = 26;
  static const double spinner = 22;
  static const double sheetPadTop = 10;
  static const double handleWidth = 44;
  static const double handleHeight = 5;
  static const double handleRadius = 3;
  static const double sheetTitleTop = 4;
  static const double closeButton = 40;
  static const double closeIcon = 18;
  static const double backButton = 44;
  static const double backIcon = 22;

  /// The sign-up title row's top under the status bar (32 less 24).
  static const double titleTop = 8;
}

/// The login and first sign-up screens' text styles (P8). Like the rest of
/// the app they follow the system text size.
extension AuthText on TextTheme {
  /// "GYMMOUSE": Oxanium 800, 46, slanted by the screen.
  TextStyle get authLogo => bodyMedium!.copyWith(
    fontFamily: AppFonts.number,
    fontSize: 46,
    fontWeight: FontWeight.w800,
    height: 1,
    letterSpacing: 1,
    color: AppColors.ink,
  );

  /// "1V1" before the line under the logo: Oxanium 700, 13 on 18, spaced.
  TextStyle get authTagMark => bodyMedium!.copyWith(
    fontFamily: AppFonts.number,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 18 / 13,
    letterSpacing: 2,
    color: AppColors.ink,
  );

  /// The line under the logo, a help line, a field error's detail: 13 on 18.
  TextStyle get authSmall => bodyMedium!.copyWith(
    fontFamily: AppFonts.body,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    letterSpacing: 0,
    color: AppColors.textSecondary,
  );

  /// A field's name, the cancel line, a field error: 13 on 18, bold.
  TextStyle get authLabel =>
      authSmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink);

  /// The Google button's words: 16 on 22, bold.
  TextStyle get authButton => bodyMedium!.copyWith(
    fontFamily: AppFonts.body,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 22 / 16,
    letterSpacing: 0,
    color: AppColors.ink,
  );

  /// The "G" before it: 18, bold, tight.
  TextStyle get authMark => authButton.copyWith(fontSize: 18, height: 1);

  /// A link: 14 on 20, semibold, underlined.
  TextStyle get authLink => bodyMedium!.copyWith(
    fontFamily: AppFonts.body,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    letterSpacing: 0,
    color: AppColors.textSecondary,
    decoration: TextDecoration.underline,
  );

  /// An error box's first sentence: 14 on 20, bold.
  TextStyle get authErrorTitle => authLink.copyWith(
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    decoration: TextDecoration.none,
  );

  /// Typed text: 17, semibold.
  TextStyle get authField => bodyMedium!.copyWith(
    fontFamily: AppFonts.body,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.ink,
  );

  /// A hidden password's dots: 17, bold, spaced 3.
  TextStyle get authSecret =>
      authField.copyWith(fontWeight: FontWeight.w700, letterSpacing: 3);

  /// The nickname's count: Oxanium 700, 13.
  TextStyle get authCount => bodyMedium!.copyWith(
    fontFamily: AppFonts.number,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    color: AppColors.textMuted,
  );

  /// The lime button's words: Do Hyeon 24 on 28.
  TextStyle get authLime => bodyMedium!.copyWith(
    fontFamily: AppFonts.display,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 28 / 24,
    letterSpacing: 0,
    color: AppColors.ink,
  );

  /// The id sheet's title: Do Hyeon 28 on 32.
  TextStyle get authSheetTitle =>
      authLime.copyWith(fontSize: 28, height: 32 / 28);

  /// The sign-up screen's title: Do Hyeon 30 on 36.
  TextStyle get authTitle => authLime.copyWith(fontSize: 30, height: 36 / 30);
}

/// The friend battle screens' colors (A11, `FrPlay`, `FrFriends`,
/// `FrWait`, `FrAlert`) that [AppColors] lacks.
abstract final class FriendColors {
  /// The shade under the slanted edge of 친구와의 대전's sky panel, under
  /// [AppColors.fever].
  static const skyShade = Color(0xFF22D3EE);

  /// The quiet gray: a time bar's and the ring's track, the lines between
  /// friends, an ended wait's lower cell and its band.
  static const quiet = Color(0xFFE3E6EC);
}

/// The friend battle screens' text styles (A11). Like the rest of the app
/// they follow the system text size, but for the sticker.
extension FriendText on TextTheme {
  TextStyle _friend({
    required String family,
    required double size,
    FontWeight weight = FontWeight.w400,
    double? height,
    double spacing = 0,
    Color color = AppColors.ink,
  }) => bodyMedium!.copyWith(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// "친구와의 / 대전" on 게임 시작's friend card: Do Hyeon 31 on 1.08.
  TextStyle get friendCardName =>
      _friend(family: AppFonts.display, size: 31, height: 1.08);

  /// "수락 대기!" on its orange sticker: Do Hyeon 19.
  TextStyle get friendSticker =>
      _friend(family: AppFonts.display, size: 19, height: 1);

  /// The inviter in an invite card and the alert ("deadlift님이"): Do Hyeon
  /// 24 on 28.
  TextStyle get friendInviteName =>
      _friend(family: AppFonts.display, size: 24, height: 28 / 24);

  /// The time left, "0:48": Oxanium 700, 15 on 20.
  TextStyle get friendClock => _friend(
    family: AppFonts.number,
    size: 15,
    weight: FontWeight.w700,
    height: 20 / 15,
  );

  /// "스쿼트 대결을 신청했어요" in the alert: 15 bold on 22.
  TextStyle get friendInviteLine => _friend(
    family: AppFonts.body,
    size: 15,
    weight: FontWeight.w700,
    height: 22 / 15,
  );

  /// "스쿼트 대결" on its pill: 13 bold on 20; also "나", "친구" in the
  /// waiting room.
  TextStyle get friendPill => _friend(
    family: AppFonts.body,
    size: 13,
    weight: FontWeight.w700,
    height: 20 / 13,
  );

  /// 거절, 요청, 친구 목록으로: 15 bold.
  TextStyle get friendButton =>
      _friend(family: AppFonts.body, size: 15, weight: FontWeight.w700);

  /// 수락 on its lime button: Do Hyeon 20.
  TextStyle get friendAccept =>
      _friend(family: AppFonts.display, size: 20, height: 1);

  /// A friend's nickname in the list: Do Hyeon 21 on 26.
  TextStyle get friendRowName =>
      _friend(family: AppFonts.display, size: 21, height: 26 / 21);

  /// A friend's code under it: Oxanium 600, 12 on 16, gray.
  TextStyle get friendRowCode => _friend(
    family: AppFonts.number,
    size: 12,
    weight: FontWeight.w600,
    height: 16 / 12,
    color: AppColors.textMuted,
  );

  /// 대결 on a friend's row: Do Hyeon 19.
  TextStyle get friendChallenge =>
      _friend(family: AppFonts.display, size: 19, height: 1);

  /// "내 친구 코드": 12 on 16, gray.
  TextStyle get friendCodeLabel => _friend(
    family: AppFonts.body,
    size: 12,
    height: 16 / 12,
    color: AppColors.textSecondary,
  );

  /// My code itself: 18 bold on 24.
  TextStyle get friendCode => _friend(
    family: AppFonts.body,
    size: 18,
    weight: FontWeight.w700,
    height: 24 / 18,
  );

  /// My code's tag, "#0042": [friendCode] in [AppFonts.number].
  TextStyle get friendCodeTag =>
      friendCode.copyWith(fontFamily: AppFonts.number);

  /// What is typed in the code field, and its hint: 15.
  TextStyle get friendCodeInput => _friend(family: AppFonts.body, size: 15);

  /// The waiting room's 신청 취소 / 나가기: 14 bold.
  TextStyle get friendWaitBack =>
      _friend(family: AppFonts.body, size: 14, weight: FontWeight.w700);

  /// Its band, "CHALLENGE": Oxanium 700, 15 on 20, spaced 3.
  TextStyle get friendWaitTag => _friend(
    family: AppFonts.number,
    size: 15,
    weight: FontWeight.w700,
    height: 20 / 15,
    spacing: 3,
  );

  /// "스쿼트 · 30초" under the band: 14 bold on 20, gray.
  TextStyle get friendWaitInfo => _friend(
    family: AppFonts.body,
    size: 14,
    weight: FontWeight.w700,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );

  /// Its "30": [friendWaitInfo] in [AppFonts.number].
  TextStyle get friendWaitInfoNumber =>
      friendWaitInfo.copyWith(fontFamily: AppFonts.number);

  /// The two-line title: Do Hyeon 30 on 36.
  TextStyle get friendWaitTitle =>
      _friend(family: AppFonts.display, size: 30, height: 36 / 30);

  /// A player's nickname on the board: Do Hyeon 28 on 34.
  TextStyle get friendWaitName =>
      _friend(family: AppFonts.display, size: 28, height: 34 / 28);

  /// The friend's "?": Oxanium 800, 150 (white over [friendMysteryEdge]).
  TextStyle get friendMystery => _friend(
    family: AppFonts.number,
    size: 150,
    weight: FontWeight.w800,
    height: 1,
  );

  /// The "?"'s 7 ink edge, drawn under its fill (`FrWait`'s `stroke-width
  /// 7`, `paint-order: stroke`).
  TextStyle get friendMysteryEdge => friendMystery.copyWith(
    foreground: Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.ink,
  );

  /// The seconds in the ring: Oxanium 800, 32, tight.
  TextStyle get friendSeconds => _friend(
    family: AppFonts.number,
    size: 32,
    weight: FontWeight.w800,
    height: 1,
    spacing: -1,
  );

  /// "VS" in the circle once the friend accepted: Oxanium 800, 34, tight.
  TextStyle get friendVs => _friend(
    family: AppFonts.number,
    size: 34,
    weight: FontWeight.w800,
    height: 1,
    spacing: -1,
  );

  /// "기다리는 동안 자리를 준비해 두세요": 15 bold on 22.
  TextStyle get friendPrepTitle => friendInviteLine;

  /// The exercise's placement words under it: 14 on 21, gray.
  TextStyle get friendPrepTip => _friend(
    family: AppFonts.body,
    size: 14,
    height: 21 / 14,
    color: AppColors.textSecondary,
  );

  /// "deadlift님에게 다시 신청": Do Hyeon 24 on 30.
  TextStyle get friendRetry =>
      _friend(family: AppFonts.display, size: 24, height: 30 / 24);
}

/// The text styles of the weekly rankings screen and its rules sheet (A13
/// design `RankD1`, `RankRules`), made from the theme's body style. The
/// rankings' big numbers use the number styles that already have their
/// sizes: [StatsText.statsAverage] (40), [ArchiveText.archiveTotal] (32),
/// [ArchiveText.archiveGain] (26), [StatsText.statsCount] (20) and
/// [ArchiveText.archiveScore] (18). Ink unless the screen colors them.
extension RankingText on TextTheme {
  TextStyle _ranking({
    required String family,
    required double size,
    FontWeight weight = FontWeight.w400,
    double? height,
  }) => bodyMedium!.copyWith(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: 0,
    color: AppColors.ink,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The week on the ink banner, "11월 4주차": Do Hyeon 21, tight.
  TextStyle get rankingWeekName =>
      _ranking(family: AppFonts.display, size: 21, height: 1);

  /// The list's name, "TOP 50", "나와 친구 4명": Do Hyeon 18.
  TextStyle get rankingListTitle =>
      _ranking(family: AppFonts.display, size: 18);

  /// "점수 규칙" on the rules sheet: Do Hyeon 28.
  TextStyle get rankingSheetTitle =>
      _ranking(family: AppFonts.display, size: 28);

  /// A two-digit rank in a row's rank cell: Oxanium 800, 17 (one digit is
  /// [StatsText.statsCount], 20).
  TextStyle get rankingRowRankWide =>
      _ranking(family: AppFonts.number, size: 17, weight: FontWeight.w800);

  /// The points in the goal line, "3" of "3위까지 3점": Oxanium 800, 11.5.
  TextStyle get rankingGoalNumber =>
      _ranking(family: AppFonts.number, size: 11.5, weight: FontWeight.w800);

  /// 전체 and 친구 on the scope tab, and "위" after my rank: 15 (bold when
  /// chosen).
  TextStyle get rankingScopeTab =>
      _ranking(family: AppFonts.body, size: 15, weight: FontWeight.w500);

  /// 푸시업 and 스쿼트 on the exercise tab, and the time left on the orange
  /// flag: 13.5 (bold when chosen).
  TextStyle get rankingExerciseTab =>
      _ranking(family: AppFonts.body, size: 13.5, weight: FontWeight.w500);

  /// A player's name in my card and in a row: 14 bold on 18.
  TextStyle get rankingName => _ranking(
    family: AppFonts.body,
    size: 14,
    weight: FontWeight.w700,
    height: 18 / 14,
  );

  /// A record line, "4전 2승 · KO 1", and my card's goal line without a bar:
  /// 11 on 14.
  TextStyle get rankingRecord =>
      _ranking(family: AppFonts.body, size: 11, height: 14 / 11);

  /// The scope over my rank ("전체"), the goal line beside its bar and the
  /// "점" on the rules sheet: 10.5 bold.
  TextStyle get rankingTiny =>
      _ranking(family: AppFonts.body, size: 10.5, weight: FontWeight.w700);

  /// The week's dates, the list's right-hand note and the "점" after a row's
  /// points: 11.5.
  TextStyle get rankingSmall => _ranking(family: AppFonts.body, size: 11.5);

  /// A rule's description on the rules sheet: 11.5 on 15.
  TextStyle get rankingRuleDetail =>
      _ranking(family: AppFonts.body, size: 11.5, height: 15 / 11.5);

  /// The "점" after my points, and the rules sheet's lead line: 13.
  TextStyle get rankingLead => _ranking(family: AppFonts.body, size: 13);

  /// The "나" mark after my name in my row: 9.5 bold.
  TextStyle get rankingMeMark =>
      _ranking(family: AppFonts.body, size: 9.5, weight: FontWeight.w700);

  /// The rules sheet's four notes: 12.5 on 17.
  TextStyle get rankingRuleNote =>
      _ranking(family: AppFonts.body, size: 12.5, height: 17 / 12.5);

  /// A rule's name on the rules sheet, "KO승": 15 bold.
  TextStyle get rankingRuleName =>
      _ranking(family: AppFonts.body, size: 15, weight: FontWeight.w700);

  /// "아직 비교할 친구가 없어요" on the no-friends card: 15 bold on 20.
  TextStyle get rankingEmptyTitle => _ranking(
    family: AppFonts.body,
    size: 15,
    weight: FontWeight.w700,
    height: 20 / 15,
  );

  /// The no-friends card's second line: 12 on 17.
  TextStyle get rankingEmptyLine =>
      _ranking(family: AppFonts.body, size: 12, height: 17 / 12);

  /// "친구 추가하러 가기" on its white button: 14.5 bold.
  TextStyle get rankingButton =>
      _ranking(family: AppFonts.body, size: 14.5, weight: FontWeight.w700);

  // The rank ladder over an online battle's report and its rank chip (A15).
  // A two-character rank is [rankingRowRankWide], the chip's 위 and the
  // row's 나 [rankingMeMark], a row's name [rankingName].

  /// A ladder row's week points and a one-character rank: Oxanium 800, 19.
  TextStyle get ladderNumber =>
      _ranking(family: AppFonts.number, size: 19, weight: FontWeight.w800);

  /// A ladder rank of three characters or more ("803", "1,204"): Oxanium
  /// 800, 15.
  TextStyle get ladderRankNarrow =>
      _ranking(family: AppFonts.number, size: 15, weight: FontWeight.w800);

  /// My "+10" in my ladder row: Oxanium 800, 13.
  TextStyle get ladderGain =>
      _ranking(family: AppFonts.number, size: 13, weight: FontWeight.w800);

  /// The rank chip's rank and week points: Oxanium 800, 14.
  TextStyle get rankChipNumber =>
      _ranking(family: AppFonts.number, size: 14, weight: FontWeight.w800);

  /// The rank chip's "+10": Oxanium 800, 11.
  TextStyle get rankChipGain =>
      _ranking(family: AppFonts.number, size: 11, weight: FontWeight.w800);

  /// The "점" after the rank chip's points: 10 bold.
  TextStyle get rankChipUnit =>
      _ranking(family: AppFonts.body, size: 10, weight: FontWeight.w700);
}
