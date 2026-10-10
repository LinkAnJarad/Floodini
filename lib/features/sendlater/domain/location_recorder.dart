import '../../locations/domain/aid_facility.dart';
import '../../locations/domain/location_provider.dart';
import 'send_later_gateway.dart';

/// Records the device position so queued messages can quote it later.
class LocationRecorder {
  const LocationRecorder({required this.provider, required this.gateway});

  final LocationProvider provider;
  final SendLaterGateway gateway;

  /// Returns the new fix, or null if none could be had (the previously
  /// recorded location stays in place).
  Future<LocationFix?> record() async {
    try {
      final fix = await provider.currentFix();
      await gateway.saveLocation(fix);
      return fix;
    } catch (_) {
      return null;
    }
  }
}
