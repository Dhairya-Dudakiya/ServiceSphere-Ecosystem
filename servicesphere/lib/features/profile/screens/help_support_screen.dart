import 'package:flutter/material.dart';
import 'help/faqs_screen.dart';
import 'help/contact_us_screen.dart';
import 'help/legal_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Help & Support",
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: textColor, size: 20),
            onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0, left: 4),
            child: Text("How can we help you today?",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.5)),
          ),
          _buildHelpTile(
              context,
              "FAQs",
              "Frequently asked questions",
              Icons.question_answer_rounded,
              Colors.blue,
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const FAQsScreen()))),
          const SizedBox(height: 16),
          _buildHelpTile(
              context,
              "Contact Us",
              "Chat or call support",
              Icons.headset_mic_rounded,
              Colors.green,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ContactUsScreen()))),
          const SizedBox(height: 16),
          _buildHelpTile(
              context,
              "Terms & Conditions",
              "Read our terms of service",
              Icons.gavel_rounded,
              Colors.purple,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LegalScreen(
                          title: "Terms & Conditions", content: _termsText)))),
          const SizedBox(height: 16),
          _buildHelpTile(
              context,
              "Privacy Policy",
              "Data usage & protection",
              Icons.shield_rounded,
              Colors.orange,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LegalScreen(
                          title: "Privacy Policy", content: _privacyText)))),
        ],
      ),
    );
  }

  Widget _buildHelpTile(BuildContext context, String title, String subtitle,
      IconData icon, MaterialColor color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return Container(
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon,
                color: isDark ? color.shade300 : color.shade600, size: 24)),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 16)),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(subtitle,
                style: TextStyle(
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500))),
        trailing: Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: isDark ? Colors.white30 : const Color(0xFFCBD5E1)),
        onTap: onTap,
      ),
    );
  }

  static const String _termsText =
      """1. Introduction\nWelcome to ServiceSphere. By using our app, you agree to these terms.\n\n2. Services\nWe connect users with independent service providers. We are not responsible for the conduct of agents.\n\n3. Payments\nPayments must be made upon completion of service.\n\n4. Cancellations\nCancellations made after the agent has arrived may incur a fee.""";
  static const String _privacyText =
      """1. Data Collection\nWe collect your name, phone number, and location to provide services.\n\n2. Location Data\nYour location is used to match you with nearby agents and for navigation.\n\n3. Sharing\nWe share your details only with the assigned agent for the duration of the job.\n\n4. Security\nWe use industry-standard encryption to protect your data.""";
}
