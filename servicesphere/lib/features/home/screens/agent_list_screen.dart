import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgentListScreen extends StatelessWidget {
  final String categoryName;

  const AgentListScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName), // e.g., "Plumbing"
      ),
      body: StreamBuilder<QuerySnapshot>(
        // --- The Firestore Query ---
        // This is the "magic" that finds the right agents.
        // It requires an 'agents' collection where each agent has
        // a 'skills' field that is an ARRAY (e.g., ['Plumbing', 'Electrical'])
        stream: FirebaseFirestore.instance
            .collection('agents')
            .where('isVerified', isEqualTo: true) // Only show approved agents
            .where('skills', arrayContains: categoryName)
            .snapshots(),
        // --- End of Query ---

        builder: (context, snapshot) {
          // 1. Show a loading circle while data is coming
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Show an error if something went wrong
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // 3. Show a message if no agents are found
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No $categoryName agents found in your area yet.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            );
          }

          // 4. We have data! Show the list of agents.
          final agentDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: agentDocs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final agentData = agentDocs[index].data() as Map<String, dynamic>;

              // This is a reusable card for each agent
              return AgentCard(agentData: agentData);
            },
          );
        },
      ),
    );
  }
}

// --- A Reusable Agent Card Widget ---
class AgentCard extends StatelessWidget {
  final Map<String, dynamic> agentData;

  const AgentCard({super.key, required this.agentData});

  @override
  Widget build(BuildContext context) {
    // Get agent details with fallbacks
    final String name = agentData['displayName'] ?? 'Service Professional';
    final double rating = (agentData['rating'] ?? 5.0).toDouble();
    final int totalJobs = (agentData['jobsCompleted'] ?? 0);
    final String photoUrl = agentData['photoUrl'] ?? ''; // Placeholder

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // --- TODO: NEXT STEP ---
          // Navigate to a full AgentProfileScreen
          // Navigator.push(context, MaterialPageRoute(
          //   builder: (context) => AgentProfileScreen(agentId: agentData['uid'])
          // ));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tapped on $name')),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Agent Profile Picture
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Text(name[0], style: const TextStyle(fontSize: 24))
                    : null,
              ),
              const SizedBox(width: 16),
              // Agent Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          ' ($totalJobs jobs)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // "View" Arrow
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
