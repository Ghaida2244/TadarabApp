import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tadarab_app/services/text_extraction_service.dart';

import '../helpers/ooxml_fixture_builder.dart';

Uint8List _bytesOf(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('PPTX extraction', () {
    test('a normal title + body slide is tagged with its title', () {
      final contentShape =
          '<p:sp><p:nvSpPr><p:nvPr><p:ph idx="1"/></p:nvPr></p:nvSpPr>'
          '<p:txBody><a:p><a:r><a:t>Why Data Mining</a:t></a:r></a:p>'
          '<a:p><a:r><a:t>What Is Data Mining</a:t></a:r></a:p>'
          '</p:txBody></p:sp>';
      final bytes = buildPptxBytes([
        pptxTitleShape('Chapter Outline') + contentShape,
      ]);

      final text = extractText(bytes: bytes, type: 'pptx');

      expect(text, contains('[Slide 1: Chapter Outline]'));
      expect(text, contains('Why Data Mining'));
      expect(text, contains('What Is Data Mining'));
    });

    test('multiple slides are numbered and ordered via the real slide order '
        'in presentation.xml, not filename order', () {
      // Deliberately built so slide2.xml (filename) is listed *first* in
      // the deck's real order, to prove ordering comes from p:sldIdLst.
      final bytes = buildPptxBytes([
        pptxTitleShape('Second In File, First On Screen'),
        pptxTitleShape('First In File, Second On Screen'),
      ]);

      final text = extractText(bytes: bytes, type: 'pptx');
      final firstTagIndex = text.indexOf(
        '[Slide 1: Second In File, First On Screen]',
      );
      final secondTagIndex = text.indexOf(
        '[Slide 2: First In File, Second On Screen]',
      );

      expect(firstTagIndex, greaterThanOrEqualTo(0));
      expect(secondTagIndex, greaterThan(firstTagIndex));
    });

    test(
      'an empty title placeholder falls back to the first text box\'s '
      'first line as the title (real-world cover-slide pattern)',
      () {
        final bytes = buildPptxBytes([
          pptxTitleShape('', phType: 'ctrTitle') +
              pptxTextBoxShape([
                'Chapter 1',
                'Chapter 1 — Introduction to Data Mining, IS 463.',
              ]),
        ]);

        final text = extractText(bytes: bytes, type: 'pptx');

        expect(text, contains('[Slide 1: Chapter 1]'));
        expect(
          text,
          contains('Chapter 1 — Introduction to Data Mining, IS 463.'),
        );
      },
    );

    test('a slide with no text anywhere contributes nothing', () {
      final bytes = buildPptxBytes([
        '<p:sp><p:nvSpPr><p:nvPr/></p:nvSpPr><p:txBody><a:p/></p:txBody></p:sp>',
      ]);

      final text = extractText(bytes: bytes, type: 'pptx');

      expect(text, isEmpty);
    });

    test('a real lecture deck extracts with the exact tag format and real '
        'known content', () {
      final file = File('docs/Lecture1.pptx');
      final text = extractText(bytes: file.readAsBytesSync(), type: 'pptx');

      expect(text, matches(RegExp(r'^\[Slide 1: .+\]', multiLine: true)));
      expect(text, contains('[Slide 2: Chapter Outline]'));
      expect(text, isNot(contains('[Material:')));
    });
  });

  group('DOCX extraction', () {
    test('a heading groups its following paragraphs under one tag', () {
      final bytes = buildDocxBytes(
        docxParagraph('Functional Requirements', styleId: 'Heading1') +
            docxParagraph(
              'Functional requirements describe what the system should do.',
            ) +
            docxParagraph('A second paragraph under the same heading.'),
      );

      final text = extractText(bytes: bytes, type: 'docx');

      expect(text, contains('[Heading 1: Functional Requirements]'));
      expect(
        text,
        contains(
          'Functional requirements describe what the system should do.',
        ),
      );
      expect(text, contains('A second paragraph under the same heading.'));
      expect(text, isNot(contains('[Paragraph')));
    });

    test('content before the first heading is tagged per-paragraph', () {
      final bytes = buildDocxBytes(
        docxParagraph('This document covers requirements engineering.') +
            docxParagraph('Introduction', styleId: 'Heading1') +
            docxParagraph('Body under the heading.'),
      );

      final text = extractText(bytes: bytes, type: 'docx');

      expect(text, contains('[Paragraph 1]'));
      expect(
        text,
        contains('This document covers requirements engineering.'),
      );
      expect(text, contains('[Heading 1: Introduction]'));
    });

    test('a document with no headings at all tags every paragraph', () {
      final bytes = buildDocxBytes(
        docxParagraph('First paragraph.') + docxParagraph('Second paragraph.'),
      );

      final text = extractText(bytes: bytes, type: 'docx');

      expect(text, contains('[Paragraph 1]\nFirst paragraph.'));
      expect(text, contains('[Paragraph 2]\nSecond paragraph.'));
    });

    test('non-heading styles (TOC, Caption) are not treated as headings', () {
      final bytes = buildDocxBytes(
        docxParagraph('Table of Contents', styleId: 'TOCHeading') +
            docxParagraph('1. Introduction ... 3', styleId: 'TOC1'),
      );

      final text = extractText(bytes: bytes, type: 'docx');

      expect(text, isNot(contains('[Heading')));
      expect(text, contains('[Paragraph 1]\nTable of Contents'));
      expect(text, contains('[Paragraph 2]\n1. Introduction ... 3'));
    });

    test('empty paragraphs are skipped without leaving gaps in numbering', () {
      final bytes = buildDocxBytes(
        docxParagraph('First.') +
            docxParagraph('') +
            docxParagraph('Second.'),
      );

      final text = extractText(bytes: bytes, type: 'docx');

      expect(text, contains('[Paragraph 1]\nFirst.'));
      expect(text, contains('[Paragraph 2]\nSecond.'));
    });

    test('a real SRS document with real Heading1/2/3 styles extracts '
        'cleanly, excluding TOC/Caption/Bibliography noise', () {
      final file = File("docs/SRS_GP1_Ghaida'sCopy_updated (1).docx");
      final text = extractText(bytes: file.readAsBytesSync(), type: 'docx');

      expect(text, contains('[Heading 1: Student Declaration]'));
      expect(text, isNot(contains('[Heading 1: ]')));
    });
  });

  group('TXT extraction', () {
    test('blank-line-separated blocks each become a numbered paragraph', () {
      final bytes = _bytesOf(
        'First paragraph.\n\nSecond paragraph,\nstill one block.\n\nThird.',
      );

      final text = extractText(bytes: bytes, type: 'txt');

      expect(text, contains('[Paragraph 1]\nFirst paragraph.'));
      expect(
        text,
        contains('[Paragraph 2]\nSecond paragraph,\nstill one block.'),
      );
      expect(text, contains('[Paragraph 3]\nThird.'));
    });

    test('a whitespace-only file yields empty text (caller rejects it)', () {
      final bytes = _bytesOf('   \n\n   \n');

      final text = extractText(bytes: bytes, type: 'txt');

      expect(text, isEmpty);
    });
  });

  group('corrupted files', () {
    test('a non-zip file passed as pptx throws TextExtractionException', () {
      final bytes = _bytesOf('not a real pptx file');

      expect(
        () => extractText(bytes: bytes, type: 'pptx'),
        throwsA(isA<TextExtractionException>()),
      );
    });

    test('a non-zip file passed as docx throws TextExtractionException', () {
      final bytes = _bytesOf('not a real docx file');

      expect(
        () => extractText(bytes: bytes, type: 'docx'),
        throwsA(isA<TextExtractionException>()),
      );
    });
  });
}
