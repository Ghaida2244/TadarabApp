import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Thrown when a file can't be parsed at all (corrupted zip, missing/
/// malformed required XML parts) — distinct from a file that parses fine
/// but yields no text, which [extractText] represents as an empty string
/// rather than an error (see courses_material_upload_spec.md §4b: only the
/// caller decides an empty result means "reject the upload").
class TextExtractionException implements Exception {
  TextExtractionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Extracts plain text from an uploaded PPTX/DOCX/TXT file, tagged per
/// courses_material_upload_spec.md §7 — an exact contract with the
/// generation Worker, which parses these labels, so the format below must
/// not drift from the spec.
///
/// Runs entirely client-side. PPTX/DOCX are OOXML: zip archives of XML
/// parts. Rather than a generic OOXML library (see CLAUDE.md's Progress Log
/// for why `open_xml`/`doc_text_extractor` didn't fit), this parses the
/// specific parts needed — `ppt/slides/*.xml` for PPTX, `word/document.xml`
/// for DOCX — directly with `archive` (unzip) and `xml` (parse).
String extractText({required Uint8List bytes, required String type}) {
  switch (type) {
    case 'pptx':
      return _extractPptx(bytes);
    case 'docx':
      return _extractDocx(bytes);
    case 'txt':
      return _extractTxt(bytes);
    default:
      throw TextExtractionException('Unsupported file type "$type".');
  }
}

// ---------------------------------------------------------------------------
// PPTX
// ---------------------------------------------------------------------------

String _extractPptx(Uint8List bytes) {
  final archive = _decodeZip(bytes);
  if (archive.findFile('ppt/presentation.xml') == null) {
    throw TextExtractionException('This file is not a valid PowerPoint file.');
  }
  final slidePaths = _orderedSlidePaths(archive);

  final buffer = StringBuffer();
  var slideNumber = 0;
  for (final path in slidePaths) {
    final file = archive.findFile(path);
    if (file == null) continue;
    final xmlString = utf8.decode(file.content as List<int>);
    final doc = _tryParseXml(xmlString);
    if (doc == null) continue;

    final section = _slideTitleAndBody(doc);
    if (section.title.isEmpty && section.body.isEmpty) continue;

    slideNumber++;
    buffer.writeln('[Slide $slideNumber: ${section.title}]');
    if (section.body.isNotEmpty) buffer.writeln(section.body);
  }
  return buffer.toString().trim();
}

/// Resolves slide part paths in the deck's real display order — via
/// `ppt/presentation.xml`'s `<p:sldIdLst>` and the matching relationship
/// file — rather than assuming `slide1.xml, slide2.xml, ...` matches
/// display order (it usually does, but isn't guaranteed, and a wrong order
/// here would silently produce wrong `sourceLocation`s).
List<String> _orderedSlidePaths(Archive archive) {
  final presentationFile = archive.findFile('ppt/presentation.xml');
  final relsFile = archive.findFile('ppt/_rels/presentation.xml.rels');
  if (presentationFile == null || relsFile == null) return const [];

  final presentationDoc = _tryParseXml(
    utf8.decode(presentationFile.content as List<int>),
  );
  final relsDoc = _tryParseXml(utf8.decode(relsFile.content as List<int>));
  if (presentationDoc == null || relsDoc == null) return const [];

  final targetByRId = <String, String>{};
  for (final rel in relsDoc.findAllElements('Relationship')) {
    final id = rel.getAttribute('Id');
    final target = rel.getAttribute('Target');
    if (id != null && target != null) targetByRId[id] = target;
  }

  final paths = <String>[];
  for (final sldId in presentationDoc.findAllElements('p:sldId')) {
    final rId = sldId.getAttribute('r:id');
    final target = rId == null ? null : targetByRId[rId];
    if (target != null) paths.add('ppt/$target');
  }
  return paths;
}

class _SlideSection {
  _SlideSection({required this.title, required this.body});

