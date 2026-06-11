import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RevenueDetailsScreen extends StatelessWidget {
  const RevenueDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate Background
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('serviceRequests')
            .where('status', isEqualTo: 'completed')
            .orderBy('completedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          double totalRevenue = 0;
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final price = (data['price'] ?? 0).toDouble();
            totalRevenue += (price * 0.10);
          }

          return CustomScrollView(
            slivers: [
              // --- FINTECH HERO HEADER ---
              SliverAppBar(
                expandedHeight: 280.0,
                pinned: true,
                backgroundColor: const Color(0xFF0F172A),
                iconTheme: const IconThemeData(color: Colors.white),
                title: const Text(
                  "Revenue Ledger",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "TOTAL PLATFORM NET",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: totalRevenue),
                            duration: const Duration(milliseconds: 1200),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Text(
                                "₹ ${NumberFormat('#,##0').format(value)}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "${docs.length} Completed Transactions",
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // --- TRANSACTION LIST ---
              if (docs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            size: 48,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "No revenue generated yet",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _RevenueCard(data: data),
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

class _RevenueCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RevenueCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final String title = data['title'] ?? 'Service';
    final String agentName = data['agentName'] ?? 'Unknown Agent';
    final double jobPrice = (data['price'] ?? 0).toDouble();
    final double commission = jobPrice * 0.10;

    final Timestamp? completedAt = data['completedAt'];
    final String dateStr = completedAt != null
        ? DateFormat('MMM d • h:mm a').format(completedAt.toDate())
        : 'Unknown';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.call_received_rounded,
              color: Color(0xFF10B981),
              size: 22,
            ),
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
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  agentName,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "+ ₹${commission.toStringAsFixed(0)}",
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
