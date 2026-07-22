import 'package:c_shield_sdk/c_shield_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'network/api_client.dart';
import 'screen/otp_page.dart';

// Lets us show a dialog from the RASP subscribe callback, which lives in
// main() rather than inside a widget.
final navigatorKey = GlobalKey<NavigatorState>();

// The detailed stream can emit several vulnerable results in a row; this keeps
// only one threat dialog on screen at a time.
bool _threatDialogVisible = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize CShieldSdk.
  await CShieldSdk.initialize(
    // Override the native load-time threat popup's text. Null fields keep the
    // SDK's default strings. Pass showLoadAppThreatPopup: false to suppress the
    // popup entirely (the app is still killed).
    loadAppThreatPopup: const ThreatPopupText(title: 'Security threat detected', description: 'This app cannot run in an unsafe environment and will close.'),
    onLoadAppThreat: (event) {
      // Best-effort notification only — the process is torn down right after
      // this fires, so do not try to show UI from here.
      debugPrint('Load app threat detected: $event');
    },
  ).timeout(
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
      ),
    ),
  );
  // automaticallyShowPopup: false → the native popup is suppressed so we can
  // draw our own Flutter dialog here. Run-app threats fire while the app is
  // alive, so unlike load-app threats, showing UI from Dart is fine.
  raspChecker.subscribe(detail: true, automaticallyShowPopup: true).listen((result) {
    if (result.vulnerable) {
      debugPrint('Threat detected: ${result.checkType.key}');
      // _showThreatDialog(result);
    }
  });
  runApp(const MyApp());
}

Future<void> _showThreatDialog(RASPExtendedResult result) async {
  final context = navigatorKey.currentContext;
  if (context == null || _threatDialogVisible) return;

  final isCritical = result.threatAction == ThreatDetectedAction.killApp;
  _threatDialogVisible = true;
  await showDialog<void>(
    context: context,
    barrierDismissible: !isCritical,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(isCritical ? Icons.gpp_bad : Icons.warning_amber_rounded),
      title: Text(isCritical ? 'Security threat detected' : 'Security warning'),
      content: Text(
        'Detected: ${result.checkType.key}\n\n'
        '${isCritical ? 'This app will close to protect your data.' : 'Please review your device.'}',
      ),
      actions: [
        if (!isCritical) TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Dismiss')),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            if (isCritical) SystemNavigator.pop();
          },
          child: Text(isCritical ? 'Exit' : 'OK'),
        ),
      ],
    ),
  );
  _threatDialogVisible = false;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'CShield SDK Demo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const OtpPage(),
    );
  }
}
