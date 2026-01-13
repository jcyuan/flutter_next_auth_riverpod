import 'package:dio/dio.dart';
import 'package:flutter_next_auth_core/http/http_client.dart';
import 'package:flutter_next_auth_core/http/http_response.dart';

// simple HTTP client implementation example
// recommended to integrate directly with Dio, enum items are consistent with Dio
class SimpleDioHttpClient implements HttpClient {
  final Dio _dio = Dio();

  ResponseType? _toDioResponseType(HttpClientResponseType? responseType) {
    switch (responseType) {
      case HttpClientResponseType.json:
        return ResponseType.json;
      case HttpClientResponseType.stream:
        return ResponseType.stream;
      case HttpClientResponseType.plain:
        return ResponseType.plain;
      default:
        return null;
    }
  }

  Options? _getOptionsFromMap(String method, HttpClientOptions? options) {
    if (options != null) {
      final opts = Options(
        method: method,
        headers: options.headers,
        preserveHeaderCase: options.preserveHeaderCase,
        contentType: options.contentType,
        validateStatus: options.validateStatus as ValidateStatus?,
        followRedirects: options.followRedirects,
        maxRedirects: options.maxRedirects,
        responseType: _toDioResponseType(options.responseType),
      );

      if (options.cookies == null || options.cookies!.isEmpty) return opts;

      final oldRaw = opts.headers?['cookie'] ?? opts.headers?['Cookie'];
      final oldMap = oldRaw != null && oldRaw.isNotEmpty
          ? Map.fromEntries(
              oldRaw.split(';').map((s) {
                final kv = s.trim().split('=');
                return MapEntry(kv[0], kv.sublist(1).join('='));
              }),
            )
          : <String, String>{};

      oldMap.addAll(options.cookies!); // overwrite
      if (oldMap.isEmpty) return opts;

      final merged = oldMap.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
      opts.headers = {...(opts.headers ?? {}), 'cookie': merged};

      return opts;
    }

    return null;
  }

  @override
  Future<HttpResponse> get(String url, {HttpClientOptions? options}) async {
    try {
      final response = await _dio.get(
        url,
        options: _getOptionsFromMap('GET', options),
      );

      return HttpResponse(
        statusCode: response.statusCode,
        body: response.data,
        headers: response.headers.map,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<HttpResponse> post(
    String url, {
    HttpClientOptions? options,
    Object? body,
  }) async {
    try {
      final response = await _dio.post(
        url,
        data: body,
        options: _getOptionsFromMap('POST', options),
      );

      return HttpResponse(
        statusCode: response.statusCode,
        body: response.data,
        headers: response.headers.map,
      );
    } catch (e) {
      rethrow;
    }
  }
}
