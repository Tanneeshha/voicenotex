import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SpeechTextArea extends StatelessWidget {
  final TextEditingController textController;
  final ScrollController scrollController;
  final bool isListening;

  const SpeechTextArea({
    super.key,
    required this.textController,
    required this.scrollController,
    required this.isListening,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = textController.text.trim().isNotEmpty &&
        textController.text.trim() != 'Tap the microphone to start listening...';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark elegant slate background
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: TextField(
              controller: textController,
              scrollController: scrollController,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                fontSize: 17,
                height: 1.65,
                color: Color(0xFFF8FAFC),
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.start,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Your live lecture transcription will appear here in real-time...',
                hintStyle: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (hasText)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                  tooltip: "Copy transcript",
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: textController.text.trim()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text("Transcript copied to clipboard"),
                          ],
                        ),
                        backgroundColor: const Color(0xFF1E3A8A),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
