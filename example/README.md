# network_speed_monitor — Example App

A full showcase of the [`network_speed_monitor`](https://pub.dev/packages/network_speed_monitor) Flutter package demonstrating all widget styles, the raw stream API, and a built-in debug panel.

---

## 📱 What's in the app

### Card Widget
A full-detail card showing live download speed, upload speed, and a quality badge — all updating every second.

### Compact Pill Widget
A space-efficient pill indicator — ideal for embedding in app bars or status rows.

### Dot Indicator
A minimal animated dot that pulses and changes color based on network quality. Green = Excellent, Yellow = Good, Orange = Poor, Grey = Offline.

### Raw Stream History
A live scrolling list of the last 8 `NetworkSpeedSnapshot` objects emitted by the stream, showing timestamp, download, upload, and quality dot for each tick.

### Debug Panel *(Android only)*
Reads and displays the raw contents of `/proc/net/dev` directly from the Linux kernel. Useful for verifying that the byte counter method is working correctly on a specific device.

---

## 🚀 Running the app

```bash
cd example
flutter pub get
flutter run
```

> Run on a **physical Android device** for the most accurate results. Emulators have minimal real network traffic so readings may appear low.

---

## 🗂 Structure

```
example/
├── lib/
│   └── main.dart       # Full showcase app
├── test/
│   └── widget_test.dart
└── pubspec.yaml
```

---

## 💡 Key pattern used

The example creates **one shared `NetworkSpeedMonitor`** and passes it to all three `NetworkSpeedIndicator` widgets. This means a single stream drives all the UI — no duplicate timers or network calls:

```dart
final monitor = NetworkSpeedMonitor();
await monitor.start();

NetworkSpeedIndicator(monitor: monitor, style: SpeedIndicatorStyle.card)
NetworkSpeedIndicator(monitor: monitor, style: SpeedIndicatorStyle.compact)
NetworkSpeedIndicator(monitor: monitor, style: SpeedIndicatorStyle.dot)
```

The monitor is disposed in `dispose()` of the parent widget, which stops the timer and closes the stream cleanly.