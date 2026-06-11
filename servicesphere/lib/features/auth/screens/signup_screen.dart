import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:servicesphere/features/auth/services/auth_services.dart';
import 'package:servicesphere/auth_gate.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isLoading = false;
  bool _isObscure = true;
  bool _isOtpSent = false;

  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _otpController = TextEditingController();

  // --- PHASE 1: Request OTP ---
  Future<void> _requestOtp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('requestEmailOTP');
      await callable.call(<String, dynamic>{
        'email': _emailController.text.trim(),
      });

      if (mounted) {
        setState(() {
          _isOtpSent = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('OTP sent to your email!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Could not send OTP. Please try again."),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- PHASE 2: Verify OTP ---
  Future<void> _verifyOtpAndSignUp() async {
    FocusScope.of(context).unfocus();
    if (_otpController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter the full 6-digit code'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('verifyEmailOTP');
      final result = await callable.call(<String, dynamic>{
        'email': _emailController.text.trim(),
        'otp': _otpController.text.trim(),
        'fullName': _fullNameController.text.trim(),
      });

      String customToken = result.data['token'];
      await FirebaseAuth.instance.signInWithCustomToken(customToken);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthGate()),
          (route) => false,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Clean error handling based on backend response
        String errorMessage = e.code == 'permission-denied'
            ? "Incorrect OTP. Please try again."
            : "Server configuration error. Check backend logs.";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("An unexpected error occurred."),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color logoColor =
        isDarkMode ? Colors.white : Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme:
            IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 80,
                    color: logoColor,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.person_add, size: 80, color: logoColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isOtpSent ? 'Verify Your Email' : 'Create Your Account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isOtpSent
                        ? 'We sent a 6-digit code to ${_emailController.text}'
                        : 'Sign up to get started',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 32),
                  if (!_isOtpSent) ...[
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) =>
                          value == null || !value.contains('@')
                              ? 'Please enter a valid email'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _isObscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_isObscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _isObscure = !_isObscure),
                        ),
                      ),
                      validator: (value) => value == null || value.length < 6
                          ? 'Password must be at least 6 characters'
                          : null,
                    ),
                  ],
                  if (_isOtpSent) ...[
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: '6-Digit Code',
                        counterText: "",
                        prefixIcon: const Icon(Icons.security),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_isOtpSent ? _verifyOtpAndSignUp : _requestOtp),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(_isOtpSent ? 'Verify & Sign Up' : 'Send OTP',
                              style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_isOtpSent)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account?'),
                        TextButton(
                          onPressed:
                              _isLoading ? null : () => Navigator.pop(context),
                          child: const Text('Log In'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
