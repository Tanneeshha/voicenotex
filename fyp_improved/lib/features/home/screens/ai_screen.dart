import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../widgets/ai/message_bubble.dart';
import '../widgets/ai/style_dialog.dart';
import '../widgets/ai/chat_input.dart';
import '../../../core/services/style_service.dart';
import '../widgets/ai/chat_drawer.dart';
import '../../auth/screens/login_screen.dart';
import '../widgets/ai/ai_empty_state.dart';
import '../../auth/screens/onboarding_preferences_screen.dart';
import '../../notes/screens/notes_screen.dart';
import '../../../core/widgets/custom_snackbar.dart';

class AiAssistantScreen extends StatefulWidget {
  final String? initialPrompt;
  final String? lectureId;
  final bool persistInitialResponseToLecture;
  final bool autoSendInitialPrompt;
  final String? initialChatId;

  const AiAssistantScreen({
    super.key,
    this.initialPrompt,
    this.lectureId,
    this.persistInitialResponseToLecture = false,
    this.autoSendInitialPrompt = true,
    this.initialChatId,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> messages = [];
  List<String> selectedStyles = StyleService.selectedStyles;
  List<dynamic> userChats = [];
  String? currentChatId;
  String? userEmail = StyleService.currentUserEmail;

  bool isTyping = false;
  bool stopTyping = false;
  bool isLoadingChats = false;
  bool isLoadingHistory = false;
  bool _savedInitialLectureResponse = false;
  bool _autoScrollEnabled = true;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    if (userEmail == null) return;

    await fetchUserChats();

    if (widget.initialChatId != null && widget.initialChatId!.isNotEmpty) {
      await loadChatHistory(widget.initialChatId!);
      return;
    }

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      if (widget.autoSendInitialPrompt) {
        await createNewChat(initialText: widget.initialPrompt);
      } else {
        await createNewChat();
        if (mounted) {
          setState(() {
            controller.text = widget.initialPrompt!;
          });
        }
      }
    } else {
      await createNewChat();
    }
  }

  Future<void> fetchUserChats() async {
    if (userEmail == null) return;
    setState(() => isLoadingChats = true);
    try {
      final res = await ApiService.getChats(userEmail!);
      if (res["success"] == true) {
        setState(() {
          userChats = res["data"] is List ? res["data"] : [];
        });
      }
    } finally {
      if (mounted) setState(() => isLoadingChats = false);
    }
  }

  Future<void> loadChatHistory(String chatId) async {
    setState(() {
      currentChatId = chatId;
      messages = [];
      isLoadingHistory = true;
    });
    try {
      final res = await ApiService.getChatHistory(chatId);
      if (res["success"] == true && mounted) {
        setState(() {
          messages = (res["data"]["messages"] as List)
              .where((m) => m["role"] != "system")
              .toList()
              .reversed
              .map(
                (m) => {
                  "role": m["role"],
                  "text": m["text"] ?? m["content"] ?? "",
                },
              )
              .toList();
        });
      }
    } finally {
      if (mounted) setState(() => isLoadingHistory = false);
    }
  }

  Future<void> createNewChat({String? initialText}) async {
    if (userEmail == null) return;
    final res = await ApiService.createNewChat(userEmail!);
    if (res["success"] == true) {
      final newChatId = res["data"]["chat_id"];
      await fetchUserChats();
      if (mounted) {
        setState(() {
          currentChatId = newChatId;
          messages = [];
        });
      }
      if (initialText != null) {
        sendMessage(initialText);
      }
    }
  }

  Future<void> clearAllChats() async {
    if (userEmail == null) return;
    final res = await ApiService.getChats(userEmail!);
    if (res["success"] == true && res["data"] is List) {
      for (final chat in res["data"]) {
        await ApiService.deleteChat(chat["chat_id"]);
      }
    }
    await fetchUserChats();
    await createNewChat();
  }

  Future<void> deleteChat(String chatId) async {
    final res = await ApiService.deleteChat(chatId);
    if (res["success"] == true) {
      await fetchUserChats();
      if (currentChatId == chatId) {
        if (userChats.isNotEmpty) {
          loadChatHistory(userChats.first['chat_id']);
        } else {
          await createNewChat();
        }
      }
    }
  }

  Future<void> sendMessage(String text) async {
    if (isTyping || userEmail == null || currentChatId == null) return;

    setState(() {
      messages.insert(0, {"role": "user", "text": text});
      isTyping = true;
      stopTyping = false;
    });
    _scrollToBottom();

    List<Map<String, String>> history = messages.reversed
        .where((m) => (m["text"] ?? m["content"] ?? "").toString().isNotEmpty)
        .map(
          (m) => {
            "role": m["role"].toString(),
            "content": (m["text"] ?? m["content"] ?? "").toString(),
          },
        )
        .toList();

    if (history.isNotEmpty) history.removeLast();

    try {
      final result = await ApiService.chat(
        prompt: text,
        email: userEmail!,
        chatId: currentChatId!,
        styles: selectedStyles,
        history: history,
      );

      if (result["success"] == true) {
        final String fullReply = result["data"]["response"];

        if (widget.persistInitialResponseToLecture &&
            !_savedInitialLectureResponse &&
            widget.lectureId != null &&
            widget.lectureId!.isNotEmpty &&
            widget.initialPrompt != null &&
            text == widget.initialPrompt) {
          // Store in local variable so Dart null safety is satisfied
          final String safeLectureId = widget.lectureId ?? "";
          final saveRes = await ApiService.updateLectureAiResponse(
            safeLectureId,
            aiResponse: fullReply,
            lecturePrompt: widget.initialPrompt,
            chatId: currentChatId,
          );
          if (saveRes["success"] == true) {
            _savedInitialLectureResponse = true;
          }
        }

        await animateTyping(fullReply);
        fetchUserChats();
      } else {
        throw Exception(result["error"] ?? "Unknown error");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => isTyping = false);
    }
  }

