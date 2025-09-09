import 'package:dart_console/dart_console.dart';
import 'package:tui_client/app/state/app_state.dart';
import 'package:tui_client/app/use_cases/send_http_request.dart';
import 'package:tui_client/infra/http/http_adapter.dart';
import 'package:tui_client/ui/tui_controller.dart';

void main(List<String> arguments) {
  //(Dependency Injection)
  final console = Console();
  final appState = AppState();
  final httpClient = HttpAdapter();
  final sendHttpRequestUseCase = SendHttpRequestUseCase(httpClient);
  final tuiController = TuiController(
    console,
    appState,
    sendHttpRequestUseCase,
  );

  tuiController.run();
}