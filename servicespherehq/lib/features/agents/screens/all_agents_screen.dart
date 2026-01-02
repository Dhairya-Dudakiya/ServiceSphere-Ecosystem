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
                return _AgentDetailCard(
                  data: data,
                  uid: docs[index].id,
                ); // Pass UID
              },
            );
          },
        ),
      ),
    );
  }
}

class _AgentDetailCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String uid; // We need UID to update the wallet

  const _AgentDetailCard({required this.data, required this.uid});

  @override
  State<_AgentDetailCard> createState() => _AgentDetailCardState();
}

class _AgentDetailCardState extends State<_AgentDetailCard> {
  // --- ADMIN RECHARGE LOGIC ---
  Future<void> _showRechargeDialog() async {
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Wallet Credit"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter amount received from agent (Cash/UPI)."),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Amount",
                prefixText: "₹ ",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
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
            ),
            child: const Text("Add Credit"),
          ),
        ],
      ),
    );
  }

  Future<void> _processRecharge(double amount) async {
    try {
      // 1. Update Balance
      await FirebaseFirestore.instance
          .collection('agents')
          .doc(widget.uid)
          .update({'walletBalance': FieldValue.increment(amount)});

      // 2. Log Transaction (So agent sees it in their history)
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
            content: Text("₹${amount.toInt()} added to wallet!"),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category),
            // Show Wallet Balance here
            Text(
              "Balance: ₹${walletBalance.toStringAsFixed(0)}",
              style: TextStyle(
                color: walletBalance < 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- RECHARGE BUTTON ---
            IconButton(
              icon: const Icon(Icons.add_card, color: Colors.blue),
              tooltip: "Add Credit",
              onPressed: _showRechargeDialog,
            ),
            Icon(
              isVerified ? Icons.verified : Icons.warning,
              color: isVerified ? Colors.blue : Colors.orange,
              size: 20,
            ),
          ],
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
                // Add more bank details if needed
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
