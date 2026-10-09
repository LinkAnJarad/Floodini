import 'package:flutter/material.dart';

import '../domain/aid_facility.dart';
import '../domain/nearby_aid_finder.dart';

class NearbyAidScreen extends StatefulWidget {
  const NearbyAidScreen({
    super.key,
    required this.finder,
    this.showAppBar = true,
  });

  final NearbyAidFinder finder;
  final bool showAppBar;

  @override
  State<NearbyAidScreen> createState() => _NearbyAidScreenState();
}

class _NearbyAidScreenState extends State<NearbyAidScreen> {
  final Set<AidFacilityKind> _selectedKinds = Set.of(AidFacilityKind.values);
  double _radiusMeters = 25000;
  NearbyAidSearchResult? _result;
  String? _error;
  bool _searching = false;

  Future<void> _findNearby() async {
    if (_selectedKinds.isEmpty || _searching) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final result = await widget.finder.findNearby(
        kinds: Set.unmodifiable(_selectedKinds),
        radiusMeters: _radiusMeters,
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _toggleKind(AidFacilityKind kind, bool selected) {
    setState(() {
      if (selected) {
        _selectedKinds.add(kind);
      } else {
        _selectedKinds.remove(kind);
      }
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Nearby aid'))
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Nearby aid',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            _buildCautionCard(context),
            const SizedBox(height: 12),
            _buildFilters(context),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('find-nearby-button'),
              onPressed: _searching || _selectedKinds.isEmpty
                  ? null
                  : _findNearby,
              icon: const Icon(Icons.my_location),
              label: Text(_searching ? 'Getting location…' : 'Find nearby aid'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText('Location search failed: $_error'),
                ),
              ),
            ],
            if (_searching) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_result != null) ...[
              const SizedBox(height: 12),
              _buildResults(context, _result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCautionCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Offline nearby lookup',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Uses your device location and the bundled OpenStreetMap extract. '
              'Coverage is partial; listings and emergency/open status can be '
              'incomplete or stale. Confirm with local authorities before travel.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Facility types',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final kind in AidFacilityKind.values)
                  FilterChip(
                    label: Text(kind.label),
                    selected: _selectedKinds.contains(kind),
                    onSelected: (selected) => _toggleKind(kind, selected),
                  ),
              ],
            ),
            Row(
              children: [
                const Text('Radius'),
                const SizedBox(width: 12),
                DropdownButton<double>(
                  key: const Key('search-radius-dropdown'),
                  value: _radiusMeters,
                  items: const [5000.0, 10000.0, 25000.0, 50000.0]
                      .map(
                        (meters) => DropdownMenuItem(
                          value: meters,
                          child: Text('${(meters / 1000).round()} km'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _radiusMeters = value);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, NearbyAidSearchResult result) {
    final outsideExtract =
        result.dataset.bounds != null &&
        !result.dataset.bounds!.contains(result.location.point);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found ${result.facilities.length} mapped result(s)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Location accuracy ±${result.location.accuracyMeters.round()} m'
                  '${result.location.lastKnown ? ' · last known fix' : ''}',
                ),
                if (outsideExtract)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Your location is outside this extract’s coordinate bounds; '
                      'an empty list does not mean no services exist nearby.',
                    ),
                  ),
                if (result.dataset.generatedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'OSM snapshot: ${result.dataset.generatedAt!.toLocal()}',
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(result.dataset.attribution),
                ),
              ],
            ),
          ),
        ),
        if (result.facilities.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No matching facilities were mapped within this radius in the '
                'bundled extract. Try a wider radius or verify with local authorities.',
              ),
            ),
          )
        else
          for (final nearby in result.facilities)
            _facilityCard(context, nearby),
      ],
    );
  }

  Widget _facilityCard(BuildContext context, NearbyAidFacility nearby) {
    final facility = nearby.facility;
    final address = [
      facility.city,
      facility.province,
    ].whereType<String>().where((value) => value.isNotEmpty).toSet().join(', ');
    return Card(
      child: ListTile(
        leading: Icon(_iconFor(facility.kind)),
        title: Text(facility.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(facility.kind.label),
            if (address.isNotEmpty) Text(address),
            if (facility.emergency != null)
              Text('OSM emergency tag: ${facility.emergency}'),
            if (facility.provisional)
              const Text(
                'Mapped as a possible facility; confirm before relying on it.',
              ),
            if (facility.phone != null) Text(facility.phone!),
            if (facility.openingHours != null) Text(facility.openingHours!),
          ],
        ),
        trailing: Text(_formatDistance(nearby.distanceMeters)),
        isThreeLine: true,
      ),
    );
  }

  IconData _iconFor(AidFacilityKind kind) => switch (kind) {
    AidFacilityKind.hospital => Icons.local_hospital_outlined,
    AidFacilityKind.clinic => Icons.medical_services_outlined,
    AidFacilityKind.shelterCandidate => Icons.home_work_outlined,
  };

  String _formatDistance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
}
