import 'package:flutter/material.dart';

import '../../services/star_prompt_service.dart';

/// "Rate us"-style "Do you like Najikify?" prompt, shown after a successful
/// transfer (see [StarPromptService]).
///
/// There is deliberately **no auto-dismiss timer**: the dialog stays on screen
/// until the user closes it, taps *Don't ask again*, or opens the GitHub star
/// page — a prompt that vanishes on its own is easy to miss and feels rude.
class StarPromptDialog extends StatelessWidget {
  const StarPromptDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      icon: Icon(Icons.star_rounded, color: colorScheme.primary),
      title: const Text('Do you like Najikify?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your files just arrived safely. If Najikify makes sharing '
              'easier, a GitHub star keeps the project going — it takes a '
              'few seconds.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      // Plain button list: AlertDialog's OverflowBar wraps the buttons on
      // narrow phones, so nothing overflows on Android or small Linux windows.
      actions: [
        TextButton(
          onPressed: () {
            StarPromptService().dismissForever();
            Navigator.of(context).pop();
          },
          child: const Text("Don't ask again"),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.of(context).pop();
            await StarPromptService().starNow();
          },
          icon: const Icon(Icons.star_rounded, size: 18),
          label: const Text('Star on GitHub'),
        ),
      ],
    );
  }
}
