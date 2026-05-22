import 'package:c_shield_sdk/c_shield_sdk.dart';
import 'package:flutter/material.dart';

import 'network/api_client.dart';
import 'screen/otp_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize CShieldSdk
  await CShieldSdk.initialize().timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      debugPrint('CShieldSdk.initialize() timed out');
    },
  );

  await CShieldSSL.configure(pins: sslPins, hostname: sslHostname);
  var raspChecker = RASPChecker.builder();
  await raspChecker.setRASPConfig(
    RASPConfig(
      trustedStores: [],
      threatActionConfig: const ThreatActionConfig(
        rootDetectedAction: ThreatDetectedAction.notifyApp,
        tamperingDetectedAction: ThreatDetectedAction.notifyApp,
        emulatorDetectedAction: ThreatDetectedAction.notifyApp,
        deviceSecurityStateUnsafeDetectedAction: ThreatDetectedAction.notifyApp,
        userCADetectedAction: ThreatDetectedAction.notifyApp,
      ),
    ),
  );
  raspChecker.subscribe(detail: true, automaticallyShowPopup: true).listen((
    result,
  ) {
    if (result.vulnerable) {
      // Handle the detected threat, e.g., show a custom alert dialog
      debugPrint('Threat detected: ${result.toString()}');
    }
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CShield SDK Demo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const OtpPage(),
    );
  }
}
