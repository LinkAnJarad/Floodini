import 'dart:async';

import 'package:flutter/material.dart';

import '../../../ui/status_chip.dart';
import '../../../ui/theme.dart';
import '../../locations/domain/aid_facility.dart';
import '../domain/location_recorder.dart';
import '../domain/message_composer.dart';
import '../domain/profile_repository.dart';
import '../domain/queued_message.dart';
import '../domain/send_later_gateway.dart';
import '../domain/user_profile.dart';
import 'profile_form.dart';

/// Queue "I'm safe" and help messages; they are texted to the emergency
/// contacts automatically as soon as the phone has cellular service.
class SendLaterScreen extends StatefulWidget {
  const SendLaterScreen({
    super.key,
    required this.gateway,
    required this.profiles,
    required this.locationRecorder,
    this.showAppBar = true,
    this.retryEvery = const Duration(seconds: 20),
  });

  final SendLaterGateway gateway;
  final ProfileRepository profiles;
  final LocationRecorder locationRecorder;
  final bool showAppBar;

  /// How often the open app re-tries pending messages. A background worker
  /// also retries about once a minute while anything is queued.
  final Duration retryEvery;

  @override
  State<SendLaterScreen> createState() => _SendLaterScreenState();
}

class _SendLaterScreenState extends State<SendLaterScreen>
    with WidgetsBindingObserver {
  final _note = TextEditingController();
  UserProfile? _profile;
  List<QueuedMessage> _items = const [];
  LocationFix? _location;
  bool _hasPermission = true;
  bool _busy = false;
  String? _status;
  Timer? _timer;

  bool get _hasPending => _items.any((m) => !m.isSent);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(widget.retryEvery, (_) {
      if (_hasPending && !_busy) unawaited(_attemptSend(quiet: true));
    });
    unawaited(_refresh());
    unawaited(_updateLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _note.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_refresh());
    if (_hasPending && !_busy) unawaited(_attemptSend(quiet: true));
  }

  Future<void> _refresh() async {
    try {
      final profile = await widget.profiles.load();
      final items = await widget.gateway.list();
      final location = await widget.gateway.lastLocation();
      final permission = await widget.gateway.hasSmsPermission();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _items = items;
        _location = location;
        _hasPermission = permission;
      });
    } catch (error) {
      if (mounted) setState(() => _status = 'Could not load the queue: $error');
    }
  }

  Future<void> _updateLocation() async {
    final fix = await widget.locationRecorder.record();
    if (fix != null && mounted) setState(() => _location = fix);
  }

  Future<void> _allowSms() async {
    final granted = await widget.gateway.requestSmsPermission();
    if (mounted) setState(() => _hasPermission = granted);
  }

  Future<void> _queue(MessageKind kind) async {
    final profile = _profile;
    if (profile == null || _busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      if (!_hasPermission) {
        _hasPermission = await widget.gateway.requestSmsPermission();
      }
      await _updateLocation();
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final now = DateTime.now();
      await widget.gateway.enqueue(
        kind == MessageKind.safe
            ? MessageComposer.safe(id: id, profile: profile, now: now)
            : MessageComposer.help(
                id: id,
                profile: profile,
                now: now,
                note: _note.text,
              ),
      );
      if (kind == MessageKind.help) _note.clear();
      await _attemptSend();
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Could not queue the message: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attemptSend({bool quiet = false}) async {
    try {
      final summary = await widget.gateway.sendNow();
      await _refresh();
      if (!mounted || (quiet && summary.sent == 0)) return;
      setState(() => _status = _describe(summary));
    } catch (error) {
      if (mounted && !quiet) setState(() => _status = 'Send failed: $error');
    }
  }

  String _describe(SendSummary summary) {
    if (summary.sent > 0 && summary.failed == 0) {
      return 'Sent ${summary.sent} message(s).';
    }
    if (summary.sent > 0) {
      return 'Sent ${summary.sent}; ${summary.failed} still waiting '
          '(${summary.error ?? 'will retry'}).';
    }
    if (summary.error != null) {
      return 'Not sent yet: ${summary.error}. Floodini will keep retrying.';
    }
    return 'Nothing waiting to send.';
  }

  Future<void> _remove(QueuedMessage message) async {
    await widget.gateway.remove(message.id);
    await _refresh();
  }

  Future<void> _clearSent() async {
    for (final message in _items.where((m) => m.isSent)) {
      await widget.gateway.remove(message.id);
    }
    await _refresh();
  }

  Future<void> _editContacts() async {
    final profile = _profile;
    if (profile == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            _EditContactsPage(initial: profile, repository: widget.profiles),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Send later'))
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Send later', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'Queue a message now. Floodini texts your emergency contacts as '
              'soon as your phone has cell signal.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _buildActions(context),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _status!,
                  key: const Key('send-later-status'),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 16),
            _buildContactsCard(context),
            _buildLocationCard(context),
            if (!_hasPermission) _buildPermissionCard(context),
            const SizedBox(height: 16),
            _buildQueue(context),
            const SizedBox(height: 16),
            Text(
              'It sends from your own SIM, even if the app is in the '
              'background (checked about once a minute). Standard SMS rates '
              'may apply. If you can reach responders, call 911 instead. '
              'Sent means handed to the network, not read by your contact.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsCard(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _profile;
    return Card(
      child: ListTile(
        minVerticalPadding: 12,
        leading: Icon(
          Icons.contacts_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          profile == null
              ? 'No profile yet'
              : '${profile.name} · ${profile.contacts.length} contact(s)',
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          profile == null
              ? 'Restart the app to finish setup.'
              : profile.contacts.map((c) => c.name).join(', '),
        ),
        trailing: TextButton(
          key: const Key('edit-contacts-button'),
          onPressed: profile == null ? null : _editContacts,
          child: const Text('Edit'),
        ),
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    final theme = Theme.of(context);
    final fix = _location;
    return Card(
      child: ListTile(
        minVerticalPadding: 12,
        leading: Icon(Icons.place_outlined, color: theme.colorScheme.primary),
        title: Text(
          fix == null
              ? 'No location recorded yet'
              : '${fix.point.latitude.toStringAsFixed(5)}, '
                    '${fix.point.longitude.toStringAsFixed(5)} '
                    '(±${fix.accuracyMeters.round()} m)',
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          fix == null
              ? 'Messages will say the location is unknown.'
              : 'Last recorded ${_ago(fix.timestamp)}. Sent with your messages.',
        ),
        trailing: TextButton(
          key: const Key('update-location-button'),
          onPressed: _busy ? null : _updateLocation,
          child: const Text('Update'),
        ),
      ),
    );
  }

  Widget _buildPermissionCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: ListTile(
        minVerticalPadding: 12,
        leading: Icon(
          Icons.sms_failed_outlined,
          color: theme.colorScheme.onErrorContainer,
        ),
        title: Text(
          'SMS permission needed',
          style: theme.textTheme.titleSmall!.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        subtitle: Text(
          'Without it, queued messages cannot be sent.',
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
        trailing: TextButton(
          key: const Key('allow-sms-button'),
          onPressed: _allowSms,
          child: const Text('Allow'),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final canQueue = _profile != null && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const Key('safe-button'),
          onPressed: canQueue ? () => _queue(MessageKind.safe) : null,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text("Queue \"I'm safe\" · Ligtas ako"),
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: FloodiniPalette.sosRed, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('help-note'),
                  controller: _note,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Optional note for the help request',
                    hintText: 'e.g. Trapped on 2nd floor, 3 people',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const Key('help-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: FloodiniPalette.sosRed,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: canQueue ? () => _queue(MessageKind.help) : null,
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Queue help request'),
                ),
              ],
            ),
          ),
        ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildQueue(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Queue', style: theme.textTheme.titleLarge)),
            if (_hasPending)
              TextButton(
                key: const Key('send-now-button'),
                onPressed: _busy ? null : _attemptSend,
                child: const Text('Send now'),
              ),
            if (_items.any((m) => m.isSent))
              TextButton(
                key: const Key('clear-sent-button'),
                onPressed: _clearSent,
                child: const Text('Clear sent'),
              ),
          ],
        ),
        if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                const Text('Nothing queued.'),
              ],
            ),
          )
        else
          for (final message in _items) _buildItem(context, message),
      ],
    );
  }

  Widget _buildItem(BuildContext context, QueuedMessage message) {
    final theme = Theme.of(context);
    final colors = context.floodini;
    final safe = message.kind == MessageKind.safe;
    final StatusChip chip;
    if (message.isSent) {
      chip = const StatusChip(
        label: 'Sent',
        tone: StatusTone.safe,
        icon: Icons.check_circle_outline,
      );
    } else if (message.sentCount > 0) {
      chip = const StatusChip(
        label: 'Partly sent',
        tone: StatusTone.caution,
        icon: Icons.schedule,
      );
    } else {
      chip = const StatusChip(
        label: 'Waiting for signal',
        tone: StatusTone.caution,
        icon: Icons.schedule,
      );
    }
    return Card(
      key: Key('queued-${message.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  safe
                      ? Icons.verified_user_outlined
                      : Icons.warning_amber_rounded,
                  color: safe ? colors.safe : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    safe ? "I'm safe" : 'Help request',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: Key('remove-${message.id}'),
                  tooltip: message.isSent ? 'Remove' : 'Cancel',
                  onPressed: () => _remove(message),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  chip,
                  Text(
                    '${message.sentCount}/${message.recipients.length} sent · '
                    'queued ${_ago(message.createdAt)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            for (final r in message.recipients.where((r) => !r.sent))
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 12),
                child: Text(
                  '${r.name}: ${r.error ?? 'waiting for signal'}',
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: r.error == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}

class _EditContactsPage extends StatefulWidget {
  const _EditContactsPage({required this.initial, required this.repository});

  final UserProfile initial;
  final ProfileRepository repository;

  @override
  State<_EditContactsPage> createState() => _EditContactsPageState();
}

class _EditContactsPageState extends State<_EditContactsPage> {
  UserProfile? _draft;

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    await widget.repository.save(draft);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit contacts')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProfileForm(
              initial: widget.initial,
              showDisclaimer: false,
              onChanged: (profile) => setState(() => _draft = profile),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('save-contacts-button'),
              onPressed: _draft == null ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
