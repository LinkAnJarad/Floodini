import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodini/features/locations/domain/aid_facility.dart';
import 'package:floodini/features/locations/domain/location_provider.dart';
import 'package:floodini/features/sendlater/domain/location_recorder.dart';
import 'package:floodini/features/sendlater/domain/profile_repository.dart';
import 'package:floodini/features/sendlater/domain/queued_message.dart';
import 'package:floodini/features/sendlater/domain/send_later_gateway.dart';
import 'package:floodini/features/sendlater/domain/user_profile.dart';
import 'package:floodini/features/sendlater/presentation/send_later_screen.dart';

const _profile = UserProfile(
  name: 'Juan Cruz',
  contacts: [
    EmergencyContact(name: 'Maria', number: '09171234567'),
    EmergencyContact(name: 'Pedro', number: '+639187654321'),
  ],
  disclaimerAccepted: true,
);

void main() {
  late _Gateway gateway;

  Future<void> pump(
    WidgetTester tester, {
    bool permission = true,
    bool locationWorks = true,
  }) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    gateway = _Gateway(permission: permission);
    await tester.pumpWidget(
      MaterialApp(
        home: SendLaterScreen(
          gateway: gateway,
          profiles: _Profiles(),
          locationRecorder: LocationRecorder(
            provider: _Location(works: locationWorks),
            gateway: gateway,
          ),
          retryEvery: const Duration(hours: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('queues an "I am safe" message for every contact', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('safe-button')));
    await tester.pumpAndSettle();

    final message = gateway.queue.single;
    expect(message.kind, MessageKind.safe);
    expect(message.recipients.map((r) => r.name), ['Maria', 'Pedro']);
    expect(message.template, contains('Juan Cruz'));
    expect(message.template, contains('{LOCATION}'));
    expect(gateway.sendNowCalls, 1);
  });

  testWidgets('queues a help request with the optional note', (tester) async {
    await pump(tester);
    await tester.enterText(
      find.byKey(const Key('help-note')),
      'Trapped on 2nd floor',
    );
    await tester.tap(find.byKey(const Key('help-button')));
    await tester.pumpAndSettle();

    final message = gateway.queue.single;
    expect(message.kind, MessageKind.help);
    expect(message.template, contains('HELP NEEDED'));
    expect(message.template, contains('Trapped on 2nd floor'));
  });

  testWidgets('records the location before queueing', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('safe-button')));
    await tester.pumpAndSettle();

    expect(gateway.savedLocations.last.point.latitude, 14.65);
    expect(find.textContaining('14.65000, 121.10000'), findsOneWidget);
  });

  testWidgets('still queues when no location could be recorded', (
    tester,
  ) async {
    await pump(tester, locationWorks: false);
    await tester.tap(find.byKey(const Key('safe-button')));
    await tester.pumpAndSettle();

    expect(gateway.queue, hasLength(1));
    expect(find.text('No location recorded yet'), findsOneWidget);
  });

  testWidgets('shows waiting messages and retries them with Send now', (
    tester,
  ) async {
    await pump(tester);
    gateway.sendResult = const SendSummary(
      sent: 0,
      failed: 1,
      error: 'No cellular service',
    );
    await tester.tap(find.byKey(const Key('safe-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('0/2 sent'), findsOneWidget);
    expect(find.textContaining('Floodini will keep retrying'), findsOneWidget);

    // Signal returns.
    gateway.sendResult = const SendSummary(sent: 2, failed: 0);
    gateway.markAllSentOnNextSend = true;
    await tester.tap(find.byKey(const Key('send-now-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('2/2 sent'), findsOneWidget);
    expect(find.byKey(const Key('send-now-button')), findsNothing);
    expect(find.byKey(const Key('clear-sent-button')), findsOneWidget);
  });

  testWidgets('cancels a queued message', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('safe-button')));
    await tester.pumpAndSettle();
    final id = gateway.queue.single.id;

    await tester.tap(find.byKey(Key('remove-$id')));
    await tester.pumpAndSettle();

    expect(gateway.queue, isEmpty);
    expect(find.text('Nothing queued.'), findsOneWidget);
  });

  testWidgets('asks for SMS permission when it is missing', (tester) async {
    await pump(tester, permission: false);
    expect(find.text('SMS permission needed'), findsOneWidget);

    await tester.tap(find.byKey(const Key('allow-sms-button')));
    await tester.pumpAndSettle();

    expect(gateway.permission, isTrue);
    expect(find.text('SMS permission needed'), findsNothing);
  });
}

class _Gateway implements SendLaterGateway {
  _Gateway({required this.permission});

  bool permission;
  final queue = <QueuedMessage>[];
  final savedLocations = <LocationFix>[];
  int sendNowCalls = 0;
  bool markAllSentOnNextSend = false;
  SendSummary sendResult = const SendSummary(sent: 0, failed: 0);
  LocationFix? _location;

  @override
  Future<bool> hasSmsPermission() async => permission;

  @override
  Future<bool> requestSmsPermission() async => permission = true;

  @override
  Future<List<QueuedMessage>> list() async => List.of(queue);

  @override
  Future<void> enqueue(QueuedMessage message) async => queue.add(message);

  @override
  Future<void> remove(String id) async =>
      queue.removeWhere((message) => message.id == id);

  @override
  Future<SendSummary> sendNow() async {
    sendNowCalls++;
    if (markAllSentOnNextSend) {
      markAllSentOnNextSend = false;
      for (var i = 0; i < queue.length; i++) {
        final m = queue[i];
        queue[i] = QueuedMessage(
          id: m.id,
          kind: m.kind,
          createdAt: m.createdAt,
          template: m.template,
          recipients: [
            for (final r in m.recipients)
              QueuedRecipient(name: r.name, number: r.number, sent: true),
          ],
        );
      }
    }
    return sendResult;
  }

  @override
  Future<void> saveLocation(LocationFix fix) async {
    savedLocations.add(fix);
    _location = fix;
  }

  @override
  Future<LocationFix?> lastLocation() async => _location;
}

class _Profiles implements ProfileRepository {
  @override
  Future<UserProfile?> load() async => _profile;

  @override
  Future<void> save(UserProfile profile) async {}
}

class _Location implements LocationProvider {
  _Location({required this.works});

  final bool works;

  @override
  Future<LocationFix> currentFix() async {
    if (!works) throw StateError('No GPS');
    return LocationFix(
      point: const GeoPoint(latitude: 14.65, longitude: 121.1),
      accuracyMeters: 12,
      timestamp: DateTime.now(),
    );
  }
}
