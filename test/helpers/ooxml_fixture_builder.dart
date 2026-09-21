import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Builds minimal-but-valid PPTX/DOCX bytes for text-extraction unit tests,
/// so slide-order and heading-detection edge cases can be tested
/// deterministically without depending only on real sample files.
void _addTextFile(Archive archive, String path, String content) {
  archive.addFile(ArchiveFile.string(path, content));
}

/// A PPTX with one slide per entry in [slideBodies] (raw `<p:sp>...</p:sp>`
/// shape XML), in that display order.
Uint8List buildPptxBytes(List<String> slideBodies) {
  final archive = Archive();

  final sldIdEntries = StringBuffer();
  final relEntries = StringBuffer();
  for (var i = 0; i < slideBodies.length; i++) {
    final n = i + 1;
    final rId = 'rId$n';
    sldIdEntries.writeln('<p:sldId id="${255 + n}" r:id="$rId"/>');
    relEntries.writeln(
      '<Relationship Id="$rId" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" '
      'Target="slides/slide$n.xml"/>',
    );

    _addTextFile(
      archive,
      'ppt/slides/slide$n.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
          'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
          '<p:cSld><p:spTree>${slideBodies[i]}</p:spTree></p:cSld>'
          '</p:sld>',
    );
  }

  _addTextFile(
    archive,
    'ppt/presentation.xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<p:sldIdLst>$sldIdEntries</p:sldIdLst>'
        '</p:presentation>',
  );
  _addTextFile(
    archive,
    'ppt/_rels/presentation.xml.rels',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$relEntries'
        '</Relationships>',
  );

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// A single `<p:sp>` shape with a title placeholder ("title" or
/// "ctrTitle") containing [text] as one paragraph/run.
String pptxTitleShape(String text, {String phType = 'title'}) {
  return '<p:sp><p:nvSpPr><p:nvPr><p:ph type="$phType"/></p:nvPr></p:nvSpPr>'
      '<p:txBody><a:p><a:r><a:t>$text</a:t></a:r></a:p></p:txBody></p:sp>';
}

/// A single `<p:sp>` shape with no placeholder type (a plain text box),
/// one paragraph per entry in [lines].
String pptxTextBoxShape(List<String> lines) {
  final paragraphs = lines
      .map((l) => '<a:p><a:r><a:t>$l</a:t></a:r></a:p>')
      .join();
  return '<p:sp><p:nvSpPr><p:nvPr/></p:nvSpPr>'
      '<p:txBody>$paragraphs</p:txBody></p:sp>';
}

/// A DOCX wrapping [bodyXml] (raw `<w:p>...</w:p>` paragraph XML) as
/// `word/document.xml`'s body.
Uint8List buildDocxBytes(String bodyXml) {
  final archive = Archive();
  _addTextFile(
    archive,
    'word/document.xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$bodyXml</w:body>'
        '</w:document>',
  );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// A `<w:p>` paragraph, optionally styled with [styleId] (e.g. "Heading1"),
/// containing [text] as a single run.
String docxParagraph(String text, {String? styleId}) {
  final pPr = styleId == null
      ? ''
      : '<w:pPr><w:pStyle w:val="$styleId"/></w:pPr>';
  return '<w:p>$pPr<w:r><w:t>$text</w:t></w:r></w:p>';
}
