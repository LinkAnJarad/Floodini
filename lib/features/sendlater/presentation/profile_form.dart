import 'package:flutter/material.dart';

import '../domain/user_profile.dart';

/// Name + emergency contacts (+ optional disclaimer checkbox). Reports the
/// valid [UserProfile] through [onChanged], or null while the form is invalid.
class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.onChanged,
    this.initial,
    this.showDisclaimer = true,
  });

  final ValueChanged<UserProfile?> onChanged;
  final UserProfile? initial;
  final bool showDisclaimer;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ContactRow {
  _ContactRow({String name = '', String number = ''})
    : name = TextEditingController(text: name),
      number = TextEditingController(text: number);

  final TextEditingController name;
  final TextEditingController number;

  void dispose() {
    name.dispose();
    number.dispose();
  }
}

class _ProfileFormState extends State<ProfileForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final List<_ContactRow> _rows = [
    for (final c in widget.initial?.contacts ?? const <EmergencyContact>[])
      _ContactRow(name: c.name, number: c.number),
    if (widget.initial == null || widget.initial!.contacts.isEmpty)
      _ContactRow(),
  ];
  late bool _accepted = widget.initial?.disclaimerAccepted ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _name.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  UserProfile? _validProfile() {
    final name = _name.text.trim();
    if (name.isEmpty) return null;
    final contacts = <EmergencyContact>[];
    for (final row in _rows) {
      final contactName = row.name.text.trim();
      final rawNumber = row.number.text.trim();
      if (contactName.isEmpty && rawNumber.isEmpty) continue;
      final number = normalizePhoneNumber(rawNumber);
      if (contactName.isEmpty || number == null) return null;
      contacts.add(EmergencyContact(name: contactName, number: number));
    }
    if (contacts.isEmpty) return null;
    if (widget.showDisclaimer && !_accepted) return null;
    return UserProfile(
      name: name,
      contacts: contacts,
      disclaimerAccepted: widget.showDisclaimer
          ? _accepted
          : (widget.initial?.disclaimerAccepted ?? true),
    );
  }

  void _emit() {
    if (mounted) widget.onChanged(_validProfile());
  }

  void _changed(VoidCallback update) {
    setState(update);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('profile-name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Your name'),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 24),
        Text('Emergency contacts', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'These people get your "I\'m safe" and help messages by SMS.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _rows.length; i++) _buildRow(i),
        OutlinedButton.icon(
          key: const Key('add-contact-button'),
          onPressed: () => _changed(() => _rows.add(_ContactRow())),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Add another contact'),
        ),
        if (widget.showDisclaimer) ...[
          const SizedBox(height: 24),
          Material(
            color: theme.colorScheme.surfaceContainerLowest,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: _accepted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: _accepted ? 2 : 1.5,
              ),
            ),
            child: CheckboxListTile(
              key: const Key('disclaimer-checkbox'),
              controlAffinity: ListTileControlAffinity.leading,
              value: _accepted,
              onChanged: (value) => _changed(() => _accepted = value ?? false),
              title: Text(
                'I understand Floodini is not an official emergency service. '
                'It cannot see live weather, evacuation orders, or road '
                'conditions, and queued SMS may be delayed or fail. In an '
                'emergency I will call 911 or my local responders. Standard '
                'SMS charges may apply.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRow(int index) {
    final theme = Theme.of(context);
    final row = _rows[index];
    final rawNumber = row.number.text.trim();
    final invalidNumber =
        rawNumber.isNotEmpty && normalizePhoneNumber(rawNumber) == null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Contact ${index + 1}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (_rows.length > 1)
                  IconButton(
                    key: Key('remove-contact-$index'),
                    tooltip: 'Remove contact',
                    onPressed: () => _changed(() {
                      final removed = _rows.removeAt(index);
                      // Dispose after the rebuild has detached the old fields.
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => removed.dispose(),
                      );
                    }),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: Column(
                children: [
                  TextField(
                    key: Key('contact-name-$index'),
                    controller: row.name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Contact name',
                    ),
                    onChanged: (_) => _emit(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: Key('contact-number-$index'),
                    controller: row.number,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Mobile number',
                      errorText: invalidNumber ? 'Check the number' : null,
                    ),
                    onChanged: (_) => _changed(() {}),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
