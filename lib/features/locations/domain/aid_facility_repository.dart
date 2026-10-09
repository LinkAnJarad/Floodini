import 'aid_facility.dart';

abstract interface class AidFacilityRepository {
  Future<AidFacilityDataset> load();
}
