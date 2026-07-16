import 'dart:typed_data';

import 'package:flutter/services.dart';
import '../channels.dart';
import '../codec/error_codec.dart';
// import '../../api/rasp/load_app_threat_event.dart';
// import '../../api/rasp/load_app_threat_type.dart';
import 'c_shield_sdk_platform_interface.dart';

class MethodChannelCShieldSdk extends CShieldSdkPlatform {
  final _ch = const MethodChannel(CShieldChannels.methodChannel);
  
  // Native call
  Future<T> _invoke<T>(String method, [dynamic args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args) as T;
    } on PlatformException catch (e) {
      throw ErrorCodec.fromPlatformException(e);
    }
  }

  @override
  Future<void> initialize() => _invoke(CShieldChannels.sdkInitialize);

  // @override
  // Stream<LoadAppThreatEvent> threatEvents() {
  //   return const EventChannel(CShieldChannels.threatEventChannel)
  //       .receiveBroadcastStream()
  //       .map((raw) {
  //     final map = Map<String, dynamic>.from(raw as Map);
  //     return LoadAppThreatEvent(
  //       threatType: LoadAppThreatType.fromInt(map['threatType'] as int),
  //     );
  //   });
  // }

  // ── RASP ─────────────────────────────────────────────────────────────────

  @override
  Future<String> raspBuild({required Map<String, bool> flags}) =>
      _invoke<String>(CShieldChannels.raspBuild, {'flags': flags});

  @override
  Future<void> raspSetConfig({
    required String checkerId,
    required Map<String, dynamic> config,
  }) => _invoke(CShieldChannels.raspSetConfig, {
        'checkerId': checkerId,
        'config': config,
      });

  @override
  Future<String> raspQuickCheck({required String checkerId}) =>
      _invoke<String>(CShieldChannels.raspQuickCheck, {'checkerId': checkerId});

  @override
  Future<void> raspSubscribe({
    required String checkerId,
    required String subscriptionId,
    required bool detail,
    required bool automaticallyShowPopup,
  }) => _invoke(CShieldChannels.raspSubscribe, {
        'checkerId': checkerId,
        'subscriptionId': subscriptionId,
        'detail': detail,
        'automaticallyShowPopup': automaticallyShowPopup,
      });

  @override
  Future<void> raspCancelSubscribe({required String subscriptionId}) =>
      _invoke(CShieldChannels.raspCancelSubscribe, {
        'subscriptionId': subscriptionId,
      });

  @override
  Future<void> raspDispose({required String checkerId}) =>
      _invoke(CShieldChannels.raspDispose, {'checkerId': checkerId});

  // ── SSL ──────────────────────────────────────────────────────────────────

  @override
  Future<void> sslConfigure({
    required List<String> pins,
    required String hostname,
  }) => _invoke(CShieldChannels.sslConfigure, {
        'pins': pins,
        'hostname': hostname,
      });

  @override
  Future<void> sslUpdatePins({
    required List<String> pins,
    required String hostname,
  }) => _invoke(CShieldChannels.sslUpdatePins, {
        'pins': pins,
        'hostname': hostname,
      });

  @override
  Future<bool> sslIsConfigured() =>
      _invoke<bool>(CShieldChannels.sslIsConfigured);

  @override
  Future<bool> sslCheckServerTrusted({
    required String certDerBase64,
    required String host,
  }) => _invoke<bool>(CShieldChannels.sslCheckServerTrusted, {
        'certDer': certDerBase64,
        'host': host,
      });

  @override
  Future<Map<Object?, Object?>> sslHttpRequest({
    required String method,
    required String url,
    required Map<String, String> headers,
    Uint8List? body,
    int? connectTimeoutMs,
    int? receiveTimeoutMs,
    bool followRedirects = true,
  }) =>
      _invoke<Map<Object?, Object?>>(CShieldChannels.sslHttpRequest, {
        'method': method,
        'url': url,
        'headers': headers,
        'body': body,
        'connectTimeoutMs': connectTimeoutMs,
        'receiveTimeoutMs': receiveTimeoutMs,
        'followRedirects': followRedirects,
      });

  // ── AIP ──────────────────────────────────────────────────────────────────
  // Only sign/verify cross to native; normalization and payload construction
  // are done in Dart (see CShieldAIP / AIPNormalizer).

  @override
  Future<String> aipSign({required String payload}) =>
      _invoke<String>(CShieldChannels.aipSign, {'payload': payload});

  @override
  Future<void> aipVerify({
    required String payload,
    required String signature,
  }) =>
      _invoke(CShieldChannels.aipVerify, {
        'payload': payload,
        'signature': signature,
      });

}
