import 'package:flutter/material.dart';

class DrawerChatList extends StatelessWidget {
  final List<dynamic> chats;
  final String? activeChatId;
  final Function(String) onChatSelected;
  final Function(String) onDeleteChat;

  const DrawerChatList({
    super.key,
    required this.chats,
    required this.activeChatId,
    required this.onChatSelected,
    required this.onDeleteChat,
  });

  void _showDeleteConfirmation(BuildContext context, String chatId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Chat?"),
        content: const Text("This conversation will be permanently deleted."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDeleteChat(chatId);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Text(
              "RECENT CHATS",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: chats.isEmpty
                ? Center(
                    child: Text(
                      "No chats",
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      final isSelected = chat['chat_id'] == activeChatId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isSelected
                              ? Colors.blue.withValues(alpha: 0.08)
                              : Colors.transparent,
                        ),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          leading: Icon(
                            Icons.chat_bubble_outline,
                            size: 20,
                            color: isSelected ? Colors.blue : Colors.black54,
                          ),
                          title: Text(
                            chat['last_message'] ?? "Untitled Chat",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected
                                  ? Colors.blue.shade700
                                  : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Color.fromARGB(255, 173, 41, 41),
                            ),
                            onPressed: () {
                              _showDeleteConfirmation(context, chat['chat_id']);
                            },
                          ),
                          onTap: () => onChatSelected(chat['chat_id']),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
