import 'package:flutter/material.dart';

class DrawerFooterActions extends StatelessWidget {
  final VoidCallback onClearChats;
  final VoidCallback onLogout;

  const DrawerFooterActions({
    super.key,
    required this.onClearChats,
    required this.onLogout,
  });

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear History?"),
        content: const Text("This will permanently delete all your chats."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onClearChats();
            },
            child: const Text("Clear All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sign Out?"),
        content: const Text(
          "Are you sure you want to sign out of your account?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onLogout();
            },
            child: const Text("Sign Out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        ListTile(
          leading: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.red,
            size: 20,
          ),
          title: const Text(
            "Delete All Chats",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          onTap: () => _showClearConfirmation(context),
        ),
        ListTile(
          leading: const Padding(
            padding: EdgeInsets.only(left: 3),
            child: Icon(Icons.logout_rounded, color: Colors.red, size: 20),
          ),
          title: const Text(
            "Sign Out",
            style: TextStyle(
              color: Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () => _showLogoutConfirmation(context),
        ),
      ],
    );
  }
}
