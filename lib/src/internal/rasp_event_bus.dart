import 'dart:async';
import 'package:flutter/services.dart';
import 'channels.dart';
import 'codec/rasp_codec.dart';
import '../api/rasp/rasp_extended_result.dart';

// Singleton that wraps the RASP EventChannel and demultiplexes events by subscriptionId.
class RaspEventBus {
  RaspEventBus._();
  static final instance = RaspEventBus._();

  static const _ch = EventChannel(CShieldChannels.raspEventChannel);

  // Single broadcast stream shared across all subscriptions.
  // receiveBroadcastStream() activates native onListen on first subscriber,
  // deactivates via onCancel when all subscribers leave, and restarts on re-subscribe.
  final Stream<dynamic> _rawStream = _ch.receiveBroadcastStream();

  // Subscribe to all events for a given subscriptionId.
  // Call this BEFORE calling rasp.subscribe on native to avoid missing early events.
  Stream<RASPExtendedResult> subscribeEvents(String subscriptionId) {
    final controller = StreamController<RASPExtendedResult>();

    final sub = _rawStream.listen(
      (raw) {
        final event = raw as Map;
        if (event['subscriptionId'] != subscriptionId) return;

        switch (event['type'] as String) {
          case 'result':
            final data = Map<dynamic, dynamic>.from(event['data'] as Map);
            controller.add(RaspCodec.extendedResultFromMap(data));
          case 'complete':
            controller.close();
          case 'error':
            controller.addError(
              Exception(event['message'] ?? 'Unknown RASP error'),
            );
            controller.close();
        }
      },
      onError: (Object e) {
        controller.addError(e);
        controller.close();
      },
    );

    controller.onCancel = sub.cancel;
    return controller.stream;
  }
}
