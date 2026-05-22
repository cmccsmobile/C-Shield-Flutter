import 'dart:async';
import '../internal/platform/c_shield_sdk_platform_interface.dart';

class CShieldSdk {
  CShieldSdk._();
  static Future<void> initialize() =>
      CShieldSdkPlatform.instance.initialize();

}
