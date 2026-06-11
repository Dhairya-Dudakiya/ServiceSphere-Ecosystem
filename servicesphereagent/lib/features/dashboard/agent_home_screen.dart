import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:servicesphereagent/features/jobs/screens/job_details_screen.dart';
import 'package:servicesphereagent/features/jobs/screens/my_active_jobs_screen.dart';
import 'package:servicesphereagent/features/jobs/screens/my_completed_jobs_screen.dart';
import 'package:servicesphereagent/features/jobs/screens/job_feed_screen.dart';
import 'package:servicesphereagent/features/profile/screens/agent_profile_screen.dart';
import 'package:servicesphereagent/features/wallet/screens/wallet_screen.dart';

class AgentHomeScreen extends StatefulWidget {
  const AgentHomeScreen({super.key});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  int _selectedIndex = 0;

  // Agent rating — loaded once, not streamed
  double _agentRating = 0.0;

  // Location subscription
  StreamSubscription<Position>? _locationSubscription;

  // ─── LIFECYCLE ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadAgentRating();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  // ─── LOAD AGENT RATING ─────────────────────────────────────────────────────

  Future<void> _loadAgentRating() async {
    if (_user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(_user!.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _agentRating = (doc.data()?['rating'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {
      debugPrint('Error loading agent rating: $e');
    }
  }

  // ─── LOCATION UPDATES ──────────────────────────────────────────────────────

  Future<void> _startLocationUpdates() async {
    if (_user == null) return;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      _locationSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 50,
            ),
          ).listen((Position position) {
            if (_user == null) return;
            FirebaseFirestore.instance
                .collection('agents')
                .doc(_user!.uid)
                .update({
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                  'locationUpdatedAt': DateTime.now().millisecondsSinceEpoch,
                });
          });
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  // ─── TOGGLE ONLINE ─────────────────────────────────────────────────────────

  Future<void> _toggleOnlineStatus(bool newValue) async {
    if (_user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('agents')
          .doc(_user!.uid)
          .update({'isOnline': newValue});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final rawName = _user?.displayName?.split(' ').first ?? '';
    final displayName = rawName.trim().isNotEmpty ? rawName.trim() : 'Partner';
    final photoUrl = _user?.photoURL ?? '';

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF4F6F9),
      body: _buildBody(theme, isDark, displayName, photoUrl),
      bottomNavigationBar: _buildNavBar(theme, isDark),
    );
  }

  // ─── BOTTOM NAV ────────────────────────────────────────────────────────────

  Widget _buildNavBar(ThemeData theme, bool isDark) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        backgroundColor: theme.colorScheme.primary,
        indicatorColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined, color: Colors.white60),
            selectedIcon: Icon(
              Icons.dashboard,
              color: theme.colorScheme.primary,
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined, color: Colors.white60),
            selectedIcon: Icon(
              Icons.list_alt,
              color: theme.colorScheme.primary,
            ),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline, color: Colors.white60),
            selectedIcon: Icon(Icons.person, color: theme.colorScheme.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ─── BODY SWITCHER ─────────────────────────────────────────────────────────

  Widget _buildBody(
    ThemeData theme,
    bool isDark,
    String displayName,
    String photoUrl,
  ) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard(theme, isDark, displayName, photoUrl);
      case 1:
        return const JobsFeedScreen();
      case 2:
        return const AgentProfileScreen();
      default:
        return _buildDashboard(theme, isDark, displayName, photoUrl);
    }
  }

  // ─── DASHBOARD ─────────────────────────────────────────────────────────────

  Widget _buildDashboard(
    ThemeData theme,
    bool isDark,
    String displayName,
    String photoUrl,
  ) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('agents')
          .doc(_user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final agentData = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>
            : <String, dynamic>{};

        final bool isOnline = agentData['isOnline'] ?? false;
        final double totalEarnings = (agentData['totalEarnings'] ?? 0.0)
            .toDouble();

        return CustomScrollView(
          slivers: [
            // ── APP BAR ──────────────────────────────────────────────
            _buildAppBar(
              theme: theme,
              isDark: isDark,
              displayName: displayName,
              photoUrl: photoUrl,
              isOnline: isOnline,
            ),

            // ── EARNINGS + STATS ──────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _EarningsCard(
                  totalEarnings: totalEarnings,
                  agentRating: _agentRating,
                  userId: _user!.uid,
                  onActiveJobsTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyActiveJobsScreen(),
                    ),
                  ),
                  onCompletedJobsTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyCompletedJobsScreen(),
                    ),
                  ),
                  onEarningsTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  ),
                ),
              ),
            ),

            // ── SECTION HEADER ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New Opportunities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedIndex = 1),
                      child: Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── NEARBY JOBS LIST ──────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _NearbyJobsSliver(userId: _user!.uid),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  // ─── APP BAR ───────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar({
    required ThemeData theme,
    required bool isDark,
    required String displayName,
    required String photoUrl,
    required bool isOnline,
  }) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      snap: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      automaticallyImplyLeading: false,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
            backgroundImage: photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl.isEmpty
                ? Text(
                    displayName[0].toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hello, $displayName',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.1,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOnline ? 'Online & Ready' : 'Offline',
                    style: TextStyle(
                      color: isOnline ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Online toggle
        Row(
          children: [
            Text(
              isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 11,
                color: isOnline ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: isOnline,
                activeColor: Colors.green,
                activeTrackColor: Colors.green.withOpacity(0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.shade300,
                onChanged: _toggleOnlineStatus,
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EARNINGS CARD + STATS
// ═══════════════════════════════════════════════════════════════════════════════

class _EarningsCard extends StatelessWidget {
  final double totalEarnings;
  final double agentRating;
  final String userId;
  final VoidCallback onActiveJobsTap;
  final VoidCallback onCompletedJobsTap;
  final VoidCallback onEarningsTap;

  const _EarningsCard({
    required this.totalEarnings,
    required this.agentRating,
    required this.userId,
    required this.onActiveJobsTap,
    required this.onCompletedJobsTap,
    required this.onEarningsTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('serviceRequests')
          .where('agentId', isEqualTo: userId)
          .where('status', whereIn: ['accepted', 'in_progress', 'completed'])
          .snapshots(),
      builder: (context, snapshot) {
        int activeJobs = 0;
        int completedJobs = 0;

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? '';
            if (status == 'accepted' || status == 'in_progress') {
              activeJobs++;
            } else if (status == 'completed') {
              completedJobs++;
            }
          }
        }

        return Column(
          children: [
            // ── EARNINGS CARD ───────────────────────────────────────
            GestureDetector(
              onTap: onEarningsTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Earnings',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹ ${NumberFormat('#,##0').format(totalEarnings)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: Colors.white70,
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'View Wallet',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.currency_rupee_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── STATS ROW ───────────────────────────────────────────
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Active',
                      value: activeJobs.toString(),
                      icon: Icons.run_circle_outlined,
                      iconColor: Colors.blue,
                      onTap: onActiveJobsTap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Done',
                      value: completedJobs.toString(),
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: Colors.green,
                      onTap: onCompletedJobsTap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Rating',
                      value: agentRating.toStringAsFixed(1),
                      icon: Icons.star_rounded,
                      iconColor: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAT CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade100,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEARBY JOBS SLIVER — client-side distance filtering
// ═══════════════════════════════════════════════════════════════════════════════

class _NearbyJobsSliver extends StatelessWidget {
  final String userId;

  const _NearbyJobsSliver({required this.userId});

  @override
  Widget build(BuildContext context) {
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
              .limit(50)
              .snapshots(),
          builder: (context, jobSnap) {
            if (jobSnap.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (jobSnap.hasError) {
              return SliverToBoxAdapter(
                child: _EmptyJobState(
                  icon: Icons.error_outline_rounded,
                  message: 'Could not load jobs',
                  subMessage: 'Check your connection and try again',
                ),
              );
            }

            var docs = jobSnap.data?.docs ?? [];

            // Client-side distance filter
            if (agentLat != null && agentLng != null) {
              docs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final double? jobLat = (data['latitude'] as num?)?.toDouble();
                final double? jobLng = (data['longitude'] as num?)?.toDouble();
                if (jobLat == null || jobLng == null) return false;

                final distanceMeters = Geolocator.distanceBetween(
                  agentLat,
                  agentLng,
                  jobLat,
                  jobLng,
                );
                return distanceMeters <= 5000;
              }).toList();
            }

            if (docs.isEmpty) {
              return SliverToBoxAdapter(
                child: _EmptyJobState(
                  icon: Icons.location_searching_rounded,
                  message: 'No nearby jobs right now',
                  subMessage: agentLat == null
                      ? 'Enable location to see jobs near you'
                      : 'Check back soon — new requests appear here',
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return JobCardWidget(
                  jobData: data,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          JobDetailsScreen(jobId: doc.id, jobData: data),
                    ),
                  ),
                );
              }, childCount: docs.length),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyJobState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subMessage;

  const _EmptyJobState({
    required this.icon,
    required this.message,
    required this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subMessage,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REUSABLE JOB CARD (used on dashboard)
// ═══════════════════════════════════════════════════════════════════════════════

class JobCardWidget extends StatelessWidget {
  final Map<String, dynamic> jobData;
  final VoidCallback onTap;

  const JobCardWidget({super.key, required this.jobData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
      if (diff.inDays > 0) {
        timeDisplay = '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        timeDisplay = '${diff.inHours}h ago';
      } else {
        timeDisplay = '${diff.inMinutes}m ago';
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
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
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.work_outline_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white60 : Colors.grey[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
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

              // Right column — time + price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 3),
                      Text(
                        timeDisplay,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  price > 0
                      ? Text(
                          '₹ ${price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Quote',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.orange,
                            ),
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
