import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../widgets/login_signup_widget.dart';
import '../../../core/widgets/custom_snackbar.dart';
import 'login_screen.dart';
import 'onboarding_preferences_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      CustomSnackBar.show(context, "Please fill in all fields", isError: true);
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      CustomSnackBar.show(context, "Please enter a valid email", isError: true);
      return;
    }
    if (password.length < 6) {
      CustomSnackBar.show(
          context, "Password must be at least 6 characters", isError: true);
      return;
    }
    if (password != confirm) {
      CustomSnackBar.show(context, "Passwords do not match", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.signup(name, email, password);
      if (!mounted) return;

      if (res["success"] == true) {
        CustomSnackBar.show(context, "Account created! Let's personalize it.");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingPreferencesScreen()),
        );
      } else {
        CustomSnackBar.show(
            context, res["error"] ?? "Signup failed", isError: true);
      }
    } catch (_) {
      if (mounted) {
        CustomSnackBar.show(context, "Connection failed", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Create Account",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text("Join VoiceNoteX today",
                style: TextStyle(color: Colors.black45)),
            const SizedBox(height: 32),
            CustomTextField(
              controller: _nameController,
              hint: "Full Name",
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _emailController,
              hint: "Email",
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _passwordController,
              hint: "Password (min 6 chars)",
              icon: Icons.lock_outline,
              isPassword: true,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _confirmPasswordController,
              hint: "Confirm Password",
              icon: Icons.lock_outline,
              isPassword: true,
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : GradientButton(
                    label: "Create Account",
                    onTap: _handleSignup,
                  ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account?",
                    style: TextStyle(color: Colors.black54)),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text(
                    "Log in",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
