import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _holderNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _bankNameController = TextEditingController();

  bool _isLoading = false;

  // List of major banks for autocomplete
  static const List<String> _bankOptions = [
    'HDFC Bank',
    'ICICI Bank',
    'State Bank of India (SBI)',
    'Axis Bank',
    'Kotak Mahindra Bank',
    'IndusInd Bank',
    'Yes Bank',
    'Punjab National Bank (PNB)',
    'Bank of Baroda',
    'Bank of India',
    'Union Bank of India',
    'Canara Bank',
    'IDFC First Bank',
    'Federal Bank',
    'Indian Bank',
    'Central Bank of India',
    'IDBI Bank',
    'Bandhan Bank',
    'RBL Bank',
  ];

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
  }

  Future<void> _loadBankDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('agents')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data()!.containsKey('bankDetails')) {
      final data = doc.data()!['bankDetails'] as Map<String, dynamic>;
      _holderNameController.text = data['holderName'] ?? '';
      _accountNumberController.text = data['accountNumber'] ?? '';
      _ifscController.text = data['ifscCode'] ?? '';
      _bankNameController.text = data['bankName'] ?? '';
      setState(() {}); // Refresh UI
    }
  }

  Future<void> _saveDetails() async {
    if (!_formKey.currentState!.validate()) return;

    String finalBankName = _bankNameController.text.trim();
    if (finalBankName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select or enter a Bank Name")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('agents')
          .doc(user.uid)
          .update({
            'bankDetails': {
              'holderName': _holderNameController.text.trim(),
              'accountNumber': _accountNumberController.text.trim(),
              'ifscCode': _ifscController.text.trim().toUpperCase(),
              'bankName': finalBankName,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bank details saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving details: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Bank Details",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Payout Information",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter your bank account details to receive earnings.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // 1. Bank Name Autocomplete
              const Text(
                "Bank Name",
                style: TextStyle(
                  fontWeight: FontWeight.bold, // Bold
                  fontSize: 14,
                  color: Colors.black, // Proper Black
                ),
              ),
              const SizedBox(height: 8),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<String>.empty();
                  }
                  return _bankOptions.where((String option) {
                    return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  });
                },
                onSelected: (String selection) {
                  _bankNameController.text = selection;
                },
                fieldViewBuilder:
                    (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      if (_bankNameController.text.isNotEmpty &&
                          textEditingController.text.isEmpty) {
                        textEditingController.text = _bankNameController.text;
                      }

                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onChanged: (val) => _bankNameController.text = val,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search bank (e.g. HDFC)",
                          prefixIcon: const Icon(
                            Icons.account_balance,
                            color: Colors.grey,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        validator: (val) =>
                            val!.isEmpty ? "Bank Name is required" : null,
                      );
                    },
              ),
              const SizedBox(height: 20),

              // 2. Account Holder Name
              _buildTextField(
                controller: _holderNameController,
                label: "Account Holder Name",
                hint: "Name as per passbook",
                icon: Icons.person,
              ),
              const SizedBox(height: 20),

              // 3. Account Number
              _buildTextField(
                controller: _accountNumberController,
                label: "Account Number",
                hint: "Enter account number",
                icon: Icons.numbers,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),

              // 4. IFSC Code
              _buildTextField(
                controller: _ifscController,
                label: "IFSC Code",
                hint: "e.g. SBIN0001234",
                icon: Icons.qr_code,
                isCapitalized: true,
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Save Bank Details",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isCapitalized = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold, // Bold
            fontSize: 14,
            color: Colors.black, // Proper Black
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ), // Input Text Color
          textCapitalization: isCapitalized
              ? TextCapitalization.characters
              : TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(icon, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
          ),
          validator: (val) => val!.isEmpty ? "$label is required" : null,
        ),
      ],
    );
  }
}
