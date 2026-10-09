import 'aid_facility.dart';

abstract interface class LocationProvider {
  Future<LocationFix> currentFix();
}
