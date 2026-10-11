import 'package:flutter_test/flutter_test.dart';
import 'package:vibes_staff/main.dart';

void main() {
  testWidgets('shows login when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(const StaffApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('مكتب الموظفين'), findsOneWidget);
  });
}
