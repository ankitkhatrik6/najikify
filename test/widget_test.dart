import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:localdrop/app/theme.dart';
import 'package:localdrop/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState renders icon, title and message',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: EmptyState(
            icon: Icons.devices,
            title: 'No devices found',
            message: 'Make sure both devices are on the same Wi-Fi network.',
          ),
        ),
      ),
    );

    expect(find.text('No devices found'), findsOneWidget);
    expect(find.text('Make sure both devices are on the same Wi-Fi network.'),
        findsOneWidget);
    expect(find.byIcon(Icons.devices), findsOneWidget);
  });

  testWidgets('AppTheme light and dark themes provide ColorSchemes',
      (WidgetTester tester) async {
    expect(AppTheme.lightTheme.colorScheme.primary, isNot(0x00000000));
    expect(AppTheme.darkTheme.colorScheme.primary, isNot(0x00000000));
  });
}
