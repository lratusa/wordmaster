import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordmaster/src/core/theme/app_theme.dart';

void main() {
  group('App smoke tests', () {
    testWidgets('Light theme builds correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          title: 'WordMaster',
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(child: Text('WordMaster')),
          ),
        ),
      );

      expect(find.text('WordMaster'), findsOneWidget);
    });

    testWidgets('Dark theme builds correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          title: 'WordMaster',
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Center(child: Text('WordMaster')),
          ),
        ),
      );

      expect(find.text('WordMaster'), findsOneWidget);
    });
  });
}
