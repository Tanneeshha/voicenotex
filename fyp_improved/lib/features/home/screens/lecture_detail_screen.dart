import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/style_service.dart';
import '../../../core/widgets/custom_snackbar.dart';
import 'ai_screen.dart';

// ============================================================
// LectureDetailScreen — View a Saved Lecture's Notes
// ============================================================
// Shows:
// - Full AI-generated notes (with markdown-style rendering)
// - Feedback buttons: Helpful / Needs Improvement
// - Improve Notes button (AI regenerates if feedback was negative)
// - Option to open in AI Chat for further questions
// - Favorite toggle
// ============================================================

class LectureDetailScreen extends StatefulWidget {
  final String lectureId;

  const LectureDetailScreen({super.key, required this.lectureId});

  @override
  State<LectureDetailScreen> createState() => _LectureDetailScreenState();
}

class _LectureDetailScreenState extends State<LectureDetailScreen> {
  Map<String, dynamic>? _lecture;
  bool _isLoading = true;
  bool _isSubmittingFeedback = false;
  bool _isImprovingNotes = false;
  String? _currentFeedback;

  @override
  void initState() {
    super.initState();
    _loadLecture();
  }

  Future<void> _loadLecture() async {
    setState(() => _isLoading = true);
    final res = await ApiService.getLectureDetail(widget.lectureId);
    if (res["success"] == true && mounted) {
      setState(() {
        _lecture = res["data"];
        _currentFeedback = res["data"]?["feedback"]?["rating"];
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitFeedback(String rating, {String? feedbackType}) async {
    final email = StyleService.currentUserEmail;
    if (email == null) return;

    setState(() => _isSubmittingFeedback = true);

    final res = await ApiService.submitFeedback(
      lectureId: widget.lectureId,
      email: email,
      rating: rating,
      feedbackType: feedbackType,
    );

    if (!mounted) return;
    setState(() {
      _isSubmittingFeedback = false;
      if (res["success"] == true) _currentFeedback = rating;
    });

    if (res["success"] == true) {
      CustomSnackBar.show(
        context,
        rating == "helpful"
            ? "Thanks! Glad the notes were helpful 👍"
            : "Got it! You can tap 'Improve Notes' to regenerate them.",
      );
    }
  }

  Future<void> _improveNotes() async {
    final email = StyleService.currentUserEmail;
    if (email == null) return;

    // Ask which type of improvement
    final feedbackType = await _showImprovementTypeDialog();
    if (feedbackType == null || !mounted) return;

    setState(() => _isImprovingNotes = true);
    CustomSnackBar.show(context, "Improving notes with AI... ⏳");

    final res = await ApiService.improveNotes(
      lectureId: widget.lectureId,
      email: email,
      feedbackType: feedbackType,
    );

    if (!mounted) return;
    setState(() => _isImprovingNotes = false);

    if (res["success"] == true) {
      CustomSnackBar.show(context, "Notes improved! 🎉");
      await _loadLecture(); // Reload with improved notes
    } else {
      CustomSnackBar.show(
        context,
        res["error"] ?? "Failed to improve notes",
        isError: true,
      );
    }
  }

  Future<String?> _showImprovementTypeDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("What should be improved?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildImprovementOption(ctx, "too_long", "Too long", "Summarize and shorten"),
            _buildImprovementOption(ctx, "too_short", "Too brief", "Add more detail"),
            _buildImprovementOption(ctx, "unclear", "Hard to understand", "Simplify language"),
            _buildImprovementOption(ctx, "missing_content", "Missing content", "Cover more topics"),
            _buildImprovementOption(ctx, "general", "General improvement", "Overall quality"),
          ],
        ),
      ),
    );
  }

