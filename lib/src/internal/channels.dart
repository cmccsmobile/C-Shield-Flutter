class CShieldChannels {
  static const String methodChannel = 'c_shield_sdk';
  static const String raspEventChannel = 'c_shield_sdk/rasp_events';
  static const String threatEventChannel = 'c_shield_sdk/threat_events';

  static const String sdkInitialize = 'sdk.initialize';

  static const String raspBuild = 'rasp.build';
  static const String raspSetConfig = 'rasp.setConfig';
  static const String raspQuickCheck = 'rasp.quickCheck';
  static const String raspSubscribe = 'rasp.subscribe';
  static const String raspCancelSubscribe = 'rasp.cancelSubscribe';
  static const String raspDispose = 'rasp.dispose';

  static const String sslConfigure = 'ssl.configure';
  static const String sslUpdatePins = 'ssl.updatePins';
  static const String sslIsConfigured = 'ssl.isConfigured';
  static const String sslCheckServerTrusted = 'ssl.checkServerTrusted';

  // Standalone — caller constructs payload manually (Android + iOS)
  static const String aipSign = 'aip.sign';
  static const String aipVerify = 'aip.verify';
  static const String aipNormalizeBody = 'aip.normalizeBody';

  // Interceptor-style — SDK auto-constructs payload from request/response (Android + iOS)
  static const String aipSignRequest = 'aip.signRequest';
  static const String aipVerifyResponse = 'aip.verifyResponse';

}
