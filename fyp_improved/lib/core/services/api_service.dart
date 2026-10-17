import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_fyp/core/services/style_service.dart';

// ============================================================
// ApiService — All backend communication happens here
// ============================================================
// This class is the "bridge" between the Flutter app and the
// Python backend. Every screen uses this service to:
// - Log in / sign up users
// - Send messages to the AI
// - Save and load lectures
// - Submit feedback, search notes, manage favorites
// ============================================================

class ApiService {
  // ── Base URL ─────────────────────────────────────────────────────────────
  // On Android, the app needs your computer's local IP address.
  // Pass it at run time instead of editing this file:
  //   flutter run --dart-define=API_HOST=192.168.1.5
  // Run `ipconfig` on Windows or `ifconfig` on Mac/Linux to find it.
  // If API_HOST is not given, the default below is used.
  static const String _androidIp = String.fromEnvironment(
    'API_HOST',
    defaultValue: "192.168.18.97",
  );

  static String get baseUrl {
    if (kIsWeb) return "http://127.0.0.1:8000";
    if (Platform.isAndroid) return "http://$_androidIp:8000";
    return "http://127.0.0.1:8000"; // iOS / Desktop
  }

  // ── Request timeouts ─────────────────────────────────────────────────────
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _aiTimeout = Duration(seconds: 90); // AI takes longer

