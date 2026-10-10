import 'package:flutter/material.dart';

import '../../../ui/status_chip.dart';
import '../../../ui/theme.dart';
import '../domain/aid_facility.dart';
import '../domain/directions_launcher.dart';
import '../domain/nearby_aid_finder.dart';

class NearbyAidScreen extends StatefulWidget {
  const NearbyAidScreen({
    super.key,
    required this.finder,
    this.directions,
    this.showAppBar = true,
  });

  final NearbyAidFinder finder;

  /// Enables tap-for-walking-directions on each result when provided.
  final DirectionsLauncher? directions;
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

  Future<void> _openDirections(AidFacility facility) async {
    final launcher = widget.directions;
    if (launcher == null) return;
    final opened = await launcher.openWalkingDirections(
      destination: facility.point,
      label: facility.name,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a maps app.')),
      );
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Nearby aid'))
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Nearby aid', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'Hospitals, clinics and possible shelters near you.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _buildCautionCard(context),
            const SizedBox(height: 16),
            _buildFilters(context),
            const SizedBox(height: 16),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(
                  'Location search failed: $_error',
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
            if (_searching) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              _buildResults(context, _result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCautionCard(BuildContext context) {
    final colors = context.floodini;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cautionContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.caution.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.onCautionContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Works offline with the saved OpenStreetMap extract. Coverage is '
              'partial, and listings or open status can be incomplete or '
              'stale. Confirm with local authorities before you travel.',
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(color: colors.onCautionContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Facility types', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final kind in AidFacilityKind.values)
                  FilterChip(
                    label: Text(kind.label),
                    selected: _selectedKinds.contains(kind),
                    onSelected: (selected) => _toggleKind(kind, selected),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Radius', style: theme.textTheme.titleSmall),
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
    final theme = Theme.of(context);
    final outsideExtract =
        result.dataset.bounds != null &&
        !result.dataset.bounds!.contains(result.location.point);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found ${result.facilities.length} mapped result(s)',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(
                      label:
                          'Location ±${result.location.accuracyMeters.round()} m'
                          '${result.location.lastKnown ? ' · last known' : ''}',
                      tone: result.location.lastKnown
                          ? StatusTone.caution
                          : StatusTone.neutral,
                      icon: Icons.my_location,
                    ),
                    if (result.dataset.generatedAt != null)
                      StatusChip(
                        label:
                            'Map data: ${_formatDate(result.dataset.generatedAt!)}',
                        icon: Icons.update,
                      ),
                  ],
                ),
                if (outsideExtract)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Your location is outside this extract’s coordinate '
                      'bounds; an empty list does not mean no services exist '
                      'nearby.',
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: context.floodini.onCautionContainer,
                      ),
                    ),
                  ),
                if (result.dataset.generatedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'OSM snapshot: ${result.dataset.generatedAt!.toLocal()}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    result.dataset.attribution,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.directions != null && result.facilities.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Tap a result for walking directions in Google Maps. Maps needs '
              'mobile data unless you saved an offline map, and it cannot see '
              'flooded or closed roads. Verify locally before travelling.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (result.facilities.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No matching facilities were mapped within this radius in the '
                'bundled extract. Try a wider radius or verify with local '
                'authorities.',
                style: theme.textTheme.bodyLarge,
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
    final theme = Theme.of(context);
    final colors = context.floodini;
    final facility = nearby.facility;
    final address = [
      facility.city,
      facility.province,
    ].whereType<String>().where((value) => value.isNotEmpty).toSet().join(', ');
    final details = [
      if (address.isNotEmpty) (Icons.place_outlined, address),
      if (facility.emergency != null)
        (Icons.emergency_outlined, 'OSM emergency tag: ${facility.emergency}'),
      if (facility.phone != null) (Icons.call_outlined, facility.phone!),
      if (facility.openingHours != null)
        (Icons.schedule, facility.openingHours!),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('facility-${facility.id}'),
        onTap: widget.directions == null
            ? null
            : () => _openDirections(facility),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconFor(facility.kind),
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(facility.name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          facility.kind.label,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _formatDistance(nearby.distanceMeters),
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              if (details.isNotEmpty) const SizedBox(height: 12),
              for (final (icon, text) in details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(text, style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
              if (facility.provisional)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.cautionContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Mapped as a possible facility; confirm before relying on it.',
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: colors.onCautionContainer,
                    ),
                  ),
                ),
              if (widget.directions != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.directions_walk,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Walking directions',
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
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

  String _formatDate(DateTime time) {
    final local = time.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }
}
