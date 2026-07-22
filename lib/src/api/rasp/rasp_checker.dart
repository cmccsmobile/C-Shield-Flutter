import 'dart:async';
import 'dart:math';
import '../../internal/codec/rasp_codec.dart';
import '../../internal/platform/c_shield_sdk_platform_interface.dart';
import '../../internal/rasp_event_bus.dart';
import '../exceptions/c_shield_exception.dart';
import 'rasp_config.dart';
import 'rasp_extended_result.dart';
import 'rasp_result.dart';

class RASPChecker {
  final bool checkDebugger;
  final bool rootDetector;
  final bool tampering;
  final bool emulator;
  final bool deviceSecurityState;

  String? _checkerId;
  bool _disposed = false;

  RASPChecker.builder({this.checkDebugger = true, this.rootDetector = true, this.tampering = true, this.emulator = true, this.deviceSecurityState = true});

  Future<String> _ensureBuilt() async {
    _assertNotDisposed();
    return _checkerId ??= await CShieldSdkPlatform.instance.raspBuild(
      flags: {'checkDebugger': checkDebugger, 'rootDetector': rootDetector, 'tampering': tampering, 'emulator': emulator, 'deviceSecurityState': deviceSecurityState},
    );
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw const CShieldException(CShieldErrorCode.raspCheckerDisposed, 'RASPChecker has been disposed');
    }
  }

  Future<void> setRASPConfig(RASPConfig config) async {
    final id = await _ensureBuilt();
    await CShieldSdkPlatform.instance.raspSetConfig(checkerId: id, config: RaspCodec.configToMap(config));
  }

  Future<RASPResult> quickCheck() async {
    final id = await _ensureBuilt();
    final key = await CShieldSdkPlatform.instance.raspQuickCheck(checkerId: id);
    return RaspCodec.resultFromKey(key);
  }

  // Start the RASP event stream. Subscribes to the EventChannel BEFORE calling
  // native so no events can be missed between subscribe and listen.
  Stream<RASPExtendedResult> subscribe({bool detail = false, bool automaticallyShowPopup = true}) async* {
    final id = await _ensureBuilt();

    // Generate ID on Dart side so the bus can start filtering before native fires.
    final subscriptionId = _generateId();
    final events = RaspEventBus.instance.subscribeEvents(subscriptionId);

    try {
      await CShieldSdkPlatform.instance.raspSubscribe(checkerId: id, subscriptionId: subscriptionId, detail: detail, automaticallyShowPopup: automaticallyShowPopup);
      yield* events;
    } finally {
      await CShieldSdkPlatform.instance.raspCancelSubscribe(subscriptionId: subscriptionId).catchError((_) {});
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_checkerId != null) {
      await CShieldSdkPlatform.instance.raspDispose(checkerId: _checkerId!).catchError((_) {});
    }
  }

  static String _generateId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
