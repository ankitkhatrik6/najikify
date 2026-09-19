import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/constants/app_constants.dart';
import '../models/device.dart';
import '../models/transfer.dart';
import '../models/transfer_file.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    // Linux desktop requires sqflite_common_ffi initialization
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, AppConstants.appName, AppConstants.databaseName);

    // Ensure parent directory exists
    final parentDir = Directory(p.dirname(dbPath));
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    return await openDatabase(
      dbPath,
      version: AppConstants.databaseVersion,
      onCreate: (db, version) async {
        // Devices table (persists known/trusted peers)
        await db.execute('''
          CREATE TABLE devices (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            platform TEXT NOT NULL,
            ip_address TEXT NOT NULL,
            port INTEGER NOT NULL,
            fingerprint TEXT NOT NULL,
            is_trusted INTEGER NOT NULL DEFAULT 0,
            last_seen INTEGER NOT NULL
          )
        ''');

        // Transfers table
        await db.execute('''
          CREATE TABLE transfers (
            id TEXT PRIMARY KEY,
            peer_device_id TEXT NOT NULL,
            peer_device_name TEXT NOT NULL,
            peer_platform TEXT NOT NULL,
            peer_ip TEXT NOT NULL,
            peer_port INTEGER NOT NULL,
            direction TEXT NOT NULL,
            state TEXT NOT NULL,
            total_bytes INTEGER NOT NULL,
            transferred_bytes INTEGER NOT NULL DEFAULT 0,
            file_count INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            completed_at INTEGER,
            error_message TEXT
          )
        ''');

        // Transfer files table
        await db.execute('''
          CREATE TABLE transfer_files (
            id TEXT PRIMARY KEY,
            transfer_id TEXT NOT NULL,
            name TEXT NOT NULL,
            relative_path TEXT NOT NULL,
            size INTEGER NOT NULL,
            bytes_transferred INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL,
            checksum TEXT,
            local_path TEXT,
            is_folder INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (transfer_id) REFERENCES transfers (id) ON DELETE CASCADE
          )
        ''');

        // Settings table
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // --- Device operations ---
  Future<void> saveOrUpdateDevice(Device device) async {
    final db = await database;
    await db.insert(
      'devices',
      device.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateDeviceTrust(String deviceId, bool isTrusted) async {
    final db = await database;
    await db.update(
      'devices',
      {'is_trusted': isTrusted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<List<Device>> getTrustedDevices() async {
    final db = await database;
    final results = await db.query(
      'devices',
      where: 'is_trusted = 1',
      orderBy: 'last_seen DESC',
    );
    return results.map((m) => Device.fromMap(m)).toList();
  }

  Future<Device?> getDeviceById(String deviceId) async {
    final db = await database;
    final results = await db.query(
      'devices',
      where: 'id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Device.fromMap(results.first);
  }

  // --- Transfer operations ---
  Future<void> recordTransfer(Transfer transfer) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'transfers',
        transfer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final file in transfer.files) {
        await txn.insert(
          'transfer_files',
          file.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> updateTransferStatus(String transferId, TransferState state,
      {int? transferredBytes, DateTime? completedAt, String? errorMessage}) async {
    final db = await database;
    final values = <String, dynamic>{
      'state': state.name,
    };
    if (transferredBytes != null) values['transferred_bytes'] = transferredBytes;
    if (completedAt != null) values['completed_at'] = completedAt.millisecondsSinceEpoch;
    if (errorMessage != null) values['error_message'] = errorMessage;

    await db.update(
      'transfers',
      values,
      where: 'id = ?',
      whereArgs: [transferId],
    );
  }

  Future<List<Transfer>> getTransfers({String? filterDirection}) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (filterDirection != null && filterDirection.isNotEmpty && filterDirection != 'all') {
      if (filterDirection == 'failed') {
        whereClause = 'state = ?';
        whereArgs = ['failed'];
      } else {
        whereClause = 'direction = ?';
        whereArgs = [filterDirection];
      }
    }

    final transferMaps = await db.query(
      'transfers',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    final transfers = <Transfer>[];
    for (final map in transferMaps) {
      final transferId = map['id'] as String;
      final fileMaps = await db.query(
        'transfer_files',
        where: 'transfer_id = ?',
        whereArgs: [transferId],
      );

      final files = fileMaps.map((fm) => TransferFile.fromMap(fm)).toList();

      final peer = Device(
        id: map['peer_device_id'] as String,
        name: map['peer_device_name'] as String,
        platform: DevicePlatform.fromString(map['peer_platform'] as String),
        ipAddress: map['peer_ip'] as String,
        port: map['peer_port'] as int,
        fingerprint: '',
        lastSeen: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

      transfers.add(Transfer(
        id: transferId,
        peerDevice: peer,
        direction: TransferDirection.fromString(map['direction'] as String),
        state: TransferState.fromString(map['state'] as String),
        files: files,
        totalBytes: map['total_bytes'] as int,
        transferredBytes: map['transferred_bytes'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        completedAt: map['completed_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
            : null,
        errorMessage: map['error_message'] as String?,
      ));
    }

    return transfers;
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('transfer_files');
    await db.delete('transfers');
  }

  // --- Generic Key-Value Settings ---
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final results = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }
}
