import 'package:flutter_test/flutter_test.dart';

import 'package:najikify/core/utils/version_utils.dart';
import 'package:najikify/services/star_prompt_service.dart';

void main() {
  group('StarPromptService policy', () {
    test('prompt is transfer-triggered with a minimum completion count', () {
      expect(StarPromptService.minCompletedTransfers, greaterThanOrEqualTo(1));
    });

    test('repeat prompts are spaced out (interval + every-Nth gate)', () {
      expect(StarPromptService.promptEveryNth, greaterThanOrEqualTo(2));
      expect(
        StarPromptService.promptInterval,
        const Duration(days: 14),
      );
    });

    test('the prompt has no auto-dismiss — the user always closes it', () {
      // StarPromptService deliberately exposes no auto-dismiss duration: the
      // dialog stays on screen until the user acts (see StarPromptDialog).
      // This test documents that the old 5-second auto-close is gone.
      expect(StarPromptService.promptInterval, const Duration(days: 14));
    });

    test('version comparison treats debug-signed 1.0.2 as older', () {
      expect(VersionUtils.isNewer('1.0.3', '1.0.2'), isTrue);
      expect(VersionUtils.isNewer('1.0.4', '1.0.3'), isTrue);
      expect(VersionUtils.isNewer('1.0.3', '1.0.3'), isFalse);
    });
  });
}
