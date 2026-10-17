import 'package:flutter/material.dart';
import 'package:my_fyp/core/services/style_service.dart';
import 'package:my_fyp/features/auth/screens/onboarding_preferences_screen.dart' as my_fyp_auth;

class StyleDialog extends StatefulWidget {
  final List<String> initialStyles;
  final Function(List<String>) onApply;

  const StyleDialog({
    super.key,
    required this.initialStyles,
    required this.onApply,
  });

  /// Static helper to open the AI Personalization Sheet cleanly as a bottom sheet
  static Future<void> show(
    BuildContext context, {
    required List<String> initialStyles,
    required Function(List<String>) onApply,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StyleDialog(
        initialStyles: initialStyles,
        onApply: onApply,
      ),
    );
  }

  @override
  State<StyleDialog> createState() => _StyleDialogState();
}

class _StyleDialogState extends State<StyleDialog> {
  late List<String> tempSelectedStyles;
  late String tempStudentLevel;

  final List<String> allLevels = [
    "Beginner",
    "Intermediate",
    "Advanced",
    "Expert",
  ];

  final List<String> allStyles = [
    "Short",
    "Descriptive",
    "Long",
    "Professional",
    "Bulletpoints",
  ];

  @override
  void initState() {
    super.initState();
    tempSelectedStyles = List.from(widget.initialStyles);
    tempStudentLevel = StyleService.advancedLevel;
    if (!allLevels.contains(tempStudentLevel)) {
      tempStudentLevel = "Intermediate";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF4F46E5),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "AI Personalization",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          "Quick level & response preferences",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Section 1: Student Level
              const Text(
                "STUDENT LEVEL",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allLevels.map((lvl) {
                  final isSelected = tempStudentLevel == lvl;
                  return ChoiceChip(
                    label: Text(lvl),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() => tempStudentLevel = lvl);
                      }
                    },
                    selectedColor: const Color(0xFFE0E7FF),
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF4338CA) : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF4338CA) : Colors.transparent,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Section 2: Response Style
              const Text(
                "RESPONSE FLAVOR",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allStyles.map((style) {
                  final styleLower = style.toLowerCase();
                  final isLengthOption = ["short", "descriptive", "long"].contains(styleLower);
                  final isSelected = tempSelectedStyles.contains(styleLower);

                  return FilterChip(
                    label: Text(style),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (isLengthOption) {
                          tempSelectedStyles.remove("short");
                          tempSelectedStyles.remove("descriptive");
                          tempSelectedStyles.remove("long");
                          if (val) {
                            tempSelectedStyles.add(styleLower);
                          }
                        } else {
                          if (val) {
                            tempSelectedStyles.add(styleLower);
                          } else {
                            tempSelectedStyles.remove(styleLower);
                          }
                        }
                      });
                    },
                    selectedColor: const Color(0xFFE0E7FF),
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF4338CA) : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                    checkmarkColor: const Color(0xFF4338CA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF4338CA) : Colors.transparent,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Link to Full Advanced Profile
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const my_fyp_auth.OnboardingPreferencesScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 18, color: Color(0xFF4F46E5)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Advanced AI Profile Settings",
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF4F46E5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        await StyleService.savePreferences(
                          advancedLevel: tempStudentLevel,
                        );
                        widget.onApply(tempSelectedStyles);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text(
                        "Save Preferences",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
