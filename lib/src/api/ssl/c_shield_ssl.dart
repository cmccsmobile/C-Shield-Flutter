import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:http/io_client.dart';

import '../../api/exceptions/c_shield_exception.dart';
import '../../internal/platform/c_shield_sdk_platform_interface.dart';

/// Public API for Certificate Pinning.
///
/// Android equivalent: getSSLSocketFactory() / getTrustManager() / getSSLContext()
/// iOS equivalent: urlSession() / trustManager()
/// Flutter equivalent: createHttpClient() / createIOClient() / verifyPin()
///
/// ## Quick integration guide
///
/// ### `http` package
/// ```dart
/// await CShieldSSL.configure(pins: ['sha256/...'], hostname: 'api.example.com');
/// final client = CShieldSSL.createIOClient(); // drop-in for http.Client()
/// ```
///
/// ### Dio
/// ```dart
/// import 'package:dio/io.dart';
/// await CShieldSSL.configure(pins: ['sha256/...'], hostname: 'api.example.com');
/// dio.httpClientAdapter = IOHttpClientAdapter(
///   createHttpClient: CShieldSSL.createHttpClient,
/// );
/// ```
///
/// ### Verify a certificate independently (full CA + SPKI, native-backed)
/// ```dart
/// final trusted = await CShieldSSL.verifyPin(certDerBase64: base64Cert, host: 'api.example.com');
/// ```
class CShieldSSL {
  CShieldSSL._();

  static List<String>? _pins;
  static String? _hostname;

  /// Configures certificate pinning.
  ///
  /// [pins] — pin list in format `"sha256/<base64>"`. Recommend at least 2 (primary + backup).
  /// [hostname] — domain to pin (e.g. `"api.example.com"`).
  ///
  /// Throws [ArgumentError] if [pins] is empty, [hostname] is blank, or any
  /// pin does not start with `"sha256/"`.
  static Future<void> configure({
    required List<String> pins,
    required String hostname,
  }) async {
    if (pins.isEmpty) {
      throw ArgumentError.value(pins, 'pins', 'Must contain at least one pin.');
    }
    if (hostname.trim().isEmpty) {
      throw ArgumentError.value(hostname, 'hostname', 'Must not be blank.');
    }
    for (final pin in pins) {
      if (!pin.startsWith('sha256/')) {
        throw ArgumentError.value(pin, 'pins', 'Each pin must be in format "sha256/<base64>". Got: "$pin"');
      }
    }
    await CShieldSdkPlatform.instance.sslConfigure(pins: pins, hostname: hostname);
    _pins = List.unmodifiable(pins);
    _hostname = hostname;
  }

  /// Updates pins (e.g. after certificate rotation).
  static Future<void> updatePins({
    required List<String> pins,
    required String hostname,
  }) => configure(pins: pins, hostname: hostname);

  /// Returns true if pinning has been configured.
  static Future<bool> isConfigured() =>
      CShieldSdkPlatform.instance.sslIsConfigured();

  // ── createHttpClient ────────────────────────────────────────────────────

  /// Returns an [HttpClient] configured with SPKI certificate pinning.
  ///
  /// Flutter equivalent of Android's `getSSLSocketFactory()` / iOS's `urlSession()`.
  ///
  /// Uses the system [SecurityContext] (with trusted roots) so that normal
  /// CA chain validation runs first. [HttpClient.badCertificateCallback] then
  /// acts as a secondary gate: if a certificate fails system validation (e.g.
  /// self-signed or internal CA), the SPKI pin is checked as a fallback.
  ///
  /// On Android, using `SecurityContext(withTrustedRoots: false)` causes
  /// BoringSSL to abort the TLS handshake at the C layer with
  /// `CERTIFICATE_VERIFY_FAILED` before Dart's callback can fire. Keeping
  /// system roots avoids this while still rejecting any cert whose SPKI pin
  /// does not match (for non-CA-verified certs).
  ///
  /// For additional SPKI verification on CA-signed certs, call [verifyPin]
  /// after the connection is established.
  ///
  /// Throws [StateError] if [configure] has not been called.
  static HttpClient createHttpClient() {
    final pins = _pins;
    final hostname = _hostname;
    if (pins == null || hostname == null) {
      throw StateError(
        'CShieldSSL has not been configured. Call CShieldSSL.configure() first.',
      );
    }

    final client = HttpClient();

    // Called only when the cert fails normal CA validation (self-signed,
    // unknown CA, hostname mismatch, etc.). Returns true iff the SPKI pin
    // matches, allowing pinned non-standard certs through.
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      if (host != hostname) return false;
      final computed = _computeSpkiPin(cert.der);
      return computed != null && pins.contains(computed);
    };

