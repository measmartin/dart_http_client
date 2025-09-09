import 'package:dart_console/dart_console.dart';
import 'package:ansicolor/ansicolor.dart';

/// A simple component to draw a bordered box in the console.
class Box {
  final Console console;
  final int top, left, width, height;
  final String title;
  final bool hasFocus;

  Box({
    required this.console,
    required this.top,
    required this.left,
    required this.width,
    required this.height,
    this.title = '',
    this.hasFocus = false,
  });

  /// Draws the box with borders and an optional title onto the console.
  void draw() {
    final pen = AnsiPen();
    if (hasFocus) {
      pen.cyan(bold: true);
    } else {
      pen.gray(level: 0.5);
    }

    // Draw corners
    console.cursorPosition = Coordinate(top, left);
    console.write(pen('┌'));
    console.cursorPosition = Coordinate(top, left + width - 1);
    console.write(pen('┐'));
    console.cursorPosition = Coordinate(top + height - 1, left);
    console.write(pen('└'));
    console.cursorPosition = Coordinate(top + height - 1, left + width - 1);
    console.write(pen('┘'));

    // Draw sides
    for (int y = top + 1; y < top + height - 1; y++) {
      console.cursorPosition = Coordinate(y, left);
      console.write(pen('│'));
      console.cursorPosition = Coordinate(y, left + width - 1);
      console.write(pen('│'));
    }

    // Draw top/bottom border and title
    final horizontalBorder = '─' * (width - 2);
    console.cursorPosition = Coordinate(top, left + 1);
    console.write(pen(horizontalBorder));

    if (title.isNotEmpty) {
      final titleString = ' $title ';
      console.cursorPosition = Coordinate(top, left + 3);
      console.write(pen(titleString));
    }
    
    console.cursorPosition = Coordinate(top + height - 1, left + 1);
    console.write(pen(horizontalBorder));
  }
}

