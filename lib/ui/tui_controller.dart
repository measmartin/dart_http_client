import 'dart:io';
import 'dart:math';
import 'package:dart_console/dart_console.dart';
import 'package:ansicolor/ansicolor.dart';
import 'dart:isolate';
import 'dart:async';
import 'dart:convert'; 

import '../app/state/app_state.dart';
import '../app/use_cases/send_http_request.dart';
import 'components/box.dart';

class TuiController {
  final Console _console;
  final AppState _state;
  final SendHttpRequestUseCase _sendHttpRequest;

  TuiController(
    this._console,
    this._state,
    this._sendHttpRequest,
  );

  Isolate? _keyIsolate;
  StreamSubscription? _keySub;
  final List<_KeyEvent> _keyQueue = [];

  bool _needsRepaint = true;
  bool _cursorVisible = false;

  void _requestRepaint() => _needsRepaint = true;

  void _setCursorVisible(bool visible) {
    if (_cursorVisible == visible) return;
    _cursorVisible = visible;
    if (visible) {
      _console.showCursor();
    } else {
      _console.hideCursor();
    }
  }

  Future<void> run() async {
    _console.rawMode = true;
    _console.hideCursor();

    final port = ReceivePort();
    _keyIsolate = await Isolate.spawn(_keyReader, port.sendPort);
    _keySub = port.listen((msg) {
      final data = msg as List;
      final isControl = data[0] as bool;
      final controlIndex = data[1] as int;
      final char = (data[2] as String?) ?? '';
      final controlChar = (isControl && controlIndex >= 0)
          ? ControlCharacter.values[controlIndex]
          : ControlCharacter.enter; // unused when !isControl
      _keyQueue.add(_KeyEvent(isControl: isControl, controlChar: controlChar, char: char));
    });

    while (true) {
      bool processedInput = false;
      while (_keyQueue.isNotEmpty) {
        final key = _keyQueue.removeAt(0);
        _handleInput(key);
        processedInput = true;
      }
      if (processedInput) _needsRepaint = true;

      if (_needsRepaint) {
        _draw();
        _needsRepaint = false;
      }

      await Future.delayed(const Duration(milliseconds: 33));
    }
  }

  void _handleInput(_KeyEvent key) {
    // Global shortcuts
    if (key.isControl && key.controlChar == ControlCharacter.ctrlC) {
      _shutdown();
      return;
    }
    if ((key.isControl && key.controlChar == ControlCharacter.escape) ||
        (!key.isControl && key.char == '\x1B')) {
      _clearResponse();
      return;
    }
    if (key.isControl && key.controlChar == ControlCharacter.tab) {
      final nextIndex = (_state.focusedPanel.index + 1) % ActivePanel.values.length;
      _state.focusedPanel = ActivePanel.values[nextIndex];
      _requestRepaint();
      return;
    }
    if (key.isControl && key.controlChar == ControlCharacter.arrowLeft) {
      _cycleMethod(-1);
      return;
    }
    if (key.isControl && key.controlChar == ControlCharacter.arrowRight) {
      _cycleMethod(1);
      return;
    }

    // Delegate to focused panel
    if (_state.focusedPanel == ActivePanel.request) {
      _handleRequestInput(key);
    } else if (_state.focusedPanel == ActivePanel.response) {
      _handleResponseInput(key);
    }
  }

  // Supported HTTP methods
  static const List<String> _methods = ['GET', 'POST', 'PUT', 'DELETE'];

  void _handleRequestInput(_KeyEvent key) {
    if (key.isControl) {
      if (key.controlChar == ControlCharacter.enter) {
        _fetchData();
      } else if (key.controlChar == ControlCharacter.backspace) {
        final url = _state.currentRequest.url;
        if (url.isNotEmpty) {
          _state.currentRequest.url = url.substring(0, url.length - 1);
          _requestRepaint();
        }
      }
      return;
    }

    _state.currentRequest.url += key.char;
    _requestRepaint();
  }

