class AppResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  AppResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });
}