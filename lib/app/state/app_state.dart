import '../../core/models/request.dart';
import '../../core/models/response.dart';

/// Defines the panels available in the UI.
enum ActivePanel { request, response }

class AppState {
  AppRequest currentRequest = AppRequest(method: 'GET', url: 'https://jsonplaceholder.typicode.com/todos/1');
  AppResponse? lastResponse;
  bool isLoading = false;
  String statusMessage = 'Idle';
  int responseScrollOffset = 0;
  List<String> wrappedResponseLines = [];

  /// The panel that currently has user focus.
  ActivePanel focusedPanel = ActivePanel.request;
}

