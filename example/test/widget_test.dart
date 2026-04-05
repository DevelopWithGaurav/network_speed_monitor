import 'package:flutter_test/flutter_test.dart';
import 'package:network_speed_monitor_example/main.dart';

void main() {
  testWidgets('Example app renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    // App bar / header title is present
    expect(find.text('Network Monitor'), findsOneWidget);
  });

  testWidgets('All section labels are present', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    expect(find.text('CARD STYLE'), findsOneWidget);
    expect(find.text('COMPACT PILL STYLE'), findsOneWidget);
    expect(find.text('RAW STREAM — RECENT SNAPSHOTS'), findsOneWidget);
    expect(find.text('API USAGE EXAMPLE'), findsOneWidget);
  });

  testWidgets('NetworkSpeedIndicator card widget is present', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    expect(find.text('Network Speed'), findsWidgets);
    expect(find.text('Download'), findsWidgets);
    expect(find.text('Upload'), findsWidgets);
  });

  testWidgets('Shows waiting message when no history yet', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump(); // single pump — no timer ticks yet

    expect(find.text('Waiting for data...'), findsOneWidget);
  });
}
