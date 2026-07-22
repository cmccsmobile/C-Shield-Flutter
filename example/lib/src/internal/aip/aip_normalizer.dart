import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Result of normalizing a request/response body for AIP signing.
///
/// Mirrors `BodySigningResult` on Android (Kotlin) and iOS (Swift).
class AIPBodySigningResult {
  /// Canonical signing form of the body (text only, sorted for multipart).
  final String normalizedString;

  /// UTF-8 byte length of [normalizedString].
  final int sizeInBytes;

  /// SHA-256 of the normalized bytes, lowercase hex.
  final String hash;

  const AIPBodySigningResult({
    required this.normalizedString,
    required this.sizeInBytes,
    required this.hash,
  });

  Map<String, dynamic> toMap() => {
        'normalizedString': normalizedString,
        'sizeInBytes': sizeInBytes,
        'hash': hash,
      };
}

/// Pure-Dart port of the native AIP body normalization
/// (`AIPCore.normalizeBodyForSigning` + `AIPUtils` on Android/iOS).
///
/// The native SDKs need a full `Request`/`URLRequest` only because their
/// normalize entry point takes one; the URL is irrelevant to the result.
/// Doing it in Dart removes that round-trip (and the fabricated placeholder
/// URL it required) while producing byte-identical output to native, so the
/// signed/verified payload hash matches the server.
class AIPNormalizer {
  AIPNormalizer._();

  /// Normalizes [body] for the given [contentType] and returns its canonical
  /// string, byte size and SHA-256 hash.
  ///
  /// - `multipart/form-data`: text fields only (files skipped), sorted by key,
  ///   JSON-encoded without HTML escaping.
  /// - everything else: raw bytes decoded as UTF-8.
  static AIPBodySigningResult normalizeBodyForSigning({
    required Uint8List body,
    required String contentType,
  }) {
    if (body.isEmpty) {
      return AIPBodySigningResult(
        normalizedString: '',
        sizeInBytes: 0,
        hash: sha256Hex(const <int>[]),
      );
    }

    final boundary = _multipartBoundary(contentType);
    final normalizedString = boundary != null
        ? normalizeMultipart(body, boundary)
        : normalizeRegularBody(body);

    // Hash the re-encoded normalized string, exactly like native
    // (`Data(normalizedString.utf8)` / `normalizedString.toByteArray(UTF_8)`).
    final bytes = utf8.encode(normalizedString);
    return AIPBodySigningResult(
      normalizedString: normalizedString,
      sizeInBytes: bytes.length,
      hash: sha256Hex(bytes),
    );
  }

  /// Reads the body as a UTF-8 string. Mirrors `normalizeRegularBody`.
  static String normalizeRegularBody(Uint8List body) =>
      utf8.decode(body, allowMalformed: true);

