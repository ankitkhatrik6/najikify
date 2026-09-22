import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:najikify/core/constants/app_constants.dart';

void main() {
  group('App Version Consistency Tests', () {
    test('AppConstants.appVersion matches the version in pubspec.yaml', () {
      // Regression guard: the Settings screen shows AppConstants.appVersion,
      // and it once drifted from pubspec.yaml (Settings displayed 1.0.0 while
      // the release was 1.0.2). Keep the two in sync.
      final pubspec = File('pubspec.yaml');
      expect(pubspec.existsSync(), isTrue,
          reason: 'Tests must run from the package root.');

      final versionLine = pubspec
          .readAsLinesSync()
          .firstWhere((line) => line.startsWith('version:'));
      // "version: 1.0.3+4" -> "1.0.3"
      final pubspecVersion = versionLine.split(':')[1].trim().split('+').first;

      expect(AppConstants.appVersion, pubspecVersion);
    });

    test('version string is plain semver and build number is numeric', () {
      final versionLine = File('pubspec.yaml')
          .readAsLinesSync()
          .firstWhere((line) => line.startsWith('version:'));
      final full = versionLine.split(':')[1].trim();
      final parts = full.split('+');

      expect(parts.length, 2, reason: 'Expected "<semver>+<buildNumber>".');
      expect(
        RegExp(r'^\d+\.\d+\.\d+$').hasMatch(parts[0]),
        isTrue,
        reason: 'Version "$full" must be plain semver.',
      );
      expect(
        int.tryParse(parts[1]),
        isNotNull,
        reason: 'Build number "${parts[1]}" must be an integer.',
      );
    });
  });
}
