import 'package:tui_client/core/models/request.dart';
import 'package:tui_client/core/models/response.dart';

abstract class IHttpClient {
  Future<AppResponse> send(AppRequest request);
}