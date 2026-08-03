import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over connectivity_plus, reduced to the one thing the
/// rest of the app actually cares about: are we online or not.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onStatusChanged =>
      _connectivity.onConnectivityChanged.map(_isOnline);

  Future<bool> get isOnline async =>
      _isOnline(await _connectivity.checkConnectivity());

  bool _isOnline(List<ConnectivityResult> results) {
    // connectivity_plus can report multiple simultaneous interfaces
    // (e.g. wifi + mobile); "online" if any of them isn't `none`.
    return results.any((r) => r != ConnectivityResult.none);
  }
}
