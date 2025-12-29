import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AllAgentsScreen extends StatelessWidget {
  const AllAgentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text(
          "All Agents",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('agents').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No agents found."));
            }

            final docs = snapshot.data!.docs;

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return _AgentDetailCard(data: data);
              },
            );
          },
        ),
      ),
    );
  }
}

class _AgentDetailCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AgentDetailCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final String name = data['name'] ?? 'Unknown';
    final String email = data['email'] ?? 'No Email';
    final String phone = data['phone'] ?? 'No Phone';
    final String category = data['category'] ?? 'Unassigned';
    final bool isVerified = data['isVerified'] ?? false;
    final Map<String, dynamic> bankDetails = data['bankDetails'] ?? {};
    final String bankName = bankDetails['bankName'] ?? 'Not Added';
    final String accountNum = bankDetails['accountNumber'] ?? '---';
    final String ifsc = bankDetails['ifscCode'] ?? '---';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isVerified
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          child: Text(
            name[0].toUpperCase(),
            style: TextStyle(
              color: isVerified ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(category),
        trailing: Icon(
          isVerified ? Icons.verified : Icons.warning,
          color: isVerified ? Colors.blue : Colors.orange,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const Text(
                  "Contact Details",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.email, email),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.phone, phone),

                const SizedBox(height: 16),
                const Text(
                  "Bank Details",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.account_balance, bankName),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.numbers, "Acc: $accountNum"),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.qr_code, "IFSC: $ifsc"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
