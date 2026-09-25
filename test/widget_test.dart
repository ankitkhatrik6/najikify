import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:najikify/app/theme.dart';
import 'package:najikify/features/settings/about_najikify_screen.dart';
import 'package:najikify/features/updates/star_prompt_dialog.dart';
import 'package:najikify/widgets/app_logo.dart';
import 'package:najikify/widgets/empty_state.dart';

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

  testWidgets('AboutNajikifyScreen shows logo, description and support actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AboutNajikifyScreen(),
      ),
    );
    await tester.pump();

    expect(find.byType(AppLogo), findsWidgets);
    expect(find.text('About Najikify'), findsOneWidget);
    expect(find.textContaining('Buy me a Momo'), findsOneWidget);
    expect(find.textContaining('View source'), findsOneWidget);
    expect(find.text('How it works'), findsOneWidget);
  });

  testWidgets('EmptyState shows a radar scan animation while discovering',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: EmptyState(
            icon: Icons.wifi_tethering_rounded,
            title: 'No devices found',
            message: 'Scanning the Wi-Fi network…',
            isScanning: true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('No devices found'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_tethering_rounded), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.byType(AnimatedBuilder),
      ),
      findsOneWidget,
    );

    // Dispose the animated widget so no ticker stays active.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('EmptyState renders a static icon when not scanning',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: EmptyState(
            icon: Icons.wifi_tethering_rounded,
            title: 'No devices found',
            message: 'Make sure Najikify is open on the other device.',
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
  });

  testWidgets('StarPromptDialog renders prompt, countdown and actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: StarPromptDialog()),
      ),
    );

    expect(find.text('Do you like Najikify?'), findsOneWidget);
    expect(find.textContaining('Closing in'), findsOneWidget);
    expect(find.text('Star on GitHub'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text("Don't ask again"), findsOneWidget);

    // Let the auto-dismiss countdown finish so no timer stays pending.
    await tester.pump(const Duration(seconds: 6));
  });
}