  // ── Auth headers (JWT token included automatically) ───────────────────────
  static Map<String, String> get _headers {
    final token = StyleService.authToken;
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  // ── Standard response handler ─────────────────────────────────────────────
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {"success": true, "data": body};
      } else {
        final detail = body["detail"] ?? "Request failed";
        return {"success": false, "error": detail};
      }
    } catch (_) {
      return {"success": false, "error": "Invalid server response"};
    }
  }

  // ====================================================================
  // AUTH
  // ====================================================================

  static Future<Map<String, dynamic>> signup(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/signup"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "name": name,
              "email": email,
              "password": password,
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {
        "success": false,
        "error": "Connection failed. Is the backend running?",
      };
    }
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/login"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {
        "success": false,
        "error": "Connection failed. Is the backend running?",
      };
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/forgot-password"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email}),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Connection failed."};
    }
  }

  static Future<Map<String, dynamic>> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/reset-password"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": email,
              "otp": otp,
              "new_password": newPassword,
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Connection failed."};
    }
  }

  // ====================================================================
  // CHAT
  // ====================================================================

  static Future<Map<String, dynamic>> chat({
    required String prompt,
    required String email,
    required String chatId,
    List<Map<String, String>> history = const [],
    List<String> styles = const ["descriptive"],
    bool codeRequest = false,
    bool onlyCode = false,
    String? language,
  }) async {
    try {
      final List<Map<String, String>> finalHistory = List.from(history);
      final pPrompt = StyleService.personalizationPrompt;
      if (pPrompt.isNotEmpty) {
        finalHistory.insert(0, {
          "role": "system",
          "content": "Adhere tightly to this persona/student profile: $pPrompt",
        });
      }

      final response = await http
          .post(
            Uri.parse("$baseUrl/chat"),
            headers: _headers,
            body: jsonEncode({
              "prompt": prompt,
              "email": email,
              "chat_id": chatId,
              "history": finalHistory,
              "styles": styles,
              "code_request": codeRequest,
              "only_code": onlyCode,
              "language": ?language,
            }),
          )
          .timeout(_aiTimeout);
      return _handleResponse(response);
    } catch (e) {
      return {
        "success": false,
        "error": "AI request timed out. Please try again.",
      };
    }
  }

  static Future<Map<String, dynamic>> getChats(String email) async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/chats/$email"), headers: _headers)
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Failed to load chats."};
    }
  }

  static Future<Map<String, dynamic>> getChatHistory(String chatId) async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/chat-history/$chatId"), headers: _headers)
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Failed to load chat history."};
    }
  }

  static Future<Map<String, dynamic>> createNewChat(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/new-chat"),
            headers: _headers,
            body: jsonEncode({"email": email}),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Failed to create new chat."};
    }
  }

  static Future<Map<String, dynamic>> deleteChat(String chatId) async {
    try {
      final response = await http
          .delete(Uri.parse("$baseUrl/chat/$chatId"), headers: _headers)
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Failed to delete chat."};
    }
  }

  // ====================================================================
  // TRANSCRIPTION
  // ====================================================================

  static Future<Map<String, dynamic>> transcribeAudio(
    List<int> fileBytes,
    String filename,
  ) async {
    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/transcribe"),
      );
      request.headers.addAll({
        if (StyleService.authToken != null)
          "Authorization": "Bearer ${StyleService.authToken}",
      });
      request.files.add(
        http.MultipartFile.fromBytes("file", fileBytes, filename: filename),
      );
      final streamed = await request.send().timeout(const Duration(minutes: 10));
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Transcription failed: $e"};
    }
  }

  // ====================================================================
  // LECTURES
  // ====================================================================

  static Future<Map<String, dynamic>> saveLecture({
    required String email,
    required String title,
    String? courseCode,
    String? instructor,
    required String transcript,
    String? lecturePrompt,
    String? aiResponse,
    String? aiTitle,
    String? chatId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/lectures"),
            headers: _headers,
            body: jsonEncode({
              "email": email,
              "title": title,
              "course_code": ?courseCode,
              "instructor": ?instructor,
              "transcript": transcript,
              "lecture_prompt": ?lecturePrompt,
              "ai_response": ?aiResponse,
              "ai_title": ?aiTitle,
              "chat_id": ?chatId,
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Failed to save lecture."};
    }
  }

  static Future<Map<String, dynamic>> getLectures(
    String email, {
    bool favoritesOnly = false,
    String? search,
  }) async {
    try {
      final params = <String, String>{};
      if (favoritesOnly) params["favorites_only"] = "true";
      if (search != null && search.isNotEmpty) params["search"] = search;

      final uri = Uri.parse(
        "$baseUrl/lectures/$email",
      ).replace(queryParameters: params.isNotEmpty ? params : null);

      final response = await http.get(uri, headers: _headers).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Failed to load lectures."};
    }
  }

  static Future<Map<String, dynamic>> getLectureDetail(String lectureId) async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/lecture/$lectureId"), headers: _headers)
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Failed to load lecture details."};
    }
  }

  static Future<Map<String, dynamic>> deleteLecture(String lectureId) async {
    try {
      final response = await http
          .delete(Uri.parse("$baseUrl/lecture/$lectureId"), headers: _headers)
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Failed to delete lecture."};
    }
  }

  static Future<Map<String, dynamic>> updateLectureAiResponse(
    String lectureId, {
    required String aiResponse,
    String? lecturePrompt,
    String? aiTitle,
    String? chatId,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse("$baseUrl/lecture/$lectureId/ai-response"),
            headers: _headers,
            body: jsonEncode({
              "ai_response": aiResponse,
              "lecture_prompt": ?lecturePrompt,
              "ai_title": ?aiTitle,
              "chat_id": ?chatId,
            }),
          )
          .timeout(_aiTimeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Failed to update notes."};
    }
  }

  // ====================================================================
  // NEW: FEEDBACK
  // ====================================================================

  /// Submit feedback on AI-generated notes (Helpful / Needs Improvement)
  static Future<Map<String, dynamic>> submitFeedback({
    required String lectureId,
    required String email,
    required String rating, // "helpful" or "improve"
    String? feedbackType, // "too_long", "unclear", etc.
    String? comment,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/feedback"),
            headers: _headers,
            body: jsonEncode({
              "lecture_id": lectureId,
              "email": email,
              "rating": rating,
              "feedback_type": ?feedbackType,
              "comment": ?comment,
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Failed to submit feedback."};
    }
  }

  // ====================================================================
  // NEW: IMPROVE NOTES
  // ====================================================================

  /// Ask the AI to regenerate improved notes based on feedback
  static Future<Map<String, dynamic>> improveNotes({
    required String lectureId,
    required String email,
    String feedbackType = "general",
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/improve-notes"),
            headers: _headers,
            body: jsonEncode({
              "lecture_id": lectureId,
              "email": email,
              "feedback_type": feedbackType,
            }),
          )
          .timeout(_aiTimeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Failed to improve notes."};
    }
  }

  // ====================================================================
  // NEW: FAVORITES
  // ====================================================================

  /// Mark or unmark a lecture as a favorite
  static Future<Map<String, dynamic>> toggleFavorite({
    required String lectureId,
    required String email,
    required bool isFavorite,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/favorite"),
            headers: _headers,
            body: jsonEncode({
              "lecture_id": lectureId,
              "email": email,
              "is_favorite": isFavorite,
            }),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Failed to update favorite."};
    }
  }

  // ====================================================================
  // NEW: SEARCH
  // ====================================================================

  /// Search through saved lecture notes by keyword
  static Future<Map<String, dynamic>> searchNotes({
    required String email,
    required String query,
  }) async {
    try {
      final uri = Uri.parse(
        "$baseUrl/search",
      ).replace(queryParameters: {"email": email, "q": query});
      final response = await http.get(uri, headers: _headers).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Search failed."};
    }
  }

  // ====================================================================
  // NEW: STATS
  // ====================================================================

  /// Get dashboard statistics for the current user
  static Future<Map<String, dynamic>> getUserStats(String email) async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/stats/$email"), headers: _headers)
          .timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": "Failed to load stats."};
    }
  }
}