  final String title;
  final String body;
}

/// A slide's title is its `<p:ph type="title"/>` (or `ctrTitle`) shape's
/// text, when that shape actually has text. Some real decks (e.g. a cover
/// slide) have an *empty* title placeholder and put the visible title in an
/// untyped text box instead — trusting the placeholder type alone there
/// would silently cite an empty title, so when it's empty this falls back
/// to the first non-empty shape's first line instead.
_SlideSection _slideTitleAndBody(XmlDocument slideDoc) {
  final shapes = slideDoc.findAllElements('p:sp').toList();

  String? placeholderTitle;
  final shapeTexts = <String>[];
  for (final shape in shapes) {
    final text = _shapeText(shape);
    shapeTexts.add(text);
    if (text.trim().isEmpty) continue;
    if (placeholderTitle == null && _isTitlePlaceholder(shape)) {
      placeholderTitle = text.trim();
    }
  }

  if (placeholderTitle != null) {
    final body = [
      for (var i = 0; i < shapes.length; i++)
        if (!_isTitlePlaceholder(shapes[i])) shapeTexts[i],
    ].where((t) => t.trim().isNotEmpty).join('\n').trim();
    return _SlideSection(title: placeholderTitle, body: body);
  }

  // No non-empty title placeholder: fall back to the first non-empty
  // shape's first line as the title, keeping the rest as body.
  for (var i = 0; i < shapeTexts.length; i++) {
    final lines = shapeTexts[i].trim().split('\n');
    if (lines.isEmpty || lines.first.trim().isEmpty) continue;
    final title = lines.first.trim();
    final remainder = [
      if (lines.length > 1) lines.skip(1).join('\n'),
      for (var j = i + 1; j < shapeTexts.length; j++) shapeTexts[j],
    ].where((t) => t.trim().isNotEmpty).join('\n').trim();
    return _SlideSection(title: title, body: remainder);
  }

  return _SlideSection(title: '', body: '');
}

bool _isTitlePlaceholder(XmlElement shape) {
  final ph = shape.findAllElements('p:ph').firstOrNull;
  if (ph == null) return false;
  final type = ph.getAttribute('type');
  return type == 'title' || type == 'ctrTitle';
}

/// A shape's text, paragraph-by-paragraph (`<a:p>`), each paragraph's runs
/// (`<a:t>`) concatenated directly and paragraphs joined with newlines.
String _shapeText(XmlElement shape) {
  final paragraphs = <String>[];
  for (final p in shape.findAllElements('a:p')) {
    final text = p.findAllElements('a:t').map((t) => t.innerText).join();
    paragraphs.add(text);
  }
  return paragraphs.join('\n');
}

// ---------------------------------------------------------------------------
// DOCX
// ---------------------------------------------------------------------------

final _headingStyleId = RegExp(r'^Heading\d+$');

String _extractDocx(Uint8List bytes) {
  final archive = _decodeZip(bytes);
  final file = archive.findFile('word/document.xml');
  if (file == null) {
    throw TextExtractionException('This file is not a valid Word document.');
  }
  final doc = _tryParseXml(utf8.decode(file.content as List<int>));
  if (doc == null) {
    throw TextExtractionException('This file is not a valid Word document.');
  }

  final buffer = StringBuffer();
  var headingNumber = 0;
  var paragraphNumber = 0;
  var seenHeading = false;
  final currentSection = StringBuffer();

  void flushSection() {
    final content = currentSection.toString().trim();
    if (content.isNotEmpty) buffer.writeln(content);
    currentSection.clear();
  }

  for (final p in doc.findAllElements('w:p')) {
    final text = p
        .findAllElements('w:t')
        .map((t) => t.innerText)
        .join()
        .trim();
    if (text.isEmpty) continue;

    final styleId = p
        .findElements('w:pPr')
        .firstOrNull
        ?.findElements('w:pStyle')
        .firstOrNull
        ?.getAttribute('w:val');
    final isHeading = styleId != null && _headingStyleId.hasMatch(styleId);

    if (isHeading) {
      flushSection();
      headingNumber++;
      seenHeading = true;
      buffer.writeln('[Heading $headingNumber: $text]');
    } else if (seenHeading) {
      currentSection.writeln(text);
    } else {
      paragraphNumber++;
      buffer.writeln('[Paragraph $paragraphNumber]');
      buffer.writeln(text);
    }
  }
  flushSection();

  return buffer.toString().trim();
}

// ---------------------------------------------------------------------------
// TXT
// ---------------------------------------------------------------------------

String _extractTxt(Uint8List bytes) {
  String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    throw TextExtractionException('This file is not readable text.');
  }

  final paragraphs = text
      .replaceAll('\r\n', '\n')
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);

  final buffer = StringBuffer();
  var n = 0;
  for (final paragraph in paragraphs) {
    n++;
    buffer.writeln('[Paragraph $n]');
    buffer.writeln(paragraph);
  }
  return buffer.toString().trim();
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

Archive _decodeZip(Uint8List bytes) {
  try {
    return ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw TextExtractionException('This file appears to be corrupted.');
  }
}

XmlDocument? _tryParseXml(String source) {
  try {
    return XmlDocument.parse(source);
  } on XmlException {
    return null;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
