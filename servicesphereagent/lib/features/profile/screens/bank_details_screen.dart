import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});
  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  bool _isLoading = false;

  // Theme Constants
  static const Color kMainText = Color(0xFF111827);
  static const Color kSecondaryText = Color(0xFF6B7280);
  static const Color kBorderColor = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _loadBankData();
  }

  Future<void> _loadBankData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _bankNameController.text = data['bankName'] ?? '';
        _accountNumberController.text = data['accountNumber'] ?? '';
        _ifscController.text = data['ifscCode'] ?? '';
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _saveBankDetails() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('agents')
          .doc(user!.uid)
          .update({
            'bankName': _bankNameController.text.trim(),
            'accountNumber': _accountNumberController.text.trim(),
            'ifscCode': _ifscController.text.trim(),
          });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bank Details Saved')));
        Navigator.pop(context);
      }
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
          "Bank Details",
          style: TextStyle(
            color: kMainText,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        iconTheme: const IconThemeData(color: kMainText),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Your bank details are securely stored and only used for payouts.",
                      style: TextStyle(color: Colors.blue, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            _buildProfessionalField(
              "Bank Name",
              _bankNameController,
              Icons.account_balance,
            ),
            const SizedBox(height: 20),
            _buildProfessionalField(
              "Account Number",
              _accountNumberController,
              Icons.numbers,
              isNumber: true,
            ),
            const SizedBox(height: 20),
            _buildProfessionalField(
              "IFSC / Routing Code",
              _ifscController,
              Icons.code,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveBankDetails,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor:
                      kMainText, // Using Main theme color instead of generic green
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
                        "Save Bank Details",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    bool isNumber = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5),
        ],
      ),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        // RULE: Input text is Darker and Bolder
        style: const TextStyle(
          color: kMainText,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kSecondaryText),
          prefixIcon: Icon(icon, color: kSecondaryText, size: 20),
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
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
      ),
    );
  }
}
