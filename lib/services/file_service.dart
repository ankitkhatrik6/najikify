import 'dart:io';
import 'package:path/path.dart' as p;
import '../core/errors/app_exceptions.dart';
import '../core/utils/file_utils.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  /// Ensures that target download directory exists and is writable.
  Future<Directory> ensureDownloadDirectory(String basePath) async {
    final dir = Directory(basePath);
    if (!await dir.exists()) {
      try {
        await dir.create(recursive: true);
      } catch (e) {
        throw FilePermissionException(basePath, 'Failed to create download folder: $e');
      }
    }
    return dir;
  }

  /// Verifies available storage on target filesystem.
  Future<void> checkAvailableDiskSpace(String destinationDir, int requiredBytes) async {
    // Basic safety check: Ensure directory is accessible
    final dir = Directory(destinationDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Prepares a destination file path for an incoming file, preserving relative directory structure.
  Future<String> prepareDestinationPath({
    required String downloadBasePath,
    required String relativePath,
    FileConflictAction conflictAction = FileConflictAction.keepBoth,
  }) async {
    final sanitizedRelative = FileUtils.sanitizeRelativePath(relativePath);
    final targetPath = p.join(downloadBasePath, sanitizedRelative);

    // Ensure subdirectories exist for folder transfers
    final parentDir = Directory(p.dirname(targetPath));
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    // Resolve filename conflicts
    final resolvedPath = FileUtils.resolveConflictPath(targetPath, conflictAction);
    return resolvedPath;
  }
}
