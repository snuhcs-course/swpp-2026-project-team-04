import 'dart:ui';

/// Builds a [Path] from the path data of the design's drawings (the `d` of an
/// SVG path), so the fighter and the pictograms keep the design's own
/// coordinates instead of being retyped call by call.
///
/// It reads what those drawings use: move, line, horizontal and vertical
/// line, quadratic curve and close, absolute or relative, with the numbers
/// run together the way SVG allows ("l3.5 8 8 3.5-8 3.5"). Anything else is
/// an [ArgumentError].
///
/// The drawings are constants painted on every frame, so each one is read
/// once and the same [Path] is handed out after that: draw it, do not change
/// it.
Path battleArtPath(String data) => _parsed[data] ??= _parse(data);

final _parsed = <String, Path>{};

Path _parse(String data) {
  final tokens = _token.allMatches(data).map((match) => match[0]!).toList();
  if (tokens.join().length != data.replaceAll(_gaps, '').length) {
    throw ArgumentError.value(data, 'data', 'has something that is not a path');
  }
  final path = Path();
  var x = 0.0;
  var y = 0.0;
  var startX = 0.0;
  var startY = 0.0;
  var command = '';
  var i = 0;

  double number() {
    if (i >= tokens.length || _isCommand(tokens[i])) {
      throw ArgumentError.value(data, 'data', 'is missing a number');
    }
    return double.parse(tokens[i++]);
  }

  while (i < tokens.length) {
    if (_isCommand(tokens[i])) {
      command = tokens[i++];
    } else if (command == 'M') {
      // More pairs after a move are lines.
      command = 'L';
    } else if (command == 'm') {
      command = 'l';
    } else if (command.isEmpty || command == 'Z' || command == 'z') {
      throw ArgumentError.value(data, 'data', 'has a number with no command');
    }
    final relative = command == command.toLowerCase();
    final baseX = relative ? x : 0.0;
    final baseY = relative ? y : 0.0;
    switch (command.toUpperCase()) {
      case 'M':
        x = baseX + number();
        y = baseY + number();
        startX = x;
        startY = y;
        path.moveTo(x, y);
      case 'L':
        x = baseX + number();
        y = baseY + number();
        path.lineTo(x, y);
      case 'H':
        x = baseX + number();
        path.lineTo(x, y);
      case 'V':
        y = baseY + number();
        path.lineTo(x, y);
      case 'Q':
        final controlX = baseX + number();
        final controlY = baseY + number();
        x = baseX + number();
        y = baseY + number();
        path.quadraticBezierTo(controlX, controlY, x, y);
      case 'Z':
        path.close();
        x = startX;
        y = startY;
    }
  }
  return path;
}

final _token = RegExp(r'[MmLlHhVvQqZz]|-?(?:\d+\.?\d*|\.\d+)');
final _gaps = RegExp(r'[\s,]');

bool _isCommand(String token) =>
    token.length == 1 && 'MmLlHhVvQqZz'.contains(token);
