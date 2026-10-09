import 'package:yaml/yaml.dart';

import 'knowledge_chunk.dart';

class MarkdownKnowledgeChunker {
  const MarkdownKnowledgeChunker({
    this.maxWordsPerChunk = 160,
    this.overlapWords = 24,
  }) : assert(maxWordsPerChunk > 0),
       assert(overlapWords >= 0),
       assert(overlapWords < maxWordsPerChunk);

  final int maxWordsPerChunk;
  final int overlapWords;

  static const _excludedHeadings = <String>{
    'retrieval cues',
    'rag and safety metadata',
    'suggested rag metadata',
    'recommended answer policy',
    'suggested answer policy',
  };

  List<KnowledgeChunk> chunkDocument(
    String markdown, {
    required String sourceId,
  }) {
    final (frontMatter, body) = _splitFrontMatter(markdown);
    final metadata = _parseMetadata(frontMatter);
    final fallbackTitle = (metadata['title'] ?? sourceId).toString();
    final headingStack = <String>[];
    final chunks = <KnowledgeChunk>[];
    final currentLines = <String>[];
    String? currentPath;
    var currentExcluded = false;
    var sectionNumber = 0;

    void flushSection() {
      final sectionBody = currentLines.join('\n').trim();
      currentLines.clear();
      final path = currentPath;
      if (sectionBody.isEmpty || path == null || currentExcluded) return;

      final words = RegExp(r'\S+').allMatches(sectionBody).toList();
      if (words.isEmpty) return;
      var startWord = 0;
      while (startWord < words.length) {
        final endWord = (startWord + maxWordsPerChunk).clamp(0, words.length);
        final content = sectionBody
            .substring(words[startWord].start, words[endWord - 1].end)
            .trim();
        final chunkMetadata = <String, Object?>{
          ...metadata,
          'document_id': sourceId,
          'document_title': fallbackTitle,
          'section_path': path,
        };
        chunks.add(
          KnowledgeChunk(
            id: '$sourceId::$sectionNumber',
            documentId: sourceId,
            documentTitle: fallbackTitle,
            sectionPath: path,
            content: content,
            metadata: Map.unmodifiable(chunkMetadata),
          ),
        );
        sectionNumber++;
        if (endWord == words.length) break;
        startWord = endWord - overlapWords;
      }
    }

    for (final line in body.split(RegExp(r'\r?\n'))) {
      final heading = RegExp(r'^(#{1,6})\s+(.+?)\s*#*\s*$').firstMatch(line);
      if (heading == null) {
        currentLines.add(line);
        continue;
      }

      flushSection();
      final level = heading.group(1)!.length;
      final text = heading.group(2)!.trim();
      while (headingStack.length >= level) {
        headingStack.removeLast();
      }
      headingStack.add(text);
      if (level == 1 && metadata['title'] == null) {
        metadata['title'] = text;
      }
      currentPath = headingStack.join(' > ');
      currentExcluded = headingStack.any(
        (part) => _excludedHeadings.contains(_normalizeHeading(part)),
      );
    }
    flushSection();

    return List.unmodifiable(chunks);
  }

  static String _normalizeHeading(String heading) =>
      heading.toLowerCase().replaceAll(RegExp(r'^\d+[.)]?\s*'), '').trim();

  static (String? frontMatter, String body) _splitFrontMatter(String markdown) {
    final match = RegExp(
      r'^---\s*\r?\n(.*?)\r?\n---\s*(?:\r?\n|$)',
      dotAll: true,
    ).firstMatch(markdown);
    if (match == null) return (null, markdown);
    return (match.group(1), markdown.substring(match.end));
  }

  static Map<String, Object?> _parseMetadata(String? frontMatter) {
    if (frontMatter == null || frontMatter.trim().isEmpty) return {};
    final parsed = loadYaml(frontMatter);
    if (parsed is! YamlMap) return {};
    return Map<String, Object?>.from(_toJsonValue(parsed) as Map);
  }

  static Object? _toJsonValue(Object? value) {
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _toJsonValue(nestedValue)),
      );
    }
    if (value is List) return value.map(_toJsonValue).toList(growable: false);
    return value;
  }
}
