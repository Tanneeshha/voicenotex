import 'package:flutter/material.dart';

class MicButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback onMicPressed;
  final VoidCallback onClearPressed;
  final bool canClear;

  const MicButton({
    super.key,
    required this.isListening,
    required this.onMicPressed,
    required this.onClearPressed,
    required this.canClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FloatingActionButton(
          heroTag: 'mic',
          onPressed: onMicPressed,
          child: Icon(isListening ? Icons.mic : Icons.mic_none),
        ),
        const SizedBox(width: 16),
        FloatingActionButton(
          heroTag: 'clear',
          onPressed: canClear ? onClearPressed : null,
          child: const Icon(Icons.clear),
        ),
      ],
    );
  }
}
