import 'package:flutter_test/flutter_test.dart';
import 'package:student_survivor/app.dart';

void main() {
  testWidgets('App shows auth screen', (WidgetTester tester) async {
    await tester.pumpWidget(const StudentSurvivorApp());

    expect(find.text('Student Survivor'), findsWidgets);
    expect(find.text('Login'), findsOneWidget);
  });
}