  void _cycleMethod(int delta) {
    final current = _state.currentRequest.method.toUpperCase();
    final idx = _methods.indexOf(current);
    final safeIdx = idx < 0 ? 0 : idx;
    final next = (safeIdx + delta) % _methods.length;
    final nextIdx = next < 0 ? next + _methods.length : next;
    _state.currentRequest.method = _methods[nextIdx];
    _requestRepaint();
  }

  void _handleResponseInput(_KeyEvent key) {
    final contentHeight = _console.windowHeight - 7;
    final maxScroll = max(0, _state.wrappedResponseLines.length - contentHeight);

    if (key.controlChar == ControlCharacter.arrowUp) {
      if (_state.responseScrollOffset > 0) {
        _state.responseScrollOffset--;
        _requestRepaint();
      }
    } else if (key.controlChar == ControlCharacter.arrowDown) {
      if (_state.responseScrollOffset < maxScroll) {
        _state.responseScrollOffset++;
        _requestRepaint();
      }
    }
  }

  void _fetchData() {

    _state.responseScrollOffset = 0;
    _state.wrappedResponseLines.clear();
    _state.lastResponse = null;

    _state.isLoading = true;
    _state.statusMessage = 'Fetching...';
    _requestRepaint();

    _performFetch();
  }

  Future<void> _performFetch() async {
    try {
      final result = await _sendHttpRequest.execute(_state.currentRequest);

      _state.isLoading = false;
      _state.lastResponse = result;
      if (result.statusCode >= 200 && result.statusCode < 300) {
        _state.statusMessage = '${result.statusCode} OK';
      } else {
        _state.statusMessage = '${result.statusCode} Error';
      }

      _updateWrappedResponseLines();
      _requestRepaint();
    } catch (e) {
      _state.isLoading = false;
      _state.statusMessage = 'Error: $e';
      _state.lastResponse = null;
      _updateWrappedResponseLines();
      _requestRepaint();
    }
  }

  void _updateWrappedResponseLines() {
    _state.wrappedResponseLines.clear();
    var responseBody = _state.lastResponse?.body ?? '';
    if (responseBody.isEmpty) {
      _state.responseScrollOffset = 0;
      return;
    }

    final contentType = (_state.lastResponse?.headers['content-type'] ?? '').toLowerCase();
    if (contentType.contains('application/json') || _looksLikeJson(responseBody)) {
      responseBody = _prettyPrintJson(responseBody);
    }

    final contentWidth = _console.windowWidth - 4;
    final rawLines = responseBody.replaceAll('\r\n', '\n').split('\n');

    for (final line in rawLines) {
      if (line.length <= contentWidth) {
        _state.wrappedResponseLines.add(line);
      } else {
        var remaining = line;
        while (remaining.length > contentWidth) {
          _state.wrappedResponseLines.add(remaining.substring(0, contentWidth));
          remaining = remaining.substring(contentWidth);
        }
        _state.wrappedResponseLines.add(remaining);
      }
    }

    // Reset scroll to top for new content
    _state.responseScrollOffset = 0;

    _requestRepaint();
  }

  bool _looksLikeJson(String body) {
    final s = body.trimLeft();
    return s.startsWith('{') || s.startsWith('[');
  }

  String _prettyPrintJson(String body) {
    try {
      final decoded = json.decode(body);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return body; 
    }
  }

  void _draw() {
    _console.clearScreen();
    _console.resetCursorPosition();

    _drawRequestPanel();
    _drawResponsePanel();
    _drawStatusBar();

    if (_state.focusedPanel == ActivePanel.request && !_state.isLoading) {
      final urlPosition = _state.currentRequest.method.length + 5;
      _console.cursorPosition = Coordinate(1, urlPosition + _state.currentRequest.url.length);
      _setCursorVisible(true);
    } else {
      _setCursorVisible(false);
    }
  }

