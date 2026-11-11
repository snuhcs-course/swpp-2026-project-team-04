import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';

import '../models/reject_reason_korean.dart';
import '../theme/app_theme.dart';
import 'battle_camera_area.dart';
import 'battle_fighter.dart';
import 'battle_fx_motion.dart';
import 'battle_reject_sign.dart';
import 'battle_stage.dart';
import 'battle_stage_model.dart';

/// Feeds a [BattleArena]: a battle screen gives it each judged rep once
/// ([rep]); the arena reads the rest from the state it is built with.
///
/// It keeps the stage's clock, which the arena turns: the clock stands
/// still while no arena is on screen, and goes on from there when one comes
/// back, so an ending that has played stays played.
class BattleStageController {
  BattleFxTimeline _fx = BattleFxTimeline();
  double _now = 0;
  bool _started = false;

  /// What a screen reader is still to be told.
  final _toSay = <String>[];

  /// Plays a rep on the stage: the game has judged and scored it already.
  /// Once the battle has ended a rep is not played, nor read out.
  void rep(BattleStageEvent event) {
    _started = true;
    if (!_fx.rep(event, _now)) return;
    final reason = event.reason;
    if (event.side == BattleSide.me && !event.counted && reason != null) {
      _toSay.add(
        event.grade == null
            ? reason.koreanMessage
            : '${reason.koreanMessage} · +${event.points}점',
      );
    }
  }

  /// Brings the stage in line with [state].
  void _sync(BattleStageState state) {
    if (!_started) {
      // Nothing has moved yet: stand where the score is, without gliding.
      _started = true;
      _fx = BattleFxTimeline(
        share: state.barShare,
        feverMultiplier: state.feverMultiplier,
      );
    }
    _fx
      ..setShare(state.barShare, _now)
      ..setScores(state.myScore, state.opponentScore)
      ..setFever(state.fever, _now)
      ..danger = state.danger
      ..opponentGone = state.opponentDisconnected;
    switch (state.phase) {
      case BattleStagePhase.setup:
        _fx.setSetup(
          active: true,
          meReady: state.meReady,
          opponentReady: state.opponentReady,
        );
      case BattleStagePhase.countdown:
        final left = state.countdown;
        if (left != null) {
          _fx.countDown(
            left.inMicroseconds / Duration.microsecondsPerMillisecond,
            _now,
          );
        }
      case BattleStagePhase.playing || BattleStagePhase.ended:
        _fx.setSetup(active: false);
    }
    final end = state.end;
    if (end != null) _fx.finish(end, _now);
  }
}

/// What a screen reader is told for a [cue] of the stage, or null when the
/// cue has nothing to add: the points and valid reps after a blow, the
/// countdown, the start and how the battle ended.
String? battleAnnouncement(BattleStageCue cue, BattleStageState state) {
  final mine = cue.side == BattleSide.me;
  return switch (cue.kind) {
    BattleCueKind.hit =>
      mine
          ? '내 점수 ${state.myScore}점, 유효 ${state.myReps}회'
          : '상대 점수 ${state.opponentScore}점, 유효 ${state.opponentReps}회',
    // The user's own miss is said with its reason; the opponent's is not
    // the user's business while exercising.
    BattleCueKind.miss => null,
    BattleCueKind.knockout => mine ? 'K.O. 이겼어요' : 'K.O. 졌어요',
    BattleCueKind.timeUp => '시간 종료',
    BattleCueKind.verdict => switch (cue.side) {
      BattleSide.me => '이겼어요',
      BattleSide.opponent => '졌어요',
      null => '비겼어요',
    },
    BattleCueKind.countdown => '${cue.number}',
    BattleCueKind.go => '시작',
    BattleCueKind.playerLeft => mine ? '상대가 나가서 이겼어요' : '연결이 끊겨서 졌어요',
  };
}

/// The whole battle screen's picture, for a bot battle and an online one
/// alike: the fighting stage on the upper half, the user's camera on the
/// lower half, the reject sign across the line between them, and the red
/// edge while the user is about to lose.
///
/// It turns one clock for all of it. The stage is drawn in its own design
/// points and sized as a whole: as large as fits the width and the room
/// between the status bar and the line, standing on the line.
class BattleArena extends StatefulWidget {
  const BattleArena({
    super.key,
    required this.controller,
    required this.state,
    required this.camera,
    this.fighterBuilder = BattleFighter.standIn,
    this.onCue,
    this.onLeave,
    this.hint,
    this.readyLabel,
    this.onReady,
    this.onSwitchCamera,
    this.setupProgress,
    this.onShowResult,
  });

  final BattleStageController controller;
  final BattleStageState state;

  /// The camera picture with what is drawn on it, in its own shape.
  final Widget camera;

  /// Draws a fighter's picture for a pose; the characters come in here.
  final BattleFighterBuilder fighterBuilder;

  /// Called once for each moment a sound can follow, as it shows: a blow
  /// landing, a miss, a KO, time-up and its verdict, the countdown's
  /// numbers, the start, a player leaving.
  final ValueChanged<BattleStageCue>? onCue;

  /// Asks to leave; the button hides once the battle has ended.
  final VoidCallback? onLeave;

  /// The camera area's one line of guidance.
  final String? hint;

