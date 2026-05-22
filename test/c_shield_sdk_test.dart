// ignore_for_file: implementation_imports
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:c_shield_sdk/c_shield_sdk.dart';
import 'package:c_shield_sdk/src/internal/platform/c_shield_sdk_platform_interface.dart';
import 'package:c_shield_sdk/src/internal/platform/c_shield_sdk_method_channel.dart';

class _MockPlatform with MockPlatformInterfaceMixin implements CShieldSdkPlatform {
  final _calls = <String>[];
  List<String> get calls => _calls;

  @override
  Future<void> initialize() async => _calls.add('initialize');

  @override
  Future<String> raspBuild({required Map<String, bool> flags}) async {
    _calls.add('raspBuild');
    return 'mock-checker-id';
  }

  @override
  Future<void> raspSetConfig({
    required String checkerId,
    required Map<String, dynamic> config,
  }) async => _calls.add('raspSetConfig');

  @override
  Future<String> raspQuickCheck({required String checkerId}) async {
    _calls.add('raspQuickCheck');
    return 'Secure';
  }

  @override
  Future<void> raspSubscribe({
    required String checkerId,
    required String subscriptionId,
    required bool detail,
    required bool automaticallyShowPopup,
  }) async => _calls.add('raspSubscribe');

  @override
  Future<void> raspCancelSubscribe({required String subscriptionId}) async =>
      _calls.add('raspCancelSubscribe');

  @override
  Future<void> raspDispose({required String checkerId}) async =>
      _calls.add('raspDispose');

  @override
  Future<void> sslConfigure({required List<String> pins, required String hostname}) async {}

  @override
  Future<void> sslUpdatePins({required List<String> pins, required String hostname}) async {}

  @override
  Future<bool> sslIsConfigured() async => false;

  @override
  Future<Map<String, String>> aipSignRequest({
    required String method,
    required String path,
    required Map<String, String> headers,
    required Uint8List body,
    required String contentType,
  }) async => {};

  @override
  Future<void> aipVerifyResponse({
    required int statusCode,
    required String path,
    required Map<String, String> headers,
    required Uint8List body,
  }) async {}

  @override
  Future<Map<String, dynamic>> aipNormalizeBody({
    required String contentType,
    required Uint8List body,
    List<Map<String, String>>? multipartFields,
  }) async => {};
  
  @override
  Future<String> aipSign({required String payload}) {
    // TODO: implement aipSign
    throw UnimplementedError();
  }
  
  @override
  Future<void> aipVerify({required String payload, required String signature}) {
    // TODO: implement aipVerify
    throw UnimplementedError();
  }
  
  @override
  Future<bool> sslCheckServerTrusted({required String certDerBase64, required String host}) {
    // TODO: implement sslCheckServerTrusted
    throw UnimplementedError();
  }
  
  @override
  Stream<LoadAppThreatEvent> threatEvents() {
    // TODO: implement threatEvents
    throw UnimplementedError();
  }

}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default platform instance is MethodChannelCShieldSdk', () {
    expect(CShieldSdkPlatform.instance, isA<MethodChannelCShieldSdk>());
  });

  group('CShieldSdk with mock platform', () {
    late _MockPlatform mock;

    setUp(() {
      mock = _MockPlatform();
      CShieldSdkPlatform.instance = mock;
    });

    tearDown(() {
      CShieldSdkPlatform.instance = MethodChannelCShieldSdk();
    });

    test('initialize calls platform', () async {
      await CShieldSdk.initialize();
      expect(mock.calls, contains('initialize'));
    });

    test('RASPChecker builds lazily on first quickCheck', () async {
      final checker = RASPChecker.builder();
      final result = await checker.quickCheck();
      expect(mock.calls, containsAllInOrder(['raspBuild', 'raspQuickCheck']));
      expect(result, RASPResult.secure);
    });

    test('RASPChecker reuses checkerId without rebuilding', () async {
      final checker = RASPChecker.builder();
      await checker.quickCheck();
      await checker.quickCheck();
      // raspBuild called once, quickCheck twice
      expect(mock.calls.where((c) => c == 'raspBuild').length, 1);
      expect(mock.calls.where((c) => c == 'raspQuickCheck').length, 2);
    });

    test('dispose calls platform dispose', () async {
      final checker = RASPChecker.builder();
      await checker.quickCheck(); // trigger build
      await checker.dispose();
      expect(mock.calls, contains('raspDispose'));
    });

    test('quickCheck after dispose throws CShieldException', () async {
      final checker = RASPChecker.builder();
      await checker.quickCheck();
      await checker.dispose();
      expect(
        () => checker.quickCheck(),
        throwsA(isA<CShieldException>().having(
          (e) => e.code,
          'code',
          CShieldErrorCode.raspCheckerDisposed,
        )),
      );
    });

    test('setRASPConfig calls platform setConfig', () async {
      final checker = RASPChecker.builder();
      await checker.setRASPConfig(const RASPConfig(
        threatActionConfig: ThreatActionConfig(
          rootDetectedAction: ThreatDetectedAction.killApp,
        ),
      ));
      expect(mock.calls, containsAllInOrder(['raspBuild', 'raspSetConfig']));
    });

    test('CShieldSSL.isConfigured returns false from mock', () async {
      expect(await CShieldSSL.isConfigured(), false);
    });
  });
}
