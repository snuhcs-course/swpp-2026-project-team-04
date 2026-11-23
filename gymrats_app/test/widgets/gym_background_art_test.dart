import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';
import 'package:gymrats_app/widgets/gym_background_art.dart';
import 'package:gymrats_app/widgets/gym_background_art_data.dart';

const _owners = ['seal', 'penguin', 'kangaroo', 'bear'];
const _faces = ['watch', 'blow', 'ok'];

/// The design's shots (P16-2 spec 0): the reference renderer's SVGs at 2x on
/// white. An owner's shot shows its box from (-30, -12), 200 x 180; a
/// background's shows its whole 360 x 390 window.
const _shotsDir = 'assets/arcade/shots';
const _shotScale = 2.0;
const _ownerShotTopLeft = Offset(-30, -12);
const _white = Color(0xFFFFFFFF);

/// A pixel counts as different when a channel is off by more than this;
/// edges smoothed a little differently stay under it.
const _pixelTolerance = 64;

/// The share of pixels that may differ: anti-aliased edges only, as for the
/// W3 characters. On 2026-11-23 no pixel of the 17 shots differed by more
/// than 20 in a channel; the seal's watching and smiling faces, which differ
/// only in the mouth, differ by 0.074%.
const _maxDifferentShare = 0.0003;

final _art = GymArt.standard;

/// The art as JSON, to break on purpose.
Map<String, dynamic> _source() =>
    jsonDecode(gymArtJson) as Map<String, dynamic>;

/// The first shape of the seal's watching face in [source].
Map<String, dynamic> _firstShape(Map<String, dynamic> source) =>
    source['owners']['art']['seal']['watch'][0] as Map<String, dynamic>;

/// Checks that the art, broken by [breakIt], is rejected.
void _expectRejected(void Function(Map<String, dynamic> source) breakIt) {
  final source = _source();
  breakIt(source);
  expect(() => GymArt.parse(jsonEncode(source)), throwsFormatException);
}

/// Art whose 1F background is [shapes] (JSON), to paint small cases.
List<GymArtShape> _shapes(List<Map<String, Object?>> shapes) {
  final source = _source();
  source['backgrounds']['floors']['1'] = shapes;
  return GymArt.parse(jsonEncode(source)).floors[1]!;
}

/// [painter] painted on a [w] x [h] canvas of [ground], as RGBA bytes;
/// [paintAt] places the painted area.
Future<Uint8List> _render(
  GymArtPainter painter,
  int w,
  int h, {
  Rect? paintAt,
  Color ground = _white,
}) async {
  final area = paintAt ?? Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(ground, BlendMode.src);
  canvas.translate(area.left, area.top);
  painter.paint(canvas, area.size);
  final image = await recorder.endRecording().toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return bytes!.buffer.asUint8List();
}

/// The RGBA of pixel ([x], [y]) in [bytes] of an image [w] wide.
List<int> _pixel(Uint8List bytes, int w, int x, int y) {
  final i = (y * w + x) * 4;
  return bytes.sublist(i, i + 4);
}

GymArtPainter _ownerPainter(GymOwnerArt owner, String face) =>
    GymArtPainter(shapes: owner.faces[face]!, window: _art.ownerBox);

GymArtPainter _floorPainter(List<GymArtShape> shapes) =>
    GymArtPainter(shapes: shapes, window: _art.backgroundSize, clip: true);

