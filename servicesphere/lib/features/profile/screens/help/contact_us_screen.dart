import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  Future<void> _launch(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Contact Us",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "We're here to help",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 8),
            const Text(
              "Have a question or issue? Reach out to us via any of the channels below.",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            _buildContactCard(
              icon: Icons.phone,
              title: "Call Support",
              subtitle: "+91 88665 38397",
              color: Colors.green,
              onTap: () => _launch(Uri(scheme: 'tel', path: '+918866538397')),
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              icon: Icons.email,
              title: "Email Us",
              subtitle: "servicesphere.dev@gmail.com",
              color: Colors.blue,
              onTap: () => _launch(
                  Uri(scheme: 'mailto', path: 'servicesphere.dev@gmail.com')),
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              icon: Icons.language,
              title: "Visit Website",
              subtitle: "www.servicesphere.com",
              color: Colors.purple,
              onTap: () => _launch(Uri.parse(
                  'https://sites.google.com/view/service-sphere-policy/home')), // Placeholder
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
