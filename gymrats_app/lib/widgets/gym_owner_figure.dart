import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'gym_background_art.dart';

/// A gym owner's face (P16-2 spec 1): watching (the default), blowing the
/// whistle (a hold stage's warning), or smiling (a hold stage cleared).
enum GymOwnerFace { watch, blow, ok }

/// Where each owner's face is centred in its 140 x 160 box, for places that
/// show only the face cut round (the map's hold stages). The same points as
/// the W3 characters' faces (spec 3).
const gymOwnerFaceCenters = <String, Offset>{
  'seal': Offset(70, 66),
  'penguin': Offset(70, 66),
  'kangaroo': Offset(76, 50),
  'bear': Offset(72, 62),
};

/// A gym owner in sports goggles and the opponent's pink (P16-2 spec 3):
/// `seal` 물렁범 (1F), `penguin` 펭뚱이 (2F), `kangaroo` 그루 (3F), `bear`
/// 곰탱이 (4F). An unknown [ownerId] draws `seal`.
///
/// Like `CharacterFigure` it is the 140 x 160 box times [scale], faces right
/// with its feet on (70, 150) of the box, and its art may leave the box (a
/// tail, the whistle's sound lines). A caller flips it with a `Transform` to
/// face left. With [idle] it breathes about its feet, unless the device asks
/// for reduced motion. Screen readers hear "체육관 관장 {name}".
class GymOwnerFigure extends StatelessWidget {
  const GymOwnerFigure({
    super.key,
    required this.ownerId,
    this.face = GymOwnerFace.watch,
    this.scale = 1,
    this.idle = false,
  });

  /// The owner drawn when the id is not one of them.
  static const defaultOwnerId = 'seal';

  final String ownerId;
  final GymOwnerFace face;
  final double scale;

  /// Whether it breathes (spec 3): a 2.2 s cycle about its feet.
  final bool idle;

  /// The owner's art for [ownerId], or the default owner's.
  static GymOwnerArt artOf(String ownerId) {
    final owners = GymArt.standard.owners;
    return owners[ownerId] ?? owners[defaultOwnerId]!;
  }

  @override
  Widget build(BuildContext context) {
    final art = GymArt.standard;
    final owner = artOf(ownerId);
    Widget figure = CustomPaint(
      size: art.ownerBox * scale,
      painter: GymArtPainter(
        shapes: owner.faces[face.name]!,
        window: art.ownerBox,
      ),
    );
    if (idle) figure = _Breathing(scale: scale, child: figure);
    return Semantics(label: '체육관 관장 ${owner.name}', image: true, child: figure);
  }
}

/// Scales its child about the owner's feet as the art's breathing says:
/// s = sin(2π·t / 2200 ms), 1 − 0.012·s across and 1 + 0.02·s up.
class _Breathing extends StatefulWidget {
  const _Breathing({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing>
    with SingleTickerProviderStateMixin {
  late final _ticker = createTicker(
    (elapsed) => _now.value = elapsed.inMicroseconds / 1000,
  );

  /// Milliseconds since the owner started breathing.
  final _now = ValueNotifier<double>(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _ticker.stop();
      _now.value = 0;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _now.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = GymArt.standard;
    return ValueListenableBuilder<double>(
      valueListenable: _now,
      builder: (context, now, child) {
        final s = math.sin(2 * math.pi * now / art.idlePeriodMs);
        return Transform(
          transform: Matrix4.diagonal3Values(
            1 + art.idleScaleX * s,
            1 + art.idleScaleY * s,
            1,
          ),
          origin: art.ownerAnchor * widget.scale,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
