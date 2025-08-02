// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognify_flutter/main.dart';

void main() {
  testWidgets('Home screen shows sources button', (WidgetTester tester) async {
    await tester.pumpWidget(const CognifyApp());

    // Check for the sources button by text
    expect(find.text('Browse sources'), findsOneWidget);
    // Check for the sources header action by tooltip
    expect(find.byTooltip('Sources'), findsOneWidget);
  });
}
