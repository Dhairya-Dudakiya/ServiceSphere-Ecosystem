import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AgentVerificationScreen extends StatelessWidget {
  const AgentVerificationScreen({super.key});

  // --- LOGIC: APPROVE ---
  Future<void> _approveAgent(BuildContext context, String uid) async {
    try {
      await FirebaseFirestore.instance.collection('agents').doc(uid).update({
        'isVerified': true,
        'verificationStatus': 'verified',
        'verifiedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Agent Approved!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- LOGIC: REJECT ---
  Future<void> _rejectAgent(BuildContext context, String uid) async {
    try {
      await FirebaseFirestore.instance.collection('agents').doc(uid).update({
        'isVerified': false,
        'verificationSubmitted': false, // Reset so they can submit again
        'verificationStatus': 'rejected',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Agent Rejected."),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('agents')
            .where('verificationSubmitted', isEqualTo: true)
            .where('isVerified', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 60,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No pending verifications",
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildAgentCard(context, doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildAgentCard(
    BuildContext context,
    String uid,
    Map<String, dynamic> data,
  ) {
    final String name = data['name'] ?? 'Unknown';
    final String email = data['email'] ?? 'No Email';
    final String phone = data['phone'] ?? 'No Phone';
    final String docType = data['verificationDocType'] ?? 'ID';
    final String docNumber = data['verificationDocNumber'] ?? '---';
    final Timestamp? submittedAt = data['submittedAt'];

    String dateStr = 'Unknown';
    if (submittedAt != null) {
      dateStr = DateFormat('MMM d, h:mm a').format(submittedAt.toDate());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue.shade50,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Details
          _buildInfoRow(Icons.phone, "Phone: $phone"),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.badge, "$docType: $docNumber"),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.access_time, "Submitted: $dateStr"),

          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rejectAgent(context, uid),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Reject"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approveAgent(context, uid),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Approve"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}
