import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'gym_background_art_data.dart';

/// The arcade's drawings (P16-2 spec 2): the gym owners, each in three faces,
/// and the floor backgrounds, all read once from [gymArtJson].
///
/// Each drawing is a list of [GymArtShape]s painted in order by
/// [GymArtPainter], as the design's reference renderer does. The widgets
/// `GymOwnerFigure` and `GymBackground` show them.
class GymArt {
  const GymArt({
    required this.version,
    required this.ownerBox,
    required this.ownerAnchor,
    required this.faces,
    required this.idlePeriodMs,
    required this.idleScaleX,
    required this.idleScaleY,
    required this.owners,
    required this.backgroundSize,
    required this.floorLineY,
    required this.floors,
  });

  /// Reads art in the `gym_art.json` format; anything malformed throws a
  /// [FormatException].
  factory GymArt.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('the art is not a JSON object');
    }
    return _read('art', () {
      final owners = decoded['owners'] as Map<String, dynamic>;
      final box = owners['box'] as Map<String, dynamic>;
      final anchor = owners['anchor'] as Map<String, dynamic>;
      final idle = owners['idle'] as Map<String, dynamic>;
      final faces = List<String>.from(owners['faces'] as List);
      final backgrounds = decoded['backgrounds'] as Map<String, dynamic>;
      final size = backgrounds['size'] as Map<String, dynamic>;
      final floors = backgrounds['floors'] as Map<String, dynamic>;
      return GymArt(
        version: decoded['version'] as String,
        ownerBox: Size(_number(box['w']), _number(box['h'])),
        ownerAnchor: Offset(_number(anchor['x']), _number(anchor['y'])),
        faces: faces,
        idlePeriodMs: _number(idle['periodMs']),
        idleScaleX: _number(idle['scaleX']),
        idleScaleY: _number(idle['scaleY']),
        owners: {
          for (final MapEntry(key: id, value: art)
              in (owners['art'] as Map<String, dynamic>).entries)
            id: _owner(id, art as Map<String, dynamic>, faces),
        },
        backgroundSize: Size(_number(size['w']), _number(size['h'])),
        floorLineY: _number(backgrounds['floorLineY']),
        floors: {
          for (final MapEntry(key: floor, value: shapes) in floors.entries)
            int.tryParse(floor) ??
                    (throw FormatException('not a floor number: "$floor"')):
                _shapes('floor $floor', shapes),
        },
      );
    });
  }

  /// The art the app draws, read once.
  static final standard = GymArt.parse(gymArtJson);

  /// Reads [standard] and builds every path and paint of it now (spec 2:
  /// built once when the app starts, then reused), so the first frame that
  /// shows an owner or a floor does not pay for it. Call it once at start-up;
  /// calling it again builds nothing new. Without it each shape builds its
  /// path and paints on its first paint and keeps them.
  static void warmUp() {
    final art = standard;
    for (final shapes in [
      for (final owner in art.owners.values) ...owner.faces.values,
      ...art.floors.values,
    ]) {
      for (final shape in shapes) {
        shape.build();
      }
    }
  }

  final String version;

  /// An owner's box (140 x 160, as the W3 characters'); the art may leave it.
  final Size ownerBox;

  /// Where an owner's feet stand in its box, (70, 150).
  final Offset ownerAnchor;

  /// The face keys every owner has: watch, blow, ok.
  final List<String> faces;

  /// The owners' breathing (spec 3): with s = sin(2π·t / [idlePeriodMs]),
  /// the owner is scaled by 1 + [idleScaleX]·s across and 1 + [idleScaleY]·s
  /// up, about [ownerAnchor].
  final double idlePeriodMs;
  final double idleScaleX;
  final double idleScaleY;

  /// The owners by id, in the data's order.
  final Map<String, GymOwnerArt> owners;

  /// The window of a background (360 x 390); its floor lines run past it.
  final Size backgroundSize;

  /// The y of the line where the wall meets the floor, 296.
  final double floorLineY;

  /// The backgrounds by floor number.
  final Map<int, List<GymArtShape>> floors;

  static GymOwnerArt _owner(
    String id,
    Map<String, dynamic> json,
    List<String> faces,
  ) {
    return GymOwnerArt(
      id: id,
      name: json['name'] as String,
      faces: {
        for (final face in faces)
          face: _shapes(
            '$id $face',
            json[face] ?? (throw FormatException('"$id" has no "$face" face')),
          ),
      },
    );
  }

  static List<GymArtShape> _shapes(String where, Object? json) {
    return _read(where, () {
      return [
        for (final shape in json as List)
          GymArtShape.fromJson(shape as Map<String, dynamic>),
      ];
    });
  }
}

