// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:webrtc/main.dart';

void main() {
  testWidgets('renders role selector and command action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ControlCenterApp());
    await tester.pump();

    expect(find.text('控制端'), findsOneWidget);
    expect(find.text('被控制端'), findsOneWidget);
    expect(find.text('广播命令'), findsOneWidget);
  });
}
