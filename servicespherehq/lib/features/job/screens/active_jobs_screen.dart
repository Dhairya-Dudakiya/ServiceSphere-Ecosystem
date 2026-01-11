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
        title: const Text(
          "Force Cancel Job?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "This will immediately stop the job and update its status to 'cancelled'. "
          "Both the User and Agent will see this change.\n\nThis action cannot be undone.",
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Keep Job", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Yes, Cancel"),
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
        debugPrint("Error cancelling job: $e"); // Debug print
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Professional Light Grey
      appBar: AppBar(
        title: const Text(
          "Active Operations",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        size: 60,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "All Quiet Here",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "No active jobs at the moment.",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            final docs = snapshot.data!.docs;

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 16),
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
    final String title = data['title'] ?? 'Service Request';
    final String customerName = data['customerName'] ?? 'Unknown';
    final String agentName = data['agentName'] ?? 'Unassigned';
    final String status = data['status']?.toString().toUpperCase() ?? 'UNKNOWN';
    final double price = (data['price'] ?? 0).toDouble();
    final Timestamp? createdAt = data['createdAt'];

    String dateStr = '---';
    if (createdAt != null) {
      dateStr = DateFormat('MMM d, h:mm a').format(createdAt.toDate());
    }

    Color statusColor = Colors.blue;
    if (status == 'PENDING_APPROVAL') statusColor = Colors.purple;
    if (status == 'IN_PROGRESS') statusColor = Colors.orange;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.work, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Posted: $dateStr",
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.replaceAll('_', ' '),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Details Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCompactInfo(
                  "Customer",
                  customerName,
                  Icons.person_outline,
                  Colors.black87,
                ),
                _buildCompactInfo(
                  "Agent",
                  agentName,
                  Icons.engineering_outlined,
                  Colors.black87,
                ),
                _buildCompactInfo(
                  "Value",
                  "₹ ${price.toStringAsFixed(0)}",
                  Icons.attach_money,
                  Colors.green[700]!,
                ),
              ],
            ),
          ),

          // Action Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: TextButton.icon(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.warning_amber_rounded, size: 18),
              label: const Text(
                "FORCE CANCEL JOB",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfo(
    String label,
    String value,
    IconData icon,
    Color valueColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[400]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 90, // Limit width to prevent overflow
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