/// One owner's art: its name and a drawing per face.
class GymOwnerArt {
  const GymOwnerArt({
    required this.id,
    required this.name,
    required this.faces,
  });

  final String id;

  /// The owner's name shown to people (물렁범, 펭뚱이, 그루, 곰탱이).
  final String name;
  final Map<String, List<GymArtShape>> faces;
}

/// A path command of a shape: absolute coordinates only.
enum GymArtCommand {
  move('M', 2),
  line('L', 2),
  quad('Q', 4),
  cubic('C', 6),
  close('Z', 0);

  const GymArtCommand(this.letter, this.arity);

  final String letter;

  /// How many numbers follow the letter.
  final int arity;
}

/// A step of a shape's path: a command and its numbers.
class GymArtSegment {
  const GymArtSegment(this.command, this.values);

  final GymArtCommand command;
  final List<double> values;

  factory GymArtSegment.fromJson(List<dynamic> json) {
    if (json.isEmpty) throw const FormatException('an empty path command');
    final letter = json.first;
    final command = GymArtCommand.values
        .where((c) => c.letter == letter)
        .firstOrNull;
    if (command == null) {
      throw FormatException('unknown path command "$letter"');
    }
    if (json.length != command.arity + 1) {
      throw FormatException(
        '"${command.letter}" takes ${command.arity} numbers',
      );
    }
    return GymArtSegment(command, [for (final v in json.skip(1)) _number(v)]);
  }
}

/// One shape of a drawing (spec 2): a path under an optional matrix, filled
/// and then outlined. Its path and paints are built on first use and kept.
class GymArtShape {
  GymArtShape({
    this.matrix,
    required this.segments,
    this.fill,
    this.stroke,
    this.strokeWidth = 0,
    this.cap = StrokeCap.round,
    this.join = StrokeJoin.round,
    this.fillOpacity = 1,
    this.strokeOpacity = 1,
  });

  /// Reads a shape; anything malformed throws a [FormatException].
  factory GymArtShape.fromJson(Map<String, dynamic> json) {
    final d = json['d'] as List? ?? (throw const FormatException('no "d"'));
    if (d.isEmpty) throw const FormatException('an empty path');
    final m = json['m'] as List?;
    if (m != null && m.length != 6) {
      throw const FormatException('a matrix takes 6 numbers');
    }
    final stroke = _color(json['stroke']);
    return GymArtShape(
      matrix: m == null ? null : [for (final v in m) _number(v)],
      segments: [
        for (final segment in d) GymArtSegment.fromJson(segment as List),
      ],
      fill: _color(json['fill']),
      stroke: stroke,
      strokeWidth: stroke == null ? 0 : _number(json['strokeWidth']),
      cap: stroke == null ? StrokeCap.round : _cap(json['cap']),
      join: stroke == null ? StrokeJoin.round : _join(json['join']),
      fillOpacity: _opacity(json['fillOpacity']),
      strokeOpacity: _opacity(json['strokeOpacity']),
    );
  }

  /// `[a, b, c, d, e, f]` as in SVG's `matrix()`, applied to the canvas
  /// before the path; null for none.
  final List<double>? matrix;
  final List<GymArtSegment> segments;

  /// Colors as 0xAARRGGBB with full alpha; null draws no fill or no outline.
  final int? fill;
  final int? stroke;

  /// In the shape's own coordinates, so [matrix] scales it too.
  final double strokeWidth;
  final StrokeCap cap;
  final StrokeJoin join;
  final double fillOpacity;
  final double strokeOpacity;

