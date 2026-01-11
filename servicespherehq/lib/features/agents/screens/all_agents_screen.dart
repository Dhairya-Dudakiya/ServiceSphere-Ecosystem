import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AllAgentsScreen extends StatefulWidget {
  const AllAgentsScreen({super.key});

  @override
  State<AllAgentsScreen> createState() => _AllAgentsScreenState();
}

class _AllAgentsScreenState extends State<AllAgentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC), // Admin Background
      body: CustomScrollView(
        slivers: [
          // --- 1. MODERN APP BAR ---
          SliverAppBar(
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black87),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: const Text(
                "Agent Management",
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              background: Container(color: Colors.white),
            ),
          ),

          // --- 2. SEARCH BAR ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Search by Name, Phone or Category...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ),

          // --- 3. AGENT LIST ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('agents').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text("No agents registered yet.")),
                );
              }

              final allDocs = snapshot.data!.docs;

              // Client-side Search Filter
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final phone = (data['phone'] ?? '').toString().toLowerCase();
                final category = (data['category'] ?? '')
                    .toString()
                    .toLowerCase();

                return name.contains(_searchQuery) ||
                    phone.contains(_searchQuery) ||
                    category.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text("No matching agents found.")),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final data =
                      filteredDocs[index].data() as Map<String, dynamic>;
                  return _AgentDetailCard(
                    data: data,
                    uid: filteredDocs[index].id,
                  );
                }, childCount: filteredDocs.length),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _AgentDetailCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String uid;

  const _AgentDetailCard({required this.data, required this.uid});

  @override
  State<_AgentDetailCard> createState() => _AgentDetailCardState();
}

class _AgentDetailCardState extends State<_AgentDetailCard> {
  // --- SMART RECHARGE DIALOG ---
  Future<void> _showRechargeDialog() async {
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Add Wallet Credit",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Amount received (Cash/UPI):",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                prefixText: "₹ ",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Quick Select:",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [100, 500, 1000, 2000].map((amt) {
                return ActionChip(
                  label: Text("₹$amt"),
                  backgroundColor: Colors.green.shade50,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                  onPressed: () => amountController.text = amt.toString(),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.pop(ctx);
                await _processRecharge(amount);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Add Credit"),
          ),
        ],
      ),
    );
  }

  Future<void> _processRecharge(double amount) async {
    try {
      await FirebaseFirestore.instance
          .collection('agents')
          .doc(widget.uid)
          .update({'walletBalance': FieldValue.increment(amount)});

      await FirebaseFirestore.instance.collection('walletTransactions').add({
        'agentId': widget.uid,
        'amount': amount,
        'type': 'credit',
        'description': 'Admin Recharge (Cash)',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("₹${amount.toInt()} added successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- ACTIONS ---
  Future<void> _makeCall(String? phone) async {
    if (phone != null) await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _sendEmail(String? email) async {
    if (email != null) await launchUrl(Uri(scheme: 'mailto', path: email));
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.data['name'] ?? 'Unknown';
    final String email = widget.data['email'] ?? 'No Email';
    final String phone = widget.data['phone'] ?? 'No Phone';
    final String category = widget.data['category'] ?? 'Unassigned';
    final bool isVerified = widget.data['isVerified'] ?? false;
    final double walletBalance = (widget.data['walletBalance'] ?? 0).toDouble();

    // Bank Data
    final Map<String, dynamic> bankDetails = widget.data['bankDetails'] ?? {};
    final String bankName = bankDetails['bankName'] ?? 'Not Added';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: ExpansionTile(
        shape: const Border(), // Removes internal divider
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: isVerified
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: isVerified ? Colors.blue : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            if (isVerified)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _buildTag(category, Colors.grey.shade200, Colors.black54),
                const SizedBox(width: 8),
                _buildTag(
                  "₹${walletBalance.toStringAsFixed(0)}",
                  walletBalance < 0 ? Colors.red.shade50 : Colors.green.shade50,
                  walletBalance < 0 ? Colors.red : Colors.green[800]!,
                ),
              ],
            ),
          ],
        ),
        children: [
          const Divider(height: 24),

          // Quick Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                Icons.phone,
                "Call",
                Colors.green,
                () => _makeCall(phone),
              ),
              _buildActionButton(
                Icons.email,
                "Email",
                Colors.blueGrey,
                () => _sendEmail(email),
              ),
              _buildActionButton(
                Icons.add_card,
                "Recharge",
                Colors.blue,
                _showRechargeDialog,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Details Section
          const Text(
            "Details",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.email_outlined, email),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.phone_outlined, phone),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.account_balance_outlined, "Bank: $bankName"),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
