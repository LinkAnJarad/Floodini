import 'package:flutter_test/flutter_test.dart';
import 'package:floodini/features/knowledge/domain/markdown_knowledge_chunker.dart';

void main() {
  test('keeps heading paths and source metadata on evidence chunks', () {
    const markdown = '''
---
title: "Flood Guide"
source_url: "https://example.org/flood"
publisher: PAGASA
language: en
---
# Flood Guide

## Immediate danger
Do not enter flowing floodwater. Move to higher ground.

### If trapped
Call responders and share your location.

## Retrieval cues
Questions about rising water.

## Recommended answer policy
Do not invent live alerts.
''';

    final chunks = const MarkdownKnowledgeChunker().chunkDocument(
      markdown,
      sourceId: 'flood_guide',
    );

    expect(chunks, hasLength(2));
    expect(chunks.first.sectionPath, 'Flood Guide > Immediate danger');
    expect(
      chunks.last.sectionPath,
      'Flood Guide > Immediate danger > If trapped',
    );
    expect(chunks.first.sourceUrl, 'https://example.org/flood');
    expect(chunks.first.publisher, 'PAGASA');
    expect(
      chunks.map((chunk) => chunk.content).join('\n'),
      isNot(contains('Questions about rising water')),
    );
    expect(
      chunks.map((chunk) => chunk.content).join('\n'),
      isNot(contains('Do not invent live alerts')),
    );
  });

  test(
    'splits oversized sections without exceeding the configured word limit',
    () {
      const markdown = '''
# Guide
## Steps
one two three four five six seven eight nine ten
''';

      final chunks = MarkdownKnowledgeChunker(
        maxWordsPerChunk: 4,
        overlapWords: 0,
      ).chunkDocument(markdown, sourceId: 'guide');

      expect(chunks, hasLength(3));
      expect(
        chunks.every(
          (chunk) => chunk.content.split(RegExp(r'\s+')).length <= 4,
        ),
        isTrue,
      );
      expect(
        chunks.map((chunk) => chunk.content).join(' '),
        'one two three four five six seven eight nine ten',
      );
    },
  );
}
