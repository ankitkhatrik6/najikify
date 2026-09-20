import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/pairing_session.dart';
import '../../services/network_service.dart';
import '../../services/pairing_service.dart';

class QrDisplayDialog extends StatefulWidget {
  const QrDisplayDialog({super.key});

  @override
  State<QrDisplayDialog> createState() => _QrDisplayDialogState();
}

class _QrDisplayDialogState extends State<QrDisplayDialog> {
  final PairingService _pairingService = PairingService();
  final NetworkService _networkService = NetworkService();
  late PairingSession _session;
  late Timer _timer;
  int _remainingSeconds = 300;
  String? _selectedIp;

  @override
  void initState() {
    super.initState();
    _selectedIp = _networkService.currentIp;
    _session = _pairingService.createHostSession(ipAddress: _selectedIp);
    _remainingSeconds = _session.expiresAt.difference(DateTime.now()).inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final rem = _session.expiresAt.difference(DateTime.now()).inSeconds;
      if (rem <= 0) {
        timer.cancel();
        if (mounted) setState(() => _remainingSeconds = 0);
      } else {
        if (mounted) setState(() => _remainingSeconds = rem);
      }
    });
  }

  void _regenerate({String? ipAddress}) {
    _session = _pairingService.createHostSession(ipAddress: ipAddress ?? _selectedIp);
    _remainingSeconds = _session.expiresAt.difference(DateTime.now()).inSeconds;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final qrUri = _session.toQrUri();
    final interfaces = _networkService.interfaces
        .where((e) => !e.isVirtual)
        .toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Connect Device via QR'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Scan this QR code from Najikify on any device (Linux or Android) to connect directly.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (interfaces.length > 1) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Network (${interfaces.length} found)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: interfaces.any((e) => e.address == _selectedIp)
                    ? _selectedIp
                    : interfaces.first.address,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: interfaces
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.address,
                        child: Text('${e.address}  (${e.name})',
                            style: theme.textTheme.bodySmall),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  _selectedIp = v;
                  _regenerate(ipAddress: v);
                },
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await _networkService.refreshNetwork();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh networks'),
              ),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: QrImageView(
                data: qrUri,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  _remainingSeconds > 0
                      ? 'Expires in ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}'
                      : 'Session expired',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _remainingSeconds > 0 ? colorScheme.onSurfaceVariant : colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _regenerate(),
                  child: const Icon(Icons.refresh_rounded, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'IP: ${_session.ipAddress}:${_session.port}',
              style: theme.textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: qrUri));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pairing link copied to clipboard')),
            );
          },
          child: const Text('Copy Link'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
