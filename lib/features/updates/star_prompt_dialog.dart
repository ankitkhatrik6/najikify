import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/star_prompt_service.dart';

/// "Rate us"-style "Do you like Najikify?" prompt, shown after a successful
/// transfer (see [StarPromptService]) and closing itself after
/// [StarPromptService.autoDismissAfter] without user interaction.
class StarPromptDialog extends StatefulWidget {
  const StarPromptDialog({super.key});

  @override
  State<StarPromptDialog> createState() => _StarPromptDialogState();
}

class _StarPromptDialogState extends State<StarPromptDialog> {
  Timer? _timer;
  int _secondsLeft = StarPromptService.autoDismissAfter.inSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      icon: Icon(Icons.favorite_rounded, color: colorScheme.primary),
      title: const Text('Do you like Najikify?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your file just arrived safely. If Najikify makes sharing easier, '
            'a GitHub star keeps the project going — it takes a few seconds.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Closing in $_secondsLeft s…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () {
            StarPromptService().dismissForever();
            Navigator.of(context).pop();
          },
          child: const Text("Don't ask again"),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                await StarPromptService().starNow();
              },
              icon: const Icon(Icons.star_rounded, size: 18),
              label: const Text('Star on GitHub'),
            ),
          ],
        ),
      ],
    );
  }
}
