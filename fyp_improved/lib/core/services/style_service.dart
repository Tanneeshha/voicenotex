import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// StyleService manages:
/// - User session (email + JWT token)
/// - AI response style preferences
/// - Global logout signaling
class StyleService {
  static const String _stylesKey = 'selected_styles';
  static const String _emailKey = 'user_email';
  static const String _tokenKey = 'auth_token';
  static const String _nameKey = 'user_name';
  
  // AI Personalization settings
  static const String _explanationStyleKey = 'explanation_style';
  static const String _advancedLevelKey = 'advanced_level';
  static const String _noteLengthKey = 'note_length';
  static const String _focusAreasKey = 'focus_areas';
  static const String _noteFormatKey = 'note_format';
  static const String _languageKey = 'language';

  static List<String> _selectedStyles = ["descriptive"];
  static String? _currentUserEmail;
  static String? _authToken;
  static String? _userName;
  
  static String _explanationStyle = "Balanced";
  static String _advancedLevel = "Intermediate";
  static double _noteLength = 2.0; // 1 = Short, 2 = Balanced, 3 = Detailed
  static List<String> _focusAreas = ["Key Points"];
  static String _noteFormat = "Headings & Bullets";
  static String _language = "English";

  /// Broadcast logout events globally (listened to in main.dart)
  static final ValueNotifier<bool> logoutNotifier = ValueNotifier<bool>(false);

  // ── Getters ──────────────────────────────────────────────────────────────────
  static List<String> get selectedStyles => _selectedStyles;
  static String? get currentUserEmail => _currentUserEmail;
  static String? get authToken => _authToken;
  static String? get userName => _userName;
  
  static String get explanationStyle => _explanationStyle;
  static String get advancedLevel => _advancedLevel;
  static double get noteLength => _noteLength;
  static List<String> get focusAreas => _focusAreas;
  static String get noteFormat => _noteFormat;
  static String get language => _language;
  
  static bool get isLoggedIn => _currentUserEmail != null && _authToken != null;

  /// Generates a prompt injection based on user preferences.
  static String get personalizationPrompt {
    List<String> parts = [];
    parts.add("Student Level: $_advancedLevel.");
    parts.add("Advanced Level: $_advancedLevel.");
    parts.add("Explanation Style: $_explanationStyle.");
    String lengthStr = "Balanced length";
    if (_noteLength <= 1.5) lengthStr = "Short and concise";
    if (_noteLength >= 2.5) lengthStr = "Detailed and comprehensive";
    parts.add("Note Length: $lengthStr.");
    
    if (_focusAreas.isNotEmpty) {
      parts.add("Focus Areas: ${_focusAreas.join(', ')}.");
    }
    parts.add("Note Format: $_noteFormat.");
    parts.add("Language: $_language.");
    
    return parts.join(" ");
  }

  // ── Initialization (call on app start) ───────────────────────────────────────
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedStyles = prefs.getStringList(_stylesKey) ?? ["descriptive"];
    _currentUserEmail = prefs.getString(_emailKey);
    _authToken = prefs.getString(_tokenKey);
    _userName = prefs.getString(_nameKey);
    
    _explanationStyle = prefs.getString(_explanationStyleKey) ?? "Balanced";
    _advancedLevel = prefs.getString(_advancedLevelKey) ?? "Intermediate";
    _noteLength = prefs.getDouble(_noteLengthKey) ?? 2.0;
    _focusAreas = prefs.getStringList(_focusAreasKey) ?? ["Key Points"];
    _noteFormat = prefs.getString(_noteFormatKey) ?? "Headings & Bullets";
    _language = prefs.getString(_languageKey) ?? "English";
  }

  // ── Save session after login ──────────────────────────────────────────────────
  static Future<void> saveSession({
    required String email,
    required String token,
    String? name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserEmail = email;
    _authToken = token;
    _userName = name;
    await prefs.setString(_emailKey, email);
    await prefs.setString(_tokenKey, token);
    if (name != null) await prefs.setString(_nameKey, name);
  }

  // ── Save AI styles ────────────────────────────────────────────────────────────
  static Future<void> saveStyles(List<String> styles) async {
    final prefs = await SharedPreferences.getInstance();
    _selectedStyles = styles;
    await prefs.setStringList(_stylesKey, styles);
  }

  // ── Save Preferences ────────────────────────────────────────────────────────
  static Future<void> savePreferences({
    String? explanationStyle,
    String? advancedLevel,
    double? noteLength,
    List<String>? focusAreas,
    String? noteFormat,
    String? language,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (explanationStyle != null) {
      _explanationStyle = explanationStyle;
      await prefs.setString(_explanationStyleKey, explanationStyle);
    }
    if (advancedLevel != null) {
      _advancedLevel = advancedLevel;
      await prefs.setString(_advancedLevelKey, advancedLevel);
    }
    if (noteLength != null) {
      _noteLength = noteLength;
      await prefs.setDouble(_noteLengthKey, noteLength);
    }
    if (focusAreas != null) {
      _focusAreas = focusAreas;
      await prefs.setStringList(_focusAreasKey, focusAreas);
    }
    if (noteFormat != null) {
      _noteFormat = noteFormat;
      await prefs.setString(_noteFormatKey, noteFormat);
    }
    if (language != null) {
      _language = language;
      await prefs.setString(_languageKey, language);
    }
  }

  // ── Logout — clears session ───────────────────────────────────────────────────
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserEmail = null;
    _authToken = null;
    _userName = null;
    await prefs.remove(_emailKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_nameKey);
    // Keep styles so user preference survives logout
  }

  // ── Legacy: kept for backward compatibility ──────────────────────────────────
  static Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserEmail = email;
    await prefs.setString(_emailKey, email);
  }
}
