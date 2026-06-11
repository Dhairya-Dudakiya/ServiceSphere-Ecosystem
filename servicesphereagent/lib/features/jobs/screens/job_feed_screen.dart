import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'job_details_screen.dart';

class JobsFeedScreen extends StatefulWidget {
  const JobsFeedScreen({super.key});

  @override
  State<JobsFeedScreen> createState() => _JobsFeedScreenState();
}

class _JobsFeedScreenState extends State<JobsFeedScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'Plumber',
    'Electrician',
    'Cleaner',
    'AC Repair',
    'High Pay',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // ── APP BAR ──────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            pinned: true,
            snap: false,
            elevation: 0,
            scrolledUnderElevation: 1,
            automaticallyImplyLeading: false,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'Marketplace',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(58),
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : const Color(0xFFEEEEEE),
                    ),
                  ),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;
                    return _FilterChip(
                      label: filter,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedFilter = filter),
                    );
                  },
                ),
              ),
            ),
          ),

          // ── JOB LIST ─────────────────────────────────────────────────
          _JobFeedSliver(selectedFilter: _selectedFilter),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILTER CHIP
// ═══════════════════════════════════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : isDark
              ? const Color(0xFF2A2A2A)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 13),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : isDark
                    ? Colors.white70
                    : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// JOB FEED SLIVER — with nearby filtering
// ═══════════════════════════════════════════════════════════════════════════════

class _JobFeedSliver extends StatelessWidget {
  final String selectedFilter;

  const _JobFeedSliver({required this.selectedFilter});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SliverToBoxAdapter(child: SizedBox());

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('agents')
          .doc(userId)
          .snapshots(),
      builder: (context, agentSnap) {
        final agentData = agentSnap.hasData && agentSnap.data!.exists
            ? agentSnap.data!.data() as Map<String, dynamic>
            : <String, dynamic>{};

        final double? agentLat = (agentData['latitude'] as num?)?.toDouble();
        final double? agentLng = (agentData['longitude'] as num?)?.toDouble();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('serviceRequests')
              .where('status', whereIn: ['pending', 'pending_quote'])
              .orderBy('createdAt', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return SliverFillRemaining(
                child: _FeedEmptyState(
                  icon: Icons.error_outline_rounded,
                  message: 'Something went wrong',
                  subMessage: 'Pull to refresh and try again',
                ),
              );
            }

            var docs = snapshot.data?.docs ?? [];

            // Distance filter
            if (agentLat != null && agentLng != null) {
              docs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final double? jobLat = (data['latitude'] as num?)?.toDouble();
                final double? jobLng = (data['longitude'] as num?)?.toDouble();
                if (jobLat == null || jobLng == null) return false;
                final distance = Geolocator.distanceBetween(
                  agentLat,
                  agentLng,
                  jobLat,
                  jobLng,
                );
                return distance <= 5000;
              }).toList();
            }

            // Category / High Pay filter
            if (selectedFilter != 'All') {
              if (selectedFilter == 'High Pay') {
                docs = docs.where((doc) {
                  final price = ((doc.data() as Map)['price'] ?? 0) as num;
                  return price >= 500;
                }).toList();
              } else {
                docs = docs.where((doc) {
                  final cat = ((doc.data() as Map)['category'] ?? '') as String;
                  return cat.toLowerCase().contains(
                    selectedFilter.toLowerCase(),
                  );
                }).toList();
              }
            }

            if (docs.isEmpty) {
              return SliverFillRemaining(
                child: _FeedEmptyState(
                  icon: Icons.search_off_rounded,
                  message: selectedFilter == 'All'
                      ? 'No jobs available right now'
                      : 'No $selectedFilter jobs found',
                  subMessage: agentLat == null
                      ? 'Enable location permissions for nearby jobs'
                      : 'New jobs appear here in real time',
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return FeedJobCard(
                    jobData: data,
                    agentLat: agentLat,
                    agentLng: agentLng,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            JobDetailsScreen(jobId: doc.id, jobData: data),
                      ),
                    ),
                  );
                }, childCount: docs.length),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEED JOB CARD
// ═══════════════════════════════════════════════════════════════════════════════

class FeedJobCard extends StatelessWidget {
  final Map<String, dynamic> jobData;
  final VoidCallback onTap;
  final double? agentLat;
  final double? agentLng;

  const FeedJobCard({
    super.key,
    required this.jobData,
    required this.onTap,
    this.agentLat,
    this.agentLng,
  });

  String _getDistanceLabel() {
    if (agentLat == null || agentLng == null) return '';
    final double? jobLat = (jobData['latitude'] as num?)?.toDouble();
    final double? jobLng = (jobData['longitude'] as num?)?.toDouble();
    if (jobLat == null || jobLng == null) return '';

    final meters = Geolocator.distanceBetween(
      agentLat!,
      agentLng!,
      jobLat,
      jobLng,
    );

    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m away';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km away';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String title = jobData['title'] ?? 'Untitled';
    final String category = jobData['category'] ?? 'General';
    final String address = jobData['address'] ?? 'No address';
    final String description = jobData['description'] ?? '';
    final double price = (jobData['price'] ?? 0).toDouble();
    final Timestamp? timestamp = jobData['createdAt'];
    final String? imageUrl = jobData['imageUrl'];
    final distanceLabel = _getDistanceLabel();

    String timeAgo = 'Just now';
    if (timestamp != null) {
      final diff = DateTime.now().difference(timestamp.toDate());
      if (diff.inDays > 0) {
        timeAgo = '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inMinutes}m ago';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Job image if exists
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: Image.network(
                    imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row — category + time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 3),
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

                    // Title + Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        price > 0
                            ? Text(
                                '₹ ${price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Needs Quote',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                      ],
                    ),

                    // Description
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Footer — address + distance + view button
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (distanceLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              distanceLabel,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black87,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'View',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.white,
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
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════════

class _FeedEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subMessage;

  const _FeedEmptyState({
    required this.icon,
    required this.message,
    required this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey[300]),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subMessage,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
