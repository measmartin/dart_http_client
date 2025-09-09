# Dart TUI HTTP Client

A minimal terminal HTTP client built with `dart_console`. It features a two-pane TUI (Request/Response), non-blocking input, pretty-printed JSON, and simple GET caching.

## Features
- Methods: GET, POST, PUT, DELETE (switch with Ctrl+←/→)
- Send request: Enter
- Switch panels: Tab
- Scroll response: ↑/↓
- Clear response: Esc
- Quit: Ctrl+C
- Pretty JSON formatting
- Event-driven repaint (smooth, reduced flicker)
- Simple in-memory GET cache with TTL and logging
- URL editing in the Request panel

## Requirements
- Dart SDK (stable)
- See `pubspec.yaml` for dependencies

## Getting Started
```bash
# From project root
dart pub get
dart run bin/tui_client.dart
```

If you’re wiring up main manually, a typical setup looks like:
```dart
import 'package:dart_console/dart_console.dart';
import 'package:tui_client/app/state/app_state.dart';
import 'package:tui_client/app/use_cases/send_http_request.dart';
import 'package:tui_client/infra/http/http_adapter.dart';
import 'package:tui_client/ui/tui_controller.dart';

Future<void> main() async {
  final console = Console();
  final appState = AppState();
  final httpClient = HttpAdapter();
  final useCase = SendHttpRequestUseCase(httpClient);

  final controller = TuiController(console, appState, useCase);
  await controller.run();
}
```

## Using the App
- In the Request panel, type or edit the URL.
- Press Ctrl+←/→ to change HTTP method.
- Press Enter to send.
- View formatted response in the Response panel; scroll with ↑/↓.
- Press Esc to clear the response buffer.
- Press Tab to switch between Request and Response panels.

## Caching, Logging, Validation
- Implemented in `SendHttpRequestUseCase`:
  - Validates method and URL.
  - Logs outgoing/returning requests.
  - GET cache with TTL (default 30s). Configure via constructor:
    ```dart
    final useCase = SendHttpRequestUseCase(
      httpClient,
      enableCache: true,
      cacheTtl: Duration(seconds: 30),
      logger: (m) => print('[TUI] $m'),
    );
    ```

## Project Structure
```
bin/
  tui_client.dart         # Entry point
lib/
  app/
    state/app_state.dart  # UI state (panels, scroll, last response)
    use_cases/send_http_request.dart
  core/models/            # AppRequest/AppResponse
  infra/http/http_adapter.dart
  ui/
    components/box.dart   # Simple bordered box component
    tui_controller.dart   # Input loop, drawing, key handling
```

## Notes
- Input is read in a separate isolate to keep the UI responsive while awaiting HTTP.
- JSON pretty-printing is automatic if content-type is JSON or body looks like JSON.

## Roadmap
- Request body and headers editing
- Persistent history
- Syntax highlighting
- Streaming/chunked display for large responses

## License
MIT (or
