import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ActiveJobsScreen extends StatelessWidget {
  const ActiveJobsScreen({super.key});

  // --- ADMIN ACTION: FORCE CANCEL ---
  Future<void> _forceCancelJob(BuildContext context, String jobId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Force Cancel Job?"),
        content: const Text(
          "This will immediately stop the job and update its status to 'cancelled'. "
          "Both the User and Agent will see this change.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Yes, Cancel",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // "God Mode" Update
        await FirebaseFirestore.instance
            .collection('serviceRequests')
            .doc(jobId)
            .update({
              'status': 'cancelled',
              'cancelledBy': 'admin',
              'cancelledAt': FieldValue.serverTimestamp(),
              // We keep agentId so we know who WAS assigned, but status stops the flow
            });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Job Forcefully Cancelled."),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text(
          "Active Operations",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('serviceRequests')
              // Query for ANY status that is considered "Active"
              .where(
                'status',
                whereIn: ['accepted', 'in_progress', 'pending_approval'],
              )
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 60,
                      color: Colors.green,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "No active jobs. Everything is quiet.",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            final docs = snapshot.data!.docs;

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return _ActiveJobCard(
                  data: data,
                  jobId: docs[index].id,
                  onCancel: () => _forceCancelJob(context, docs[index].id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String jobId;
  final VoidCallback onCancel;

  const _ActiveJobCard({
    required this.data,
    required this.jobId,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final String title = data['title'] ?? 'Service';
    final String customerName = data['customerName'] ?? 'Unknown Customer';
    final String agentName = data['agentName'] ?? 'Unassigned';
    final String agentPhone = data['agentPhone'] ?? 'N/A';
    final String status = data['status']?.toString().toUpperCase() ?? 'UNKNOWN';
    final double price = (data['price'] ?? 0).toDouble();
    final Timestamp? createdAt = data['createdAt'];

    String dateStr = '---';
    if (createdAt != null) {
      dateStr = DateFormat('MMM d, h:mm a').format(createdAt.toDate());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Created: $dateStr",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),

            // Details Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Column
                Expanded(
                  child: _buildInfoColumn(
                    label: "Customer",
                    value: customerName,
                    icon: Icons.person_outline,
                  ),
                ),
                // Agent Column
                Expanded(
                  child: _buildInfoColumn(
                    label: "Agent",
                    value: agentName,
                    subValue: agentPhone,
                    icon: Icons.engineering_outlined,
                  ),
                ),
                // Price Column
                Expanded(
                  child: _buildInfoColumn(
                    label: "Price",
                    value: "₹ $price",
                    icon: Icons.attach_money,
                    isPrice: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Admin Actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
                icon: const Icon(Icons.warning_amber_rounded, size: 20),
                label: const Text("FORCE CANCEL JOB (Admin Action)"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn({
    required String label,
    required String value,
    String? subValue,
    required IconData icon,
    bool isPrice = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isPrice ? Colors.green[700] : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subValue != null)
          Text(
            subValue,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }
}
