/// Global application constants for LocalDrop
class AppConstants {
  static const String appName = 'LocalDrop';
  static const String appVersion = '1.0.0';
  static const String appAuthor = 'LocalDrop Open Source Contributors';
  static const String githubRepoUrl = 'https://github.com/localdrop/localdrop';
  
  // Storage keys & database constants
  static const String databaseName = 'localdrop.db';
  static const int databaseVersion = 1;
  static const String defaultSubdirectory = 'LocalDrop';

  // Transfer limits
  static const int defaultChunkSize = 64 * 1024; // 64 KB per stream chunk
  static const int maxConcurrentTransfers = 3;
  static const Duration transferTimeout = Duration(seconds: 45);
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration pairingSessionExpiry = Duration(minutes: 5);
}
