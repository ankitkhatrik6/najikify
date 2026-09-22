import 'package:flutter/foundation.dart';
import '../models/transfer.dart';
import 'database_service.dart';

class HistoryService extends ChangeNotifier {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  final DatabaseService _db = DatabaseService();
  List<Transfer> _transfers = [];
  String _currentFilter = 'all'; // all, send, receive, failed
  bool _isLoading = false;

  List<Transfer> get transfers => _transfers;
  String get currentFilter => _currentFilter;
  bool get isLoading => _isLoading;

  Future<void> loadHistory({String? filter}) async {
    _isLoading = true;
    if (filter != null) {
      _currentFilter = filter;
    }
    notifyListeners();

    try {
      _transfers = await _db.getTransfers(filterDirection: _currentFilter);
    } catch (_) {
      _transfers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTransfer(Transfer transfer) async {
    await _db.recordTransfer(transfer);
    await loadHistory();
  }

  /// Refreshes one persisted record in place (used while a multi-file
  /// transfer is running so History shows realtime aggregate progress
  /// instead of a stale 0% snapshot).
  Future<void> refreshTransfer(Transfer transfer) async {
    await _db.updateTransferProgress(
      transfer.id,
      transfer.state,
      transferredBytes: transfer.transferredBytes,
      files: transfer.files,
    );
    final index = _transfers.indexWhere((t) => t.id == transfer.id);
    if (index >= 0) {
      _transfers[index] = transfer;
    } else {
      _transfers.insert(0, transfer);
    }
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _db.clearHistory();
    _transfers = [];
    notifyListeners();
  }
}
