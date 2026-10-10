import 'aid_facility.dart';

abstract interface class DirectionsLauncher {
  /// Opens turn-by-turn walking directions from the user's current position to
  /// [destination] in a maps app. Returns false if no app could be opened.
  Future<bool> openWalkingDirections({
    required GeoPoint destination,
    required String label,
  });
}
