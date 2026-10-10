import 'retrieved_passage.dart';

class KnowledgeBaseProgress {
  const KnowledgeBaseProgress({required this.message, this.percent});

  final String message;
  final int? percent;
}

abstract interface class LocalKnowledgeBase {
  bool get isReady;

  Future<bool> restoreIfAvailable();

  Future<void> installAndIndex({
    required void Function(KnowledgeBaseProgress progress) onProgress,
  });

  Future<List<RetrievedPassage>> retrieve(String query);

  Future<void> dispose();
}