void main() {
  group('the art data', () {
    test('is assets/arcade/gym_art.json character for character', () {
      final file = File('assets/arcade/gym_art.json').readAsStringSync();
      expect(gymArtJson, file);
    });

    test('is arcade-art-1: owners in a 140 x 160 box standing on (70, 150), '
        'backgrounds 360 x 390 with the floor line at y 296', () {
      expect(_art.version, 'arcade-art-1');
      expect(_art.ownerBox, const Size(140, 160));
      expect(_art.ownerAnchor, const Offset(70, 150));
      expect(_art.backgroundSize, const Size(360, 390));
      expect(_art.floorLineY, 296);
    });

    test('has the four owners with their names, each in three faces', () {
      expect(_art.owners.keys, _owners);
      expect(_art.faces, _faces);
      expect(
        {for (final o in _art.owners.values) o.id: o.name},
        {'seal': '물렁범', 'penguin': '펭뚱이', 'kangaroo': '그루', 'bear': '곰탱이'},
      );
      for (final owner in _art.owners.values) {
        expect(owner.faces.keys, _faces, reason: owner.id);
      }
    });

    test('breathes on a 2.2 s cycle, 1.2% narrower and 2% taller at the top '
        'of a breath', () {
      expect(_art.idlePeriodMs, 2200);
      expect(_art.idleScaleX, -0.012);
      expect(_art.idleScaleY, 0.02);
    });

    test('has the shape counts of spec 4 (701 in all)', () {
      expect(
        {
          for (final o in _art.owners.values)
            o.id: [for (final f in _faces) o.faces[f]!.length],
        },
        {
          'seal': [34, 34, 34],
          'penguin': [29, 29, 29],
          'kangaroo': [37, 37, 37],
          'bear': [34, 34, 34],
        },
      );
      expect(
        {
          for (final MapEntry(:key, :value) in _art.floors.entries)
            key: value.length,
        },
        {1: 56, 2: 51, 3: 126, 4: 20, 5: 46},
      );
    });

    test('dresses every owner in the opponent team pink', () {
      for (final owner in _art.owners.values) {
        for (final face in _faces) {
          final colors = {
            for (final s in owner.faces[face]!) ...[s.fill, s.stroke],
          };
          expect(
            colors,
            contains(AppColors.opponent.toARGB32()),
            reason: '${owner.id} $face',
          );
        }
      }
    });

    test('reads the opacity of the floor lines (93 outlines)', () {
      final faint = [
        for (final shapes in _art.floors.values)
          ...shapes.where((s) => s.strokeOpacity < 1),
      ];
      expect(faint, hasLength(93));
      expect([
        for (final shapes in [
          ..._art.floors.values,
          for (final o in _art.owners.values) ...o.faces.values,
        ])
          ...shapes.where((s) => s.fillOpacity < 1),
      ], isEmpty);
    });
  });

  group('the parser', () {
    test('reads a shape: matrix, path, colors, line ends and opacity', () {
      final [shape] = _shapes([
        {
          'm': [-1, 0, 0, 1, 50, 146],
          'd': [
            ['M', 1, 2],
            ['L', 3, 4],
            ['Q', 5, 6, 7, 8],
            ['C', 9, 10, 11, 12, 13, 14],
            ['Z'],
          ],
          'fill': '#5b7E9B',
          'stroke': '#141A26',
          'strokeWidth': 2.5,
          'cap': 'butt',
          'join': 'bevel',
          'fillOpacity': 0.5,
          'strokeOpacity': 0.25,
        },
      ]);
      expect(shape.matrix, [-1, 0, 0, 1, 50, 146]);
      expect(
        [
          for (final s in shape.segments) [s.command, ...s.values],
        ],
        [
          [GymArtCommand.move, 1, 2],
          [GymArtCommand.line, 3, 4],
          [GymArtCommand.quad, 5, 6, 7, 8],
          [GymArtCommand.cubic, 9, 10, 11, 12, 13, 14],
          [GymArtCommand.close],
        ],
      );
      expect(shape.fill, 0xFF5B7E9B);
      expect(shape.stroke, 0xFF141A26);
      expect(shape.strokeWidth, 2.5);
      expect(shape.cap, StrokeCap.butt);
      expect(shape.join, StrokeJoin.bevel);
      expect(shape.fillOpacity, 0.5);
      expect(shape.strokeOpacity, 0.25);
      // What the painter gets: the colors at their opacity, the outline's
      // width, ends and joins.
      final fillPaint = shape.fillPaint!;
      expect(fillPaint.style, PaintingStyle.fill);
      expect(fillPaint.color.toARGB32() & 0xFFFFFF, 0x5B7E9B);
      expect(fillPaint.color.a, closeTo(0.5, 1e-3));
      final strokePaint = shape.strokePaint!;
      expect(strokePaint.style, PaintingStyle.stroke);
      expect(strokePaint.color.toARGB32() & 0xFFFFFF, 0x141A26);
      expect(strokePaint.color.a, closeTo(0.25, 1e-3));
      expect(strokePaint.strokeWidth, 2.5);
      expect(strokePaint.strokeCap, StrokeCap.butt);
      expect(strokePaint.strokeJoin, StrokeJoin.bevel);
      expect(
        shape.matrix4,
        Float64List.fromList([
          -1,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          50,
          146,
          0,
          1,
        ]),
      );
    });

    test('reads a shape with no outline, no fill and no matrix', () {
      final [plain, bare] = _shapes([
        {
          'd': [
            ['M', 0, 0],
            ['L', 1, 1],
          ],
          'fill': '#FFFFFF',
          'stroke': null,
        },
        {
          'd': [
            ['M', 0, 0],
          ],
          'fill': null,
          'stroke': null,
        },
      ]);
      expect(plain.matrix, isNull);
      expect(plain.matrix4, isNull);
      expect(plain.stroke, isNull);
      expect(plain.strokePaint, isNull);
      expect(plain.fillPaint!.color, const Color(0xFFFFFFFF));
      expect(bare.fillPaint, isNull);
      expect(bare.strokePaint, isNull);
    });

    test('warmUp builds every path and paint of the art, and can run '
        'again', () {
      GymArt.warmUp();
      final shapes = [
        for (final owner in _art.owners.values)
          for (final face in owner.faces.values) ...face,
        for (final floor in _art.floors.values) ...floor,
      ];
      expect(shapes, hasLength(701));
      final paths = [for (final s in shapes) s.path];
      GymArt.warmUp();
      for (final (i, shape) in shapes.indexed) {
        expect(identical(shape.path, paths[i]), isTrue);
        expect(shape.fillPaint == null, shape.fill == null);
        expect(shape.strokePaint == null, shape.stroke == null);
      }
    });

    test('builds each path and paint once', () {
      final shape = _art.owners['seal']!.faces['watch']!.first;
      expect(identical(shape.path, shape.path), isTrue);
      expect(identical(shape.strokePaint, shape.strokePaint), isTrue);
      expect(identical(GymArt.standard, _art), isTrue);
    });

    test('rejects an unknown path command', () {
      _expectRejected(
        (s) => _firstShape(s)['d'][1] = ['A', 1, 1, 0, 0, 1, 2, 3],
      );
      _expectRejected((s) => _firstShape(s)['d'][1] = ['q', 1, 2, 3, 4]);
    });

    test('rejects a command with the wrong count of numbers', () {
      _expectRejected((s) => _firstShape(s)['d'][1] = ['Q', 1, 2, 3]);
      _expectRejected((s) => _firstShape(s)['d'][0] = ['M', 1, 2, 3]);
      _expectRejected((s) => _firstShape(s)['d'][5] = ['Z', 1]);
      _expectRejected((s) => _firstShape(s)['d'][1] = ['L', 1, 'x']);
    });

    test('rejects a color that is not #RRGGBB', () {
      for (final color in [
        'red',
        '#FFF',
        '#FF4F81FF',
        '#GG4F81',
        'FF4F81',
        1,
      ]) {
        _expectRejected((s) => _firstShape(s)['fill'] = color);
        _expectRejected((s) => _firstShape(s)['stroke'] = color);
      }
    });

    test('rejects an empty path or an empty command', () {
      _expectRejected((s) => _firstShape(s)['d'] = []);
      _expectRejected((s) => _firstShape(s)['d'][1] = []);
      _expectRejected((s) => _firstShape(s).remove('d'));
    });

    test('rejects other broken shapes: matrix, outline, opacity', () {
      _expectRejected((s) => _firstShape(s)['m'] = [1, 0, 0, 1, 0]);
      _expectRejected((s) => _firstShape(s)['cap'] = 'square');
      _expectRejected((s) => _firstShape(s)['join'] = 'arcs');
      _expectRejected((s) => _firstShape(s).remove('strokeWidth'));
      _expectRejected((s) => _firstShape(s)['strokeOpacity'] = '0.5');
    });

    test('rejects broken art: not an object, a missing face, a bad floor', () {
      expect(() => GymArt.parse('[]'), throwsFormatException);
      expect(() => GymArt.parse('{'), throwsFormatException);
      _expectRejected((s) => s.remove('owners'));
      _expectRejected((s) => (s['owners']['art']['bear'] as Map).remove('ok'));
      _expectRejected((s) => s['backgrounds']['floors']['top'] = []);
      _expectRejected((s) => s['backgrounds']['floorLineY'] = null);
    });
  });

  group('GymArtPainter', () {
    test('fills, then outlines, each shape under its matrix', () async {
      // A 20 x 20 square moved to (10, 10): pink inside, a 4 wide ink
      // outline over its edge.
      final painter = GymArtPainter(
        shapes: _shapes([
          {
            'm': [1, 0, 0, 1, 10, 10],
            'd': [
              ['M', 0, 0],
              ['L', 20, 0],
              ['L', 20, 20],
              ['L', 0, 20],
              ['Z'],
            ],
            'fill': '#FF4F81',
            'stroke': '#141A26',
            'strokeWidth': 4,
            'cap': 'round',
            'join': 'round',
          },
        ]),
        window: const Size(40, 40),
      );
      final bytes = await _render(painter, 40, 40);
      expect(_pixel(bytes, 40, 20, 20), [0xFF, 0x4F, 0x81, 0xFF]);
      expect(_pixel(bytes, 40, 10, 20), [0x14, 0x1A, 0x26, 0xFF]);
      expect(_pixel(bytes, 40, 5, 5), [0xFF, 0xFF, 0xFF, 0xFF]);
    });

    test('draws the shapes in order, the later ones on top', () async {
      Map<String, Object?> square(String color) => {
        'd': [
          ['M', 0, 0],
          ['L', 10, 0],
          ['L', 10, 10],
          ['L', 0, 10],
          ['Z'],
        ],
        'fill': color,
        'stroke': null,
      };
      final bytes = await _render(
        GymArtPainter(
          shapes: _shapes([square('#FF0000'), square('#0000FF')]),
          window: const Size(10, 10),
        ),
        10,
        10,
      );
      expect(_pixel(bytes, 10, 5, 5), [0, 0, 0xFF, 0xFF]);
    });

    test('paints a see-through fill and a faint outline at their opacity, as '
        'the floor lines are', () async {
      // Over white: black at half opacity is mid grey, at a quarter light.
      final painter = GymArtPainter(
        shapes: _shapes([
          {
            'd': [
              ['M', 0, 0],
              ['L', 10, 0],
              ['L', 10, 10],
              ['L', 0, 10],
              ['Z'],
            ],
            'fill': '#000000',
            'fillOpacity': 0.5,
            'stroke': null,
          },
          {
            'd': [
              ['M', 0, 15],
              ['L', 20, 15],
            ],
            'fill': null,
            'stroke': '#000000',
            'strokeWidth': 4,
            'cap': 'butt',
            'join': 'round',
            'strokeOpacity': 0.25,
          },
        ]),
        window: const Size(20, 20),
      );
      final bytes = await _render(painter, 20, 20);
      for (final channel in _pixel(bytes, 20, 5, 5).take(3)) {
        expect(channel, closeTo(0x80, 2));
      }
      for (final channel in _pixel(bytes, 20, 10, 15).take(3)) {
        expect(channel, closeTo(0xBF, 2));
      }
      expect(_pixel(bytes, 20, 15, 5), [0xFF, 0xFF, 0xFF, 0xFF]);
    });

    test('scales the window the same both ways and centres it', () async {
      // A 10 x 10 window in a 40 x 20 area: scaled 2x, 10 in from the left.
      final painter = GymArtPainter(
        shapes: _shapes([
          {
            'd': [
              ['M', 0, 0],
              ['L', 10, 0],
              ['L', 10, 10],
              ['L', 0, 10],
              ['Z'],
            ],
            'fill': '#000000',
            'stroke': null,
          },
        ]),
        window: const Size(10, 10),
      );
      final bytes = await _render(painter, 40, 20);
      expect(_pixel(bytes, 40, 9, 10)[0], 0xFF);
      expect(_pixel(bytes, 40, 11, 10)[0], 0);
      expect(_pixel(bytes, 40, 28, 10)[0], 0);
      expect(_pixel(bytes, 40, 31, 10)[0], 0xFF);
    });

    test("a lone move draws nothing (the penguin's mouth, a whistle's "
        'mouth)', () async {
      final painter = GymArtPainter(
        shapes: _shapes([
          {
            'd': [
              ['M', 5, 5],
            ],
            'fill': '#141A26',
            'stroke': '#141A26',
            'strokeWidth': 6,
            'cap': 'round',
            'join': 'round',
          },
        ]),
        window: const Size(10, 10),
      );
      final bytes = await _render(painter, 10, 10);
      for (var i = 0; i < bytes.length; i += 4) {
        expect(bytes.sublist(i, i + 4), [0xFF, 0xFF, 0xFF, 0xFF]);
      }
    });

    test('with clip, a background shows nothing outside its window; its '
        'floor lines run past it', () async {
      const ground = Color(0xFF00FF00);
      const margin = 100;
      const w = 360 + 2 * margin;
      const h = 390 + 2 * margin;
      final window = Rect.fromLTWH(margin * 1.0, margin * 1.0, 360, 390);
      int paintedOutside(Uint8List bytes) {
        var painted = 0;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            if (window.contains(Offset(x + 0.5, y + 0.5))) continue;
            final [r, g, b, _] = _pixel(bytes, w, x, y);
            if (r != 0 || g != 0xFF || b != 0) painted++;
          }
        }
        return painted;
      }

      for (final floor in _art.floors.keys) {
        final shapes = _art.floors[floor]!;
        final clipped = await _render(
          _floorPainter(shapes),
          w,
          h,
          paintAt: window,
          ground: ground,
        );
        expect(paintedOutside(clipped), 0, reason: '${floor}F');
        final unclipped = await _render(
          GymArtPainter(shapes: shapes, window: _art.backgroundSize),
          w,
          h,
          paintAt: window,
          ground: ground,
        );
        expect(paintedOutside(unclipped), greaterThan(0), reason: '${floor}F');
      }
    });

    test('repaints only when the drawing, window or clip changes', () {
      final shapes = _art.floors[1]!;
      final painter = _floorPainter(shapes);
      expect(painter.shouldRepaint(_floorPainter(shapes)), isFalse);
      expect(painter.shouldRepaint(_floorPainter(_art.floors[2]!)), isTrue);
      expect(
        painter.shouldRepaint(
          GymArtPainter(shapes: shapes, window: _art.backgroundSize),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          GymArtPainter(shapes: shapes, window: _art.ownerBox, clip: true),
        ),
        isTrue,
      );
    });
  });

  group('against the design shots (assets/arcade/shots)', () {
    test('there is a shot of every owner face and every floor', () {
      final names = Directory(_shotsDir)
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(names, {
        for (final o in _owners)
          for (final f in _faces) 'owner_${o}_$f.png',
        for (final n in _art.floors.keys) 'floor_$n.png',
      });
    });

    test('the comparison catches a wrong picture (another face, another '
        'floor, a missing shape)', () async {
      final seal = _art.owners['seal']!;
      expect(
        await _ownerShare('seal', 'watch', _ownerPainter(seal, 'blow')),
        greaterThan(_maxDifferentShare),
      );
      expect(
        await _ownerShare('seal', 'watch', _ownerPainter(seal, 'ok')),
        greaterThan(_maxDifferentShare),
      );
      expect(
        await _floorShare(1, _floorPainter(_art.floors[2]!)),
        greaterThan(_maxDifferentShare),
      );
      // 1F without its last shape.
      final floor1 = _art.floors[1]!;
      expect(
        await _floorShare(
          1,
          _floorPainter(floor1.sublist(0, floor1.length - 1)),
        ),
        greaterThan(_maxDifferentShare),
      );
    });

    for (final owner in _owners) {
      for (final face in _faces) {
        test('owner_${owner}_$face matches the design but for edges', () async {
          final share = await _ownerShare(
            owner,
            face,
            _ownerPainter(_art.owners[owner]!, face),
          );
          expect(
            share,
            lessThan(_maxDifferentShare),
            reason: '${(share * 100).toStringAsFixed(4)}% of pixels differ',
          );
        });
      }
    }

    for (final floor in [1, 2, 3, 4, 5]) {
      test('floor_$floor matches the design but for edges', () async {
        final share = await _floorShare(
          floor,
          _floorPainter(_art.floors[floor]!),
        );
        expect(
          share,
          lessThan(_maxDifferentShare),
          reason: '${(share * 100).toStringAsFixed(4)}% of pixels differ',
        );
      });
    }
  });
}

