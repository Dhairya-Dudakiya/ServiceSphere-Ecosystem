import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'job_details_screen.dart'; // Make sure this file exists in the same folder

class JobsFeedScreen extends StatefulWidget {
  const JobsFeedScreen({super.key});

  @override
  State<JobsFeedScreen> createState() => _JobsFeedScreenState();
}

class _JobsFeedScreenState extends State<JobsFeedScreen> {
  // 1. Filter Logic
  String _selectedFilter = 'All';
  final List<String> _filters = [
    "All",
    "Plumber",
    "Electrician",
    "Cleaner",
    "High Pay",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Professional Grey Background
      body: CustomScrollView(
        slivers: [
          // --- 2. PROFESSIONAL HEADER ---
          SliverAppBar(
            floating: true,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              "Marketplace",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.black87),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Search coming soon!")),
                  );
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;
                    return ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() => _selectedFilter = filter);
                      },
                      // Professional styling for chips
                      selectedColor: Theme.of(context).primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: Colors.white,
                      side: isSelected
                          ? BorderSide.none
                          : BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // --- 3. THE JOB LIST ---
          _buildJobStream(),
        ],
      ),
    );
  }

  Widget _buildJobStream() {
    // Base Query: Get all pending jobs
    Query query = FirebaseFirestore.instance
        .collection('serviceRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        // Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Error State
        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Center(
              child: Text("Something went wrong: ${snapshot.error}"),
            ),
          );
        }

        // Empty State (No jobs at all)
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SliverFillRemaining(
            child: _buildEmptyState("No jobs available right now"),
          );
        }

        // Get Docs
        var docs = snapshot.data!.docs;

        // --- 4. LOCAL FILTERING LOGIC ---
        // Since we can't easily combine multiple WHERE clauses without complex indexes,
        // we filter the list locally. This is fast and safe for lists < 100 items.
        if (_selectedFilter != 'All') {
          if (_selectedFilter == 'High Pay') {
            docs = docs.where((d) {
              final price = (d.data() as Map)['price'] ?? 0;
              return price >= 500; // Example threshold
            }).toList();
          } else {
            // Filter by category name
            docs = docs.where((d) {
              final cat = (d.data() as Map)['category'] ?? '';
              return cat.toString().contains(_selectedFilter);
            }).toList();
          }
        }

        // Empty State (After filtering)
        if (docs.isEmpty) {
          return SliverFillRemaining(
            child: _buildEmptyState("No $_selectedFilter jobs found"),
          );
        }

        // Render List
        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final jobDoc = docs[index]; // Capture the document
              final data = jobDoc.data() as Map<String, dynamic>;

              return FeedJobCard(
                jobData: data,
                onTap: () {
                  // --- NAVIGATION ADDED HERE ---
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JobDetailsScreen(
                        jobId: jobDoc.id, // Use the document ID
                        jobData: data, // Pass the data
                      ),
                    ),
                  );
                },
              );
            }, childCount: docs.length),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// --- 5. DETAILED JOB CARD (Specific for Feed) ---
class FeedJobCard extends StatelessWidget {
  final Map<String, dynamic> jobData;
  final VoidCallback onTap;

  const FeedJobCard({super.key, required this.jobData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String title = jobData['title'] ?? 'Untitled';
    final String category = jobData['category'] ?? 'General';
    final String address = jobData['address'] ?? 'No address';
    final String description = jobData['description'] ?? '';
    final double price = (jobData['price'] ?? 0).toDouble();
    final Timestamp? timestamp = jobData['createdAt'];

    // Simple time ago logic
    String timeAgo = 'Just now';
    if (timestamp != null) {
      final diff = DateTime.now().difference(timestamp.toDate());
      if (diff.inDays > 0)
        timeAgo = '${diff.inDays}d ago';
      else if (diff.inHours > 0)
        timeAgo = '${diff.inHours}h ago';
      else
        timeAgo = '${diff.inMinutes}m ago';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category Badge & Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title & Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹ ${price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Description Preview (if exists)
                if (description.isNotEmpty) ...[
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                ],

                // Footer: Address & Action
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // "View" Button
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "View Details",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
