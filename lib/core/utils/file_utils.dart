import 'dart:io';
import 'package:path/path.dart' as p;

enum FileConflictAction {
  replace,
  keepBoth,
  skip,
}

class FileUtils {
  /// Resolves the final destination path based on the conflict resolution action.
  static String resolveConflictPath(String originalPath, FileConflictAction action) {
    if (!File(originalPath).existsSync() && !Directory(originalPath).existsSync()) {
      return originalPath;
    }

    switch (action) {
      case FileConflictAction.replace:
        return originalPath;

      case FileConflictAction.skip:
        return originalPath;

      case FileConflictAction.keepBoth:
        final dir = p.dirname(originalPath);
        final extension = p.extension(originalPath);
        final baseNameWithoutExt = p.basenameWithoutExtension(originalPath);

        var counter = 1;
        String candidate;
        do {
          candidate = p.join(dir, '${baseNameWithoutExt}_$counter$extension');
          counter++;
        } while (File(candidate).existsSync() || Directory(candidate).existsSync());

        return candidate;
    }
  }

  /// Sanitizes incoming relative path to prevent directory traversal vulnerabilities (e.g. "../").
  static String sanitizeRelativePath(String relativePath) {
    var sanitized = relativePath.replaceAll('\\', '/');
    while (sanitized.startsWith('/') || sanitized.startsWith('./')) {
      sanitized = sanitized.replaceFirst(RegExp(r'^(/|\./)+'), '');
    }
    // Remove any '..' path segments
    final segments = sanitized.split('/').where((s) => s.isNotEmpty && s != '..' && s != '.').toList();
    return segments.join(p.separator);
  }

  /// Recursively collects all files from a directory maintaining relative paths.
  static Future<List<FileEntityEntry>> listDirectoryFiles(Directory directory) async {
    final results = <FileEntityEntry>[];
    if (!await directory.exists()) return results;

    final baseDirPath = directory.path;

    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final length = await entity.length();
        final relPath = p.relative(entity.path, from: baseDirPath);
        results.add(FileEntityEntry(
          file: entity,
          relativePath: relPath,
          size: length,
          isFolder: false,
        ));
      }
    }
    return results;
  }
}

class FileEntityEntry {
  final File file;
  final String relativePath;
  final int size;
  final bool isFolder;

  const FileEntityEntry({
    required this.file,
    required this.relativePath,
    required this.size,
    this.isFolder = false,
  });
}
