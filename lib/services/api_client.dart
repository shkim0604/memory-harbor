import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

/// Lightweight HTTP client for JSON API calls.
///
/// Centralises Content-Type, encoding, status-code checking, and
/// Firebase Auth token injection so that individual services don't
/// have to repeat the same boilerplate.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  /// Expose the current Firebase ID token for services that need custom
  /// request formatting (e.g., multipart uploads).
  Future<String?> getIdToken() async => _getIdToken();

  /// Fetch the current user's Firebase ID token.
  /// Returns `null` if the user is not signed in.
  Future<String?> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken();
    } catch (_) {
      return null;
    }
  }

  /// POST [body] as JSON to [url] and return the decoded response body.
  ///
  /// Automatically attaches `Authorization: Bearer <idToken>` when
  /// a Firebase user is signed in.
  ///
  /// Returns `null` if the request fails or the server returns a non-2xx status.
  Future<Map<String, dynamic>?> postJson(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final uri = Uri.parse(url);
      final idToken = await _getIdToken();
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      if (idToken != null && idToken.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $idToken');
      }
      request.write(jsonEncode(body));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      if (responseBody.trim().isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return null;
    }
  }

  /// POST [body] as JSON to [url] and return `true` if the server responds
  /// with 2xx.
  Future<bool> postJsonOk(String url, Map<String, dynamic> body) async {
    final result = await postJson(url, body);
    return result != null;
  }

  /// POST multipart/form-data with a single file and return decoded JSON.
  ///
  /// Returns `null` if the request fails or the server returns non-2xx.
  Future<Map<String, dynamic>?> postMultipart(
    String url, {
    required File file,
    String fileField = 'file',
    String? filename,
    String contentType = 'application/octet-stream',
    Map<String, String> fields = const {},
  }) async {
    try {
      final uri = Uri.parse(url);
      final idToken = await _getIdToken();
      final client = HttpClient();
      final request = await client.postUrl(uri);
      final boundary = '----memharbor-${DateTime.now().microsecondsSinceEpoch}';
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      if (idToken != null && idToken.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $idToken');
      }

      void writeString(String value) {
        request.add(utf8.encode(value));
      }

      for (final entry in fields.entries) {
        writeString('--$boundary\r\n');
        writeString(
          'Content-Disposition: form-data; name="${entry.key}"\r\n\r\n',
        );
        writeString('${entry.value}\r\n');
      }

      final resolvedFilename =
          filename ?? file.path.split(Platform.pathSeparator).last;
      writeString('--$boundary\r\n');
      writeString(
        'Content-Disposition: form-data; name="$fileField"; filename="$resolvedFilename"\r\n',
      );
      writeString('Content-Type: $contentType\r\n\r\n');
      request.add(await file.readAsBytes());
      writeString('\r\n');
      writeString('--$boundary--\r\n');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      if (responseBody.trim().isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return null;
    }
  }
}
