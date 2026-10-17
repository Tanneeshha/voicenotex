import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model representing an auto-saved draft of a lecture recording session.
class LectureDraft {
  final String id;
  final String title;
  final String? courseCode;
  final String? instructor;
  final String transcript;
  final int durationSeconds;
  final DateTime lastSaved;

  LectureDraft({
    required this.id,
    required this.title,
    this.courseCode,
    this.instructor,
    required this.transcript,
    required this.durationSeconds,
    required this.lastSaved,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'courseCode': courseCode,
        'instructor': instructor,
        'transcript': transcript,
        'durationSeconds': durationSeconds,
        'lastSaved': lastSaved.toIso8601String(),
      };

  factory LectureDraft.fromJson(Map<String, dynamic> json) => LectureDraft(
        id: json['id'] as String? ?? 'active_draft',
        title: json['title'] as String? ?? 'Untitled Lecture',
        courseCode: json['courseCode'] as String?,
        instructor: json['instructor'] as String?,
        transcript: json['transcript'] as String? ?? '',
        durationSeconds: json['durationSeconds'] as int? ?? 0,
        lastSaved: json['lastSaved'] != null
            ? DateTime.tryParse(json['lastSaved'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Service that handles automatic checkpointing and recovery of lecture transcripts.
class LectureDraftService {
  static const String _draftKey = 'active_lecture_draft_checkpoint';

  /// Save an in-progress lecture draft to local storage.
  static Future<void> saveDraft({
    required String id,
    required String title,
    String? courseCode,
    String? instructor,
    required String transcript,
    required int durationSeconds,
  }) async {
    if (transcript.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = LectureDraft(
        id: id,
        title: title,
        courseCode: courseCode,
        instructor: instructor,
        transcript: transcript,
        durationSeconds: durationSeconds,
        lastSaved: DateTime.now(),
      );
      await prefs.setString(_draftKey, jsonEncode(draft.toJson()));
    } catch (e) {
      debugPrint("Failed to save lecture draft checkpoint: $e");
    }
  }

  /// Retrieve the current stored draft, if one exists.
  static Future<LectureDraft?> loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || raw.isEmpty) return null;

      final Map<String, dynamic> data = jsonDecode(raw);
      final draft = LectureDraft.fromJson(data);
      if (draft.transcript.trim().isEmpty) {
        await clearDraft();
        return null;
      }
      return draft;
    } catch (e) {
      debugPrint("Failed to load lecture draft checkpoint: $e");
      return null;
    }
  }

  /// Check whether an active draft exists in local storage.
  static Future<bool> hasDraft() async {
    final draft = await loadDraft();
    return draft != null && draft.transcript.trim().isNotEmpty;
  }

  /// Clear the active draft upon successful save or explicit discard.
  static Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (e) {
      debugPrint("Failed to clear lecture draft checkpoint: $e");
    }
  }
}