  /// Normalizes a `multipart/form-data` body: skips file parts, keeps text
  /// fields, sorts by key and JSON-encodes them.
  ///
  /// Ported byte-for-byte from iOS `AIPUtils.normalizeMultipart`: parses on raw
  /// bytes so binary file parts are never decoded, only text headers/values are.
  static String normalizeMultipart(Uint8List body, String boundary) {
    final map = <String, String>{};

    final delimiter = utf8.encode('--$boundary');
    const crlf = [0x0D, 0x0A]; // \r\n
    const crlfcrlf = [0x0D, 0x0A, 0x0D, 0x0A]; // \r\n\r\n
    const dashDash = [0x2D, 0x2D]; // --

    // Locate every boundary occurrence by byte search (no full-body decode).
    final boundaries = <({int start, int end})>[];
    var cursor = 0;
    while (true) {
      final idx = _indexOf(body, delimiter, cursor);
      if (idx < 0) break;
      boundaries.add((start: idx, end: idx + delimiter.length));
      cursor = idx + delimiter.length;
    }

    for (var i = 0; i < boundaries.length; i++) {
      final start = boundaries[i].end;
      final end =
          (i + 1 < boundaries.length) ? boundaries[i + 1].start : body.length;
      if (start >= end) continue;
      var part = Uint8List.sublistView(body, start, end);

      // Close-delimiter ("--\r\n") / epilogue after the last boundary → skip.
      if (_startsWith(part, dashDash)) continue;
      // Each part begins with the CRLF that ended the boundary line → trim it.
      if (_startsWith(part, crlf)) {
        part = Uint8List.sublistView(part, crlf.length);
      }

      // Split header / value at the first CRLF-CRLF.
      final sep = _indexOf(part, crlfcrlf, 0);
      if (sep < 0) continue;
      final headerData = Uint8List.sublistView(part, 0, sep);
      var valueData = Uint8List.sublistView(part, sep + crlfcrlf.length);
      // Drop the trailing CRLF that precedes the next boundary.
      if (valueData.length >= crlf.length &&
          valueData[valueData.length - 2] == crlf[0] &&
          valueData[valueData.length - 1] == crlf[1]) {
        valueData = Uint8List.sublistView(valueData, 0, valueData.length - crlf.length);
      }

      // Headers are always ASCII → safe to decode strictly.
      final headersPart = _tryUtf8Strict(headerData);
      if (headersPart == null) continue;

      String? contentType;
      String? name;
      for (final header in headersPart.split('\r\n')) {
        final lower = header.toLowerCase();
        if (lower.startsWith('content-type:')) {
          contentType = header.substring(header.indexOf(':') + 1).trim();
        } else if (lower.startsWith('content-disposition:')) {
          const marker = 'name="';
          final nameStart = header.indexOf(marker);
          if (nameStart >= 0) {
            final after = header.substring(nameStart + marker.length);
            final endQuote = after.indexOf('"');
            if (endQuote >= 0) name = after.substring(0, endQuote);
          }
        }
      }

      // Skip non-text parts (files): same rule as Android/iOS —
      // skip when content-type is present and does not start with "text".
      if (contentType != null && !contentType.toLowerCase().startsWith('text')) {
        continue;
      }
      if (name == null || name.isEmpty) continue;

      // Only decode the value of a TEXT field (never touches binary file bytes).
      final value = _tryUtf8Strict(valueData);
      if (value == null) continue;

      map[name] = value;
    }

    // Sort keys and JSON-encode. Dart's jsonEncode does not HTML-escape
    // (`< > & ' =`), matching server JSON.stringify, iOS JSONSerialization and
    // Android Gson with disableHtmlEscaping().
    final sortedKeys = map.keys.toList()..sort();
    final sorted = <String, String>{for (final k in sortedKeys) k: map[k]!};
    return jsonEncode(sorted);
  }

  /// Canonical signing bytes for a set of multipart text [fields]
  /// (sorted by key, JSON-encoded, no HTML escaping).
  ///
  /// Use this when the HTTP layer exposes already-parsed form fields (Dio
  /// [FormData], `http` `MultipartRequest`) instead of raw multipart bytes —
  /// the file parts are simply not included, matching how the server (and
  /// [normalizeMultipart]) only hash text fields.
  static Uint8List normalizeFields(Map<String, String> fields) {
    final sortedKeys = fields.keys.toList()..sort();
    final sorted = <String, String>{for (final k in sortedKeys) k: fields[k]!};
    return Uint8List.fromList(utf8.encode(jsonEncode(sorted)));
  }

  /// SHA-256 of [bytes] as lowercase hex. Mirrors `toSHA256()` on native.
  static String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Extracts the boundary from a `multipart/form-data` content type, or
  /// `null` if [contentType] is not multipart.
  static String? _multipartBoundary(String contentType) {
    final lower = contentType.toLowerCase();
    if (!lower.contains('multipart/form-data')) return null;

    const marker = 'boundary=';
    final idx = lower.indexOf(marker);
    if (idx < 0) return null;

    var boundary = contentType.substring(idx + marker.length).trim();
    // Strip any trailing parameters and optional surrounding quotes.
    final semi = boundary.indexOf(';');
    if (semi >= 0) boundary = boundary.substring(0, semi).trim();
    if (boundary.length >= 2 && boundary.startsWith('"') && boundary.endsWith('"')) {
      boundary = boundary.substring(1, boundary.length - 1);
    }
    return boundary.isEmpty ? null : boundary;
  }

  static String? _tryUtf8Strict(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return null;
    }
  }

  static int _indexOf(List<int> haystack, List<int> needle, int start) {
    if (needle.isEmpty) return start;
    final last = haystack.length - needle.length;
    for (var i = start; i <= last; i++) {
      var match = true;
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  static bool _startsWith(List<int> data, List<int> prefix) {
    if (data.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (data[i] != prefix[i]) return false;
    }
    return true;
  }
}