    return client;
  }

  /// Returns an [IOClient] (from the `http` package) wrapping a pinned [HttpClient].
  ///
  /// Drop-in replacement for `http.Client()` — customers using the `http`
  /// package do **not** need to rewrite any request code:
  /// ```dart
  /// // Setup (once, e.g. in main()):
  /// await CShieldSSL.configure(pins: [...], hostname: 'api.example.com');
  /// final client = CShieldSSL.createIOClient();
  ///
  /// // Usage — identical to http.Client():
  /// final response = await client.get(Uri.parse('https://api.example.com/data'));
  /// ```
  ///
  /// Throws [StateError] if [configure] has not been called.
  static IOClient createIOClient() => IOClient(createHttpClient());

  // ── createDioAdapter ───────────────────────────────────────────────────

  /// Returns a Dio [HttpClientAdapter] that enforces SPKI certificate pinning
  /// for **every** connection — including CA-signed certs — by checking the
  /// peer certificate after the TLS handshake completes.
  ///
  /// This is the recommended adapter for Dio users because it closes the gap
  /// that [createHttpClient] has: `badCertificateCallback` only fires for
  /// invalid/untrusted certificates, so a CA-signed cert (e.g. Let's Encrypt)
  /// would pass through without a pin check. Here, `HttpClientResponse.certificate`
  /// is inspected post-handshake, matching Android (`CShieldTrustManager`) and
  /// iOS (`URLSession` delegate) behaviour.
  ///
  /// ```dart
  /// import 'package:c_shield_sdk/c_shield_sdk.dart';
  /// import 'package:dio/dio.dart';
  ///
  /// await CShieldSSL.configure(pins: ['sha256/...'], hostname: 'api.example.com');
  ///
  /// final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  /// dio.httpClientAdapter = CShieldSSL.createDioAdapter();
  /// dio.interceptors.add(const CShieldDioInterceptor());
  /// ```
  ///
  /// For the `http` package, use [createIOClient] instead.
  ///
  /// Throws [StateError] if [configure] has not been called.
  static HttpClientAdapter createDioAdapter() {
    final pins = _pins;
    final hostname = _hostname;
    if (pins == null || hostname == null) {
      throw StateError(
        'CShieldSSL has not been configured. Call CShieldSSL.configure() first.',
      );
    }
    return _CShieldDioAdapter(pins: pins, hostname: hostname);
  }

  // ── verifyPin ──────────────────────────────────────────────────────────

  /// Verifies a certificate against the configured pins using the native
  /// trust manager (system CA validation + SPKI pin check).
  ///
  /// Flutter equivalent of Android's `CShieldTrustManager.checkServerTrusted()`
  /// and iOS's `SecTrustEvaluateWithError` + SPKI check.
  ///
  /// [certDerBase64] — base64-encoded DER certificate (leaf cert from the server).
  /// [host] — hostname of the server being verified.
  ///
  /// Returns `true` if the certificate passes both system CA validation and
  /// SPKI pin verification.
  ///
  /// Typical usage with Dio or any HTTP interceptor:
  /// ```dart
  /// final certBase64 = base64.encode(peerCertificateDerBytes);
  /// final trusted = await CShieldSSL.verifyPin(certDerBase64: certBase64, host: 'api.example.com');
  /// if (!trusted) throw Exception('Certificate pin mismatch');
  /// ```
  static Future<bool> verifyPin({
    required String certDerBase64,
    required String host,
  }) =>
      CShieldSdkPlatform.instance.sslCheckServerTrusted(
        certDerBase64: certDerBase64,
        host: host,
      );

  // ── SPKI computation (Dart-level) ───────────────────────────────────────

  static String? _computeSpkiPin(Uint8List derCert) {
    final spki = _extractSpki(derCert);
    if (spki == null) return null;
    final digest = crypto.sha256.convert(spki);
    return 'sha256/${base64.encode(digest.bytes)}';
  }

  /// Extracts the SubjectPublicKeyInfo (SPKI) SEQUENCE from a DER-encoded X.509 cert.
  ///
  /// X.509 DER structure navigated:
  ///   Certificate SEQUENCE
  ///     TBSCertificate SEQUENCE
  ///       version [0] EXPLICIT (optional)
  ///       serialNumber INTEGER
  ///       signature AlgorithmIdentifier
  ///       issuer Name
  ///       validity Validity
  ///       subject Name
  ///       subjectPublicKeyInfo SubjectPublicKeyInfo  ← extracted
  static Uint8List? _extractSpki(Uint8List der) {
    try {
      var i = 0;

      // Certificate SEQUENCE — enter content
      if (der[i++] != 0x30) return null;
      final (cContent, _) = _readLength(der, i);
      i = cContent;

      // TBSCertificate SEQUENCE — enter content
      if (der[i++] != 0x30) return null;
      final (tbsContent, _) = _readLength(der, i);
      i = tbsContent;

      // version [0] EXPLICIT — skip if present
      if (der[i] == 0xA0) i = _skipTlv(der, i);

      // serialNumber, signature, issuer, validity, subject — skip
      i = _skipTlv(der, i);
      i = _skipTlv(der, i);
      i = _skipTlv(der, i);
      i = _skipTlv(der, i);
      i = _skipTlv(der, i);

      // subjectPublicKeyInfo SEQUENCE — capture bytes
      final spkiStart = i;
      final spkiEnd = _skipTlv(der, i);
      return der.sublist(spkiStart, spkiEnd);
    } catch (_) {
      return null;
    }
  }

  /// Given offset [i] pointing at a DER length field, returns
  /// `(contentOffset, length)` where `contentOffset` is the first byte of content.
  static (int, int) _readLength(Uint8List data, int i) {
    final b = data[i];
    if (b < 0x80) return (i + 1, b);
    final n = b & 0x7F;
    var len = 0;
    for (var j = 1; j <= n; j++) { len = (len << 8) | data[i + j]; }
    return (i + 1 + n, len);
  }

  /// Given offset [i] pointing at a DER TLV tag byte, returns the offset
  /// of the next TLV (i.e. skips this entire tag-length-value).
  static int _skipTlv(Uint8List data, int i) {
    i++; // tag
    final (contentOffset, length) = _readLength(data, i);
    return contentOffset + length;
  }
}

