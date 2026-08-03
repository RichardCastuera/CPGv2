import 'dart:async';
import '../connectivity/connectivity_service.dart';
import '../../repositories/guideline_repository.dart';

/// Reacts to connectivity regaining a signal by re-syncing the library,
/// and tells the UI how many *new* guidelines showed up as a result —
/// this is what powers the "3 new guidelines added" banner.
///
/// Does NOT sync full guideline detail trees automatically (that stays
/// on-demand, triggered when a screen opens or a download starts) —
/// only the lightweight library list, since that's cheap enough to run
/// on every reconnect without surprising the user with data usage.
class SyncService {
  final GuidelineRepository _repository;
  final ConnectivityService _connectivity;

  SyncService(this._repository, this._connectivity);

  StreamSubscription<bool>? _connectivitySub;
  bool _wasOffline = false;

  final _newGuidelinesController = StreamController<int>.broadcast();

  /// Emits the count of newly-appeared guidelines each time a sync
  /// finds any. UI subscribes to this to show/dismiss the banner.
  Stream<int> get newGuidelinesAvailable => _newGuidelinesController.stream;

  final _syncStateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get syncState => _syncStateController.stream;

  /// Call once at app start (e.g. from a Riverpod provider's build()).
  Future<void> start() async {
    _wasOffline = !(await _connectivity.isOnline);

    // Initial sync on app start, whether online or not — if offline,
    // this just quietly does nothing and the UI falls back to
    // whatever's already cached locally.
    if (!_wasOffline) {
      await _syncAndReport(isReconnect: false);
    }

    _connectivitySub = _connectivity.onStatusChanged.listen((isOnline) async {
      if (isOnline && _wasOffline) {
        // Transition: offline -> online. This is the moment that
        // matters for the "reconnect" UX from the original design.
        await _syncAndReport(isReconnect: true);
      }
      _wasOffline = !isOnline;
    });
  }

  Future<void> _syncAndReport({required bool isReconnect}) async {
    _syncStateController.add(
      isReconnect ? SyncState.reconnectSyncing : SyncState.syncing,
    );

    try {
      final beforeIds = await _repository.currentGuidelineIds();
      await _repository.syncLibrary();
      final afterIds = await _repository.currentGuidelineIds();

      final newCount = afterIds.difference(beforeIds).length;
      if (newCount > 0) {
        _newGuidelinesController.add(newCount);
      }

      _syncStateController.add(SyncState.idle);
    } catch (e) {
      // Sync failures are silent-by-design for the UI — the app just
      // keeps showing local data. Logged for our own debugging only.
      _syncStateController.add(SyncState.error);
    }
  }

  /// Manual pull-to-refresh / retry entry point for the UI.
  Future<void> syncNow() => _syncAndReport(isReconnect: false);

  void dispose() {
    _connectivitySub?.cancel();
    _newGuidelinesController.close();
    _syncStateController.close();
  }
}

enum SyncState { idle, syncing, reconnectSyncing, error }
