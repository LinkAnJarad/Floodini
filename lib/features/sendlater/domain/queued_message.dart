enum MessageKind { safe, help }

class QueuedRecipient {
  const QueuedRecipient({
    required this.name,
    required this.number,
    this.sent = false,
    this.error,
  });

  final String name;
  final String number;
  final bool sent;
  final String? error;

  Map<String, Object?> toJson() => {
    'name': name,
    'number': number,
    'sent': sent,
    'error': error,
  };

  factory QueuedRecipient.fromJson(Map<String, Object?> json) =>
      QueuedRecipient(
        name: json['name'] as String? ?? '',
        number: json['number'] as String? ?? '',
        sent: json['sent'] as bool? ?? false,
        error: json['error'] as String?,
      );
}

/// A message waiting to be texted to every recipient. [template] may contain
/// the location placeholder, which the sender fills in with the last recorded
/// location at the moment of sending.
class QueuedMessage {
  const QueuedMessage({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.template,
    required this.recipients,
  });

  final String id;
  final MessageKind kind;
  final DateTime createdAt;
  final String template;
  final List<QueuedRecipient> recipients;

  int get sentCount => recipients.where((r) => r.sent).length;
  bool get isSent => recipients.isNotEmpty && sentCount == recipients.length;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'template': template,
    'recipients': recipients.map((r) => r.toJson()).toList(),
  };

  factory QueuedMessage.fromJson(Map<String, Object?> json) => QueuedMessage(
    id: json['id'] as String,
    kind: MessageKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => MessageKind.help,
    ),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['createdAt'] as num).toInt(),
    ),
    template: json['template'] as String? ?? '',
    recipients: [
      for (final raw in (json['recipients'] as List? ?? const []))
        QueuedRecipient.fromJson(Map<String, Object?>.from(raw as Map)),
    ],
  );
}
