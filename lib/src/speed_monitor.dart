import 'dart:async';
import 'dart:io' as io show HttpClient;
import 'package:flutter/foundation.dart';
import 'speed_snapshot.dart';
import 'proc_net_dev.dart';

/// Configuration for [NetworkSpeedMonitor].
class NetworkSpeedConfig {
  /// How often to emit a new [NetworkSpeedSnapshot].
  /// Defaults to 1 second.
  final Duration interval;

  /// URL used for the HTTP probe on all platforms except Android.
  /// Also used as fallback on Android if /proc/net/dev returns zero.
  final String probeUrl;

  /// Thresholds (in Kbps) used to classify [NetworkQuality].
  final QualityThresholds thresholds;

  const NetworkSpeedConfig({
    this.interval = const Duration(seconds: 1),
    this.probeUrl = 'https://speed.cloudflare.com/__down?bytes=10000',
    this.thresholds = const QualityThresholds(),
  });
}

/// Thresholds for mapping download Kbps → [NetworkQuality].
class QualityThresholds {
  /// Below this → [NetworkQuality.poor]. Default: 512 Kbps.
  final double poorBelow;

  /// Below this → [NetworkQuality.good]. Default: 10,000 Kbps (10 Mbps).
  final double goodBelow;

  const QualityThresholds({this.poorBelow = 512, this.goodBelow = 10000});

  NetworkQuality classify(double kbps) {
    if (kbps <= 0) return NetworkQuality.offline;
    if (kbps < poorBelow) return NetworkQuality.poor;
    if (kbps < goodBelow) return NetworkQuality.good;
    return NetworkQuality.excellent;
  }
}

/// The main class for monitoring network speed.
///
/// Usage:
/// ```dart
/// final monitor = NetworkSpeedMonitor();
/// monitor.stream.listen((snapshot) {
///   print(snapshot.downloadFormatted);
/// });
/// await monitor.start();
/// // ...later
/// monitor.dispose();
/// ```
class NetworkSpeedMonitor {
  final NetworkSpeedConfig config;

  NetworkSpeedMonitor({this.config = const NetworkSpeedConfig()});

  final StreamController<NetworkSpeedSnapshot> _controller = StreamController<NetworkSpeedSnapshot>.broadcast();

  Timer? _timer;
  bool _isRunning = false;

  // Baseline counters for Android /proc/net/dev diff
  int _lastRxBytes = 0;
  int _lastTxBytes = 0;
  DateTime _lastTick = DateTime.now();

  // Tracks whether /proc/net/dev is working on this device
  bool _procNetDevWorks = false;

  _ProbeSession? _activeProbe;

  /// The live stream of [NetworkSpeedSnapshot].
  /// Emits every [NetworkSpeedConfig.interval].
  Stream<NetworkSpeedSnapshot> get stream => _controller.stream;

  /// Whether the monitor is currently active.
  bool get isRunning => _isRunning;

