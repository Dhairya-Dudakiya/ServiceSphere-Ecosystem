import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _dismissNotification(String docId) async {
    await FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(docId)
        .update({'isHiddenFromUser': true});
  }

  Future<void> _clearAll(BuildContext context, String userId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.red.shade400),
            const SizedBox(width: 8),
            Text("Clear All?",
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E293B))),
          ],
        ),
        content: Text(
          "This will remove all notifications from your view.",
          style: TextStyle(
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel",
                style: TextStyle(
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("Clear",
                style: TextStyle(
                    color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final snapshot = await FirebaseFirestore.instance
          .collection('serviceRequests')
          .where('customerId', isEqualTo: userId)
          .where('status', whereIn: [
        'accepted',
        'in_progress',
        'completed',
        'pending_approval'
      ]).get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isHiddenFromUser': true});
      }
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Notifications",
            style: TextStyle(
                fontWeight: FontWeight.w800, color: textColor, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: textColor, size: 20),
            onPressed: () => Navigator.pop(context)),
        actions: [
          if (user != null)
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
              child: IconButton(
                  icon: Icon(Icons.delete_sweep_rounded,
                      color: Colors.red.shade400, size: 20),
                  tooltip: "Clear All",
                  onPressed: () => _clearAll(context, user.uid)),
            ),
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
                'completed',
                'pending_approval'
              ]).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

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
                        Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : Colors.white,
                                shape: BoxShape.circle),
                            child: Icon(Icons.notifications_off_rounded,
                                size: 64,
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300)),
                        const SizedBox(height: 24),
                        Text("No notifications yet",
                            style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                            "When you book a service, updates will appear here.",
                            style: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey.shade500,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  );
                }

                docs.sort((a, b) {
                  Timestamp tA = (a.data() as Map)['acceptedAt'] ??
                      (a.data() as Map)['createdAt'];
                  Timestamp tB = (b.data() as Map)['acceptedAt'] ??
                      (b.data() as Map)['createdAt'];
                  return tB.compareTo(tA);
                });

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return Dismissible(
                      key: Key(doc.id),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.red.shade400,
                              Colors.red.shade600
                            ]),
                            borderRadius: BorderRadius.circular(20)),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 24),
                        child: const Icon(Icons.delete_sweep_rounded,
                            color: Colors.white, size: 28),
                      ),
                      secondaryBackground: Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.red.shade600,
                              Colors.red.shade400
                            ]),
                            borderRadius: BorderRadius.circular(20)),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete_sweep_rounded,
                            color: Colors.white, size: 28),
                      ),
                      onDismissed: (direction) {
                        _dismissNotification(doc.id);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text("Notification cleared"),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor:
                                isDark ? Colors.white : const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            duration: const Duration(seconds: 2)));
                      },
                      child: _NotificationTile(
                          data: doc.data() as Map<String, dynamic>,
                          isDark: isDark),
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
  final bool isDark;

  const _NotificationTile({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';
    final title = data['title'] ?? 'Service';
    final Timestamp? time = data['acceptedAt'] ?? data['createdAt'];

    String timeStr = 'Just now';
    if (time != null)
      timeStr = DateFormat('MMM d • h:mm a').format(time.toDate());

    Color iconColor;
    IconData iconData;
    String message;

    if (status == 'completed') {
      iconColor = isDark ? Colors.green.shade400 : Colors.green;
      iconData = Icons.check_circle_rounded;
      message = "Your job '$title' has been completed!";
    } else if (status == 'pending_approval') {
      iconColor = isDark ? Colors.purple.shade300 : Colors.purple;
      iconData = Icons.local_offer_rounded;
      message = "New Quote! Agent offered a price for '$title'.";
    } else {
      iconColor = isDark ? Colors.blue.shade300 : Colors.blue;
      iconData = Icons.handshake_rounded;
      message = "An agent has accepted your job '$title'.";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        height: 1.4)),
                const SizedBox(height: 6),
                Text(timeStr,
                    style: TextStyle(
                        color:
                            isDark ? Colors.grey[400] : const Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
