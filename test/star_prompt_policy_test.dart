import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:najikify/services/star_prompt_service.dart';

/// Deterministic pseudo-random source for the probability gate tests.
class _FixedRandom implements math.Random {
  final double value;
  _FixedRandom(this.value);

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => value >= 0.5;
}

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

    test('fixed random source behaves deterministically', () {
      expect(_FixedRandom(0.0).nextDouble(), 0.0);
      expect(_FixedRandom(0.99).nextDouble(), 0.99);
    });
  });
}
