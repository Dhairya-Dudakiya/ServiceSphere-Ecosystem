import 'package:flutter/material.dart';
import 'help/faqs_screen.dart';
import 'help/contact_us_screen.dart';
import 'help/legal_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Help & Support",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHelpTile(
            context,
            "FAQs",
            "Frequently asked questions",
            () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const FAQsScreen())),
          ),
          const SizedBox(height: 12),
          _buildHelpTile(
            context,
            "Contact Us",
            "Chat or call support",
            () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ContactUsScreen())),
          ),
          const SizedBox(height: 12),
          _buildHelpTile(
            context,
            "Terms & Conditions",
            "Read our terms of service",
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LegalScreen(
                  title: "Terms & Conditions",
                  content: _termsText, // Defines text below
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildHelpTile(
            context,
            "Privacy Policy",
            "Data usage & protection",
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LegalScreen(
                  title: "Privacy Policy",
                  content: _privacyText, // Defines text below
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpTile(
      BuildContext context, String title, String subtitle, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black)),
        subtitle: Text(subtitle,
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  static const String _termsText = """
1. Introduction
Welcome to ServiceSphere. By using our app, you agree to these terms.

2. Services
We connect users with independent service providers. We are not responsible for the conduct of agents.

3. Payments
Payments must be made upon completion of service.

4. Cancellations
Cancellations made after the agent has arrived may incur a fee.
""";

  static const String _privacyText = """
1. Data Collection
We collect your name, phone number, and location to provide services.

2. Location Data
Your location is used to match you with nearby agents and for navigation.

3. Sharing
We share your details only with the assigned agent for the duration of the job.

4. Security
We use industry-standard encryption to protect your data.
""";
}
