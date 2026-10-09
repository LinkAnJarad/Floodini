import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walang_signal/features/chat/domain/chat_image_picker.dart';
import 'package:walang_signal/features/chat/domain/gemma_chat_backend.dart';
import 'package:walang_signal/features/chat/presentation/gemma_chat_screen.dart';
import 'package:walang_signal/features/knowledge/domain/knowledge_base.dart';
import 'package:walang_signal/features/knowledge/domain/retrieved_passage.dart';

void main() {
  testWidgets('installs Gemma 4 E2B before enabling chat', (tester) async {
    final backend = _FakeGemmaChatBackend(installed: false);

    await tester.pumpWidget(
      MaterialApp(home: GemmaChatScreen(backend: backend)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('install-model-button')), findsOneWidget);
    expect(find.text('Ready to chat'), findsNothing);

    await tester.tap(find.byKey(const Key('install-model-button')));
    await tester.pumpAndSettle();

    expect(backend.installCalls, 1);
    expect(backend.prepareCalls, 1);
    expect(find.text('Ready to chat'), findsOneWidget);
  });

  testWidgets('shows the streamed local reply in the conversation', (
    tester,
  ) async {
    final backend = _FakeGemmaChatBackend(installed: true);

    await tester.pumpWidget(
      MaterialApp(home: GemmaChatScreen(backend: backend)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('chat-input')),
      'How do I prepare for a typhoon?',
    );
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();

    expect(backend.sentPrompts, ['How do I prepare for a typhoon?']);
    expect(find.text('A sample local reply.'), findsOneWidget);
  });

  testWidgets('sends a selected photo with its prompt', (tester) async {
    final photoBytes = Uint8List.fromList(const [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
      73,
      72,
      68,
      82,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      1,
      8,
      2,
      0,
      0,
      0,
      144,
      119,
      83,
      222,
      0,
      0,
      0,
      12,
      73,
      68,
      65,
      84,
      120,
      156,
      99,
      248,
      207,
      192,
      0,
      0,
      3,
      1,
      1,
      0,
      201,
      254,
      146,
      239,
      0,
      0,
      0,
      0,
      73,
      69,
      78,
      68,
      174,
      66,
      96,
      130,
    ]);
    final picker = _FakeChatImagePicker(photoBytes);
    final backend = _FakeGemmaChatBackend(installed: true);

    await tester.pumpWidget(
      MaterialApp(
        home: GemmaChatScreen(backend: backend, imagePicker: picker),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('attach-image-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    expect(find.text('Image attached'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('chat-input')),
      'Describe this photo.',
    );
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();

    expect(picker.requestedSources, [false]);
    expect(backend.sentPrompts.last, 'Describe this photo.');
    expect(backend.sentImages.last, same(photoBytes));
  });

  testWidgets('retrieves for each query and gives relevant passages to Gemma', (
    tester,
  ) async {
    final knowledgeBase = _FakeKnowledgeBase(
      passages: const [
        RetrievedPassage(
          id: 'pagasa::1',
          content: 'Move to a safe area before water cuts off access.',
          title: 'PAGASA Flood Guide',
          sectionPath: 'What to do when water is rising',
          similarity: 0.82,
        ),
      ],
    );
    final backend = _FakeGemmaChatBackend(installed: true);

    await tester.pumpWidget(
      MaterialApp(
        home: GemmaChatScreen(backend: backend, knowledgeBase: knowledgeBase),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('chat-input')),
      'Water is rising',
    );
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();

    expect(knowledgeBase.queries, ['Water is rising']);
    expect(backend.sentPrompts.single, contains('Move to a safe area'));
    expect(backend.sentPrompts.single, contains('Water is rising'));
    expect(find.text('Water is rising'), findsOneWidget);
  });
}

class _FakeGemmaChatBackend implements GemmaChatBackend {
  _FakeGemmaChatBackend({required this.installed});

  final bool installed;
  int installCalls = 0;
  int prepareCalls = 0;
  final List<String> sentPrompts = [];
  final List<Uint8List?> sentImages = [];

  @override
  String get activeBackendLabel => 'fake';

  @override
  Future<bool> isModelInstalled() async => installed || installCalls > 0;

  @override
  Future<void> installModel({required void Function(int) onProgress}) async {
    installCalls++;
    onProgress(100);
  }

  @override
  Future<void> prepareChat() async {
    prepareCalls++;
  }

  @override
  Stream<String> sendMessage(String prompt, {Uint8List? imageBytes}) async* {
    sentPrompts.add(prompt);
    sentImages.add(imageBytes);
    yield 'A sample ';
    yield 'local reply.';
  }

  @override
  Future<void> dispose() async {}
}

class _FakeChatImagePicker implements ChatImagePicker {
  _FakeChatImagePicker(this.imageBytes);

  final Uint8List? imageBytes;
  final List<bool> requestedSources = [];

  @override
  Future<Uint8List?> pickImage({required bool fromCamera}) async {
    requestedSources.add(fromCamera);
    return imageBytes;
  }
}

class _FakeKnowledgeBase implements LocalKnowledgeBase {
  _FakeKnowledgeBase({required this.passages});

  final List<RetrievedPassage> passages;
  final List<String> queries = [];

  @override
  bool get isReady => true;

  @override
  Future<bool> restoreIfAvailable() async => true;

  @override
  Future<void> installAndIndex({
    required String accessToken,
    required void Function(KnowledgeBaseProgress progress) onProgress,
  }) async {}

  @override
  Future<List<RetrievedPassage>> retrieve(String query) async {
    queries.add(query);
    return passages;
  }

  @override
  Future<void> dispose() async {}
}
