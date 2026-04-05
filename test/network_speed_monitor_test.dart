import 'package:flutter_test/flutter_test.dart';
import 'package:network_speed_monitor/network_speed_monitor.dart';

void main() {
  group('NetworkSpeedSnapshot', () {
    test('zero() returns all-zero snapshot with offline quality', () {
      final snap = NetworkSpeedSnapshot.zero();
      expect(snap.downloadKbps, 0);
      expect(snap.uploadKbps, 0);
      expect(snap.quality, NetworkQuality.offline);
    });

    test('downloadMbps converts correctly', () {
      final snap = NetworkSpeedSnapshot(downloadKbps: 5000, uploadKbps: 1000, quality: NetworkQuality.good, timestamp: DateTime.now());
      expect(snap.downloadMbps, 5.0);
      expect(snap.uploadMbps, 1.0);
    });

    test('downloadFormatted shows Mbps when >= 1000 Kbps', () {
      final snap = NetworkSpeedSnapshot(downloadKbps: 12400, uploadKbps: 500, quality: NetworkQuality.excellent, timestamp: DateTime.now());
      expect(snap.downloadFormatted, '12.4 Mbps');
      expect(snap.uploadFormatted, '500 Kbps');
    });

    test('toString includes arrow symbols', () {
      final snap = NetworkSpeedSnapshot.zero();
      expect(snap.toString(), contains('↓'));
      expect(snap.toString(), contains('↑'));
    });
  });

  group('NetworkQuality', () {
    test('label returns non-empty string for all values', () {
      for (final q in NetworkQuality.values) {
        expect(q.label.isNotEmpty, true);
      }
    });

    test('icon returns non-empty string for all values', () {
      for (final q in NetworkQuality.values) {
        expect(q.icon.isNotEmpty, true);
      }
    });
  });

  group('QualityThresholds', () {
    const thresholds = QualityThresholds(poorBelow: 512, goodBelow: 10000);

    test('0 Kbps → offline', () {
      expect(thresholds.classify(0), NetworkQuality.offline);
    });

    test('negative Kbps → offline', () {
      expect(thresholds.classify(-1), NetworkQuality.offline);
    });

    test('100 Kbps → poor', () {
      expect(thresholds.classify(100), NetworkQuality.poor);
    });

    test('511 Kbps → poor', () {
      expect(thresholds.classify(511), NetworkQuality.poor);
    });

    test('512 Kbps → good', () {
      expect(thresholds.classify(512), NetworkQuality.good);
    });

    test('5000 Kbps → good', () {
      expect(thresholds.classify(5000), NetworkQuality.good);
    });

    test('10000 Kbps → excellent', () {
      expect(thresholds.classify(10000), NetworkQuality.excellent);
    });

    test('50000 Kbps → excellent', () {
      expect(thresholds.classify(50000), NetworkQuality.excellent);
    });
  });

  group('NetworkSpeedMonitor', () {
    test('starts and stops without error', () async {
      final monitor = NetworkSpeedMonitor();
      expect(monitor.isRunning, false);
      await monitor.start();
      expect(monitor.isRunning, true);
      monitor.stop();
      expect(monitor.isRunning, false);
      monitor.dispose();
    });

    test('start is idempotent', () async {
      final monitor = NetworkSpeedMonitor();
      await monitor.start();
      await monitor.start(); // Should not throw
      expect(monitor.isRunning, true);
      monitor.dispose();
    });

    test('stream emits snapshots after start', () async {
      final monitor = NetworkSpeedMonitor(config: const NetworkSpeedConfig(interval: Duration(milliseconds: 100)));
      await monitor.start();

      final snapshot = await monitor.stream.first.timeout(const Duration(seconds: 5));

      expect(snapshot, isA<NetworkSpeedSnapshot>());
      expect(snapshot.timestamp, isNotNull);

      monitor.dispose();
    });

    test('dispose closes the stream', () async {
      final monitor = NetworkSpeedMonitor();
      await monitor.start();
      monitor.dispose();
      expect(monitor.stream.isBroadcast, true);
    });

    test('custom config is respected', () {
      const config = NetworkSpeedConfig(interval: Duration(seconds: 2), thresholds: QualityThresholds(poorBelow: 1000, goodBelow: 5000));
      final monitor = NetworkSpeedMonitor(config: config);
      expect(monitor.config.interval, const Duration(seconds: 2));
      expect(monitor.config.thresholds.poorBelow, 1000);
      monitor.dispose();
    });
  });
}