  Widget _buildImprovementOption(
    BuildContext ctx,
    String value,
    String title,
    String subtitle,
  ) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: () => Navigator.pop(ctx, value),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }

  Future<void> _toggleFavorite() async {
    final email = StyleService.currentUserEmail;
    if (email == null || _lecture == null) return;

    final current = _lecture!["is_favorite"] == true;
    final res = await ApiService.toggleFavorite(
      lectureId: widget.lectureId,
      email: email,
      isFavorite: !current,
    );

    if (res["success"] == true && mounted) {
      setState(() => _lecture!["is_favorite"] = !current);
      CustomSnackBar.show(
        context,
        !current ? "Added to favorites ⭐" : "Removed from favorites",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: Text(
          _lecture?["ai_title"] ?? _lecture?["title"] ?? "Lecture Notes",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_lecture != null)
            IconButton(
              icon: Icon(
                _lecture!["is_favorite"] == true
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: _lecture!["is_favorite"] == true
                    ? const Color(0xFFF59E0B)
                    : Colors.grey,
              ),
              onPressed: _toggleFavorite,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lecture == null
              ? const Center(child: Text("Lecture not found"))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final aiResponse = _lecture!["ai_response"] as String?;
    final transcript = _lecture!["transcript"] as String?;
    final courseCode = _lecture!["course_code"] as String?;
    final instructor = _lecture!["instructor"] as String?;
    final subject = _lecture!["subject"] as String? ?? "Academic";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Meta info card ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        subject,
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 4),
                    const Text(
                      "AI Generated",
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 12),
                    ),
                  ],
                ),
                if (courseCode != null || instructor != null) ...[
                  const SizedBox(height: 10),
                  if (courseCode != null)
                    Row(
                      children: [
                        const Icon(Icons.school, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text("Course: $courseCode",
                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  if (instructor != null)
                    Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text("Instructor: $instructor",
                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── AI Notes ──────────────────────────────────────
          if (aiResponse != null && aiResponse.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFF1E3A8A), size: 18),
                      SizedBox(width: 8),
                      Text(
                        "AI Generated Notes",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    aiResponse,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.7,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Feedback Section ───────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Were these notes helpful?",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Your feedback helps improve the AI system.",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (_isSubmittingFeedback)
                    const Center(child: CircularProgressIndicator())
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildFeedbackButton(
                            label: "👍 Helpful",
                            isSelected: _currentFeedback == "helpful",
                            selectedColor: const Color(0xFF10B981),
                            onTap: () => _submitFeedback("helpful"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFeedbackButton(
                            label: "👎 Needs Improvement",
                            isSelected: _currentFeedback == "improve",
                            selectedColor: Colors.orange,
                            onTap: () => _submitFeedback("improve"),
                          ),
                        ),
                      ],
                    ),

                  // Improve Notes button (shown when feedback is negative)
                  if (_currentFeedback == "improve") ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isImprovingNotes ? null : _improveNotes,
                        icon: _isImprovingNotes
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_fix_high_rounded),
                        label: Text(
                          _isImprovingNotes ? "Improving..." : "Improve Notes with AI",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Ask AI about this lecture ──────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiAssistantScreen(
                        initialPrompt:
                            "Based on this lecture content:\n\n${transcript ?? aiResponse}",
                        lectureId: widget.lectureId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.smart_toy_rounded),
                label: const Text("Ask AI About This Lecture"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ] else ...[
            // No notes yet
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome, size: 48, color: Color(0xFF6366F1)),
                  const SizedBox(height: 12),
                  const Text(
                    "No AI Notes Yet",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Generate AI notes from this lecture transcript.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AiAssistantScreen(
                            initialPrompt: transcript ?? "",
                            lectureId: widget.lectureId,
                            persistInitialResponseToLecture: true,
                          ),
                        ),
                      ).then((_) => _loadLecture());
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text("Generate Notes"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFeedbackButton({
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withValues(alpha: 0.1) : Colors.grey[100],
          border: Border.all(
            color: isSelected ? selectedColor : Colors.grey[300]!,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? selectedColor : Colors.grey[600],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
