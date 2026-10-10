import '../../locations/domain/aid_facility.dart';
import 'queued_message.dart';

class SendSummary {
  const SendSummary({required this.sent, required this.failed, this.error});

  final int sent;
  final int failed;
  final String? error;

  factory SendSummary.fromJson(Map<String, Object?> json) => SendSummary(
    sent: (json['sent'] as num?)?.toInt() ?? 0,
    failed: (json['failed'] as num?)?.toInt() ?? 0,
    error: json['error'] as String?,
  );
}

/// The persistent queue and the SMS sender. Owned by the Android side so the
/// background worker and the app share one queue and never double-send.
abstract interface class SendLaterGateway {
  Future<bool> hasSmsPermission();

  Future<bool> requestSmsPermission();

  Future<List<QueuedMessage>> list();

  /// Adds [message] and schedules background retries.
  Future<void> enqueue(QueuedMessage message);

  Future<void> remove(String id);

  /// Tries to send everything pending right now.
  Future<SendSummary> sendNow();

  Future<void> saveLocation(LocationFix fix);

  Future<LocationFix?> lastLocation();
}
