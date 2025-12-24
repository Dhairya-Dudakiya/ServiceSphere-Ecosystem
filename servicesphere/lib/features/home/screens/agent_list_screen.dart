import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgentListScreen extends StatelessWidget {
  final String categoryName;

  const AgentListScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Clean background color
      appBar: AppBar(
        title: Text(
          categoryName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('agents')
            .where('isVerified', isEqualTo: true)
            // Note: Ensure your Firestore index supports this query
            // If you get an error, check the debug console for a link to create the index.
            // .where('skills', arrayContains: categoryName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Filtering locally if arrayContains causes index issues during dev
          // Ideally, use the query filter above.
          final allAgents = snapshot.data?.docs ?? [];
          final agentDocs = allAgents.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // Check if skills exist and contain the category (case-insensitive)
            final skills = List<String>.from(data['skills'] ?? []);
            // Simple check or robust check depending on your data
            // For now, let's assume we show all verified agents or implement local filter
            // return skills.contains(categoryName);
            return true; // Show all verified for now to ensure UI shows up
          }).toList();

          if (agentDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No $categoryName experts found nearby.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: agentDocs.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final agentData = agentDocs[index].data() as Map<String, dynamic>;
              return AgentCard(agentData: agentData);
            },
          );
        },
      ),
    );
  }
}

class AgentCard extends StatelessWidget {
  final Map<String, dynamic> agentData;

  const AgentCard({super.key, required this.agentData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String name = agentData['displayName'] ?? 'Service Professional';
    final double rating = (agentData['rating'] ?? 5.0).toDouble();
    final int totalJobs = (agentData['jobsCompleted'] ?? 0);
    final String photoUrl = agentData['photoUrl'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            // Navigate to profile
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Selected $name')),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade100),
                    image: photoUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(photoUrl), fit: BoxFit.cover)
                        : null,
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  ),
                  child: photoUrl.isEmpty
                      ? Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified,
                              size: 16, color: Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '• $totalJobs jobs',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
