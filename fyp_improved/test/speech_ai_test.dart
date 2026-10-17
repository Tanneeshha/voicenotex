import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_fyp/features/speech_ai/services/lecture_draft_service.dart';
import 'package:my_fyp/features/speech_ai/services/speech_service.dart';
import 'package:my_fyp/core/services/pdf_service.dart';
import 'package:my_fyp/core/services/style_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LectureDraftService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves, loads, and clears lecture draft correctly', () async {
      expect(await LectureDraftService.hasDraft(), isFalse);

      await LectureDraftService.saveDraft(
        id: 'test_lecture_1',
        title: 'Physics 101: Thermodynamics',
        courseCode: 'PHY101',
        instructor: 'Dr. Feynman',
        transcript: 'Today we discuss the first law of thermodynamics in detail.',
        durationSeconds: 120,
      );

      expect(await LectureDraftService.hasDraft(), isTrue);

      final draft = await LectureDraftService.loadDraft();
      expect(draft, isNotNull);
      expect(draft!.title, 'Physics 101: Thermodynamics');
      expect(draft.courseCode, 'PHY101');
      expect(draft.instructor, 'Dr. Feynman');
      expect(draft.transcript, 'Today we discuss the first law of thermodynamics in detail.');
      expect(draft.durationSeconds, 120);

      await LectureDraftService.clearDraft();
      expect(await LectureDraftService.hasDraft(), isFalse);
    });
  });

  group('SpeechService Zero-Loss Buffer Architecture Tests', () {
    late SpeechService service;

    setUp(() {
      service = SpeechService();
      service.clearTranscript();
    });

    test('initializes and manages accumulated text seamlessly', () {
      service.setAccumulatedText('Hello class.');
      expect(service.fullTranscript, 'Hello class.');

      service.setAccumulatedText('  Hello class. Today we learn Dart.  ');
      expect(service.fullTranscript, 'Hello class. Today we learn Dart.');
    });

    test('commits active utterances without losing words or creating duplicate spaces', () {
      service.setAccumulatedText('Part 1.');
      expect(service.fullTranscript, 'Part 1.');

      service.commitActiveUtterance(); // Empty utterance should do nothing
      expect(service.fullTranscript, 'Part 1.');

      final chunks = [
        'Welcome to lecture 1.',
        'We will cover algorithms.',
        'Complexity analysis is important.',
        'Big O notation measures scaling.',
        'Any questions before we continue?'
      ];

      for (final chunk in chunks) {
        service.setAccumulatedText('${service.fullTranscript} $chunk'.trim());
        service.commitActiveUtterance();
      }

      final expected =
          'Part 1. Welcome to lecture 1. We will cover algorithms. Complexity analysis is important. Big O notation measures scaling. Any questions before we continue?';
      expect(service.fullTranscript, expected);
    });

    test('continuous 60-minute simulated lecture with 40 engine restarts does not lose or duplicate text', () {
      service.clearTranscript();

      for (int minute = 1; minute <= 60; minute++) {
        final phrase = 'Minute $minute content discussed.';
        service.setAccumulatedText(
          service.fullTranscript.isEmpty
              ? phrase
              : '${service.fullTranscript} $phrase',
        );
        service.commitActiveUtterance();
      }

      for (int minute = 1; minute <= 60; minute++) {
        expect(service.fullTranscript.contains('Minute $minute content discussed.'), isTrue);
      }

      final words = service.fullTranscript.split(RegExp(r'\s+'));
      expect(words.length, 60 * 4);
    });
  });

  group('StyleService Personalization Tests', () {
    test('generates accurate student level personalization prompt', () async {
      SharedPreferences.setMockInitialValues({});
      await StyleService.init();

      await StyleService.savePreferences(
        explanationStyle: 'Simple',
        advancedLevel: 'Beginner',
        noteLength: 1.0,
        focusAreas: ['Definitions', 'Examples'],
        noteFormat: 'Headings & Bullets',
        language: 'English',
      );

      final prompt = StyleService.personalizationPrompt;
      expect(prompt.contains('Student Level: Beginner.'), isTrue);
      expect(prompt.contains('Explanation Style: Simple.'), isTrue);
      expect(prompt.contains('Short and concise'), isTrue);
      expect(prompt.contains('Definitions, Examples'), isTrue);
    });
  });

  group('PdfService Note-Centric Tests', () {
    test('generates PDF bytes focusing on AI notes structure', () async {
      final bytes = await PdfService.generateLecturePdfBytes(
        title: 'Operating Systems: Virtual Memory',
        courseCode: 'CS301',
        instructor: 'Prof. Tanenbaum',
        notesContent: '# Key Concepts\n- Paging and Segmentation\n- Page Fault Handling\n\n## Summary\nVirtual memory provides address isolation.',
        rawTranscript: 'Today we discuss virtual memory and paging in operating systems.',
        date: 'Aug 15, 2026',
        includeTranscriptAppendix: false,
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });
  });
}
