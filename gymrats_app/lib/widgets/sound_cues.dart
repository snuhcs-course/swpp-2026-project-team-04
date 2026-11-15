import 'package:flutter/widgets.dart';

import '../models/voice_cue.dart';
import '../services/audio/background_music.dart';
import '../services/audio/sound_services.dart';

/// Plays a screen's sound from its state: wrap the screen's body and pass
/// the cues its state calls for on every build.
///
/// ```dart
/// SoundCues(
///   music: state.inFever ? MusicCue.fever : MusicCue.battle,
///   voice: VoiceCueTable.forEnd(state.end),
///   child: body,
/// )
/// ```
///
/// The services drop repeats, so passing the same cue on every build plays
/// it once. A null [music] keeps whatever is playing. Leaving the screen
/// stops nothing: the music fades into the next screen's cue, and a line
/// being said (e.g. the result at the end of a battle) is finished. When the
/// screen shows again (the screen pushed over it was closed, e.g. home after
/// a battle), its music comes back.
class SoundCues extends StatefulWidget {
  const SoundCues({
    super.key,
    this.music,
    this.voice,
    this.services,
    required this.child,
  });

  final MusicCue? music;
  final VoiceCue? voice;

  /// The app's sound; [SoundServices.shared] when null.
  final SoundServices? services;

  final Widget child;

  @override
  State<SoundCues> createState() => _SoundCuesState();
}

class _SoundCuesState extends State<SoundCues> {
  late SoundServices _services = widget.services ?? SoundServices.shared;
  Animation<double>? _covering;

  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The route's secondary animation runs while another route covers it,
    // and is dismissed again once that route is gone.
    final covering = ModalRoute.of(context)?.secondaryAnimation;
    if (identical(covering, _covering)) return;
    _covering?.removeStatusListener(_onCovering);
    _covering = covering?..addStatusListener(_onCovering);
  }

  void _onCovering(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    final music = widget.music;
    if (music != null) _services.music.play(music);
  }

  @override
  void dispose() {
    _covering?.removeStatusListener(_onCovering);
    super.dispose();
  }

  @override
  void didUpdateWidget(SoundCues old) {
    super.didUpdateWidget(old);
    final services = widget.services ?? SoundServices.shared;
    if (!identical(services, _services)) {
      _services.voice.stop();
      _services = services;
    }
    _apply();
  }

  void _apply() {
    final music = widget.music, voice = widget.voice;
    if (music != null) _services.music.play(music);
    if (voice != null) _services.voice.say(voice);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
