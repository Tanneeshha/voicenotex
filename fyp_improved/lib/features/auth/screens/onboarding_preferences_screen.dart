import 'package:flutter/material.dart';
import 'package:my_fyp/core/services/style_service.dart';
import 'package:my_fyp/features/auth/screens/login_screen.dart';
import 'package:my_fyp/features/auth/widgets/login_signup_widget.dart';

class OnboardingPreferencesScreen extends StatefulWidget {
  const OnboardingPreferencesScreen({super.key});

  @override
  State<OnboardingPreferencesScreen> createState() => _OnboardingPreferencesScreenState();
}

class _OnboardingPreferencesScreenState extends State<OnboardingPreferencesScreen> {
  String _explanationStyle = "Balanced";
  String _advancedLevel = "Intermediate";
  double _noteLength = 2.0; // 1 = Short, 2 = Balanced, 3 = Detailed
  List<String> _focusAreas = ["Key Points"];
  String _noteFormat = "Headings & Bullets";
  String _language = "English";

  // Define lists directly as getters to prevent hot-reload erasure in Flutter Web
  List<String> get _explanationStyles => ["Simple", "Step-by-Step", "Concept-Focused", "Example-Based", "Balanced"];
  List<String> get _advancedLevels => ["Beginner", "Intermediate", "Advanced", "Expert"];
  List<String> get _availableFocusAreas => ["Key Points", "Definitions", "Examples", "Formulas", "Important Concepts", "Exam Focus", "Difficult Topics"];
  List<String> get _noteFormats => ["Headings & Bullets", "Step-by-Step", "Short Paragraphs", "Tables"];
  List<String> get _languages => ["English", "Urdu", "Urdu + English", "Same as Lecture"];

  @override
  void initState() {
    super.initState();
    _explanationStyle = StyleService.explanationStyle;
    _advancedLevel = StyleService.advancedLevel;
    _noteLength = StyleService.noteLength;
    _focusAreas = List.from(StyleService.focusAreas);
    _noteFormat = StyleService.noteFormat;
    _language = StyleService.language;
    
    if (!_explanationStyles.contains(_explanationStyle)) _explanationStyle = "Balanced";
    if (!_advancedLevels.contains(_advancedLevel)) _advancedLevel = "Intermediate";
    if (_noteLength < 1.0 || _noteLength > 3.0) _noteLength = 2.0;
    if (!_noteFormats.contains(_noteFormat)) _noteFormat = "Headings & Bullets";
    if (!_languages.contains(_language)) _language = "English";
  }

  void _savePreferences() async {
    await StyleService.savePreferences(
      explanationStyle: _explanationStyle,
      advancedLevel: _advancedLevel,
      noteLength: _noteLength,
      focusAreas: _focusAreas,
      noteFormat: _noteFormat,
      language: _language,
    );
    
    if (mounted) {
      if (StyleService.isLoggedIn) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.black54)),
      ],
    );
  }

  Widget _buildChoiceChips(List<String> options, String currentValue, Function(String) onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = option == currentValue;
        return ChoiceChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (_) => setState(() => onSelect(option)),
          selectedColor: const Color(0xFFE0E7FF),
          backgroundColor: Colors.grey.shade100,
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFF4338CA) : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isSelected ? const Color(0xFF4338CA) : Colors.transparent),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMultiChoiceChips(List<String> options, List<String> currentValues) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = currentValues.contains(option);
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _focusAreas.add(option);
              } else {
                _focusAreas.remove(option);
              }
            });
          },
          selectedColor: const Color(0xFFE0E7FF),
          backgroundColor: Colors.grey.shade100,
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFF4338CA) : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          checkmarkColor: const Color(0xFF4338CA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isSelected ? const Color(0xFF4338CA) : Colors.transparent),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdown(List<String> options, String currentValue, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: Color(0xFF4338CA)),
          items: options.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => onChanged(val));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("AI Note Settings"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 40),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Personalize Your Notes", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text("Design how your AI should process lectures.", style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Explanation Style
            _buildSectionTitle("How do you want your notes explained?", "Choose the overall flavor of your AI notes."),
            const SizedBox(height: 12),
            _buildChoiceChips(_explanationStyles, _explanationStyle, (val) => _explanationStyle = val),
            const SizedBox(height: 32),

            // Advanced Level
            _buildSectionTitle("How advanced should your explanations be?", "Adjust the complexity format."),
            const SizedBox(height: 12),
            _buildChoiceChips(_advancedLevels, _advancedLevel, (val) => _advancedLevel = val),
            const SizedBox(height: 32),

            // Note Length
            _buildSectionTitle("Note Length", "Short & punchy or detailed & thorough?"),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("Short", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                Text("Balanced", style: TextStyle(color: Color(0xFF4338CA), fontSize: 12, fontWeight: FontWeight.bold)),
                Text("Detailed", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF4F46E5),
                inactiveTrackColor: Colors.grey.shade200,
                thumbColor: const Color(0xFF4F46E5),
                tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
                activeTickMarkColor: Colors.white,
                inactiveTickMarkColor: Colors.grey.shade400,
              ),
              child: Slider(
                value: _noteLength,
                min: 1.0,
                max: 3.0,
                divisions: 2,
                onChanged: (val) {
                  setState(() => _noteLength = val);
                },
              ),
            ),
            const SizedBox(height: 32),

            // Focus Areas
            _buildSectionTitle("Focus Areas", "Select what the AI should emphasize the most."),
            const SizedBox(height: 12),
            _buildMultiChoiceChips(_availableFocusAreas, _focusAreas),
            const SizedBox(height: 32),

            // Note Format
            _buildSectionTitle("Note Format", "How should the final document be structured?"),
            const SizedBox(height: 12),
            _buildDropdown(_noteFormats, _noteFormat, (val) => _noteFormat = val),
            const SizedBox(height: 32),

            // Language
            _buildSectionTitle("Output Language", "In which language should the notes be written?"),
            const SizedBox(height: 12),
            _buildDropdown(_languages, _language, (val) => _language = val),
            const SizedBox(height: 48),

            GradientButton(
              label: StyleService.isLoggedIn ? "Save AI Profile" : "Complete Setup",
              onTap: _savePreferences,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
