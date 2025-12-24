import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // --- FIX 1: HIDE instead of DELETE ---
  // We update the document so it stays in the database (for the Agent)
  // but disappears from your list.
  Future<void> _dismissNotification(String docId) async {
    await FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(docId)
        .update({'isHiddenFromUser': true});
  }

  // --- FIX 2: CLEAR ALL (Hide All) ---
  Future<void> _clearAll(BuildContext context, String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All?"),
        content:
            const Text("This will remove all notifications from your view."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final snapshot = await FirebaseFirestore.instance
          .collection('serviceRequests')
          .where('customerId', isEqualTo: userId)
          .where('status',
              whereIn: ['accepted', 'in_progress', 'completed']).get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        // Set hidden flag for all
        batch.update(doc.reference, {'isHiddenFromUser': true});
      }
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              tooltip: "Clear All",
              onPressed: () => _clearAll(context, user.uid),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: user == null
          ? const Center(child: Text("Please log in to see notifications"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('serviceRequests')
                  .where('customerId', isEqualTo: user.uid)
                  .where('status', whereIn: [
                'accepted',
                'in_progress',
                'completed'
              ]).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // --- FIX 3: CLIENT-SIDE FILTER ---
                // We filter out items that are marked as hidden
                final allDocs = snapshot.data?.docs ?? [];
                final docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isHiddenFromUser'] != true;
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          "No notifications yet",
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                // Sort by time
                docs.sort((a, b) {
                  Timestamp tA = (a.data() as Map)['acceptedAt'] ??
                      (a.data() as Map)['createdAt'];
                  Timestamp tB = (b.data() as Map)['acceptedAt'] ??
                      (b.data() as Map)['createdAt'];
                  return tB.compareTo(tA);
                });

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Dismissible(
                      key: Key(doc.id),
                      direction: DismissDirection.horizontal,
                      // Red Background (Delete style)
                      background: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),

                      // Trigger Hide Logic
                      onDismissed: (direction) {
                        _dismissNotification(doc.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Notification cleared"),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: _NotificationTile(data: data),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _NotificationTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';
    final title = data['title'] ?? 'Service';
    final Timestamp? time = data['acceptedAt'] ?? data['createdAt'];

    String timeStr = 'Just now';
    if (time != null) {
      timeStr = DateFormat('MMM d, h:mm a').format(time.toDate());
    }

    Color iconColor;
    IconData iconData;
    String message;

    if (status == 'completed') {
      iconColor = Colors.green;
      iconData = Icons.check_circle;
      message = "Your job '$title' has been completed!";
    } else {
      iconColor = Colors.blue;
      iconData = Icons.person_pin_circle;
      message = "An agent has accepted your job '$title'.";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  timeStr,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
