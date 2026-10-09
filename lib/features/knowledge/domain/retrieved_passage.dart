class RetrievedPassage {
  const RetrievedPassage({
    required this.id,
    required this.content,
    required this.title,
    required this.sectionPath,
    required this.similarity,
    this.publisher,
    this.sourceUrl,
  });

  final String id;
  final String content;
  final String title;
  final String sectionPath;
  final String? publisher;
  final String? sourceUrl;
  final double similarity;
}
