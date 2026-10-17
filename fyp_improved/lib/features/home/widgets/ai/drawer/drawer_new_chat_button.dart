import 'package:flutter/material.dart';

class DrawerNewChatButton extends StatelessWidget {
  final VoidCallback onNewChat;

  const DrawerNewChatButton({super.key, required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: OutlinedButton.icon(
        onPressed: onNewChat,
        icon: const Icon(Icons.add, size: 20),
        label: const Text("New Conversation"),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blueAccent,
          side: BorderSide(color: Colors.grey.shade300),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
