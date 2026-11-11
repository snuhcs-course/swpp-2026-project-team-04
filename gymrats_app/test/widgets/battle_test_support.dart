import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymrats_app/theme/app_theme.dart';

/// Loads the app's own fonts, so texts measure as they do on a phone. Tests
/// otherwise lay text out in the square placeholder font. Call it from
/// `setUpAll`.
Future<void> loadBattleFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final entry in {
    AppFonts.number: [
      'assets/fonts/Oxanium-Bold.ttf',
      'assets/fonts/Oxanium-ExtraBold.ttf',
    ],
    AppFonts.display: ['assets/fonts/DoHyeon-Regular.ttf'],
    AppFonts.headline: ['assets/fonts/BlackHanSans-Regular.ttf'],
    AppFonts.body: [
      'assets/fonts/IBMPlexSansKR-Regular.ttf',
      'assets/fonts/IBMPlexSansKR-Medium.ttf',
      'assets/fonts/IBMPlexSansKR-SemiBold.ttf',
      'assets/fonts/IBMPlexSansKR-Bold.ttf',
    ],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

/// [child] in the app's theme, at the top left of a screen of [size].
Widget battleTestApp(Widget child, {Size size = const Size(360, 780)}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(size: size, child: child),
    ),
  );
}

/// What a widget painted, to read single pixels from.
class PaintedPicture {
  PaintedPicture(this._bytes, this._width, this._height);

  final ByteData _bytes;
  final int _width;
  final int _height;

  /// The color at ([x], [y]) in the widget's own points.
  Color at(double x, double y) {
    final column = x.round();
    final row = y.round();
    if (column < 0 || row < 0 || column >= _width || row >= _height) {
      throw RangeError('($x, $y) is outside the $_width x $_height picture');
    }
    final i = (row * _width + column) * 4;
    return Color.fromARGB(
      _bytes.getUint8(i + 3),
      _bytes.getUint8(i),
      _bytes.getUint8(i + 1),
      _bytes.getUint8(i + 2),
    );
  }
}

/// Paints [child] on [ground], [size] large, and returns the picture. The
/// child may draw outside its own box: the picture is as large as [size].
Future<PaintedPicture> paintPicture(
  WidgetTester tester,
  Widget child, {
  required Size size,
  Color ground = AppColors.card,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    battleTestApp(
      RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: ground,
          child: Stack(children: [Positioned(left: 0, top: 0, child: child)]),
        ),
      ),
      size: size,
    ),
  );
  late ByteData bytes;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
  });
  return PaintedPicture(bytes, size.width.round(), size.height.round());
}

/// Everything [painter] draws on a canvas of [size], one line per canvas
/// call, with every number in it: coordinates, radii, stroke widths, colors,
/// and for a path its bounds and its length to a tenth (a curve's length
/// may differ in later digits between machines). Two drawings with the same lines
/// are the same drawing, on any machine.
List<String> paintedOps(CustomPainter painter, Size size) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, size);
  return [
    for (final call in canvas.invocations)
      '${_name(call.invocation.memberName)}'
          '(${call.invocation.positionalArguments.map(_describe).join(', ')})',
  ];
}

String _name(Symbol symbol) {
  final text = symbol.toString();
  return text.substring('Symbol("'.length, text.length - '")'.length);
}

String _n(double value) {
  final text = value.toStringAsFixed(3);
  return text == '-0.000' ? '0.000' : text;
}

String _describe(Object? value) => switch (value) {
  final double number => _n(number),
  final Offset offset => '(${_n(offset.dx)}, ${_n(offset.dy)})',
  final Rect rect =>
    'rect(${_n(rect.left)}, ${_n(rect.top)}, ${_n(rect.right)}, '
        '${_n(rect.bottom)})',
  final RRect box =>
    'rrect(${_n(box.left)}, ${_n(box.top)}, ${_n(box.right)}, '
        '${_n(box.bottom)}, r ${_n(box.tlRadiusX)})',
  final Path path =>
    'path(${_describe(path.getBounds())}, length '
        '${path.computeMetrics().fold<double>(0, (sum, m) => sum + m.length).toStringAsFixed(1)}, '
        '${path.computeMetrics().length} parts)',
  final Paint paint =>
    paint.style == PaintingStyle.fill
        ? 'fill ${_hex(paint.color)}'
        : 'stroke ${_hex(paint.color)} ${_n(paint.strokeWidth)} '
              '${paint.strokeCap.name} ${paint.strokeJoin.name}',
  _ => '$value',
};

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// The file of reviewed drawings: for each name, the lines of [paintedOps].
const _drawingsPath = 'test/widgets/battle_art_drawings.json';

/// Checks [ops] against the reviewed drawing called [name].
///
/// The drawings were compared with the design's files element by element
/// when they were reviewed; this keeps every number of them where it was.
/// After a deliberate change to a drawing, run the test once with
/// `--dart-define=UPDATE_BATTLE_ART=true` to record it again, and review the
/// diff of the file.
void expectReviewedDrawing(String name, List<String> ops) {
  final file = File(_drawingsPath);
  final drawings = file.existsSync()
      ? (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
      : <String, dynamic>{};
  if (const bool.fromEnvironment('UPDATE_BATTLE_ART')) {
    drawings[name] = ops;
    final sorted = {
      for (final key in drawings.keys.toList()..sort()) key: drawings[key],
    };
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent(' ').convert(sorted)}\n',
    );
    return;
  }
  expect(drawings, contains(name), reason: 'no reviewed drawing "$name"');
  expect(ops.join('\n'), (drawings[name] as List<dynamic>).join('\n'));
}
