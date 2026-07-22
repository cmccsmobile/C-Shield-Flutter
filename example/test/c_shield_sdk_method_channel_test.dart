// ignore_for_file: implementation_imports
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:c_shield_sdk/src/internal/platform/c_shield_sdk_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelCShieldSdk platform;
  const channel = MethodChannel('c_shield_sdk');

  final calls = <MethodCall>[];

  setUp(() {
    platform = MethodChannelCShieldSdk();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'sdk.initialize' => null,
        'rasp.build' => 'checker-abc',
        'rasp.setConfig' => null,
        'rasp.quickCheck' => 'Secure',
        'rasp.subscribe' => null,
        'rasp.cancelSubscribe' => null,
        'rasp.dispose' => null,
        'ssl.configure' => null,
        'ssl.updatePins' => null,
        'ssl.isConfigured' => false,
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize sends sdk.initialize', () async {
    await platform.initialize();
    expect(calls.single.method, 'sdk.initialize');
  });

  test('raspBuild sends correct flags and returns checkerId', () async {
    final id = await platform.raspBuild(flags: {
      'checkDebugger': true,
      'rootDetector': false,
      'tampering': true,
      'emulator': true,
      'deviceSecurityState': true,
      'userCA': false,
    });
    expect(id, 'checker-abc');
    final call = calls.single;
    expect(call.method, 'rasp.build');
    expect((call.arguments as Map)['flags']['rootDetector'], false);
  });

  test('raspQuickCheck sends checkerId and returns result key', () async {
    final key = await platform.raspQuickCheck(checkerId: 'checker-abc');
    expect(key, 'Secure');
    final call = calls.single;
    expect(call.method, 'rasp.quickCheck');
    expect((call.arguments as Map)['checkerId'], 'checker-abc');
  });

  test('raspSubscribe sends all required args', () async {
    await platform.raspSubscribe(
      checkerId: 'checker-abc',
      subscriptionId: 'sub-uuid',
      detail: true,
      automaticallyShowPopup: false,
    );
    final call = calls.single;
    expect(call.method, 'rasp.subscribe');
    final args = call.arguments as Map;
    expect(args['checkerId'], 'checker-abc');
    expect(args['subscriptionId'], 'sub-uuid');
    expect(args['detail'], true);
    expect(args['automaticallyShowPopup'], false);
  });

  test('raspSetConfig encodes config map correctly', () async {
    await platform.raspSetConfig(
      checkerId: 'checker-abc',
      config: {
        'trustedStores': ['com.android.vending'],
        'threatActionConfig': {
          'rootDetectedAction': 'KillApp',
          'debuggerDetectedAction': 'NotifyApp',
        },
      },
    );
    final call = calls.single;
    expect(call.method, 'rasp.setConfig');
    final config = (call.arguments as Map)['config'] as Map;
    expect(config['trustedStores'], ['com.android.vending']);
    expect(config['threatActionConfig']['rootDetectedAction'], 'KillApp');
  });

  test('sslIsConfigured returns bool', () async {
    final result = await platform.sslIsConfigured();
    expect(result, false);
    expect(calls.single.method, 'ssl.isConfigured');
  });

  test('raspDispose sends checkerId', () async {
    await platform.raspDispose(checkerId: 'checker-abc');
    expect(calls.single.method, 'rasp.dispose');
    expect((calls.single.arguments as Map)['checkerId'], 'checker-abc');
  });

  test('raspCancelSubscribe sends subscriptionId', () async {
    await platform.raspCancelSubscribe(subscriptionId: 'sub-uuid');
    expect(calls.single.method, 'rasp.cancelSubscribe');
    expect((calls.single.arguments as Map)['subscriptionId'], 'sub-uuid');
  });
}
