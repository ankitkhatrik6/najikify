import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/transfer_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/transfer_card.dart';

class TransfersScreen extends StatelessWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final transferService = context.watch<TransferService>();

    final active = transferService.activeTransfers;
    final completed = transferService.completedTransfers;
    final failed = transferService.failedTransfers;

    final hasTransfers = active.isNotEmpty || completed.isNotEmpty || failed.isNotEmpty;

    if (!hasTransfers) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Transfers'),
        ),
        body: const EmptyState(
          icon: Icons.swap_horiz_rounded,
          title: 'No active transfers',
          message: 'Files you send or receive will appear here with live speed and progress.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfers'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Active Transfers Section
          if (active.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active (${active.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            ...active.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TransferCard(
                    transfer: t,
                    onCancel: () => transferService.cancelTransfer(t.id),
                  ),
                )),
            const SizedBox(height: 12),
          ],

          // Completed Transfers Section
          if (completed.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'Completed (${completed.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...completed.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TransferCard(transfer: t),
                )),
            const SizedBox(height: 12),
          ],

          // Failed Transfers Section
          if (failed.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'Failed / Cancelled (${failed.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
            ),
            ...failed.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TransferCard(
                    transfer: t,
                    onRetry: () {
                      // Attempt restart with same peer
                    },
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
