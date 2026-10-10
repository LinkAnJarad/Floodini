import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_rag/flutter_edge_ai_rag.dart';
import 'package:flutter_edge_ai_sqlite/flutter_edge_ai_sqlite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/knowledge_base.dart';
import '../domain/markdown_knowledge_chunker.dart';
import '../domain/knowledge_chunk.dart';
import '../domain/retrieved_passage.dart';

class FlutterEdgeKnowledgeBase implements LocalKnowledgeBase {
  FlutterEdgeKnowledgeBase({
    AssetBundle? bundle,
    this.chunker = const MarkdownKnowledgeChunker(),
  }) : _bundle = bundle ?? rootBundle;

  // Gecko-110m-en: Apache-2.0 and ungated, so no Hugging Face token is needed.
  static const embeddingProfileId =
      'gecko-110m-en-seq256-quant-rev-61a0d0c2-v1';
  static const modelFileName = 'Gecko_256_quant-61a0d0c2.tflite';
  static const modelUrl =
      'https://huggingface.co/litert-community/Gecko-110m-en/'
      'resolve/61a0d0c2cdc9b4f2c1727e63acb7ad86e68508c2/'
      'Gecko_256_quant.tflite';
  static const tokenizerUrl =
      'https://huggingface.co/litert-community/Gecko-110m-en/'
      'resolve/61a0d0c2cdc9b4f2c1727e63acb7ad86e68508c2/'
      'sentencepiece.model';

  static const retrievalThreshold = 0.35;
  static const resultLimit = 4;
  static const assetPaths = <String>[
    'assets/who_flood_safety_rag.md',
    'assets/pagasa_floods_citizen.md',
    'assets/cdc_emergency_wound_care_rag.md',
  ];

  final AssetBundle _bundle;
  final MarkdownKnowledgeChunker chunker;
  final FlutterEdgeAiRag _rag = FlutterEdgeAiRag(
    providers: [SqliteVectorStoreProvider()],
  );
  Future<List<KnowledgeChunk>>? _chunksFuture;
  Future<RagIndex>? _openingIndex;
  Future<void>? _preparing;
  RagIndex? _index;
  bool _ready = false;

  @override
  bool get isReady => _ready && _index != null;

  @override
  Future<bool> restoreIfAvailable() async {
    if (isReady) return true;
    if (FlutterEdgeAi.activeEmbedderSpec == null) return false;

    final chunks = await _loadChunks();
    final index = await _openIndex();
    final stats = await index.stats();
    if (stats.documentCount != chunks.length) {
      return false;
    }
    _ready = true;
    return true;
  }

  @override
  Future<void> installAndIndex({
    required void Function(KnowledgeBaseProgress progress) onProgress,
  }) {
    final existing = _preparing;
    if (existing != null) return existing;
    final future = _installAndIndex(onProgress: onProgress);
    _preparing = future;
    return future.whenComplete(() => _preparing = null);
  }

  Future<void> _installAndIndex({
    required void Function(KnowledgeBaseProgress progress) onProgress,
  }) async {
    _ready = false;
    await FlutterEdgeAi.installEmbedder()
        .modelFromNetwork(modelUrl, filename: modelFileName)
        .tokenizerFromNetwork(tokenizerUrl)
        .withModelProgress(
          (percent) => onProgress(
            KnowledgeBaseProgress(
              message: 'Downloading embedding model',
              percent: percent,
            ),
          ),
        )
        .withTokenizerProgress(
          (percent) => onProgress(
            KnowledgeBaseProgress(
              message: 'Downloading embedding tokenizer',
              percent: percent,
            ),
          ),
        )
        .install();

    final chunks = await _loadChunks();
    final index = await _openIndex();
    await index.clear();
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      await index.addText(
        id: chunk.id,
        content: chunk.embeddingText,
        metadata: jsonEncode(chunk.metadata),
      );
      onProgress(
        KnowledgeBaseProgress(
          message: 'Indexing offline guidance (${i + 1}/${chunks.length})',
          percent: ((i + 1) * 100 / chunks.length).round(),
        ),
      );
    }
    await index.flush();
    _ready = true;
    onProgress(
      const KnowledgeBaseProgress(message: 'Offline RAG ready', percent: 100),
    );
  }

  @override
  Future<List<RetrievedPassage>> retrieve(String query) async {
    if (!isReady) return const [];
    final results = await _index!.searchText(
      query: query,
      topK: resultLimit,
      threshold: retrievalThreshold,
    );
    return results
        .map((result) {
          final metadata = _decodeMetadata(result.metadata);
          return RetrievedPassage(
            id: result.id,
            content: result.content,
            title: metadata['document_title']?.toString() ?? 'Offline guidance',
            sectionPath: metadata['section_path']?.toString() ?? 'Unsectioned',
            publisher: _publisher(metadata),
            sourceUrl: metadata['source_url']?.toString(),
            similarity: result.similarity,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> dispose() async {
    final index = _index;
    _index = null;
    _ready = false;
    if (index != null) await index.dispose();
  }

  Future<RagIndex> _openIndex() {
    final current = _index;
    if (current != null && !current.isDisposed) return Future.value(current);
    final opening = _openingIndex;
    if (opening != null) return opening;

    final future = _createIndex();
    _openingIndex = future;
    return future.whenComplete(() => _openingIndex = null);
  }

  Future<RagIndex> _createIndex() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final location = p.join(
      documentsDirectory.path,
      'floodini_knowledge_gecko_seq256_v1.sqlite',
    );
    final index = await _rag.open(
      spec: VectorStoreSpec(providerId: 'sqlite', location: location),
      activeEmbedderProfileId: embeddingProfileId,
    );
    _index = index;
    return index;
  }

  Future<List<KnowledgeChunk>> _loadChunks() => _chunksFuture ??= _readChunks();

  Future<List<KnowledgeChunk>> _readChunks() async {
    final chunks = <KnowledgeChunk>[];
    for (final assetPath in assetPaths) {
      final markdown = await _bundle.loadString(assetPath);
      final fileName = p.basenameWithoutExtension(assetPath);
      chunks.addAll(chunker.chunkDocument(markdown, sourceId: fileName));
    }
    if (chunks.isEmpty) {
      throw StateError('The bundled offline knowledge base is empty.');
    }
    return List.unmodifiable(chunks);
  }

  static Map<String, Object?> _decodeMetadata(String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } on FormatException {
      // A malformed metadata value should not prevent retrieval of the text.
    }
    return const {};
  }

  static String? _publisher(Map<String, Object?> metadata) =>
      metadata['publisher']?.toString() ??
      metadata['source_agency']?.toString();
}
