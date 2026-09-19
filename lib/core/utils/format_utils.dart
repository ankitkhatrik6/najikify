import 'dart:math';
import 'package:intl/intl.dart';

class FormatUtils {
  /// Formats byte count to human-readable size (B, KB, MB, GB, TB).
  static String formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    final clampedIndex = i.clamp(0, suffixes.length - 1);
    final size = bytes / pow(1024, clampedIndex);
    return '${size.toStringAsFixed(decimals)} ${suffixes[clampedIndex]}';
  }

  /// Formats transfer rate to human readable speed string, e.g. "18.7 MB/s".
  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    return '${formatBytes(bytesPerSecond.round())}/s';
  }

  /// Formats remaining seconds into natural text, e.g. "About 1 second remaining".
  static String formatEta(int remainingSeconds) {
    if (remainingSeconds <= 0) return 'Almost done';
    if (remainingSeconds < 60) {
      return remainingSeconds == 1 ? 'About 1 second remaining' : 'About $remainingSeconds seconds remaining';
    }
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    if (minutes < 60) {
      if (seconds == 0) {
        return minutes == 1 ? 'About 1 minute remaining' : 'About $minutes minutes remaining';
      }
      return 'About $minutes min $seconds sec remaining';
    }
    final hours = minutes ~/ 60;
    return 'About $hours hr remaining';
  }

  /// Formats a DateTime for transfer history.
  static String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (itemDate == today) {
      return DateFormat.jm().format(dateTime); // e.g. 7:42 PM
    } else if (itemDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat.jm().format(dateTime)}';
    } else {
      return DateFormat('MMM d, y • h:mm a').format(dateTime);
    }
  }
}
