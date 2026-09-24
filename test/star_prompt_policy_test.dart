import 'package:flutter_test/flutter_test.dart';

import 'package:najikify/core/utils/version_utils.dart';
import 'package:najikify/services/star_prompt_service.dart';

void main() {
  group('StarPromptService policy', () {
    test('probability gate honors the random roll', () {
      expect(StarPromptService.showProbability, greaterThan(0));
      expect(StarPromptService.showProbability, lessThan(1));
    });

    test('auto-dismiss is 5 seconds', () {
      expect(
        StarPromptService.autoDismissAfter,
        const Duration(seconds: 5),
      );
    });

    test('prompt is gated behind a minimum launch count', () {
      expect(StarPromptService.minLaunches, greaterThanOrEqualTo(5));
    });

    test('prompts are spaced at least two weeks apart', () {
      expect(
        StarPromptService.promptInterval,
        const Duration(days: 14),
      );
    });

    test('version comparison treats debug-signed 1.0.2 as older', () {
      expect(VersionUtils.isNewer('1.0.3', '1.0.2'), isTrue);
      expect(VersionUtils.isNewer('1.0.4', '1.0.3'), isTrue);
      expect(VersionUtils.isNewer('1.0.3', '1.0.3'), isFalse);
    });
  });
}
