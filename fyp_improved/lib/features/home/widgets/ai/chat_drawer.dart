import 'package:flutter/material.dart';
import 'drawer/drawer_profile_header.dart';
import 'drawer/drawer_new_chat_button.dart';
import 'drawer/drawer_chat_list.dart';
import 'drawer/drawer_footer_actions.dart';

class ChatDrawer extends StatelessWidget {
  final List<dynamic> chats;
  final String? activeChatId;
  final String userEmail;
  final Function(String) onChatSelected;
  final VoidCallback onNewChat;
  final VoidCallback onLogout;
  final VoidCallback onClearChats;
  final Function(String) onDeleteChat;

  const ChatDrawer({
    super.key,
    required this.chats,
    required this.activeChatId,
    required this.userEmail,
    required this.onChatSelected,
    required this.onNewChat,
    required this.onLogout,
    required this.onClearChats,
    required this.onDeleteChat,
  });

  @override
  Widget build(BuildContext context) {
    final filteredChats = chats
        .where((chat) => chat['last_message'] != "New Chat")
        .toList();

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DrawerProfileHeader(userEmail: userEmail),
            DrawerNewChatButton(onNewChat: onNewChat),
            const SizedBox(height: 16),
            DrawerChatList(
              chats: filteredChats,
              activeChatId: activeChatId,
              onChatSelected: onChatSelected,
              onDeleteChat: onDeleteChat,
            ),
            DrawerFooterActions(
              onClearChats: onClearChats,
              onLogout: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}
