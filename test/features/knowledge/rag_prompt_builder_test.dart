import 'package:flutter_test/flutter_test.dart';
import 'package:walang_signal/features/knowledge/domain/rag_prompt_builder.dart';
import 'package:walang_signal/features/knowledge/domain/retrieved_passage.dart';

void main() {
  test(
    'leaves the original user prompt unchanged when retrieval has no hits',
    () {
      const prompt = 'Is the water rising?';

      expect(RagPromptBuilder.withContext(prompt, const []), prompt);
    },
  );

  test(
    'attaches retrieved text and traceable source metadata to the prompt',
    () {
      const passage = RetrievedPassage(
        id: 'pagasa::1',
        content: 'Move to a safe area before water cuts off access.',
        title: 'PAGASA Flood Guide for the Public',
        sectionPath: 'PAGASA Flood Guide > What to do when water is rising',
        publisher: 'PAGASA (DOST)',
        sourceUrl: 'https://www.pagasa.dost.gov.ph/learning-tools/floods',
        similarity: 0.82,
      );

      final augmented = RagPromptBuilder.withContext(
        'Water is rising near my home. What should I do?',
        const [passage],
      );

      expect(augmented, contains('[1] PAGASA Flood Guide for the Public'));
      expect(augmented, contains('What to do when water is rising'));
      expect(
        augmented,
        contains('Move to a safe area before water cuts off access.'),
      );
      expect(augmented, contains(passage.sourceUrl!));
      expect(
        augmented,
        contains('Water is rising near my home. What should I do?'),
      );
    },
  );
}
