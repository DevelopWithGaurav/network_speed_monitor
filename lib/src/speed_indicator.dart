import 'dart:async';
import 'package:flutter/material.dart';
import 'speed_snapshot.dart';
import 'speed_monitor.dart';

/// Display style for [NetworkSpeedIndicator].
enum SpeedIndicatorStyle {
  /// Compact pill — great for status bars or app bars.
  compact,

  /// Full card with download + upload + quality badge.
  card,

  /// Minimal icon-only dot with color.
  dot,
}

/// A ready-made widget that displays live network speed.
///
/// Attach your own [NetworkSpeedMonitor] or let the widget manage one.
///
/// ```dart
/// NetworkSpeedIndicator(
///   style: SpeedIndicatorStyle.card,
/// )
/// ```
class NetworkSpeedIndicator extends StatefulWidget {
  /// An external monitor to listen to. If null, the widget creates its own.
  final NetworkSpeedMonitor? monitor;

  /// Visual style of the indicator.
  final SpeedIndicatorStyle style;

  /// Override the card/pill background color.
  final Color? backgroundColor;

  /// Override the text color.
  final Color? textColor;

  /// Whether to auto-start the monitor (only applies when widget owns it).
  final bool autoStart;

  const NetworkSpeedIndicator({
    super.key,
    this.monitor,
    this.style = SpeedIndicatorStyle.card,
    this.backgroundColor,
    this.textColor,
    this.autoStart = true,
  });

  @override
  State<NetworkSpeedIndicator> createState() => _NetworkSpeedIndicatorState();
}

class _NetworkSpeedIndicatorState extends State<NetworkSpeedIndicator> with SingleTickerProviderStateMixin {
  late final NetworkSpeedMonitor _monitor;
  bool _ownsMonitor = false;
  StreamSubscription<NetworkSpeedSnapshot>? _subscription;
  NetworkSpeedSnapshot _latest = NetworkSpeedSnapshot.zero();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

    if (widget.monitor != null) {
      _monitor = widget.monitor!;
    } else {
      _monitor = NetworkSpeedMonitor();
      _ownsMonitor = true;
      if (widget.autoStart) _monitor.start();
    }

    _subscription = _monitor.stream.listen((snapshot) {
      if (mounted) setState(() => _latest = snapshot);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pulseController.dispose();
    if (_ownsMonitor) _monitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.style) {
      SpeedIndicatorStyle.dot => _buildDot(),
      SpeedIndicatorStyle.compact => _buildCompact(),
      SpeedIndicatorStyle.card => _buildCard(),
    };
  }

  // ── Quality color ──────────────────────────────────────────────────────────

  Color _qualityColor(NetworkQuality quality) => switch (quality) {
    NetworkQuality.excellent => const Color(0xFF00C853),
    NetworkQuality.good => const Color(0xFFFFD600),
    NetworkQuality.poor => const Color(0xFFFF6D00),
    NetworkQuality.offline => const Color(0xFF9E9E9E),
  };

  // ── Dot style ─────────────────────────────────────────────────────────────

  Widget _buildDot() {
    final color = _qualityColor(_latest.quality);
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final opacity = _latest.quality == NetworkQuality.offline ? 0.3 : 0.5 + _pulseController.value * 0.5;
        return Tooltip(
          message: '${_latest.quality.label} · ↓ ${_latest.downloadFormatted}',
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(opacity),
              boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, spreadRadius: 1)],
            ),
          ),
        );
      },
    );
  }

  // ── Compact pill style ────────────────────────────────────────────────────

  Widget _buildCompact() {
    final bg = widget.backgroundColor ?? _qualityColor(_latest.quality).withOpacity(0.15);
    final textColor = widget.textColor ?? _qualityColor(_latest.quality).withValues(alpha: 1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _qualityColor(_latest.quality).withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          _buildDot(),
          Text(
            '↓ ${_latest.downloadFormatted}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  // ── Card style ────────────────────────────────────────────────────────────

  Widget _buildCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.backgroundColor ?? (isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8F9FF));
    final subtleColor = isDark ? Colors.white12 : Colors.black12;
    final labelColor = isDark ? Colors.white38 : Colors.black38;
    final quality = _latest.quality;
    final qualityColor = _qualityColor(quality);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: subtleColor, width: 1),
        boxShadow: [BoxShadow(color: qualityColor.withOpacity(0.08), blurRadius: 16, spreadRadius: 2, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Network Speed',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: labelColor, letterSpacing: 0.5),
              ),
              _QualityBadge(quality: quality, color: qualityColor),
            ],
          ),
          const SizedBox(height: 14),

          // Speed row
          Row(
            children: [
              Expanded(
                child: _SpeedTile(
                  label: 'Download',
                  icon: Icons.arrow_downward_rounded,
                  value: _latest.downloadFormatted,
                  color: qualityColor,
                  textColor: widget.textColor,
                ),
              ),
              Container(width: 1, height: 40, color: subtleColor, margin: const EdgeInsets.symmetric(horizontal: 16)),
              Expanded(
                child: _SpeedTile(
                  label: 'Upload',
                  icon: Icons.arrow_upward_rounded,
                  value: _latest.uploadFormatted,
                  color: const Color(0xFF7C83FD),
                  textColor: widget.textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _QualityBadge extends StatelessWidget {
  final NetworkQuality quality;
  final Color color;

  const _QualityBadge({required this.quality, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          Text(
            quality.label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

class _SpeedTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final Color color;
  final Color? textColor;

  const _SpeedTile({required this.label, required this.icon, required this.value, required this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white38 : Colors.black38;
    final valueColor = textColor ?? (isDark ? Colors.white : Colors.black87);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: labelColor, fontWeight: FontWeight.w500, letterSpacing: 0.3),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            value,
            key: ValueKey(value),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: valueColor, letterSpacing: -0.5),
          ),
        ),
      ],
    );
  }
}
