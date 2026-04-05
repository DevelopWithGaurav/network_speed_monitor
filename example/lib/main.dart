import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:network_speed_monitor/network_speed_monitor.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Speed Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C83FD), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final NetworkSpeedMonitor _monitor;
  final List<NetworkSpeedSnapshot> _history = [];
  static const int _maxHistory = 20;

  @override
  void initState() {
    super.initState();
    _monitor = NetworkSpeedMonitor(
      config: const NetworkSpeedConfig(interval: Duration(seconds: 1), thresholds: QualityThresholds(poorBelow: 512, goodBelow: 10000)),
    );
    _monitor.stream.listen((snapshot) {
      setState(() {
        _history.insert(0, snapshot);
        if (_history.length > _maxHistory) _history.removeLast();
      });
    });
    _monitor.start();
  }

  @override
  void dispose() {
    _monitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Network Monitor',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                      ),
                      SizedBox(height: 2),
                      Text('Live traffic analysis', style: TextStyle(fontSize: 13, color: Colors.white38)),
                    ],
                  ),
                  NetworkSpeedIndicator(monitor: _monitor, style: SpeedIndicatorStyle.dot),
                ],
              ),
              const SizedBox(height: 28),

              // ── Card style ────────────────────────────────────────────
              _SectionLabel('Card Style'),
              const SizedBox(height: 10),
              NetworkSpeedIndicator(monitor: _monitor, style: SpeedIndicatorStyle.card),
              const SizedBox(height: 24),

              // ── Compact style ─────────────────────────────────────────
              _SectionLabel('Compact Pill Style'),
              const SizedBox(height: 10),
              NetworkSpeedIndicator(monitor: _monitor, style: SpeedIndicatorStyle.compact),
              const SizedBox(height: 24),

              // ── History ───────────────────────────────────────────────
              _SectionLabel('Raw Stream — Recent Snapshots'),
              const SizedBox(height: 10),
              _HistoryList(history: _history),
              const SizedBox(height: 24),

              // ── Debug panel (Android only) ────────────────────────────
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
                _SectionLabel('Debug — /proc/net/dev'),
                const SizedBox(height: 10),
                const _ProcNetDevDebugPanel(),
                const SizedBox(height: 24),
              ],

              // ── API usage ─────────────────────────────────────────────
              _SectionLabel('API Usage Example'),
              const SizedBox(height: 10),
              _CodeBlock(
                code: '''
final monitor = NetworkSpeedMonitor(
  config: NetworkSpeedConfig(
    interval: Duration(seconds: 1),
    thresholds: QualityThresholds(
      poorBelow: 512,   // Kbps
      goodBelow: 10000, // Kbps
    ),
  ),
);

monitor.stream.listen((snapshot) {
  print(snapshot.downloadFormatted); // "12.4 Mbps"
  print(snapshot.quality.label);    // "Excellent"
});

await monitor.start();
''',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Debug panel ───────────────────────────────────────────────────────────────

class _ProcNetDevDebugPanel extends StatefulWidget {
  const _ProcNetDevDebugPanel();

  @override
  State<_ProcNetDevDebugPanel> createState() => _ProcNetDevDebugPanelState();
}

class _ProcNetDevDebugPanelState extends State<_ProcNetDevDebugPanel> {
  String _raw = 'Tap "Read" to load...';

  Future<void> _read() async {
    final raw = await compute(readProcNetDevRaw, null);
    setState(() => _raw = raw);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111122),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Raw /proc/net/dev',
                style: TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: _read,
                child: const Text('Read', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _raw,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF8BE9FD), height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 1.2),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<NetworkSpeedSnapshot> history;
  const _HistoryList({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Waiting for data...', style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: history.take(8).toList().asMap().entries.map((e) {
          final snapshot = e.value;
          final isLast = e.key == (history.take(8).length - 1);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: isLast ? null : const Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
            ),
            child: Row(
              children: [
                Text(
                  '${snapshot.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${snapshot.timestamp.minute.toString().padLeft(2, '0')}:'
                  '${snapshot.timestamp.second.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white38),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('↓ ${snapshot.downloadFormatted}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                ),
                Expanded(
                  child: Text('↑ ${snapshot.uploadFormatted}', style: const TextStyle(fontSize: 13, color: Colors.white54)),
                ),
                _QualityDot(snapshot.quality),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QualityDot extends StatelessWidget {
  final NetworkQuality quality;
  const _QualityDot(this.quality);

  Color get _color => switch (quality) {
    NetworkQuality.excellent => const Color(0xFF00C853),
    NetworkQuality.good => const Color(0xFFFFD600),
    NetworkQuality.poor => const Color(0xFFFF6D00),
    NetworkQuality.offline => const Color(0xFF9E9E9E),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _color),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;
  const _CodeBlock({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111122),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        code.trim(),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF8BE9FD), height: 1.6),
      ),
    );
  }
}
