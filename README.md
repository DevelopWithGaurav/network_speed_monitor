# network_speed_monitor

[![pub.dev](https://img.shields.io/pub/v/network_speed_monitor.svg)](https://pub.dev/packages/network_speed_monitor)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Flutter package that monitors **real-time network upload/download speed** by tracking actual app traffic — no fake file downloads. Includes a stream API, quality labels, and a ready-made widget.

---

## ✨ Features

- 📡 **Live speed stream** — emits `NetworkSpeedSnapshot` every second (configurable)
- 🏷️ **Quality labels** — `Excellent`, `Good`, `Poor`, `Offline` with custom thresholds
- 🎨 **3 widget styles** — Card, Compact pill, and Dot indicator
- ⚡ **Zero native code** — pure Dart + Flutter, works everywhere
- 🌐 **All platforms** — Android, iOS, macOS, Windows, Linux, Web
- 🔧 **Fully configurable** — interval, probe URL, quality thresholds

---

## 📦 Installation

```yaml
dependencies:
  network_speed_monitor: ^0.0.1
```

---

## 🚀 Quick Start

### Stream API

```dart
import 'package:network_speed_monitor/network_speed_monitor.dart';

final monitor = NetworkSpeedMonitor();

monitor.stream.listen((snapshot) {
  print('↓ ${snapshot.downloadFormatted}');     // "12.4 Mbps"
  print('↑ ${snapshot.uploadFormatted}');       // "850 Kbps"
  print('Quality: ${snapshot.quality.label}'); // "Excellent"
});

await monitor.start();

// When done:
monitor.dispose();
```

### Ready-made Widget

```dart
// Card (full details)
NetworkSpeedIndicator(
  style: SpeedIndicatorStyle.card,
)

// Compact pill (great for app bars)
NetworkSpeedIndicator(
  style: SpeedIndicatorStyle.compact,
)

// Minimal dot (status bar)
NetworkSpeedIndicator(
  style: SpeedIndicatorStyle.dot,
)
```

### Sharing a monitor between widgets

```dart
final monitor = NetworkSpeedMonitor();
await monitor.start();

// Pass to multiple widgets — they all share the same stream
NetworkSpeedIndicator(monitor: monitor, style: SpeedIndicatorStyle.card)
NetworkSpeedIndicator(monitor: monitor, style: SpeedIndicatorStyle.compact)
```

---

## ⚙️ Configuration

```dart
final monitor = NetworkSpeedMonitor(
  config: NetworkSpeedConfig(
    // How often to emit snapshots
    interval: Duration(seconds: 1),

    // URL for HTTP probe (used on iOS, macOS, Web, Windows, Linux)
    probeUrl: 'https://speed.cloudflare.com/__down?bytes=10000',

    // Quality classification thresholds (in Kbps)
    thresholds: QualityThresholds(
      poorBelow: 512,    // < 512 Kbps  → Poor
      goodBelow: 10000,  // < 10 Mbps   → Good, else Excellent
    ),
  ),
);
```

---

## 📊 NetworkSpeedSnapshot

| Property | Type | Description |
|---|---|---|
| `downloadKbps` | `double` | Download speed in Kbps |
| `uploadKbps` | `double` | Upload speed in Kbps |
| `downloadMbps` | `double` | Download speed in Mbps |
| `uploadMbps` | `double` | Upload speed in Mbps |
| `downloadFormatted` | `String` | Human-readable string e.g. "12.4 Mbps" |
| `uploadFormatted` | `String` | Human-readable string e.g. "850 Kbps" |
| `quality` | `NetworkQuality` | `.offline / .poor / .good / .excellent` |
| `timestamp` | `DateTime` | When this snapshot was captured |

---

## 🔬 How It Works — Technical Deep Dive

The package uses two different measurement strategies depending on the platform. It always picks the most accurate method available, with an automatic fallback.

### Android — `/proc/net/dev` Byte Counter Diff

On Android, the Linux kernel exposes a virtual file at `/proc/net/dev` that contains **cumulative byte counters** for every network interface on the device (WiFi, mobile data, ethernet, etc.). This file is updated by the kernel in real time and requires no special permissions to read.

A sample of what the file looks like:

```
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
  lo:  123456     100    0    0    0     0          0         0   123456     100    0    0    0     0       0          0
wlan0: 45678901   9000   0    0    0     0          0         0  2345678    4500    0    0    0     0       0          0
```

The package reads this file every tick using `dart:io`'s `File.readAsStringSync()` inside a `compute()` isolate (so it never blocks the UI thread), then:

1. Parses out the `rx_bytes` (column 0) and `tx_bytes` (column 8) for every non-loopback interface
2. Sums them across all interfaces to get total bytes in/out
3. Subtracts the previous tick's reading to get the **delta** (bytes transferred in the last interval)
4. Divides by elapsed time to get **bytes per second**
5. Converts to **Kbps** using: `(deltaBytes × 8) ÷ elapsedSeconds ÷ 1000`

This approach measures **actual real app traffic** — every byte your app (and the OS) sends or receives is counted, not just a synthetic test download.

**Automatic fallback:** If `/proc/net/dev` returns zero (some Android manufacturers restrict access), the package silently switches to the HTTP probe method described below.

### iOS / macOS / Windows / Linux / Web — HTTP Probe

On platforms where kernel traffic counters aren't accessible from pure Dart, the package performs a lightweight **HTTP probe** each interval:

1. Opens an `HttpClient` connection to `https://speed.cloudflare.com/__down?bytes=10000` (configurable)
2. Streams the response body, counting every byte received
3. Starts a `Stopwatch` when the request begins and stops it when the response completes
4. Calculates download speed: `(bytesReceived × 8) ÷ elapsedSeconds ÷ 1000`
5. Estimates upload speed from outgoing request header size (~400 bytes)

The probe runs within 85% of the configured interval duration to ensure it completes before the next tick fires.

### Quality Classification

Every snapshot is labelled with a `NetworkQuality` enum value based on the download speed in Kbps:

| Quality | Condition | Typical use case |
|---|---|---|
| `offline` | 0 Kbps | No network / probe failed |
| `poor` | < 512 Kbps | 2G / very weak signal |
| `good` | 512 Kbps – 10 Mbps | 3G / average WiFi |
| `excellent` | ≥ 10 Mbps | 4G/5G / strong WiFi |

Thresholds are fully configurable via `QualityThresholds`.

### Stream Architecture

`NetworkSpeedMonitor` uses a `broadcast` `StreamController` internally, which means:
- Multiple widgets or listeners can subscribe to the **same monitor instance** simultaneously
- No data is buffered — each subscriber only receives snapshots emitted after they subscribe
- The stream stays open until `dispose()` is called

---

## 📄 License

MIT