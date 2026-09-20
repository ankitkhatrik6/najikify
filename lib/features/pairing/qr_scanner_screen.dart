import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/pairing_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final PairingService _pairingService = PairingService();
  final TextEditingController _manualInputController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code != null && code.startsWith('najikify://pair/')) {
      _processPairing(code);
    }
  }

  Future<void> _processPairing(String qrUri) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final device = await _pairingService.processScannedQr(qrUri, trustDevice: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully paired with ${device.name}!')),
        );
        Navigator.of(context).pop(device);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('NajikifyException: ', '');
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Platform.isAndroid || Platform.isIOS;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isMobile) ...[
              Expanded(
                flex: 3,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      onDetect: _onDetect,
                    ),
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isProcessing)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: colorScheme.onErrorContainer),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        isMobile
                            ? 'Point camera at the QR code displayed on Linux desktop'
                            : 'Enter pairing URI or manual session string below',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _manualInputController,
                        decoration: InputDecoration(
                          labelText: 'Pairing URI',
                          hintText: 'najikify://pair/...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: () {
                              final text = _manualInputController.text.trim();
                              if (text.isNotEmpty) _processPairing(text);
                            },
                          ),
                        ),
                        onSubmitted: (text) {
                          if (text.trim().isNotEmpty) _processPairing(text.trim());
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
