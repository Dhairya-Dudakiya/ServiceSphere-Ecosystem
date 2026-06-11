import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ActiveJobsScreen extends StatelessWidget {
  const ActiveJobsScreen({super.key});

  Future<void> _forceCancelJob(BuildContext context, String jobId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text(
              "Force Cancel?",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: const Text(
          "This will instantly terminate the job and update its status to 'cancelled' for both User and Agent.\n\nThis action cannot be undone.",
          style: TextStyle(color: Color(0xFF64748B), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "Keep Job",
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Terminate"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('serviceRequests')
            .doc(jobId)
            .update({
              'status': 'cancelled',
              'cancelledBy': 'admin',
              'cancelledAt': FieldValue.serverTimestamp(),
            });
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Job Forcefully Terminated."),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
      } catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $e"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('serviceRequests')
            .where(
              'status',
              whereIn: ['accepted', 'in_progress', 'pending_approval'],
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)),
            );

          final docs = snapshot.data?.docs ?? [];

          return CustomScrollView(
            slivers: [
              const SliverAppBar(
                expandedHeight: 120.0,
                floating: true,
                pinned: true,
                backgroundColor: Color(0xFF0F172A),
                iconTheme: IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: EdgeInsets.only(left: 60, bottom: 16),
                  title: Text(
                    "Active Operations",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  background: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
              if (docs.isEmpty)
                SliverFillRemaining(
                  child: Center(
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
                            Icons.satellite_alt_rounded,
                            size: 48,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "All Quiet Here",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "No active operations currently running.",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _ActiveJobCard(
                          data: data,
                          jobId: docs[index].id,
                          onCancel: () =>
                              _forceCancelJob(context, docs[index].id),
                        ),
                      );
                    }, childCount: docs.length),
                  ),
                ),
            ],
          );
        },
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

    final String dateStr = createdAt != null
        ? DateFormat('MMM d • h:mm a').format(createdAt.toDate())
        : '---';

    Color statusColor = Colors.blue;
    if (status == 'PENDING_APPROVAL') statusColor = Colors.purple;
    if (status == 'IN_PROGRESS') statusColor = Colors.orange;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.bolt_rounded, color: statusColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Posted: $dateStr",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
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
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    status.replaceAll('_', ' '),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCompactInfo(
                  "Customer",
                  customerName,
                  Icons.person_rounded,
                  const Color(0xFF334155),
                ),
                _buildCompactInfo(
                  "Agent",
                  agentName,
                  Icons.engineering_rounded,
                  const Color(0xFF334155),
                ),
                _buildCompactInfo(
                  "Value",
                  "₹ ${price.toStringAsFixed(0)}",
                  Icons.account_balance_wallet_rounded,
                  Colors.green.shade700,
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: InkWell(
              onTap: onCancel,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "TERMINATE JOB",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.red.shade700,
                        letterSpacing: 1.0,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
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
            Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 90,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
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
