import 'package:flutter_test/flutter_test.dart';
import 'package:safe_drive_monitor/app/app.dart';
import 'package:safe_drive_monitor/features/drowsiness_detection/presentation/screens/driver_monitor_screen.dart';

void main() {
  testWidgets('SafeDriveApp renders DriverMonitorScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SafeDriveApp(initialOnboardingCompleted: true));
    expect(find.byType(DriverMonitorScreen), findsOneWidget);
  });
}
