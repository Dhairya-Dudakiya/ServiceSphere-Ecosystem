import 'package:flutter/material.dart';

class FAQsScreen extends StatelessWidget {
  const FAQsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("FAQs",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          FAQItem(
              question: "How do I book a service?",
              answer:
                  "Go to the Home screen, select a category (e.g., Cleaning), choose a date/time, and click 'Request Quote'."),
          SizedBox(height: 12),
          FAQItem(
              question: "How do I pay?",
              answer:
                  "Currently, we support Cash or direct UPI to the agent after the job is completed."),
          SizedBox(height: 12),
          FAQItem(
              question: "Can I cancel a booking?",
              answer:
                  "Yes, you can cancel a booking from the Home screen as long as the status is 'Pending'."),
          SizedBox(height: 12),
          FAQItem(
              question: "Is my data safe?",
              answer:
                  "Yes, we use secure encryption and only share necessary details with the verified agent assigned to you."),
          SizedBox(height: 12),
          FAQItem(
              question: "What if the agent doesn't show up?",
              answer:
                  "Please contact our support team immediately via the 'Contact Us' page."),
        ],
      ),
    );
  }
}

class FAQItem extends StatelessWidget {
  final String question;
  final String answer;

  const FAQItem({super.key, required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ExpansionTile(
        title: Text(question,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black87)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer,
                style: TextStyle(color: Colors.grey[700], height: 1.5)),
          ),
        ],
      ),
    );
  }
}
