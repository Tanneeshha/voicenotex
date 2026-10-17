import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../widgets/login_signup_widget.dart';
import '../../../core/widgets/custom_snackbar.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  int _step = 1;
  bool _isLoading = false;
  Timer? _timer;
  int _countdown = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _countdown = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown == 0) {
        setState(() => _canResend = true);
        t.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      CustomSnackBar.show(context, "Please enter your email", isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.forgotPassword(email);
      if (!mounted) return;
      if (res["success"] == true) {
        // Show the server's message which tells user to check console for demo
        final msg = res["data"]?["message"] ??
            "OTP sent! Check the server console for your 6-digit code.";
        CustomSnackBar.show(context, msg);
        setState(() => _step = 2);
        _startTimer();
      } else {
        CustomSnackBar.show(context, res["error"] ?? "Failed to send OTP",
            isError: true);
      }
    } catch (_) {
      if (mounted) {
        CustomSnackBar.show(context, "Connection failed", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final otp = _otpController.text.trim();
    final pw = _newPasswordController.text;
    if (otp.isEmpty || pw.isEmpty) {
      CustomSnackBar.show(context, "Please fill in all fields", isError: true);
      return;
    }
    if (pw.length < 6) {
      CustomSnackBar.show(context, "Password must be at least 6 characters",
          isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.resetPassword(
          _emailController.text.trim(), otp, pw);
      if (!mounted) return;
      if (res["success"] == true) {
        CustomSnackBar.show(context, "Password reset! Please log in.");
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      } else {
        CustomSnackBar.show(context, res["error"] ?? "Reset failed",
            isError: true);
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
      backgroundColor: const Color(0xFFFEFEFE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Reset Password",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _step == 1
                  ? "Enter your email to receive a 6-digit OTP."
                  : "Enter the 6-digit OTP from the server console and your new password.",
              style: const TextStyle(color: Colors.black54, fontSize: 15),
            ),
            const SizedBox(height: 32),
            if (_step == 1) ...[
              CustomTextField(
                controller: _emailController,
                hint: "Your Email",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GradientButton(label: "Send OTP", onTap: _sendOtp),
            ] else ...[
              // Info banner for demo mode
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Demo mode: OTP is printed in the server terminal/console. Check where you ran the backend.",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              CustomTextField(
                controller: _otpController,
                hint: "6-digit OTP",
                icon: Icons.lock_clock_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _newPasswordController,
                hint: "New Password (min 6 chars)",
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GradientButton(
                      label: "Reset Password", onTap: _resetPassword),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _canResend && !_isLoading ? _sendOtp : null,
                  child: Text(
                    _canResend
                        ? "Resend OTP"
                        : "Resend OTP in $_countdown seconds",
                    style: TextStyle(
                      color:
                          _canResend ? Colors.black : Colors.black38,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