  /// [matrix] as the 4 x 4 column-major matrix [Canvas.transform] takes.
  late final Float64List? matrix4 = switch (matrix) {
    null => null,
    [final a, final b, final c, final d, final e, final f] =>
      Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1]),
    _ => throw StateError('a matrix of ${matrix!.length} numbers'),
  };

  late final Path path = () {
    final path = Path();
    for (final GymArtSegment(:command, values: v) in segments) {
      switch (command) {
        case GymArtCommand.move:
          path.moveTo(v[0], v[1]);
        case GymArtCommand.line:
          path.lineTo(v[0], v[1]);
        case GymArtCommand.quad:
          path.quadraticBezierTo(v[0], v[1], v[2], v[3]);
        case GymArtCommand.cubic:
          path.cubicTo(v[0], v[1], v[2], v[3], v[4], v[5]);
        case GymArtCommand.close:
          path.close();
      }
    }
    return path;
  }();

  /// Builds [path], [fillPaint] and [strokePaint] now if they are not yet.
  void build() {
    path;
    fillPaint;
    strokePaint;
  }

  late final Paint? fillPaint = switch (fill) {
    null => null,
    final argb => Paint()..color = Color(argb).withValues(alpha: fillOpacity),
  };

  late final Paint? strokePaint = switch (stroke) {
    null => null,
    final argb =>
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = cap
        ..strokeJoin = join
        ..color = Color(argb).withValues(alpha: strokeOpacity),
  };
}

/// Paints a drawing's [shapes] as the reference renderer does (spec 2): in
/// order, each under its matrix, fill first and then outline.
///
/// The drawing's [window] (from (0, 0)) is scaled the same both ways to fit
/// the paint area and centred. With [clip] nothing outside the window shows
/// (a background's floor lines run past it); without it the art may leave
/// the window (an owner's tail, the whistle's sound lines).
class GymArtPainter extends CustomPainter {
  const GymArtPainter({
    required this.shapes,
    required this.window,
    this.clip = false,
  });

  final List<GymArtShape> shapes;
  final Size window;
  final bool clip;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / window.width,
      size.height / window.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - window.width * scale) / 2,
      (size.height - window.height * scale) / 2,
    );
    canvas.scale(scale);
    if (clip) canvas.clipRect(Offset.zero & window);
    for (final shape in shapes) {
      canvas.save();
      final matrix = shape.matrix4;
      if (matrix != null) canvas.transform(matrix);
      final fill = shape.fillPaint;
      if (fill != null) canvas.drawPath(shape.path, fill);
      final stroke = shape.strokePaint;
      if (stroke != null) canvas.drawPath(shape.path, stroke);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GymArtPainter oldDelegate) =>
      !identical(oldDelegate.shapes, shapes) ||
      oldDelegate.window != window ||
      oldDelegate.clip != clip;
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  throw FormatException('not a number: $value');
}

/// A `#RRGGBB` color as 0xFFRRGGBB; null stays null.
int? _color(Object? value) {
  if (value == null) return null;
  final match = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch('$value');
  if (match == null) throw FormatException('not a #RRGGBB color: $value');
  return 0xFF000000 | int.parse(match[1]!, radix: 16);
}

double _opacity(Object? value) => value == null ? 1 : _number(value);

StrokeCap _cap(Object? value) => switch (value) {
  'round' => StrokeCap.round,
  'butt' => StrokeCap.butt,
  _ => throw FormatException('unknown line end "$value"'),
};

StrokeJoin _join(Object? value) => switch (value) {
  'round' => StrokeJoin.round,
  'miter' => StrokeJoin.miter,
  'bevel' => StrokeJoin.bevel,
  _ => throw FormatException('unknown line join "$value"'),
};

/// Runs [read] and turns a wrong JSON type into a [FormatException] that
/// says where it was.
T _read<T>(String where, T Function() read) {
  try {
    return read();
  } on TypeError catch (error) {
    throw FormatException('$where: $error');
  }
}
