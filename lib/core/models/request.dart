class AppRequest {
  String url;
  String method;
  Map<String, String> headers;
  String? body;

  AppRequest({
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    this.body,
  });
}