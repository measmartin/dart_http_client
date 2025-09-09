import 'package:tui_client/core/models/request.dart';
import 'package:tui_client/core/models/response.dart';
import 'http_client_interface.dart';

class SendHttpRequestUseCase {
  final IHttpClient _httpClient;

  // Logging, validation, and simple in-memory caching (GET only)
  final bool enableCache;
  final Duration cacheTtl;
  final void Function(String) _log;

  final Map<String, _CacheEntry> _cache = {};

  SendHttpRequestUseCase(
    this._httpClient, {
    this.enableCache = true,
    this.cacheTtl = const Duration(seconds: 30),
    void Function(String)? logger,
  }) : _log = logger ?? print;

  Future<AppResponse> execute(AppRequest request) async {
    _validate(request);

    final method = request.method.toUpperCase();
    final url = request.url;
    final cacheKey = '$method|$url';

    // Cache: GET only
    if (enableCache && method == 'GET') {
      final hit = _cache[cacheKey];
      if (hit != null && DateTime.now().isBefore(hit.expiresAt)) {
        _log('[CACHE HIT] $method $url');
        return hit.response;
      } else if (hit != null) {
        _cache.remove(cacheKey);
      }
    }

    _log('[HTTP] -> $method $url');
    final response = await _httpClient.send(request);
    _log('[HTTP] <- ${response.statusCode} for $method $url');

    if (enableCache && method == 'GET' && response.statusCode == 200) {
      _cache[cacheKey] = _CacheEntry(
        response: response,
        expiresAt: DateTime.now().add(cacheTtl),
      );
      _log('[CACHE SET] $method $url (ttl: ${cacheTtl.inSeconds}s)');
    }

    return response;
  }

  void _validate(AppRequest request) {
    final errors = <String>[];

    final method = request.method.toUpperCase();
    const allowed = {'GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD'};
    if (!allowed.contains(method)) {
      errors.add('Unsupported method: ${request.method}');
    }

    final uri = Uri.tryParse(request.url);
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      errors.add('Invalid URL: ${request.url}');
    }

    if (errors.isNotEmpty) {
      _log('[VALIDATION ERROR] ${errors.join('; ')}');
      throw ArgumentError(errors.join('; '));
    }
  }

  void clearCache() => _cache.clear();
}

class _CacheEntry {
  final AppResponse response;
  final DateTime expiresAt;
  _CacheEntry({required this.response, required this.expiresAt});
}
