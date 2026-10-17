import 'package:flutter/material.dart';
import 'recent_lecture_item.dart';

class RecentLecturesList extends StatefulWidget {
  final bool isLoading;
  final List<dynamic> lectures;
  final Function(Map<String, dynamic>) onDelete;
  final Future<void> Function() onDeleteAll;
  final Function(String) onTap;
  final String Function(String) formatDate;

  const RecentLecturesList({
    super.key,
    required this.isLoading,
    required this.lectures,
    required this.onDelete,
    required this.onDeleteAll,
    required this.onTap,
    required this.formatDate,
  });

  @override
  State<RecentLecturesList> createState() => _RecentLecturesListState();
}

class _RecentLecturesListState extends State<RecentLecturesList> {
  static const int _initialVisibleCount = 4;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final hasMoreLectures = widget.lectures.length > _initialVisibleCount;
    final visibleLectures = _showAll
        ? widget.lectures
        : widget.lectures.take(_initialVisibleCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Recent Lectures",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            Row(
              children: [
                if (!widget.isLoading && widget.lectures.isNotEmpty)
                  TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text("Delete all lectures?"),
                          content: const Text(
                            "This will permanently remove all recent lectures.",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext, false),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext, true),
                              child: const Text(
                                "Delete all",
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await widget.onDeleteAll();
                      }
                    },
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    label: const Text(
                      "Delete all",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                if (hasMoreLectures)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showAll = !_showAll;
                      });
                    },
                    child: Row(
                      children: [
                        Text(_showAll ? "Show less" : "See all"),
                        const SizedBox(width: 4),
                        Icon(
                          _showAll ? Icons.expand_less : Icons.arrow_forward,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (widget.lectures.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(Icons.history_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  "No recent lectures yet",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          )
        else
          ...visibleLectures.map(
            (lec) => RecentLectureItem(
              title: lec["title"] ?? "Untitled",
              subtitle:
                  "${widget.formatDate(lec["created_at"]?.toString() ?? '')} · ${lec["course_code"] ?? lec["instructor"] ?? "No details"}${((lec["ai_response"] ?? "").toString().trim().isNotEmpty) ? " · AI ready" : ""}",
              icon: Icons.auto_awesome,
              onDelete: () => widget.onDelete(lec),
              onTap: () {
                final lectureId = lec["lecture_id"]?.toString() ?? "";
                if (lectureId.isNotEmpty) {
                  widget.onTap(lectureId);
                }
              },
            ),
          ),
      ],
    );
  }
}
