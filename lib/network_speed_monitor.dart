/// network_speed_monitor
///
/// A pure Dart + Flutter package for monitoring real-time network
/// upload/download speed by tracking actual app traffic.
///
/// ## Quick start
///
/// ```dart
/// import 'package:network_speed_monitor/network_speed_monitor.dart';
///
/// final monitor = NetworkSpeedMonitor();
/// monitor.stream.listen((snapshot) {
///   print('↓ ${snapshot.downloadFormatted}  ↑ ${snapshot.uploadFormatted}');
///   print('Quality: ${snapshot.quality.label}');
/// });
/// monitor.start();
///
/// // In a widget:
/// NetworkSpeedIndicator(style: SpeedIndicatorStyle.card)
/// ```
library;

export 'src/speed_snapshot.dart' show NetworkSpeedSnapshot, NetworkQuality;
export 'src/speed_monitor.dart' show NetworkSpeedMonitor, NetworkSpeedConfig, QualityThresholds;
export 'src/speed_indicator.dart' show NetworkSpeedIndicator, SpeedIndicatorStyle;
export 'src/proc_net_dev.dart' show readProcNetDevRaw;
