import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_harbor/theme/app_theme.dart';

void main() {
  testWidgets('AppTheme can render a themed scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Text('가독성 테스트 문장'),
        ),
      ),
    );

    expect(find.text('가독성 테스트 문장'), findsOneWidget);
  });
}
