import 'dart:io';
import 'app_exceptions.dart';

class ErrorHandler {
  /// Converts arbitrary exceptions into user-friendly localized messages.
  static String getUserFriendlyMessage(dynamic error) {
    if (error is LocalDropException) {
      return error.message;
    }

    if (error is SocketException) {
      return 'Could not establish connection to device. Verify both devices are on the same Wi-Fi network.';
    }

    if (error is HttpException) {
      return 'Network protocol error occurred: ${error.message}';
    }

    if (error is FileSystemException) {
      return 'Filesystem error: ${error.message} (${error.path ?? 'unknown path'})';
    }

    final errStr = error.toString().toLowerCase();
    if (errStr.contains('connection refused')) {
      return 'Connection was refused by target device. Ensure LocalDrop is open on both devices.';
    }
    if (errStr.contains('network is unreachable')) {
      return 'Network is unreachable. Connect your device to a local Wi-Fi router.';
    }
    if (errStr.contains('timed out')) {
      return 'The operation timed out. The peer device may have gone to sleep or disconnected.';
    }

    return 'An unexpected error occurred: $error';
  }
}