  void _drawRequestPanel() {
    final box = Box(
      console: _console,
      top: 0,
      left: 0,
      width: _console.windowWidth,
      height: 4,
      title: 'Request',
      hasFocus: _state.focusedPanel == ActivePanel.request,
    );
    box.draw();

    _console.cursorPosition = Coordinate(1, 2);
    _console.setBackgroundColor(ConsoleColor.brightBlue);
    _console.setForegroundColor(ConsoleColor.white);
    _console.write(' ${_state.currentRequest.method} ');
    _console.resetColorAttributes();
    _console.write(' ${_state.currentRequest.url}');
  }

  void _drawResponsePanel() {
    String title = 'Response';
    if (_state.wrappedResponseLines.isNotEmpty) {
      final contentHeight = _console.windowHeight - 7;
      final maxScroll = max(0, _state.wrappedResponseLines.length - contentHeight);
      if (maxScroll > 0) {
        final percent = ((_state.responseScrollOffset / maxScroll) * 100).toInt();
        title += ' (scrolled $percent%)';
      }
    }

    final box = Box(
      console: _console,
      top: 4,
      left: 0,
      width: _console.windowWidth,
      height: _console.windowHeight - 5,
      title: title,
      hasFocus: _state.focusedPanel == ActivePanel.response,
    );
    box.draw();

    final contentTop = 5;
    final contentLeft = 2;
    final contentHeight = _console.windowHeight - 7;

    if (_state.isLoading) {
      _console.cursorPosition = Coordinate(contentTop, contentLeft);
      _console.write('Loading...');
      return;
    }

    if (_state.wrappedResponseLines.isEmpty) {
      _console.cursorPosition = Coordinate(contentTop, contentLeft);
      _console.write('Press Enter in Request panel to fetch data...');
    } else {
      final visibleLines = _state.wrappedResponseLines
          .skip(_state.responseScrollOffset)
          .take(contentHeight);

      int lineNum = 0;
      for (final line in visibleLines) {
        _console.cursorPosition = Coordinate(contentTop + lineNum, contentLeft);
        _console.write(line);
        lineNum++;
      }
    }
  }

  void _clearResponse() {
    _state.lastResponse = null;
    _state.wrappedResponseLines.clear();
    _state.responseScrollOffset = 0;
    _state.statusMessage = 'Cleared';
    _requestRepaint();
  }

  void _drawStatusBar() {
    final pen = AnsiPen();
    _console.cursorPosition = Coordinate(_console.windowHeight - 1, 0);
    pen.black();
    pen.white(bg: true);

    String statusBarText =
        ' ${_state.statusMessage.padRight(20)} | [Enter] Send | [←/→] Method | [↑↓] Scroll | [TAB] Switch Panels | [Esc] Clear | [CTRL+C] Quit ';

    if (statusBarText.length > _console.windowWidth) {
      statusBarText = statusBarText.substring(0, _console.windowWidth);
    } else {
      statusBarText = statusBarText.padRight(_console.windowWidth);
    }

    _console.write(pen(statusBarText));
    _console.resetColorAttributes();
  }

  void _shutdown() {
    _keySub?.cancel();
    _keyIsolate?.kill(priority: Isolate.immediate);
    _console.clearScreen();
    _console.resetCursorPosition();
    _console.showCursor();
    _console.rawMode = false;
    print('Goodbye!');
    exit(0);
  }
}

// Simple, serializable key event used across isolates
class _KeyEvent {
  final bool isControl;
  final ControlCharacter controlChar;
  final String char;
  const _KeyEvent({
    required this.isControl,
    required this.controlChar,
    required this.char,
  });
}

// Top-level function run in the input isolate
void _keyReader(SendPort sendPort) {
  final console = Console();
  console.rawMode = true; // ensure single-keystroke reads
  while (true) {
    final k = console.readKey(); // blocking, safe in this isolate
    final isEscChar = !k.isControl && k.char == '\x1B';
    sendPort.send(<Object?>[
      k.isControl || isEscChar,
      k.isControl
          ? k.controlChar.index
          : (isEscChar ? ControlCharacter.escape.index : -1),
      k.char,
    ]);
  }
}

