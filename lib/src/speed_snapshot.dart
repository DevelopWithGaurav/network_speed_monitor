/// Represents a single snapshot of network speed at a point in time.
class NetworkSpeedSnapshot {
  /// Download speed in kilobits per second (Kbps).
  final double downloadKbps;

  /// Upload speed in kilobits per second (Kbps).
  final double uploadKbps;

  /// The quality level derived from download speed.
  final NetworkQuality quality;

  /// Timestamp when this snapshot was captured.
  final DateTime timestamp;

  const NetworkSpeedSnapshot({required this.downloadKbps, required this.uploadKbps, required this.quality, required this.timestamp});

  /// Download speed in megabits per second (Mbps).
  double get downloadMbps => downloadKbps / 1000;

  /// Upload speed in megabits per second (Mbps).
  double get uploadMbps => uploadKbps / 1000;

  /// Returns a human-readable download speed string (e.g. "12.4 Mbps" or "850 Kbps").
  String get downloadFormatted => _format(downloadKbps);

  /// Returns a human-readable upload speed string.
  String get uploadFormatted => _format(uploadKbps);

  String _format(double kbps) {
    if (kbps >= 1000) {
      return '${(kbps / 1000).toStringAsFixed(1)} Mbps';
    }
    return '${kbps.toStringAsFixed(0)} Kbps';
  }

  /// An empty/zero snapshot — useful as an initial value.
  factory NetworkSpeedSnapshot.zero() =>
      NetworkSpeedSnapshot(downloadKbps: 0, uploadKbps: 0, quality: NetworkQuality.offline, timestamp: DateTime.now());

  @override
  String toString() => 'NetworkSpeedSnapshot(↓ $downloadFormatted, ↑ $uploadFormatted, quality: ${quality.name})';
}

/// Qualitative label for the current network speed.
enum NetworkQuality {
  /// No network activity detected.
  offline,

  /// Very slow — below 1 Mbps download.
  poor,

  /// Usable — 1–10 Mbps download.
  good,

  /// Fast — above 10 Mbps download.
  excellent;

  /// Returns a friendly display label.
  String get label => switch (this) {
    NetworkQuality.offline => 'Offline',
    NetworkQuality.poor => 'Poor',
    NetworkQuality.good => 'Good',
    NetworkQuality.excellent => 'Excellent',
  };

  /// Returns an emoji icon for quick display.
  String get icon => switch (this) {
    NetworkQuality.offline => '📵',
    NetworkQuality.poor => '🔴',
    NetworkQuality.good => '🟡',
    NetworkQuality.excellent => '🟢',
  };
}