  /// Starts monitoring. Awaits baseline before first tick.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    // On Android, probe /proc/net/dev to see if it works on this device
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _initAndroidBaseline();
    }

    _timer = Timer.periodic(config.interval, (_) => _tick());
  }

  /// Stops monitoring and cancels the timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _activeProbe?.cancel();
    _activeProbe = null;
  }

  /// Stops monitoring and closes the stream.
  void dispose() {
    stop();
    _controller.close();
  }

  // ── Android baseline ───────────────────────────────────────────────────────

  Future<void> _initAndroidBaseline() async {
    try {
      final bytes = await compute(readProcNetDev, null);
      if (bytes.$1 > 0 || bytes.$2 > 0) {
        // /proc/net/dev returned real data — use it
        _procNetDevWorks = true;
        _lastRxBytes = bytes.$1;
        _lastTxBytes = bytes.$2;
        _lastTick = DateTime.now();
      } else {
        // Returned zeros — fall back to HTTP probe
        _procNetDevWorks = false;
      }
    } catch (_) {
      _procNetDevWorks = false;
    }
  }

  // ── Tick ───────────────────────────────────────────────────────────────────

  Future<void> _tick() async {
    try {
      final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

      if (isAndroid && _procNetDevWorks) {
        await _counterAndEmit();
      } else {
        await _probeAndEmit();
      }
    } catch (_) {
      _emit(0, 0);
    }
  }

  // ── Android: /proc/net/dev diff method ────────────────────────────────────

  Future<void> _counterAndEmit() async {
    final bytes = await compute(readProcNetDev, null);
    final now = DateTime.now();

    final rxBytes = bytes.$1;
    final txBytes = bytes.$2;

    // If both are zero again, /proc/net/dev stopped working — switch to probe
    if (rxBytes == 0 && txBytes == 0) {
      _procNetDevWorks = false;
      await _probeAndEmit();
      return;
    }

    final elapsed = now.difference(_lastTick).inMilliseconds / 1000.0;
    if (elapsed <= 0) return;

    final rxDelta = (rxBytes - _lastRxBytes).clamp(0, double.maxFinite.toInt());
    final txDelta = (txBytes - _lastTxBytes).clamp(0, double.maxFinite.toInt());

    // bytes → Kbps: (bytes × 8 bits) ÷ elapsed seconds ÷ 1000
    final downloadKbps = (rxDelta * 8) / elapsed / 1000;
    final uploadKbps = (txDelta * 8) / elapsed / 1000;

    _lastRxBytes = rxBytes;
    _lastTxBytes = txBytes;
    _lastTick = now;

    _emit(downloadKbps, uploadKbps);
  }

  // ── HTTP probe method (iOS, macOS, Web, Windows, Linux + Android fallback) ─

  Future<void> _probeAndEmit() async {
    final stopwatch = Stopwatch()..start();

    try {
      final probe = _ProbeSession(config.probeUrl);
      _activeProbe = probe;

      final bytesReceived = await probe.run(timeoutMs: (config.interval.inMilliseconds * 0.85).toInt());

      stopwatch.stop();
      _activeProbe = null;

      final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
      if (elapsedSec <= 0 || bytesReceived <= 0) {
        _emit(0, 0);
        return;
      }

      // Download speed from actual bytes received
      final downloadKbps = (bytesReceived * 8) / elapsedSec / 1000;

      // Upload: estimated from outgoing request size (~400 bytes headers)
      final uploadKbps = (400 * 8) / elapsedSec / 1000;

      _emit(downloadKbps, uploadKbps);
    } catch (_) {
      _emit(0, 0);
    }
  }

  // ── Emit ───────────────────────────────────────────────────────────────────

  void _emit(double downloadKbps, double uploadKbps) {
    if (_controller.isClosed) return;
    _controller.add(
      NetworkSpeedSnapshot(
        downloadKbps: downloadKbps,
        uploadKbps: uploadKbps,
        quality: config.thresholds.classify(downloadKbps),
        timestamp: DateTime.now(),
      ),
    );
  }
}

// ── Internal HTTP probe session ────────────────────────────────────────────

class _ProbeSession {
  final String url;
  bool _cancelled = false;

  _ProbeSession(this.url);

  Future<int> run({required int timeoutMs}) async {
    int bytesReceived = 0;
    try {
      final client = io.HttpClient();
      client.connectionTimeout = Duration(milliseconds: timeoutMs);

      final request = await client.getUrl(Uri.parse(url)).timeout(Duration(milliseconds: timeoutMs));

      final response = await request.close().timeout(Duration(milliseconds: timeoutMs));

      await for (final chunk in response) {
        if (_cancelled) break;
        bytesReceived += chunk.length;
      }

      client.close();
    } catch (_) {
      // Timeout or network error — return whatever we got
    }
    return bytesReceived;
  }

  void cancel() => _cancelled = true;
}
