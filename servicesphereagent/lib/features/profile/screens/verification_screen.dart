import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _idController = TextEditingController();
  String _selectedIdType = 'Aadhar Card';
  bool _isLoading = false;
  bool _isSubmitted = false;

  // Theme Constants
  static const Color kMainText = Color(0xFF111827);
  static const Color kSecondaryText = Color(0xFF6B7280);
  static const Color kBorderColor = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    final doc = await FirebaseFirestore.instance
        .collection('agents')
        .doc(user!.uid)
        .get();
    if (doc.exists && doc.data()!.containsKey('verificationSubmitted')) {
      setState(() => _isSubmitted = doc.data()!['verificationSubmitted']);
    }
  }

  Future<void> _submitVerification() async {
    if (_idController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('agents')
          .doc(user!.uid)
          .update({
            'verificationDocType': _selectedIdType,
            'verificationDocNumber': _idController.text.trim(),
            'verificationSubmitted': true,
            'verificationStatus': 'pending_review',
          });
      setState(() => _isSubmitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          "Verification Center",
          style: TextStyle(
            color: kMainText,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFF9FAFB),
        iconTheme: const IconThemeData(color: kMainText),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _isSubmitted ? _buildSubmittedView() : _buildFormView(),
      ),
    );
  }

  Widget _buildSubmittedView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 64,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Documents Submitted",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: kMainText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Our compliance team is currently\nreviewing your documents.",
              textAlign: TextAlign.center,
              style: TextStyle(color: kSecondaryText, height: 1.5),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: const Text(
                "Current Status: Pending Review",
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Government Identification",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kMainText,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Please select the ID type and enter the document number below.",
          style: TextStyle(color: kSecondaryText, fontSize: 13),
        ),
        const SizedBox(height: 24),

        // ID Type Dropdown
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedIdType,
            style: const TextStyle(
              color: kMainText,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            items: [
              'Aadhar Card',
              'PAN Card',
              'Driving License',
              'Passport',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) => setState(() => _selectedIdType = val!),
            decoration: InputDecoration(
              labelText: "Document Type",
              labelStyle: const TextStyle(color: kSecondaryText),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kMainText),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ID Number Input
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5),
            ],
          ),
          child: TextFormField(
            controller: _idController,
            style: const TextStyle(
              color: kMainText,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              labelText: "Document Number",
              labelStyle: const TextStyle(color: kSecondaryText),
              hintText: "e.g. XXXX-XXXX-XXXX",
              hintStyle: TextStyle(color: kSecondaryText.withOpacity(0.5)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kMainText),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitVerification,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: kMainText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
                    "Submit for Review",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