// ── _CShieldDioAdapter ─────────────────────────────────────────────────────

/// Dio [HttpClientAdapter] that verifies the SPKI pin of the peer certificate
/// **after** every successful TLS handshake via [HttpClientResponse.certificate].
///
/// This covers CA-signed certificates, which [HttpClient.badCertificateCallback]
/// cannot intercept (because the callback only fires for invalid/untrusted certs).
/// The behaviour mirrors Android's [CShieldTrustManager] and iOS's URLSession
/// delegate, both of which run on every connection regardless of CA trust status.
class _CShieldDioAdapter implements HttpClientAdapter {
  _CShieldDioAdapter({required List<String> pins, required String hostname})
      : _pins = pins,
        _hostname = hostname;

  final List<String> _pins;
  final String _hostname;
  HttpClient? _httpClient;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    final client = _getOrCreateClient();
    HttpClientRequest? req;
    try {
      req = await client.openUrl(options.method, options.uri);
      req.followRedirects = options.followRedirects;
      req.maxRedirects = options.maxRedirects;

      options.headers.forEach((key, value) {
        if (value != null) req!.headers.set(key, '$value');
      });

      // Abort the request if Dio cancels it (e.g. via CancelToken).
      cancelFuture?.then(
        (_) => req?.abort(),
        onError: (_) => req?.abort(),
      );

      if (requestStream != null) {
        await req.addStream(requestStream);
      }

      final response = await req.close();

      // ── Post-handshake SPKI pin verification ─────────────────────────────
      // HttpClientResponse.certificate is the server leaf cert, available for
      // all HTTPS connections after a successful handshake — CA-signed or not.
      if (options.uri.isScheme('https') && options.uri.host == _hostname) {
        final cert = response.certificate;
        if (cert != null) {
          final computed = CShieldSSL._computeSpkiPin(cert.der);
          if (computed == null || !_pins.contains(computed)) {
            req.abort();
            throw CShieldException(
              CShieldErrorCode.sslPinMismatch,
              'Certificate SPKI pin mismatch for host: $_hostname',
            );
          }
        }
      }

      final headers = <String, List<String>>{};
      response.headers.forEach((key, values) => headers[key] = values);

      return ResponseBody(
        response.map(Uint8List.fromList),
        response.statusCode,
        headers: headers,
        isRedirect: response.isRedirect,
        statusMessage: response.reasonPhrase,
      );
    } on CShieldException {
      rethrow;
    } catch (e) {
      req?.abort();
      rethrow;
    }
  }

  HttpClient _getOrCreateClient() {
    return _httpClient ??= HttpClient()
      // badCertificateCallback handles self-signed / unknown-CA certs:
      // allows them through only if the SPKI pin matches.
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        if (host != _hostname) return false;
        final computed = CShieldSSL._computeSpkiPin(cert.der);
        return computed != null && _pins.contains(computed);
      };
  }

  @override
  void close({bool force = false}) {
    _httpClient?.close(force: force);
    _httpClient = null;
  }
}
