import 'package:flutter/widgets.dart';

import 'gym_background_art.dart';

/// A floor's background is this size in its own coordinates (P16-2 spec 1).
const gymBackgroundSize = Size(360, 390);

/// The y, in [gymBackgroundSize] coordinates, where the wall meets the floor.
/// A stage puts its characters' feet on this line.
const gymBackgroundFloorLineY = 296.0;

/// A floor's stage background (P16-2 spec 3): 1F 동네 체육관, 2F 시립 체육관,
/// 3F 복싱장, 4F 국가대표 훈련장, 5F 공사중. An unknown [floor] draws 1F.
///
/// It takes the width it is given and the height of the picture at that
/// width (width × 390 / 360), and shows nothing outside the picture: the
/// floor lines that run past it are cut. A place that shows only a part of
/// it (a stage, the map) cuts it with its own `ClipRect`. It is decoration,
/// so it has no name for screen readers.
class GymBackground extends StatelessWidget {
  const GymBackground({super.key, required this.floor});

  /// 1 to 5.
  final int floor;

  /// The floor drawn for [floor]: itself when there is one, otherwise 1F.
  static int floorShown(int floor) =>
      GymArt.standard.floors.containsKey(floor) ? floor : 1;

  @override
  Widget build(BuildContext context) {
    final art = GymArt.standard;
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: art.backgroundSize.aspectRatio,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: GymArtPainter(
              shapes: art.floors[floorShown(floor)]!,
              window: art.backgroundSize,
              clip: true,
            ),
          ),
        ),
      ),
    );
  }
}
