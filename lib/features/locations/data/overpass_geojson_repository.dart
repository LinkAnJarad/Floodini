import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/aid_facility.dart';
import '../domain/aid_facility_repository.dart';

class OverpassGeoJsonRepository implements AidFacilityRepository {
  OverpassGeoJsonRepository({AssetBundle? assetBundle})
    : assetBundle = assetBundle ?? rootBundle;

  static const assetPath = 'assets/export.geojson';

  final AssetBundle assetBundle;

  @override
  Future<AidFacilityDataset> load() async =>
      parseGeoJson(await assetBundle.loadString(assetPath));

  static AidFacilityDataset parseGeoJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map || decoded['type'] != 'FeatureCollection') {
      throw const FormatException('Expected a GeoJSON FeatureCollection.');
    }
    final rawFeatures = decoded['features'];
    if (rawFeatures is! List) {
      throw const FormatException(
        'GeoJSON FeatureCollection has no features array.',
      );
    }

    final facilities = <AidFacility>[];
    var west = double.infinity;
    var south = double.infinity;
    var east = double.negativeInfinity;
    var north = double.negativeInfinity;

    for (var index = 0; index < rawFeatures.length; index++) {
      final rawFeature = rawFeatures[index];
      if (rawFeature is! Map) continue;
      final properties = _map(rawFeature['properties']);
      final geometry = _map(rawFeature['geometry']);
      if (geometry['type'] != 'Point') continue;
      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2) continue;
      final longitude = _finiteDouble(coordinates[0]);
      final latitude = _finiteDouble(coordinates[1]);
      if (longitude == null || latitude == null) continue;
      if (longitude < -180 ||
          longitude > 180 ||
          latitude < -90 ||
          latitude > 90) {
        continue;
      }

      west = longitude < west ? longitude : west;
      east = longitude > east ? longitude : east;
      south = latitude < south ? latitude : south;
      north = latitude > north ? latitude : north;

      final amenity = _tag(properties, 'amenity');
      final healthcare = _tag(properties, 'healthcare');
      final socialFacility = _tag(properties, 'social_facility');
      final socialFacilityFor = _tagList(properties['social_facility:for']);
      final rawName = _tag(properties, 'name');
      final loweredName = rawName?.toLowerCase() ?? '';
      final explicitlyEvacuationNamed =
          loweredName.contains('evacuation center') ||
          loweredName.contains('evacuation centre');

      final AidFacilityKind? kind;
      if (amenity == 'hospital' || healthcare == 'hospital') {
        kind = AidFacilityKind.hospital;
      } else if (amenity == 'clinic' ||
          amenity == 'doctors' ||
          healthcare == 'clinic' ||
          healthcare == 'doctor') {
        kind = AidFacilityKind.clinic;
      } else if (socialFacility == 'shelter' &&
          (socialFacilityFor.contains('displaced') ||
              explicitlyEvacuationNamed)) {
        kind = AidFacilityKind.shelterCandidate;
      } else {
        kind = null;
      }
      if (kind == null) continue;

      final fallbackName = switch (kind) {
        AidFacilityKind.hospital => 'Unnamed hospital',
        AidFacilityKind.clinic => 'Unnamed clinic / health center',
        AidFacilityKind.shelterCandidate => 'Unnamed shelter candidate',
      };
      facilities.add(
        AidFacility(
          id: _tag(properties, '@id') ?? 'feature/$index',
          name: rawName ?? fallbackName,
          kind: kind,
          point: GeoPoint(latitude: latitude, longitude: longitude),
          city: _tag(properties, 'addr:city'),
          province: _tag(properties, 'addr:province'),
          phone: _tag(properties, 'phone') ?? _tag(properties, 'contact:phone'),
          openingHours: _tag(properties, 'opening_hours'),
          emergency: _tag(properties, 'emergency'),
          source: _tag(properties, 'source'),
          provisional: loweredName.contains('possible'),
        ),
      );
    }

    final bounds = west.isFinite
        ? GeoBounds(west: west, south: south, east: east, north: north)
        : null;
    return AidFacilityDataset(
      sourceFeatureCount: rawFeatures.length,
      facilities: List.unmodifiable(facilities),
      generatedAt: DateTime.tryParse(_tag(decoded, 'timestamp') ?? ''),
      attribution:
          _tag(decoded, 'copyright') ?? '© OpenStreetMap contributors · ODbL',
      bounds: bounds,
    );
  }

  static Map _map(Object? value) => value is Map ? value : const {};

  static String? _tag(Map values, String key) {
    final value = values[key];
    if (value == null) return null;
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  static List<String> _tagList(Object? value) =>
      value
          ?.toString()
          .toLowerCase()
          .split(RegExp(r'[;,]'))
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList() ??
      const [];

  static double? _finiteDouble(Object? value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return parsed != null && parsed.isFinite ? parsed : null;
  }
}
