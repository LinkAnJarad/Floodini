import 'retrieved_passage.dart';

class RagPromptBuilder {
  const RagPromptBuilder._();

  static String withContext(String prompt, List<RetrievedPassage> passages) {
    if (passages.isEmpty) return prompt;

    final buffer = StringBuffer(
      'Use the following retrieved passages as the only source for '
      'disaster or health facts. If they do not answer the question, say so. '
      'Cite supporting sources by their bracketed number.\n\n'
      'OFFLINE KNOWLEDGE:\n',
    );
    for (var index = 0; index < passages.length; index++) {
      final passage = passages[index];
      buffer.write('[${index + 1}] ${passage.title} — ${passage.sectionPath}\n');
      if (passage.publisher != null) {
        buffer.write('Publisher: ${passage.publisher}\n');
      }
      if (passage.sourceUrl != null) {
        buffer.write('Source: ${passage.sourceUrl}\n');
      }
      buffer.write('${passage.content}\n\n');
    }
    buffer.write('USER QUESTION:\n$prompt');
    return buffer.toString();
  }
}
