Future<void> onSSEParagraphComplete() async {
  // No-op: Vibration is not supported on web.
}

Future<void> onSSESentenceComplete() async {
  // No-op: Vibration is not supported on web.
}

// New SSE-specific API for web compatibility
Future<void> onSSETextReceived(String text) async {
  // No-op: Vibration is not supported on web.
}

Future<void> startVibration() async {
  // No-op: Vibration is not supported on web.
}

Future<void> stopVibration() async {
  // No-op: Vibration is not supported on web.
}

Future<void> triggerVibration() async {
  // No-op: Vibration is not supported on web.
}