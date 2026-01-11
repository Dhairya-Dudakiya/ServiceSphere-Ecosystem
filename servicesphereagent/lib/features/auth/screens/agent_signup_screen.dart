import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For numeric keyboard
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// --- IMPORT AUTH GATE ---
import 'package:servicesphereagent/auth_gate.dart';

class AgentSignupScreen extends StatefulWidget {
  const AgentSignupScreen({super.key});

  @override
  State<AgentSignupScreen> createState() => _AgentSignupScreenState();
}

class _AgentSignupScreenState extends State<AgentSignupScreen> {
  bool _isLoading = false;
  // 1. NEW: Toggle Password Visibility
  bool _isObscure = true;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _categoryController = TextEditingController();

  // Categories
  final List<String> _suggestedCategories = [
    'Plumber',
    'Electrician',
    'Carpenter',
    'Painter',
    'Cleaner',
    'HVAC Technician',
    'Gardener',
    'Appliance Repair',
    'Pest Control',
    'Locksmith',
    'Mover',
    'Roofer',
  ];

  Future<void> _signUp() async {
    // 2. NEW: Dismiss Keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    // Custom Check for Category
    if (_categoryController.text.trim().isEmpty) {
      _showError('Please select a service category.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create Auth User
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final String uid = userCredential.user!.uid;

      // 2. Create Agent Document
      await FirebaseFirestore.instance.collection('agents').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'category': _categoryController.text.trim(),
        'isVerified': false,
        'isOnline': false,
        'rating': 0.0,
        'jobsCompleted': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        // 3. FIX: Navigate to AuthGate (Handles session & routing)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AgentAuthGate()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(e.message ?? 'Registration failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Logo Tint
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color logoColor = isDarkMode
        ? Colors.white
        : Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Logo ---
                  Image.asset(
                    'assets/images/logo.png',
                    height: 80,
                    color: logoColor,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.handyman_rounded,
                      size: 80,
                      color: logoColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Title ---
                  Text(
                    'Become a Partner',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // --- Subtitle ---
                  Text(
                    'Join our network of professionals',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Full Name ---
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // --- Email ---
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (val) => val == null || !val.contains('@')
                        ? 'Invalid email'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // --- Phone (Numeric) ---
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (val) => val == null || val.length < 10
                        ? 'Enter valid phone'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // --- Category (Autocomplete) ---
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue val) {
                      if (val.text == '') return const Iterable<String>.empty();
                      return _suggestedCategories.where(
                        (opt) =>
                            opt.toLowerCase().contains(val.text.toLowerCase()),
                      );
                    },
                    onSelected: (selection) =>
                        _categoryController.text = selection,
                    fieldViewBuilder:
                        (context, textController, focusNode, onSubmitted) {
                          return TextFormField(
                            controller: textController,
                            focusNode: focusNode,
                            onChanged: (val) => _categoryController.text = val,
                            decoration: const InputDecoration(
                              labelText: 'Service Category',
                              prefixIcon: Icon(Icons.work_outline),
                              helperText: 'e.g., Plumber, Electrician',
                            ),
                            validator: (val) =>
                                val == null || val.isEmpty ? 'Required' : null,
                          );
                        },
                  ),
                  const SizedBox(height: 16),

                  // --- Password (With Eye Icon) ---
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isObscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      // 4. NEW: Eye Button
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isObscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _isObscure = !_isObscure),
                      ),
                    ),
                    validator: (val) => val == null || val.length < 6
                        ? 'Min 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // --- Sign Up Button ---
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Register as Partner',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Login Navigation ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
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
