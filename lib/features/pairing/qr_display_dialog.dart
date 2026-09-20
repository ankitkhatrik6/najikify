import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/pairing_session.dart';
import '../../services/pairing_service.dart';

class QrDisplayDialog extends StatefulWidget {
  const QrDisplayDialog({super.key});

  @override
  State<QrDisplayDialog> createState() => _QrDisplayDialogState();
}

class _QrDisplayDialogState extends State<QrDisplayDialog> {
  final PairingService _pairingService = PairingService();
  late PairingSession _session;
  late Timer _timer;
  int _remainingSeconds = 300;

  @override
  void initState() {
    super.initState();
    _session = _pairingService.createHostSession();
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

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Connect Device via QR'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Scan this QR code from Najikify on your Android device to connect directly.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
