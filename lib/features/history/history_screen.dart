import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/format_utils.dart';
import '../../models/transfer.dart';
import '../../services/history_service.dart';
import '../../widgets/empty_state.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryService>().loadHistory(filter: _selectedFilter);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final historyService = context.watch<HistoryService>();

    final query = _searchController.text.trim().toLowerCase();
    final allTransfers = historyService.transfers;

    final filteredTransfers = allTransfers.where((t) {
      if (query.isEmpty) return true;
      final peerMatch = t.peerDevice.name.toLowerCase().contains(query);
      final fileMatch = t.files.any((f) => f.name.toLowerCase().contains(query));
      return peerMatch || fileMatch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History'),
        actions: [
          if (allTransfers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear History',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear history?'),
                    content: const Text('All transfer records will be deleted. Transferred files will remain saved on disk.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await context.read<HistoryService>().clearAll();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips and Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search files or devices...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('send', 'Sent'),
                      const SizedBox(width: 8),
                      _buildFilterChip('receive', 'Received'),
                      const SizedBox(width: 8),
                      _buildFilterChip('failed', 'Failed'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Transfer List
          Expanded(
            child: filteredTransfers.isEmpty
                ? const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'No records found',
                    message: 'Past transfers and saved files will be listed here.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: filteredTransfers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filteredTransfers[index];
                      final isSend = item.direction == TransferDirection.send;
                      final primaryFileName = item.files.isNotEmpty ? item.files.first.name : 'Unknown';

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSend
                                      ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                                      : colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isSend ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  color: isSend ? colorScheme.onPrimaryContainer : colorScheme.onSecondaryContainer,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      primaryFileName,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${isSend ? '↑ Sent to' : '↓ Received from'} ${item.peerDevice.name} • ${FormatUtils.formatBytes(item.totalBytes)}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    FormatUtils.formatDateTime(item.createdAt),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (item.state == TransferState.completed)
                                    const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green)
                                  else if (item.state == TransferState.failed)
                                    Icon(Icons.error_outline_rounded, size: 16, color: colorScheme.error),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterId, String label) {
    final isSelected = _selectedFilter == filterId;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = filterId);
          context.read<HistoryService>().loadHistory(filter: filterId);
        }
      },
    );
  }
}
