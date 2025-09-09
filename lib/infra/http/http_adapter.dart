import 'dart:io'; 
import 'package:http/http.dart' as http;
import 'package:tui_client/app/use_cases/http_client_interface.dart';
import 'package:tui_client/core/models/request.dart';
import 'package:tui_client/core/models/response.dart';

class HttpAdapter implements IHttpClient {
  @override
  Future<AppResponse> send(AppRequest request) async {
    late http.Response response;
    final uri = Uri.parse(request.url);

    try {
      switch (request.method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri);
          break;
        case 'POST':
          response = await http.post(uri);
          break;
        case 'PUT':
          response = await http.put(uri);
          break;
        case 'DELETE':
          response = await http.delete(uri);
          break;
        default:
          throw UnsupportedError('Unsupported HTTP method: ${request.method}');
      }
    } on SocketException catch (e) {
      throw Exception('Connection terminated or network error: ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception('HTTP client error: ${e.message}');
    } on HandshakeException catch (e) {
      throw Exception('SSL handshake failed: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error during request: $e');
    }

    return AppResponse(
      statusCode: response.statusCode,
      body: response.body,
      headers: response.headers,
    );
  }
}
