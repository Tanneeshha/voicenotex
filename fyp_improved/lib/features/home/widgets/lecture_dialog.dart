import 'package:flutter/material.dart';

class LectureDialog extends StatefulWidget {
  final Function(String title, String code, String instructor) onStart;

  const LectureDialog({
    super.key,
    required this.onStart,
  });

  @override
  State<LectureDialog> createState() => _LectureDialogState();
}

class _LectureDialogState extends State<LectureDialog> {
  final _titleController = TextEditingController();
  final _codeController = TextEditingController();
  final _instructorController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  final _titleFocus = FocusNode();
  final _codeFocus = FocusNode();
  final _instructorFocus = FocusNode();

  bool get _isValid => _titleController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    _titleController.addListener(() {
      setState(() {});
    });

    _titleFocus.addListener(() => setState(() {}));
    _codeFocus.addListener(() => setState(() {}));
    _instructorFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _codeController.dispose();
    _instructorController.dispose();

    _titleFocus.dispose();
    _codeFocus.dispose();
    _instructorFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: keyboardHeight,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: screenHeight * 0.85,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(
                          children: [
                            Icon(
                              Icons.mic_none_rounded,
                              color: Color(0xFF2563EB),
                              size: 28,
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Start Lecture",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Add details to organize your lecture notes better",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildCardField(
                              controller: _titleController,
                              focusNode: _titleFocus,
                              label: "Lecture Title *",
                              hint: "e.g. Introduction to AI",
                              icon: Icons.title_rounded,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return "Required";
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            _buildCardField(
                              controller: _codeController,
                              focusNode: _codeFocus,
                              label: "Course Code",
                              hint: "e.g. CS101",
                              icon: Icons.code_rounded,
                            ),

                            const SizedBox(height: 14),

                            _buildCardField(
                              controller: _instructorController,
                              focusNode: _instructorFocus,
                              label: "Instructor",
                              hint: "e.g. Prof. Smith",
                              icon: Icons.person_outline_rounded,
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isValid
                                  ? const Color(0xFF2563EB)
                                  : Colors.grey.shade300,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _isValid
                                ? () {
                                    if (_formKey.currentState!.validate()) {
                                      Navigator.pop(context);

                                      widget.onStart(
                                        _titleController.text.trim(),
                                        _codeController.text.trim(),
                                        _instructorController.text.trim(),
                                      );
                                    }
                                  }
                                : null,
                            child: const Text(
                              "Start Lecture",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    final isFocused = focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isFocused
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused
              ? const Color(0xFF2563EB)
              : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        validator: validator,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF2563EB),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}