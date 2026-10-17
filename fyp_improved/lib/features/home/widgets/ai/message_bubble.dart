import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/tomorrow-night.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MessageBubble extends StatefulWidget {
  final Map msg;
  const MessageBubble({super.key, required this.msg});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool hovering = false;
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bool isUser = widget.msg["role"] == "user";
    final String text = (widget.msg["text"] ?? "").toString().trim();
    if (text.isEmpty) return const SizedBox.shrink();

    // Check if this is a long lecture prompt / transcript
    final isLongLecturePrompt = isUser && text.length > 250;

    if (isLongLecturePrompt) {
      return _buildLectureTranscriptCard(context, text);
    }

    // Standard message rendering with markdown & code highlight support
    return _buildStandardBubble(context, isUser, text);
  }

  // ── Sleek Collapsible Lecture Transcript Card ───────────────
  Widget _buildLectureTranscriptCard(BuildContext context, String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final estimatedMinutes = (words / 130).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.88,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A), // Dark slate
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.graphic_eq_rounded,
                          color: Color(0xFF38BDF8),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Lecture Audio Transcript",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          "$words words • ~$estimatedMinutes min",
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Transcript Preview / Full Content
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                    secondChild: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          text,
                          style: const TextStyle(
                            color: Color(0xFFF1F5F9),
                            fontSize: 13.5,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Footer Actions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: const Color(0xFF38BDF8),
                        ),
                        label: Text(
                          isExpanded ? "Collapse Transcript" : "View Full Transcript",
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            isExpanded = !isExpanded;
                          });
                        },
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: Colors.white54,
                        ),
                        tooltip: "Copy transcript",
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Lecture transcript copied to clipboard"),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, right: 4),
            child: Text(
              "You (Recorded Lecture)",
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Standard Message Bubble with Markdown & Table Support ────
  Widget _buildStandardBubble(BuildContext context, bool isUser, String text) {
    final regex = RegExp(r'```(\w*)\n([\s\S]*?)```');
    final matches = regex.allMatches(text);

    List<Widget> children = [];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final textChunk = text.substring(lastEnd, match.start).trim();
        if (textChunk.isNotEmpty) {
          children.add(_buildMarkdownChunk(context, isUser, textChunk));
        }
      }
      final code = match.group(2) ?? '';
      final lang = match.group(1)?.toLowerCase() ?? 'text';

      children.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUser
                ? const Color.fromARGB(255, 20, 29, 120)
                : const Color(0xFF0F111A).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HighlightView(
              code.trim(),
              language: lang.isEmpty ? 'text' : lang,
              theme: tomorrowNightTheme,
              textStyle: const TextStyle(
                fontFamily: 'SourceCodePro',
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final textChunk = text.substring(lastEnd).trim();
      if (textChunk.isNotEmpty) {
        children.add(_buildMarkdownChunk(context, isUser, textChunk));
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color.fromARGB(255, 219, 219, 229)
                        : const Color(0xFF1B1F32),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 0),
                      bottomRight: Radius.circular(isUser ? 0 : 18),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...children,
                      if (!isUser && hovering)
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: widget.msg["text"]),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Copied"),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                isUser ? "You" : "AI Assistant",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownChunk(BuildContext context, bool isUser, String textChunk) {
    final textColor = isUser ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isUser ? const Color(0xFF94A3B8) : const Color(0xFF334155);

    final lines = textChunk.split('\n');
    List<Widget> blocks = [];
    List<String> currentBuffer = [];
    bool isTableBlock = false;

    void flushBuffer() {
      if (currentBuffer.isEmpty) return;
      final content = currentBuffer.join('\n').trim();
      if (content.isEmpty) {
        currentBuffer.clear();
        return;
      }

      final markdownWidget = MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(color: textColor, fontSize: 14.5, height: 1.5),
          h1: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
          h2: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold),
          h3: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
          strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
          listBullet: TextStyle(color: textColor, fontSize: 14),
          tableBorder: TableBorder.all(
            color: borderColor,
            width: 1,
            borderRadius: BorderRadius.circular(8),
          ),
          tableHead: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
          tableBody: TextStyle(color: textColor, fontSize: 13),
          tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          tableColumnWidth: const IntrinsicColumnWidth(),
          code: TextStyle(
            fontFamily: 'SourceCodePro',
            fontSize: 13,
            backgroundColor: isUser ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A),
            color: isUser ? const Color(0xFF0F172A) : const Color(0xFF38BDF8),
          ),
        ),
      );

      if (isTableBlock) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: markdownWidget,
            ),
          ),
        );
      } else {
        blocks.add(markdownWidget);
      }
      currentBuffer.clear();
    }

    for (final line in lines) {
      final isLineTable = line.trim().startsWith('|');
      if (isLineTable != isTableBlock) {
        flushBuffer();
        isTableBlock = isLineTable;
      }
      currentBuffer.add(line);
    }
    flushBuffer();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }
}
