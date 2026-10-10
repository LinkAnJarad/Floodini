import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodini/features/locations/domain/aid_facility.dart';
import 'package:floodini/features/sendlater/data/channel_send_later_gateway.dart';
import 'package:floodini/features/sendlater/data/prefs_profile_repository.dart';
import 'package:floodini/features/sendlater/domain/message_composer.dart';
import 'package:floodini/features/sendlater/domain/queued_message.dart';
import 'package:floodini/features/sendlater/domain/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = UserProfile(
  name: '  Juan Cruz ',
  contacts: [EmergencyContact(name: 'Maria', number: '09171234567')],
  disclaimerAccepted: true,
);

void main() {
  group('normalizePhoneNumber', () {
    test('strips separators and keeps a leading plus', () {
      expect(normalizePhoneNumber('0917 123-4567'), '09171234567');
      expect(normalizePhoneNumber('+63 (917) 123 4567'), '+639171234567');
    });

    test('rejects things that are not phone numbers', () {
      expect(normalizePhoneNumber(''), isNull);
      expect(normalizePhoneNumber('12ab'), isNull);
      expect(normalizePhoneNumber('12345'), isNull);
      expect(normalizePhoneNumber('1' * 16), isNull);
    });
  });

  group('MessageComposer', () {
    final now = DateTime(2026, 10, 10, 14, 30);

    test('safe message names the sender and leaves room for the location', () {
      final message = MessageComposer.safe(
        id: '1',
        profile: _profile,
        now: now,
      );
      expect(message.template, '[Floodini] Juan Cruz: I am safe. {LOCATION}');
      expect(message.recipients.single.number, '09171234567');
      expect(message.recipients.single.sent, isFalse);
    });

    test('help message includes the note only when given', () {
      final withNote = MessageComposer.help(
        id: '2',
        profile: _profile,
        now: now,
        note: ' Trapped upstairs ',
      );
      expect(withNote.template, contains('Trapped upstairs {LOCATION}'));

      final plain = MessageComposer.help(id: '3', profile: _profile, now: now);
      expect(
        plain.template,
        '[Floodini] HELP NEEDED: Juan Cruz. '
        '{LOCATION} Please contact local responders.',
      );
    });

    test('messages are plain ASCII so each SMS part holds 160 characters', () {
      final text = MessageComposer.help(
        id: '4',
        profile: _profile,
        now: now,
        note: 'No power',
      ).template;
      expect(text.codeUnits.every((c) => c < 128), isTrue);
    });
  });

  test('QueuedMessage survives a JSON round trip', () {
    final original = QueuedMessage(
      id: '9',
      kind: MessageKind.help,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      template: 'hello {LOCATION}',
      recipients: const [
        QueuedRecipient(name: 'A', number: '1', sent: true),
        QueuedRecipient(name: 'B', number: '2', error: 'No cellular service'),
      ],
    );
    final copy = QueuedMessage.fromJson(original.toJson());

    expect(copy.id, '9');
    expect(copy.kind, MessageKind.help);
    expect(copy.createdAt, original.createdAt);
    expect(copy.sentCount, 1);
    expect(copy.isSent, isFalse);
    expect(copy.recipients[1].error, 'No cellular service');
  });

  test('PrefsProfileRepository saves and reloads the profile', () async {
    SharedPreferences.setMockInitialValues({});
    const repository = PrefsProfileRepository();
    expect(await repository.load(), isNull);

    await repository.save(_profile);
    final loaded = await repository.load();

    expect(loaded!.name, '  Juan Cruz ');
    expect(loaded.contacts.single.number, '09171234567');
    expect(loaded.isComplete, isTrue);
  });

  group('ChannelSendLaterGateway', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('test/send_later');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            switch (call.method) {
              case 'list':
                return '[{"id":"a","kind":"safe","createdAt":1000,'
                    '"template":"t","recipients":[{"name":"M","number":"1",'
                    '"sent":false,"error":null}]},'
                    '{"id":"b","kind":"help","createdAt":2000,'
                    '"template":"t","recipients":[]}]';
              case 'sendNow':
                return '{"sent":1,"failed":2,"error":"No cellular service"}';
              case 'lastLocation':
                return '{"lat":14.5,"lng":121.0,"accuracy":9.0,"time":5000}';
            }
            return null;
          });
    });

    test('lists newest first', () async {
      final items = await ChannelSendLaterGateway(channel: channel).list();
      expect(items.map((m) => m.id), ['b', 'a']);
    });

    test('sends the message as JSON and parses the summary', () async {
      final gateway = ChannelSendLaterGateway(channel: channel);
      await gateway.enqueue(
        MessageComposer.safe(id: 'x', profile: _profile, now: DateTime.now()),
      );
      expect(calls.single.method, 'enqueue');
      expect(calls.single.arguments, contains('"id":"x"'));

      final summary = await gateway.sendNow();
      expect(summary.sent, 1);
      expect(summary.failed, 2);
      expect(summary.error, 'No cellular service');
    });

    test('round-trips the last recorded location', () async {
      final gateway = ChannelSendLaterGateway(channel: channel);
      await gateway.saveLocation(
        LocationFix(
          point: const GeoPoint(latitude: 14.5, longitude: 121.0),
          accuracyMeters: 9,
          timestamp: DateTime.fromMillisecondsSinceEpoch(5000),
        ),
      );
      expect(calls.single.arguments, {
        'lat': 14.5,
        'lng': 121.0,
        'accuracy': 9.0,
        'time': 5000,
      });

      final fix = await gateway.lastLocation();
      expect(fix!.point.latitude, 14.5);
      expect(fix.accuracyMeters, 9);
      expect(fix.timestamp.millisecondsSinceEpoch, 5000);
    });
  });
}
