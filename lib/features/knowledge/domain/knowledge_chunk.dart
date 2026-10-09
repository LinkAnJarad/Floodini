class KnowledgeChunk {
  const KnowledgeChunk({
    required this.id,
    required this.documentId,
    required this.documentTitle,
    required this.sectionPath,
    required this.content,
    required this.metadata,
  });

  final String id;
  final String documentId;
  final String documentTitle;
  final String sectionPath;
  final String content;
  final Map<String, Object?> metadata;

  String? get sourceUrl => metadata['source_url']?.toString();

  String? get publisher =>
      metadata['publisher']?.toString() ??
      metadata['source_agency']?.toString();

  String get embeddingText => '$sectionPath\n$content';
}
