import 'dart:io';

/// Reads /proc/net/dev and returns (totalRxBytes, totalTxBytes).
/// This lives in its own file so dart:io is imported directly —
/// required for use inside a compute() isolate.
(int, int) readProcNetDev(void _) {
  try {
    final content = File('/proc/net/dev').readAsStringSync();
    return _parse(content);
  } catch (e) {
    return (0, 0);
  }
}

/// Exposed for debugging — returns raw /proc/net/dev content.
String readProcNetDevRaw(void _) {
  try {
    return File('/proc/net/dev').readAsStringSync();
  } catch (e) {
    return 'ERROR: $e';
  }
}

(int, int) _parse(String content) {
  int totalRx = 0;
  int totalTx = 0;

  for (final line in content.split('\n')) {
    final trimmed = line.trim();

    if (trimmed.isEmpty || trimmed.startsWith('Inter') || trimmed.startsWith('face')) continue;

    // Skip loopback
    if (trimmed.startsWith('lo:') || trimmed.startsWith('lo ')) continue;

    final colonIdx = trimmed.indexOf(':');
    if (colonIdx == -1) continue;

    final afterColon = trimmed.substring(colonIdx + 1).trim();
    final parts = afterColon.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

    if (parts.length < 9) continue;

    try {
      totalRx += int.parse(parts[0]); // rx_bytes
      totalTx += int.parse(parts[8]); // tx_bytes
    } catch (_) {}
  }

  return (totalRx, totalTx);
}
