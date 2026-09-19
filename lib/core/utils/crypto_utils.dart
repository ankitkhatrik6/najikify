import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class CryptoUtils {
  static final Random _secureRandom = Random.secure();

  /// Generates a cryptographically secure random alphanumeric token.
  static String generateRandomToken([int length = 32]) {
    final values = List<int>.generate(length, (_) => _secureRandom.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '').substring(0, length);
  }

  /// Generates a unique 6-digit numeric pairing PIN code.
  static String generatePairingPin() {
    final pin = _secureRandom.nextInt(900000) + 100000;
    return pin.toString();
  }

  /// Computes the SHA-256 digest of a string or payload.
  static String sha256Digest(String data) {
    return sha256.convert(utf8.encode(data)).toString();
  }

  /// Computes the SHA-256 digest of a byte sequence.
  static String sha256Bytes(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Computes the SHA-256 checksum of a local file via streaming.
  static Future<String> computeFileChecksum(File file) async {
    final stream = file.openRead();
    final digest = await sha256.bind(stream).first;
    return digest.toString();
  }

  /// Generates a truncated fingerprint representation for visual comparison.
  static String formatFingerprint(String hash) {
    if (hash.length < 16) return hash;
    final clean = hash.replaceAll(RegExp(r'[^a-fA-F0-9]'), '').toUpperCase();
    final segments = <String>[];
    for (var i = 0; i < 16 && i < clean.length; i += 4) {
      segments.add(clean.substring(i, i + 4));
    }
    return segments.join(':');
  }
}
