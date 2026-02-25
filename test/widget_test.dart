import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // 1. Build the app
    await tester.pumpWidget(const MyProfessionalApp());

    // 2. Verify that MainPage loads with its main elements
    expect(find.text('Rank'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Connects'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // 3. Verify cloud buttons are present
    expect(find.text('Courses'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);
    expect(find.text('Lessons'), findsOneWidget);
    expect(find.text('Sheets'), findsOneWidget);
    expect(find.text('Social'), findsOneWidget);
  });
}
