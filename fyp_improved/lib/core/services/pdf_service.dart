import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class PdfService {
  /// Generates a professional, study-focused PDF prioritizing AI Notes over raw transcripts.
  static Future<Uint8List> generateLecturePdfBytes({
    required String title,
    String? courseCode,
    String? instructor,
    required String notesContent,
    String? rawTranscript,
    String? transcript, // Backward compatibility alias
    required String date,
    bool includeTranscriptAppendix = false,
  }) async {
    final pdf = pw.Document();
    final cleanCourseCode = (courseCode ?? "").trim();
    final cleanInstructor = (instructor ?? "").trim();
    final cleanTitle = title.replaceAll('*', '').trim();
    final effectiveNotes = notesContent.isNotEmpty ? notesContent : (transcript ?? "");
    final effectiveRawTranscript = (rawTranscript ?? (notesContent.isNotEmpty ? transcript : null) ?? "").trim();

    // Fonts
    pw.Font font;
    pw.Font fontBold;

    try {
      font = await PdfGoogleFonts.poppinsRegular().timeout(
        const Duration(seconds: 3),
      );
      fontBold = await PdfGoogleFonts.poppinsBold().timeout(
        const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint("Font loading failed, using fallback: $e");
      font = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    // Process notes content into formatted PDF widgets
    final List<pw.Widget> notesWidgets = _buildFormattedContent(effectiveNotes, font, fontBold);

    // Process raw transcript appendix if enabled
    List<pw.Widget> appendixWidgets = [];
    if (includeTranscriptAppendix && effectiveRawTranscript.isNotEmpty) {
      appendixWidgets = [
        pw.SizedBox(height: 24),
        pw.Divider(thickness: 1, color: PdfColors.grey400),
        pw.SizedBox(height: 12),
        pw.Text(
          "APPENDIX: RAW AUDIO TRANSCRIPT",
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 11,
            color: PdfColors.grey700,
            letterSpacing: 1.1,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          effectiveRawTranscript,
          style: pw.TextStyle(
            font: font,
            fontSize: 9,
            color: PdfColors.grey600,
            lineSpacing: 2,
          ),
          textAlign: pw.TextAlign.justify,
        ),
      ];
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount} • VoiceNoteX AI Notes',
              style: pw.TextStyle(
                font: font,
                fontSize: 9,
                color: PdfColors.grey500,
              ),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            /// ================= HEADER =================
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        cleanTitle,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 22,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        date,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 9.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                      if (cleanCourseCode.isNotEmpty ||
                          cleanInstructor.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Row(
                          children: [
                            if (cleanCourseCode.isNotEmpty)
                              pw.Text(
                                "Course: $cleanCourseCode",
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 10,
                                  color: PdfColors.grey800,
                                ),
                              ),
                            if (cleanCourseCode.isNotEmpty &&
                                cleanInstructor.isNotEmpty)
                              pw.Text(
                                "  |  ",
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 10,
                                  color: PdfColors.grey400,
                                ),
                              ),
                            if (cleanInstructor.isNotEmpty)
                              pw.Text(
                                "Instructor: $cleanInstructor",
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 10,
                                  color: PdfColors.grey800,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.PdfLogo(),
              ],
            ),

            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1.5, color: PdfColors.blue800),
            pw.SizedBox(height: 14),

            /// ================= NOTES SECTION HEADER =================
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "AI STUDY NOTES & SUMMARY",
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 12,
                    color: PdfColors.blue800,
                    letterSpacing: 1.1,
                  ),
                ),
                pw.Text(
                  "VoiceNoteX",
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: PdfColors.grey500,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            /// ================= NOTES CONTENT =================
            ...notesWidgets,

            /// ================= OPTIONAL APPENDIX =================
            ...appendixWidgets,

            /// ================= FOOTER CONTENT =================
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                "VoiceNoteX • Smart AI Lecture Notes",
                style: pw.TextStyle(
                  font: font,
                  fontSize: 8,
                  color: PdfColors.grey400,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static List<pw.Widget> _buildFormattedContent(
    String content,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final List<pw.Widget> widgets = [];
    final lines = content.split('\n');

    for (var line in lines) {
      String trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // 1. Handle Bullet Points
      if (trimmedLine.startsWith('- ') ||
          trimmedLine.startsWith('• ') ||
          (trimmedLine.startsWith('* ') && !trimmedLine.endsWith('*'))) {
        final text = trimmedLine.substring(2).trim();
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, bottom: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4, right: 8),
                  child: pw.Container(
                    width: 4,
                    height: 4,
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue700,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                ),
                pw.Expanded(
                  child: _buildRichSpan(text, font, fontBold),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 2. Handle Headings
      int headingLevel = 0;
      if (trimmedLine.startsWith('###')) {
        headingLevel = 3;
      } else if (trimmedLine.startsWith('##')) {
        headingLevel = 2;
      } else if (trimmedLine.startsWith('#')) {
        headingLevel = 1;
      }

      bool looksLikeHeading =
          headingLevel > 0 ||
          (trimmedLine.length < 60 &&
              trimmedLine.toUpperCase() == trimmedLine &&
              trimmedLine.length > 4);

      if (looksLikeHeading) {
        final headingText = trimmedLine
            .replaceAll('#', '')
            .trim()
            .replaceAll('**', '');
        double fontSize = 14;
        pw.PdfColor color = PdfColors.blue900;
        double topPadding = 14;

        if (headingLevel == 2) {
          fontSize = 12.5;
          color = PdfColors.blue800;
          topPadding = 12;
        } else if (headingLevel == 3) {
          fontSize = 11.5;
          color = PdfColors.grey800;
          topPadding = 10;
        }

        widgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(top: topPadding, bottom: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  headingText,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: fontSize,
                    color: color,
                  ),
                ),
                if (headingLevel <= 1) ...[
                  pw.SizedBox(height: 2),
                  pw.Container(
                    height: 1.5,
                    width: 32,
                    color: PdfColors.blue400,
                  ),
                ],
              ],
            ),
          ),
        );
      } else {
        // 3. Regular Paragraphs
        widgets.add(_buildRichParagraph(trimmedLine, font, fontBold));
      }
    }

    return widgets;
  }

  static pw.Widget _buildRichParagraph(
    String text,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: _buildRichSpan(text, font, fontBold),
    );
  }

  static pw.Widget _buildRichSpan(
    String text,
    pw.Font font,
    pw.Font fontBold,
  ) {
    final List<pw.InlineSpan> spans = [];
    final RegExp regex = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final Match match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(
          pw.TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: pw.TextStyle(
              font: font,
              fontSize: 11,
              color: PdfColors.black,
            ),
          ),
        );
      }
      spans.add(
        pw.TextSpan(
          text: match.group(1),
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 11,
            color: PdfColors.blue900,
          ),
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(
        pw.TextSpan(
          text: text.substring(lastMatchEnd),
          style: pw.TextStyle(
            font: font,
            fontSize: 11,
            color: PdfColors.black,
          ),
        ),
      );
    }

    return pw.RichText(
      text: pw.TextSpan(children: spans, style: pw.TextStyle(lineSpacing: 2.8)),
      textAlign: pw.TextAlign.justify,
    );
  }

  static Future<String> savePdfBytesToDownloads(
    Uint8List pdfBytes, {
    String fileName = "lecture_notes.pdf",
  }) async {
    final safeFileName = fileName.endsWith(".pdf") ? fileName : "$fileName.pdf";

    if (kIsWeb || Platform.isAndroid) {
      await Printing.sharePdf(bytes: pdfBytes, filename: safeFileName);
      return "Shared via system sheet: $safeFileName";
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File("${tempDir.path}/$safeFileName");
    await tempFile.writeAsBytes(pdfBytes);

    final docDir = await getApplicationDocumentsDirectory();
    final finalFile = File("${docDir.path}/$safeFileName");

    final savedFile = await tempFile.copy(finalFile.path);
    return savedFile.path;
  }
}
