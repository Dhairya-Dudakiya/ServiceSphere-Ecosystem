import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:servicesphere/features/profile/screens/profile_screen.dart';
import 'package:servicesphere/features/home/models/service_category_model.dart';
import 'package:servicesphere/features/home/screens/all_categories_screen.dart';
import 'package:servicesphere/features/booking/book_service_screen.dart';
import 'package:servicesphere/features/notification/notification_screen.dart';
import 'package:servicesphere/features/rating/rate_agent_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final List<ServiceCategory> _allCategories = getHomeScreenCategories();

  // --- 1. SEARCH VARIABLES ---
  final TextEditingController _searchController = TextEditingController();
  List<ServiceCategory> _filteredCategories = [];
  String _searchQuery = "";

  StreamSubscription? _jobListener;

  @override
  void initState() {
    super.initState();
    // Initialize filtered list with all categories
    _filteredCategories = _allCategories;

    // Listen to search input
    _searchController.addListener(_onSearchChanged);

    _listenForJobUpdates();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _jobListener?.cancel();
    super.dispose();
  }

  // --- 2. SEARCH LOGIC ---
  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredCategories = _allCategories;
      } else {
        _filteredCategories = _allCategories.where((category) {
          return category.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _listenForJobUpdates() {
    if (_user == null) return;
    _jobListener = FirebaseFirestore.instance
        .collection('serviceRequests')
        .where('customerId', isEqualTo: _user!.uid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data() as Map<String, dynamic>;
          final status = data['status'];
          final title = data['title'] ?? 'Service';
          final agentName = data['agentName'] ?? 'A professional';

          if (status == 'accepted' && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.green,
                margin: const EdgeInsets.all(16),
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Job Accepted!",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("$agentName is on the way for '$title'"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }
      }
    });
  }

  String getGreeting() {
    final hour = TimeOfDay.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String displayName = _user?.displayName?.split(' ').first ?? 'User';
    final String photoUrl = _user?.photoURL ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // --- APP BAR ---
          SliverAppBar(
            expandedHeight: 80.0,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            title: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfileScreen()),
                    );
                  },
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage:
                        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(getGreeting(),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[600], fontSize: 12)),
                    Text(displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 18)),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded,
                    color: Colors.black87),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NotificationsScreen()));
                },
              ),
              const SizedBox(width: 8),
            ],
          ),

          // --- SEARCH BAR (UPDATED) ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildSearchBar(context),
            ),
          ),

          // --- PROMO BANNER (Hide when searching to focus on results) ---
          if (_searchQuery.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildPromoBanner(theme),
              ),
            ),

          // --- CATEGORIES HEADER ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: _buildSectionHeader(
                  context,
                  _searchQuery.isEmpty
                      ? 'What do you need help with?'
                      : 'Search Results'),
            ),
          ),

          // --- 5. CATEGORIES GRID (UPDATED) ---
          if (_filteredCategories.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                    child: Text("No services found for '$_searchQuery'",
                        style: TextStyle(color: Colors.grey[600]))),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category =
                        _filteredCategories[index]; // Use Filtered List
                    return ServiceCard(category: category);
                  },
                  childCount: _filteredCategories.length,
                ),
              ),
            ),

          // --- BOOKINGS HEADER (Hide if searching) ---
          if (_searchQuery.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                child: _buildSectionHeader(context, 'Active Bookings'),
              ),
            ),

          // --- REAL-TIME BOOKINGS LIST (Hide if searching) ---
          if (_searchQuery.isEmpty)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('serviceRequests')
                  .where('customerId', isEqualTo: _user?.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child:
                          _buildEmptyStateCard(context, 'No active bookings'),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: BookingCard(data: data, jobId: doc.id),
                      );
                    },
                    childCount: docs.length,
                  ),
                );
              },
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: _searchController, // Linked Controller
        decoration: InputDecoration(
          hintText: 'Search for cleaning, repair...',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          // Clear Button
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus(); // Close keyboard
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPromoBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: theme.primaryColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("20% OFF",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          SizedBox(height: 4),
          Text("Home Cleaning",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22)),
          SizedBox(height: 8),
          Text("Valid until Oct 30",
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87));
  }

  Widget _buildEmptyStateCard(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ],
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  final ServiceCategory category;
  const ServiceCard({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (category.name == 'More') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AllCategoriesScreen()));
        } else {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      BookServiceScreen(categoryName: category.name)));
        }
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: category.color.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(category.icon, size: 28, color: category.color),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            category.name,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String jobId;

  const BookingCard({super.key, required this.data, required this.jobId});

  Future<void> _callAgent(BuildContext context, String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch dialer")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'Service';
    final status = data['status'] ?? 'pending';
    final price = (data['price'] ?? 0).toDouble();
    final Timestamp? timestamp = data['createdAt'];

    final String? agentName = data['agentName'];
    final String? agentPhone = data['agentPhone'];
    final String? agentId = data['agentId'];
    final double? agentRating = data['agentRating']?.toDouble();
    final bool isRated = data['isRated'] ?? false;
    final String? completionOtp = data['completionOtp'];

    String dateStr = 'Just now';
    if (timestamp != null) {
      dateStr = DateFormat('MMM d, h:mm a').format(timestamp.toDate());
    }

    Color statusColor = Colors.orange;
    if (status == 'accepted') statusColor = Colors.blue;
    if (status == 'completed') statusColor = Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.work_outline,
                    color: Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(dateStr,
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(status.toString().toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Text("₹ $price",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ],
          ),

          // OTP
          if (status == 'accepted' && completionOtp != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.key, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text("Start OTP: ",
                      style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.w500)),
                  Text(completionOtp,
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 2)),
                ],
              ),
            ),
          ],

          // Agent Info
          if ((status == 'accepted' || status == 'completed') &&
              agentName != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.grey[200],
                  child: Text(agentName[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(agentName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          Text(" ${agentRating?.toStringAsFixed(1) ?? 'New'}",
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                if (status == 'accepted' && agentPhone != null)
                  IconButton(
                    onPressed: () => _callAgent(context, agentPhone),
                    icon: const Icon(Icons.phone, color: Colors.green),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                if (status == 'completed' && !isRated)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (c) => RateAgentScreen(
                                  jobId: jobId,
                                  agentId: agentId ?? '',
                                  agentName: agentName)));
                    },
                    icon: const Icon(Icons.star_outline,
                        size: 18, color: Colors.amber),
                    label: const Text("Rate"),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact),
                  ),
                if (status == 'completed' && isRated)
                  const Text("You rated this",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic)),
              ],
            ),
          ]
        ],
      ),
    );
  }
}