  /// The ready button before the start; see [BattleCameraArea].
  final String? readyLabel;
  final VoidCallback? onReady;

  /// The camera switch before the start.
  final VoidCallback? onSwitchCamera;

  /// The setup progress before the start, from 0 to 1.
  final double? setupProgress;

  /// Opens the result, from 결과 보기 once the ending has played.
  final VoidCallback? onShowResult;

  /// The stage's design height below its status bar room.
  static const _stageBelowStatusBar = BattleFx.stageHeight - 26;

  /// The width of the red danger edge.
  static const _dangerEdge = 10.0;

  /// How fast the reconnect band's arc turns, in degrees a millisecond.
  static const _spinSpeed = 0.4;

  @override
  State<BattleArena> createState() => _BattleArenaState();
}

class _BattleArenaState extends State<BattleArena>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final ValueNotifier<BattleFxFrame> _frame;
  bool _reducedMotion = false;

  /// Where the controller's clock stood when this arena took it over.
  late final double _clockStart;

  BattleStageController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _clockStart = _controller._now;
    _controller._sync(widget.state);
    _frame = ValueNotifier(_controller._fx.frame(_controller._now));
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(BattleArena oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller._sync(widget.state);
    final before = oldWidget.state;
    final now = widget.state;
    // Each of these is said when it begins, not when it ends.
    if (now.fever && !before.fever) {
      _say('피버, 점수 ${now.feverMultiplier}배');
    }
    if (now.reconnecting != before.reconnecting) {
      _say(now.reconnecting ? '재연결 중' : '다시 연결됐어요');
    }
    if (now.opponentDisconnected && !before.opponentDisconnected) {
      _say('상대 연결이 끊겼어요');
    }
  }

  void _onTick(Duration elapsed) {
    final now =
        _clockStart +
        elapsed.inMicroseconds / Duration.microsecondsPerMillisecond;
    _controller._now = now;
    _frame.value = _controller._fx.frame(now, reducedMotion: _reducedMotion);
    for (final cue in _controller._fx.takeCues(now)) {
      widget.onCue?.call(cue);
      final words = battleAnnouncement(cue, widget.state);
      if (words != null) _say(words);
    }
    if (_controller._toSay.isNotEmpty) {
      _controller._toSay
        ..forEach(_say)
        ..clear();
    }
  }

  /// Tells a screen reader [words], once.
  void _say(String words) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      words,
      Directionality.of(context),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final statusBar = MediaQuery.paddingOf(context).top;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // The line between the stage and the camera: half way down.
        final line = size.height / 2;
        final scale = math.max(
          0.0,
          math.min(
            size.width / BattleFx.stageWidth,
            (line - statusBar) / BattleArena._stageBelowStatusBar,
          ),
        );
        final stage = Size(
          BattleFx.stageWidth * scale,
          BattleFx.stageHeight * scale,
        );
        final origin = Offset(
          (size.width - stage.width) / 2,
          line - stage.height,
        );
        return ValueListenableBuilder<BattleFxFrame>(
          valueListenable: _frame,
          builder: (context, frame, _) {
            final sign = frame.sign;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: line,
                  child: ExcludeSemantics(
                    child: BattleStageBackdrop(
                      feverOpacity: frame.feverOpacity,
                      stripeShift: frame.stripeShift,
                      scale: scale,
                      origin: origin,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: line,
                  // A fighter knocked out of the ring leaves over the top or
                  // the side, never over the camera.
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned(
                          left: origin.dx,
                          top: origin.dy,
                          width: stage.width,
                          height: stage.height,
                          child: FittedBox(
                            fit: BoxFit.fill,
                            child: BattleStage(
                              frame: frame,
                              state: state,
                              fighterBuilder: widget.fighterBuilder,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: line,
                  bottom: 0,
                  child: BattleCameraArea(
                    camera: widget.camera,
                    // Gone once the battle has ended. While a time-up
                    // still waits for its result it stays: there is no
                    // other way out yet.
                    onLeave: state.end?.decided ?? false
                        ? null
                        : widget.onLeave,
                    hint: widget.hint,
                    readyLabel: widget.readyLabel,
                    onReady: widget.onReady,
                    onSwitchCamera: widget.onSwitchCamera,
                    setupProgress: widget.setupProgress,
                    reconnecting:
                        state.reconnecting &&
                        state.phase == BattleStagePhase.playing,
                    spin: _reducedMotion
                        ? 0
                        : (_controller._now * BattleArena._spinSpeed) % 360,
                    resultButton: frame.resultButton,
                    onShowResult: widget.onShowResult,
                    combos: frame.combos,
                    stageScale: scale,
                  ),
                ),
                if (sign != null)
                  Positioned(
                    left:
                        size.width / 2 -
                        BattleRejectSignView.size.width / 2 * scale,
                    top: line - BattleRejectSignView.riseAboveLine * scale,
                    child: IgnorePointer(
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.topLeft,
                        child: BattleRejectSignView(sign: sign),
                      ),
                    ),
                  ),
                if (frame.dangerOpacity > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.danger.withValues(
                              alpha: frame.dangerOpacity.clamp(0.0, 1.0),
                            ),
                            width: BattleArena._dangerEdge,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
