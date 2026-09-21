import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zxing2/qrcode.dart';
import '../../core/utils/qr_payload_utils.dart';
import '../../services/pairing_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final PairingService _pairingService = PairingService();
  final TextEditingController _manualInputController = TextEditingController();
  MobileScannerController? _scannerController;
  bool _isProcessing = false;
  bool _isDecodingImage = false;
  String? _errorMessage;
  String? _permissionMessage;
  bool _torchOn = false;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      _scannerController = MobileScannerController(
        // Start the camera explicitly once the permission is granted and the
        // first frame is laid out. Auto-starting here races the permission
        // dialog and can leave the native side without an attached activity.
        autoStart: false,
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
      );
      _bootstrapCamera();
    }
  }

  /// Requests the camera permission and only then starts the preview.
  Future<void> _bootstrapCamera() async {
    final granted = await _requestCameraPermission();
    if (!granted || !mounted) return;
    // Wait for the first frame so the plugin has an attached activity.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  /// Starts the camera preview, surfacing any native failure in the UI.
  Future<void> _startCamera() async {
    final controller = _scannerController;
    if (controller == null || !mounted) return;
    try {
      await controller.start();
    } catch (e) {
      _onScannerError(e);
    }
  }

  /// Requests camera permission; returns true when the scanner may start.
  Future<bool> _requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      if (!mounted) return false;
      if (status.isPermanentlyDenied || status.isRestricted) {
        setState(() {
          _permissionMessage =
              'Camera access is blocked. Open app settings and allow Camera, then reopen the scanner.';
        });
        return false;
      }
      if (!status.isGranted && !status.isLimited) {
        setState(() {
          _permissionMessage =
              'Camera permission is required. Tap retry after granting access.';
        });
        return false;
      }
      setState(() => _permissionMessage = null);
      return true;
    } catch (_) {
      // permission_handler can be unavailable on some builds; let the plugin
      // request the permission natively during start() instead.
      return true;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    if (capture.barcodes.isEmpty) return;
    for (final b in capture.barcodes) {
      final pairingUri = QrPayloadUtils.extractPairingUri(b.rawValue);
      if (pairingUri != null) {
        _processPairing(pairingUri);
        return;
      }
    }
    if (mounted && _errorMessage == null) {
      final looksLikeLink = capture.barcodes
          .any((b) => QrPayloadUtils.looksLikeNajikifyLink(b.rawValue));
      setState(() {
        _errorMessage = looksLikeLink
            ? 'That Najikify link is not a pairing code. Use Connect Device > Show my QR on the peer.'
            : 'That QR is not a Najikify code. Scan the code in Najikify > Connect Device > Show my QR.';
      });
    }
  }

  void _onScannerError(Object error) {
    if (!mounted) return;
    final s = error.toString().toLowerCase();
    if (s.contains('disposed')) return;
    setState(() {
      _permissionMessage = s.contains('permission')
          ? 'Camera permission denied. Grant Camera access, then tap Retry camera.'
          : 'Camera failed to start ($error).';
    });
  }

  Future<String?> _decodeQrBytes(Uint8List bytes) async {
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    final candidates = <img.Image>[image];
    if (image.width > 1200 || image.height > 1200) {
      candidates.add(img.copyResize(image,
          width: 1000, height: (1000 * image.height / image.width).round()));
    }
    for (final candidate in candidates) {
      final rgba = candidate
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.rgba);
      final pixels = Int32List(candidate.width * candidate.height);
      for (int i = 0; i < pixels.length; i++) {
        pixels[i] = (rgba[i * 4 + 3] << 24) |
            (rgba[i * 4] << 16) |
            (rgba[i * 4 + 1] << 8) |
            rgba[i * 4 + 2];
      }
      try {
        final source =
            RGBLuminanceSource(candidate.width, candidate.height, pixels);
        final bitmap = BinaryBitmap(HybridBinarizer(source));
        final result = QRCodeReader().decode(bitmap);
        if (result.text.isNotEmpty) return result.text;
      } catch (_) {}
    }
    return null;
  }

  Future<void> _decodeFromImageFile() async {
    if (_isDecodingImage || _isProcessing) return;
    setState(() {
      _isDecodingImage = true;
      _errorMessage = null;
    });
    try {
      const typeGroup = XTypeGroup(
        label: 'images',
        extensions: ['png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) {
        if (mounted) setState(() => _isDecodingImage = false);
        return;
      }
      // Android: prefer native ML Kit decoder first.
      if (_isMobile && _scannerController != null) {
        try {
          final capture = await _scannerController!.analyzeImage(file.path);
          if (capture != null && capture.barcodes.isNotEmpty) {
            final pairingUri = capture.barcodes
                .map((b) => QrPayloadUtils.extractPairingUri(b.rawValue))
                .firstWhere((uri) => uri != null, orElse: () => null);
            if (pairingUri != null) {
              if (mounted) setState(() => _isDecodingImage = false);
              await _processPairing(pairingUri);
              return;
            }
          }
        } catch (_) {}
      }
      final bytes = await File(file.path).readAsBytes();
      final decoded = await _decodeQrBytes(bytes);
      if (!mounted) return;
      final pairingUri = QrPayloadUtils.extractPairingUri(decoded);
      if (pairingUri == null) {
        setState(() {
          _errorMessage = decoded == null || decoded.trim().isEmpty
              ? 'No QR code found in that image. Try a clearer screenshot.'
              : 'That image holds a QR code, but not a Najikify pairing code.';
          _isDecodingImage = false;
        });
        return;
      }
      setState(() => _isDecodingImage = false);
      await _processPairing(pairingUri);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not read that image: $e';
          _isDecodingImage = false;
        });
      }
    }
  }

  /// Validates a typed or pasted pairing link before starting the handshake.
  void _submitManualInput(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    if (_isProcessing) return;

    final pairingUri = QrPayloadUtils.extractPairingUri(text);
    if (pairingUri == null) {
      setState(() {
        _errorMessage = QrPayloadUtils.looksLikeNajikifyLink(text)
            ? 'That Najikify link is not a pairing code. Use Connect Device > Show my QR on the peer.'
            : 'That does not look like a Najikify pairing link. It should start with najikify://pair/.';
      });
      return;
    }

    _processPairing(pairingUri);
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
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    final controller = _scannerController;
    if (controller == null) return;
    try {
      await controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {}
  }

  Future<void> _retryCamera() async {
    setState(() => _permissionMessage = null);
    final granted = await _requestCameraPermission();
    if (granted && mounted) {
      await _startCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = Platform.isAndroid || Platform.isIOS;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          if (isMobile)
            IconButton(
              icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
              tooltip: 'Toggle flash',
              onPressed: _toggleTorch,
            ),
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.cameraswitch_rounded),
              tooltip: 'Switch camera',
              onPressed: () => _scannerController?.switchCamera(),
            ),
        ],
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
                    if (_scannerController != null)
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: _onDetect,
                        errorBuilder: (ctx, error, child) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _onScannerError(error);
                          });
                          return Container(
                            color: Colors.black,
                            child: Center(
                              child: FilledButton.tonal(
                                onPressed: _retryCamera,
                                child: const Text('Retry camera'),
                              ),
                            ),
                          );
                        },
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
            ] else ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded,
                        size: 44, color: colorScheme.primary),
                    const SizedBox(height: 10),
                    Text(
                      'Linux scan: pick a screenshot / photo of the peer QR, or paste its link below.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          _isDecodingImage ? null : _decodeFromImageFile,
                      icon: const Icon(Icons.image_search_rounded, size: 18),
                      label: Text(_isDecodingImage
                          ? 'Reading image…'
                          : 'Choose QR image…'),
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
                      if (_permissionMessage != null && isMobile) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _permissionMessage!,
                                  style: TextStyle(
                                      color: colorScheme.onErrorContainer),
                                ),
                              ),
                              TextButton(
                                onPressed: _retryCamera,
                                child: const Text('Retry'),
                              ),
                              const TextButton(
                                onPressed: openAppSettings,
                                child: Text('Settings'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
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
                            ? 'Point camera at the peer QR, or decode from a saved image:'
                            : 'Or paste the pairing link (Copy Link on the peer device):',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (isMobile)
                        OutlinedButton.icon(
                          onPressed: _isDecodingImage
                              ? null
                              : _decodeFromImageFile,
                          icon:
                              const Icon(Icons.photo_library_outlined, size: 18),
                          label: Text(_isDecodingImage
                              ? 'Reading image…'
                              : 'Scan from gallery image'),
                        ),
                      if (isMobile) const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualInputController,
                              decoration: InputDecoration(
                                labelText: 'Pairing URI',
                                hintText: 'najikify://pair/...',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onSubmitted: _submitManualInput,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            icon: const Icon(Icons.arrow_forward),
                            tooltip: 'Connect',
                            onPressed: () =>
                                _submitManualInput(_manualInputController.text),
                          ),
                          IconButton(
                            icon: const Icon(Icons.content_paste_rounded),
                            tooltip: 'Paste from clipboard',
                            onPressed: () async {
                              final data = await Clipboard.getData(
                                  Clipboard.kTextPlain);
                              final text = data?.text ?? '';
                              if (text.trim().isEmpty) return;
                              _manualInputController.text = text.trim();
                              _submitManualInput(text);
                            },
                          ),
                        ],
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
