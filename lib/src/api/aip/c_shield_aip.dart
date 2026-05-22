import 'dart:typed_data';

import '../../internal/platform/c_shield_sdk_platform_interface.dart';

/// Low-level AIP (API Integrity Protection) API.
///
/// ## Payload format (same on Android, iOS, Flutter)
///
/// **Request:** `{METHOD}.{path}.{unixTimestamp}.{bodyHash}`
/// Example: `POST./api/v1/login.1716000000.a3f8c2...`
///
/// **Response:** `{statusCode}.{path}.{unixTimestamp}.{bodyHash}`
/// Example: `200./api/v1/login.1716000000.b7e1d4...`
///
/// - `path` is the URL path only, without query string.
/// - `bodyHash` is SHA-256 of the normalized body (lowercase hex).
/// - Timestamp window: ±30 seconds. Requests/responses outside this window fail.
///
/// ## Body normalization
///
/// For `multipart/form-data` (file uploads):
/// - **File parts are skipped** — only text fields are signed.
/// - Text fields are sorted by key and JSON-encoded (same as native).
///
/// For all other content types: body bytes are signed as-is.
///
/// ## Two usage modes
///
/// **Mode 1 — Automatic (recommended):** Use [CShieldInterceptor] (`http`)
/// or [CShieldDioInterceptor] (Dio). Sign/verify happens transparently.
///
/// **Mode 2 — Manual:** Use [signRequest]/[verifyResponse] or
/// [sign]/[verify] for full control.
class CShieldAIP {
  CShieldAIP._();

  // ── Mode 2a: Standalone — caller constructs payload manually ─────────────

  /// Signs a raw [payload] string and returns the signature.
  ///
  /// You are responsible for building the payload:
  /// ```dart
  /// final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  /// final norm = await CShieldAIP.normalizeBody(body: bytes, contentType: 'application/json');
  /// final payload = 'POST./api/v1/login.$ts.${norm['hash']}';
  /// final sig = await CShieldAIP.sign(payload);
  /// // Attach to request: {'cs-timestamp': '$ts', 'cs-signature': sig}
  /// ```
  static Future<String> sign(String payload) => CShieldSdkPlatform.instance.aipSign(payload: payload);

  /// Verifies [signature] against [payload].
  ///
  /// Throws [CShieldException] with [CShieldErrorCode.aipInvalidSignature] or
  /// [CShieldErrorCode.aipTimestampExpired] on failure.
  static Future<void> verify({required String payload, required String signature}) =>
      CShieldSdkPlatform.instance.aipVerify(payload: payload, signature: signature);

  /// Normalizes [body] bytes to their canonical signing form.
  ///
  /// Returns `{'normalizedString': String, 'sizeInBytes': int, 'hash': String}`.
  /// - For `multipart/form-data`: text fields only, sorted, JSON-encoded.
  /// - For other types: raw bytes as UTF-8 string.
  ///
  /// Pass the `hash` value when building a payload for [sign].
  static Future<Map<String, dynamic>> normalizeBody({
    required Uint8List body,
    String contentType = 'application/json',
  }) => CShieldSdkPlatform.instance.aipNormalizeBody(contentType: contentType, body: body);

  // ── Mode 2b: Interceptor helpers — SDK constructs payload automatically ───

  /// Signs an outgoing request and returns `{'cs-timestamp': ..., 'cs-signature': ...}`.
  ///
  /// [path] must be the URL path only (no query string).
  /// [body] should be normalized multipart bytes for file-upload requests
  /// (see [normalizeBody]) or raw JSON/text bytes for regular requests.
  static Future<Map<String, String>> signRequest({
    required String method,
    required String path,
    required Uint8List body,
    String contentType = 'application/json',
  }) => CShieldSdkPlatform.instance.aipSignRequest(
        method: method,
        path: path,
        headers: const {},
        body: body,
        contentType: contentType,
      );

  /// Verifies the AIP signature on an incoming response.
  ///
  /// [headers] must contain `cs-timestamp` and `cs-signature`.
  /// [body] must be the raw response bytes (not decoded).
  /// Throws [CShieldException] on failure.
  static Future<void> verifyResponse({
    required int statusCode,
    required String path,
    required Map<String, String> headers,
    required Uint8List body,
  }) => CShieldSdkPlatform.instance.aipVerifyResponse(
        statusCode: statusCode,
        path: path,
        headers: headers,
        body: body,
      );
}