  Future<void> animateTyping(String text) async {
    String currentText = "";
    setState(() {
      messages.insert(0, {"role": "assistant", "text": ""});
    });

    // For long lecture notes, use larger batches for fast, buttery smooth rendering
    final int batchSize = text.length > 500 ? 50 : 15;
    final int delayMs = text.length > 500 ? 10 : 15;

    int i = 0;
    while (i < text.length) {
      if (stopTyping) {
        setState(() {
          messages[0]["text"] = currentText + text.substring(i);
        });
        break;
      }

      int end = (i + batchSize < text.length) ? i + batchSize : text.length;
      currentText += text.substring(i, end);
      i = end;

      setState(() {
        messages[0]["text"] = currentText;
      });

      await Future.delayed(Duration(milliseconds: delayMs));
      _scrollToBottom(force: false);
    }
  }

  void stopResponse() {
    if (isTyping) {
      setState(() => stopTyping = true);
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels <= 60;
  }

  void _scrollToBottom({bool force = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (!force && (!_autoScrollEnabled || !_isNearBottom())) return;
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> showStyleSettings() async {
    await StyleDialog.show(
      context,
      initialStyles: selectedStyles,
      onApply: (newStyles) async {
        final updated = newStyles.isEmpty ? ["short"] : newStyles;
        await StyleService.saveStyles(updated);
        if (mounted) {
          setState(() => selectedStyles = updated);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leadingWidth: 100,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_open_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        title: Column(
          children: [
            const Text(
              "AI Assistant",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              "Level: ${StyleService.advancedLevel}",
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Student Level & Preferences",
            icon: const Icon(Icons.auto_awesome, color: Color(0xFF4F46E5)),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnboardingPreferencesScreen()),
              );
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            tooltip: "Response Style",
            icon: const Icon(Icons.tune, color: Colors.black),
            onPressed: showStyleSettings,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
              label: const Text("Done", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              onPressed: () {
                CustomSnackBar.show(context, "Saved to My Lectures!");
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const NotesScreen()),
                  (route) => route.isFirst,
                );
              },
            ),
          ),
        ],
      ),
      drawer: userEmail == null
          ? null
          : ChatDrawer(
              chats: userChats,
              activeChatId: currentChatId,
              userEmail: userEmail!,
              onChatSelected: (id) {
                Navigator.pop(context);
                loadChatHistory(id);
              },
              onNewChat: () {
                Navigator.pop(context);
                createNewChat();
              },
              onClearChats: () {
                Navigator.pop(context);
                clearAllChats();
              },
              onDeleteChat: (id) {
                deleteChat(id);
              },
              onLogout: () async {
                await StyleService.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
      body: Column(
        children: [
          Expanded(
            child: isLoadingHistory
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  )
                : messages.isEmpty && !isTyping
                ? const AiEmptyState()
                : NotificationListener<UserScrollNotification>(
                    onNotification: (notification) {
                      if (!_scrollController.hasClients) return false;
                      final nearBottom = _isNearBottom();
                      if (nearBottom != _autoScrollEnabled) {
                        setState(() => _autoScrollEnabled = nearBottom);
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) =>
                          MessageBubble(msg: messages[index]),
                    ),
                  ),
          ),
          if (messages.isNotEmpty) _buildQuickActionChips(),
          ChatInput(
            controller: controller,
            isTyping: isTyping,
            onSend: () {
              if (controller.text.isNotEmpty) {
                sendMessage(controller.text);
                controller.clear();
              }
            },
            onStop: stopResponse,
          ),
        ],
      ),
      floatingActionButton: !_autoScrollEnabled
          ? FloatingActionButton.extended(
              onPressed: () {
                setState(() => _autoScrollEnabled = true);
                _scrollToBottom(force: true);
              },
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.arrow_downward_rounded, size: 18),
              label: const Text(
                "Jump to latest",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildQuickActionChips() {
    final chips = [
      {
        "label": "💡 Simplify",
        "prompt": "Can you simplify the main concepts in this lecture using plain language and clear analogies suitable for a beginner?",
      },
      {
        "label": "🎓 Quiz Me",
        "prompt": "Generate 5 interactive multiple choice practice questions based on this lecture with an answer key at the end.",
      },
      {
        "label": "📊 Summary Table",
        "prompt": "Create a clear comparison summary table of all key concepts covered in this lecture.",
      },
      {
        "label": "🔑 Key Terms",
        "prompt": "Extract and format an expanded glossary table of all important definitions and technical terms from this lecture.",
      },
      {
        "label": "📝 Practice Problems",
        "prompt": "Provide 3 realistic exam-style practice problems with step-by-step solutions based on this lecture content.",
      },
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isTyping ? null : () => sendMessage(chip["prompt"]!),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                ),
                child: Center(
                  child: Text(
                    chip["label"]!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isTyping ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
