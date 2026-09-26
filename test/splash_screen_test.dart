import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:najikify/app/theme.dart';
import 'package:najikify/features/splash/splash_screen.dart';
import 'package:najikify/widgets/app_logo.dart';
import 'package:najikify/widgets/share_pulse.dart';

void main() {
  testWidgets('SplashScreen shows the logo, wordmark, tagline and discovery',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        // Long duration: this test only checks the intro, the hand-over is
        // covered by the next test.
        home: const SplashScreen(
          duration: Duration(seconds: 30),
          next: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byType(SharePulse), findsOneWidget);
    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Najikify'), findsOneWidget);
    expect(find.textContaining('no cloud, no accounts'), findsOneWidget);
    expect(find.textContaining('Looking for devices'), findsOneWidget);

    // Dispose the splash so its repeating ripple ticker stops.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('SplashScreen hands over to the app shell after its duration',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SplashScreen(
          duration: Duration(milliseconds: 200),
          next: Scaffold(body: Text('APP SHELL')),
        ),
      ),
    );

    expect(find.text('Najikify'), findsOneWidget);
    expect(find.text('APP SHELL'), findsNothing);

    // Fire the hand-over timer, then let the cross-fade finish.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('APP SHELL'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('SharePulse keeps its child centred while the rings animate',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SharePulse(size: 180, ringCount: 3, child: Text('LOGO')),
          ),
        ),
      ),
    );

    expect(find.text('LOGO'), findsOneWidget);

    // The rings are staggered copies of the pulse, drawn behind the child.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('LOGO'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SharePulse),
        matching: find.byType(AnimatedBuilder),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}