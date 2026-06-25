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

  // AIP — only the cryptographic sign/verify cross to native. Body
  // normalization, payload construction and the timestamp-window check are
  // done in Dart (CShieldAIP / AIPNormalizer).
  static const String aipSign = 'aip.sign';
  static const String aipVerify = 'aip.verify';

}