/// The share of pixels of the owner shot that [painter] draws differently.
Future<double> _ownerShare(String owner, String face, GymArtPainter painter) =>
    _differentShare(
      File('$_shotsDir/owner_${owner}_$face.png'),
      (w, h) => _render(
        painter,
        w,
        h,
        paintAt: Rect.fromLTWH(
          -_ownerShotTopLeft.dx * _shotScale,
          -_ownerShotTopLeft.dy * _shotScale,
          _art.ownerBox.width * _shotScale,
          _art.ownerBox.height * _shotScale,
        ),
      ),
    );

/// The share of pixels of the floor shot that [painter] draws differently.
Future<double> _floorShare(int floor, GymArtPainter painter) => _differentShare(
  File('$_shotsDir/floor_$floor.png'),
  (w, h) => _render(painter, w, h),
);

Future<double> _differentShare(
  File shot,
  Future<Uint8List> Function(int w, int h) render,
) async {
  final codec = await ui.instantiateImageCodec(shot.readAsBytesSync());
  final image = (await codec.getNextFrame()).image;
  final expected = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
      .buffer
      .asUint8List();
  final actual = await render(image.width, image.height);
  var different = 0;
  for (var i = 0; i < expected.length; i += 4) {
    for (var c = 0; c < 3; c++) {
      if ((expected[i + c] - actual[i + c]).abs() > _pixelTolerance) {
        different++;
        break;
      }
    }
  }
  return different / (image.width * image.height);
}
