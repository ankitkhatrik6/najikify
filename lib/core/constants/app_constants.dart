/// Global application constants for Najikify
class AppConstants {
  static const String appName = 'Najikify';
  static const String appVersion = '1.0.0';
  static const String appAuthor = 'Ankit Khatri KC';
  static const String githubRepoUrl = 'https://github.com/ankitkhatrik6/najikify';
  
  // Storage keys & database constants
  static const String databaseName = 'najikify.db';
  static const int databaseVersion = 1;
  static const String defaultSubdirectory = 'Najikify';

  // Transfer limits
  static const int defaultChunkSize = 64 * 1024; // 64 KB per stream chunk
  static const int maxConcurrentTransfers = 3;
  static const Duration transferTimeout = Duration(seconds: 45);
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration pairingSessionExpiry = Duration(minutes: 5);
}
