import 'queued_message.dart';
import 'user_profile.dart';

/// Builds the SMS text. Kept to plain ASCII so each part holds 160 characters.
class MessageComposer {
  const MessageComposer._();

  /// Replaced by the sender with the last recorded location.
  static const locationPlaceholder = '{LOCATION}';

  static QueuedMessage safe({
    required String id,
    required UserProfile profile,
    required DateTime now,
  }) => _build(
    id,
    MessageKind.safe,
    profile,
    now,
    '[Floodini] ${profile.name.trim()}: I am safe. $locationPlaceholder',
  );

  static QueuedMessage help({
    required String id,
    required UserProfile profile,
    required DateTime now,
    String note = '',
  }) {
    final trimmed = note.trim();
    return _build(
      id,
      MessageKind.help,
      profile,
      now,
      '[Floodini] HELP NEEDED: ${profile.name.trim()}. '
      '${trimmed.isEmpty ? '' : '$trimmed '}'
      '$locationPlaceholder Please contact local responders.',
    );
  }

  static QueuedMessage _build(
    String id,
    MessageKind kind,
    UserProfile profile,
    DateTime now,
    String template,
  ) => QueuedMessage(
    id: id,
    kind: kind,
    createdAt: now,
    template: template,
    recipients: [
      for (final contact in profile.contacts)
        QueuedRecipient(name: contact.name, number: contact.number),
    ],
  );
}
