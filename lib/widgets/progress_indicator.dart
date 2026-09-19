import 'package:flutter/material.dart';

class TransferProgressBar extends StatelessWidget {
  final double progress;
  final bool isIndeterminate;
  final Color? color;

  const TransferProgressBar({
    super.key,
    required this.progress,
    this.isIndeterminate = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: isIndeterminate ? null : progress.clamp(0.0, 1.0),
        minHeight: 8,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? theme.colorScheme.primary),
      ),
    );
  }
}
