## 0.0.1

* Initial release
* `NetworkSpeedMonitor` with stream API
* `NetworkSpeedSnapshot` data model with formatting helpers
* `NetworkQuality` enum with labels and icons
* `QualityThresholds` with configurable Kbps cutoffs
* `NetworkSpeedIndicator` widget with `card`, `compact`, and `dot` styles
* Android: reads `/proc/net/dev` for real traffic bytes
* Other platforms: HTTP probe via Cloudflare speed endpoint
* Full unit test coverage for models and monitor lifecycle
