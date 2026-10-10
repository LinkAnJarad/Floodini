import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodini/features/knowledge/data/flutter_edge_knowledge_base.dart';
import 'package:floodini/features/knowledge/domain/markdown_knowledge_chunker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled health and flood guidance has source-aware section chunks',
    () async {
      const chunker = MarkdownKnowledgeChunker();
      final chunks = [];
      for (final assetPath in FlutterEdgeKnowledgeBase.assetPaths) {
        final markdown = await rootBundle.loadString(assetPath);
        chunks.addAll(
          chunker.chunkDocument(
            markdown,
            sourceId: assetPath.split('/').last.split('.').first,
          ),
        );
      }

      expect(chunks, isNotEmpty);
      expect(chunks.map((chunk) => chunk.documentId).toSet(), hasLength(3));
      expect(chunks.every((chunk) => chunk.sourceUrl != null), isTrue);
      expect(chunks.any((chunk) => chunk.sectionPath.contains(' > ')), isTrue);
      expect(
        chunks.map((chunk) => chunk.content).join('\n'),
        isNot(contains('Suggested RAG metadata')),
      );
    },
  );
}
