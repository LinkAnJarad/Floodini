import 'dart:convert';

import 'package:flutter/services.dart';

import '../../locations/domain/aid_facility.dart';
import '../domain/queued_message.dart';
import '../domain/send_later_gateway.dart';

/// Talks to `SendLaterQueue` in MainActivity.kt.
class ChannelSendLaterGateway implements SendLaterGateway {
  ChannelSendLaterGateway({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.floodini.app/send_later');

  final MethodChannel _channel;

  @override
  Future<bool> hasSmsPermission() async =>
      await _channel.invokeMethod<bool>('hasSmsPermission') ?? false;

  @override
  Future<bool> requestSmsPermission() async =>
      await _channel.invokeMethod<bool>('requestSmsPermission') ?? false;

  @override
  Future<List<QueuedMessage>> list() async {
    final raw = await _channel.invokeMethod<String>('list') ?? '[]';
    final messages = [
      for (final item in jsonDecode(raw) as List)
        QueuedMessage.fromJson(Map<String, Object?>.from(item as Map)),
    ];
    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return messages;
  }

  @override
  Future<void> enqueue(QueuedMessage message) =>
      _channel.invokeMethod<void>('enqueue', jsonEncode(message.toJson()));

  @override
  Future<void> remove(String id) => _channel.invokeMethod<void>('remove', id);

  @override
  Future<SendSummary> sendNow() async {
    final raw = await _channel.invokeMethod<String>('sendNow') ?? '{}';
    return SendSummary.fromJson(Map<String, Object?>.from(jsonDecode(raw)));
  }

  @override
  Future<void> saveLocation(LocationFix fix) =>
      _channel.invokeMethod<void>('saveLocation', {
        'lat': fix.point.latitude,
        'lng': fix.point.longitude,
        'accuracy': fix.accuracyMeters,
        'time': fix.timestamp.millisecondsSinceEpoch,
      });

  @override
  Future<LocationFix?> lastLocation() async {
    final raw = await _channel.invokeMethod<String>('lastLocation');
    if (raw == null) return null;
    final json = Map<String, Object?>.from(jsonDecode(raw) as Map);
    return LocationFix(
      point: GeoPoint(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
      ),
      accuracyMeters: (json['accuracy'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['time'] as num).toInt(),
      ),
      lastKnown: true,
    );
  }
}
