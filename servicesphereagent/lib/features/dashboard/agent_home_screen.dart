import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// --- NAVIGATION IMPORTS ---
import 'package:servicesphereagent/features/jobs/screens/job_details_screen.dart';
import 'package:servicesphereagent/features/jobs/screens/my_active_jobs_screen.dart';
import 'package:servicesphereagent/features/jobs/screens/my_completed_jobs_screen.dart';
import 'package:servicesphereagent/features/jobs/screens/job_feed_screen.dart';
import 'package:servicesphereagent/features/profile/screens/agent_profile_screen.dart';
// --- NEW IMPORT FOR WALLET ---
import 'package:servicesphereagent/features/wallet/screens/wallet_screen.dart';

class AgentHomeScreen extends StatefulWidget {
  const AgentHomeScreen({super.key});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String displayName =
        _user?.displayName?.split(' ').first ?? 'Partner';
    final String photoUrl = _user?.photoURL ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),

      // --- 1. BODY SWITCHER ---
      body: _buildBody(theme, displayName, photoUrl),

      // --- 2. BOTTOM NAVIGATION BAR (MATCHES EARNINGS COLOR) ---
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          backgroundColor: theme.primaryColor, // Matches Earnings Card
          indicatorColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 10,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined, color: Colors.white70),
              selectedIcon: Icon(Icons.dashboard, color: theme.primaryColor),
              label: 'Home',
            ),
            NavigationDestination(
              icon: const Icon(Icons.list_alt, color: Colors.white70),
              selectedIcon: Icon(Icons.list_alt, color: theme.primaryColor),
              label: 'Jobs',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline, color: Colors.white70),
              selectedIcon: Icon(Icons.person, color: theme.primaryColor),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. BODY CONTENT SWITCHER ---
  Widget _buildBody(ThemeData theme, String displayName, String photoUrl) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView(theme, displayName, photoUrl);
      case 1:
        return const JobsFeedScreen();
      case 2:
        return const AgentProfileScreen();
      default:
        return _buildDashboardView(theme, displayName, photoUrl);
    }
  }

  // --- 4. THE DASHBOARD VIEW ---
  Widget _buildDashboardView(
    ThemeData theme,
    String displayName,
    String photoUrl,
  ) {
    return CustomScrollView(
      slivers: [
        // --- APP BAR ---
        SliverAppBar(
          expandedHeight: 80.0,
          floating: true,
          pinned: true,
          elevation: 0,
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? Icon(Icons.person, color: theme.primaryColor)
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $displayName',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Online & Ready',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Notifications coming soon!")),
                );
              },
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.black87,
              ),
            ),
          ],
        ),

        // --- STATS GRID ---
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(child: _buildRealTimeStats(context)),
        ),

        // --- HEADER ---
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "New Opportunities",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 18,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedIndex = 1);
                  },
                  child: const Text("See All"),
                ),
              ],
            ),
          ),
        ),

        // --- JOB LIST ---
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: _buildMarketplaceList(context),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  // --- STATS LOGIC ---
  Widget _buildRealTimeStats(BuildContext context) {
    if (_user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('serviceRequests')
          .where('agentId', isEqualTo: _user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int activeJobs = 0;
        int completedJobs = 0;
        double earnings = 0.0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final price = (data['price'] ?? 0).toDouble();

            if (status == 'accepted' || status == 'in_progress') {
              activeJobs++;
            } else if (status == 'completed') {
              completedJobs++;
              earnings += price;
            }
          }
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('agents')
              .doc(_user!.uid)
              .snapshots(),
          builder: (context, agentSnap) {
            double rating = 0.0;
            if (agentSnap.hasData && agentSnap.data!.exists) {
              rating = (agentSnap.data!.get('rating') ?? 0.0).toDouble();
            }

            return Column(
              children: [
                // --- 1. EARNINGS CARD (Now Clickable!) ---
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WalletScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Total Earnings",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.currency_rupee,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "₹ ${NumberFormat('#,##0').format(earnings)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // --- 2. STATS ROW ---
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ACTIVE -> Navigates to MyActiveJobsScreen
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MyActiveJobsScreen(),
                              ),
                            );
                          },
                          child: _buildStatCard(
                            label: "Active",
                            value: activeJobs.toString(),
                            icon: Icons.run_circle_outlined,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // DONE -> Navigates to MyCompletedJobsScreen
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MyCompletedJobsScreen(),
                              ),
                            );
                          },
                          child: _buildStatCard(
                            label: "Done",
                            value: completedJobs.toString(),
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // RATING -> Navigates to MyReviewsScreen
                      Expanded(
                        child: _buildStatCard(
                          label: "Rating",
                          value: rating.toStringAsFixed(1),
                          icon: Icons.star_rounded,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('serviceRequests')
          .where('status', whereIn: ['pending', 'pending_quote'])
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyState(context));
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final job = docs[index];
            final data = job.data() as Map<String, dynamic>;
            return JobCardWidget(
              jobData: data,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        JobDetailsScreen(jobId: job.id, jobData: data),
                  ),
                );
              },
            );
          }, childCount: docs.length),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.work_off_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No new requests nearby",
            style: TextStyle(
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class JobCardWidget extends StatelessWidget {
  final Map<String, dynamic> jobData;
  final VoidCallback onTap;

  const JobCardWidget({super.key, required this.jobData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String category = (jobData['category'] ?? 'General').toString();
    final String title = jobData['title'] ?? 'Untitled Job';
    final String address = jobData['address'] ?? 'No location';
    final double price = (jobData['price'] ?? 0).toDouble();
    final Timestamp? timestamp = jobData['createdAt'];
    final Timestamp? scheduledTime = jobData['scheduledTime'];

    String timeDisplay = 'Just now';
    if (scheduledTime != null) {
      timeDisplay = DateFormat('MMM d, h:mm a').format(scheduledTime.toDate());
    } else if (timestamp != null) {
      final diff = DateTime.now().difference(timestamp.toDate());
      if (diff.inDays > 0)
        timeDisplay = '${diff.inDays}d ago';
      else if (diff.inHours > 0)
        timeDisplay = '${diff.inHours}h ago';
      else
        timeDisplay = '${diff.inMinutes}m ago';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.work, color: theme.primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeDisplay,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  price > 0
                      ? Text(
                          '₹ ${price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: theme.primaryColor,
                          ),
                        )
                      : Text(
                          'Needs Quote',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
