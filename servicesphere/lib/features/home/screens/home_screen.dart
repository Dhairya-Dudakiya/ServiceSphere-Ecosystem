import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

// --- FEATURE IMPORTS ---
import 'package:servicesphere/features/profile/screens/profile_screen.dart';
import 'package:servicesphere/features/home/models/service_category_model.dart';
import 'package:servicesphere/features/home/screens/all_categories_screen.dart';
import 'package:servicesphere/features/booking/book_service_screen.dart';
import 'package:servicesphere/features/notification/notification_screen.dart';
import 'package:servicesphere/features/rating/rate_agent_screen.dart';
import 'package:servicesphere/features/chat/chat_screen.dart';
import 'package:servicesphere/core/services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final List<ServiceCategory> _homeCategories = getHomeScreenCategories();

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ServiceCategory> _filteredCategories = [];
  String _searchQuery = '';

  final Map<String, String> _previousStatuses = {};
  StreamSubscription? _jobListener;

  @override
  void initState() {
    super.initState();
    _filteredCategories = _homeCategories;
    _searchController.addListener(_onSearchChanged);
    _listenForJobUpdates();
    _checkAndShowWelcome();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _jobListener?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _searchQuery = query;
      _filteredCategories = query.isEmpty
          ? _homeCategories
          : _homeCategories.where((c) {
              return c.name.toLowerCase().contains(query);
            }).toList();
    });
  }

  Future<void> _checkAndShowWelcome() async {
    if (_user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      if (!userDoc.exists) return;
      final data = userDoc.data();
      final hasSeenWelcome = data?['hasSeenWelcome'] ?? false;

      if (!hasSeenWelcome) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .update({'hasSeenWelcome': true});
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        try {
          await NotificationService().showLocalNotification(
            const RemoteMessage(
              notification: RemoteNotification(
                title: 'Welcome to Service Sphere! 🚀',
                body:
                    'Book your first service today and get premium support. 🛠️✨',
              ),
            ),
          );
        } catch (e) {
          debugPrint('Welcome notification error: $e');
        }
      }
    } catch (e) {
      debugPrint('Error checking welcome flag: $e');
    }
  }

  void _listenForJobUpdates() {
    if (_user == null) return;

    _jobListener = FirebaseFirestore.instance
        .collection('serviceRequests')
        .where('customerId', isEqualTo: _user!.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.modified) continue;

        final data = change.doc.data() as Map<String, dynamic>;
        final newStatus = data['status'] as String?;
        final jobId = change.doc.id;
        final title = data['title'] ?? 'Service';

        final previousStatus = _previousStatuses[jobId];

        if (previousStatus != null && previousStatus != newStatus && mounted) {
          if (newStatus == 'accepted') {
            _showStatusSnackBar(
                message: "Agent accepted: '$title'",
                color: Colors.green,
                icon: Icons.check_circle);
          } else if (newStatus == 'pending_approval') {
            _showStatusSnackBar(
                message: "New quote received for '$title'",
                color: Colors.purple,
                icon: Icons.attach_money);
          }
        }
        if (newStatus != null) _previousStatuses[jobId] = newStatus;
      }
    });
  }

  void _showStatusSnackBar(
      {required String message, required Color color, required IconData icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500))),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = TimeOfDay.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final rawName = _user?.displayName?.split(' ').first ?? '';
    final displayName = rawName.trim().isNotEmpty ? rawName.trim() : 'there';
    final photoUrl = _user?.photoURL ?? '';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            snap: false,
            elevation: 0,
            scrolledUnderElevation: 1,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  child: Hero(
                    tag: 'user_avatar',
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                              displayName[0].toUpperCase(),
                              style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_getGreeting(),
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3)),
                    Text(displayName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 17,
                            height: 1.1)),
                  ],
                ),
              ],
            ),
            actions: [
              _NotificationBell(userId: _user?.uid),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _SearchBar(
                  controller: _searchController, searchQuery: _searchQuery),
            ),
          ),
          if (_searchQuery.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _PromoBanner()),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _searchQuery.isEmpty
                        ? 'What do you need help with?'
                        : 'Search Results',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87),
                  ),
                  if (_searchQuery.isEmpty)
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AllCategoriesScreen())),
                      child: Text('See all',
                          style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          ),
          if (_filteredCategories.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text("No services found for '$_searchQuery'",
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 14)),
                    ],
                  ),
                ),
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
                  (context, index) =>
                      _ServiceCard(category: _filteredCategories[index]),
                  childCount: _filteredCategories.length,
                ),
              ),
            ),
          if (_searchQuery.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                child: Text('Active Bookings',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
              ),
            ),
            _ActiveBookingsSliver(userId: _user?.uid),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFICATION BELL
// ═══════════════════════════════════════════════════════════════════════════════

class _NotificationBell extends StatelessWidget {
  final String? userId;
  const _NotificationBell({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return IconButton(
          icon: const Icon(Icons.notifications_none_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen())));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('serviceRequests')
          .where('customerId', isEqualTo: userId)
          .where('isReadByUser', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
                icon: const Icon(Icons.notifications_none_rounded,
                    color: Colors.black87),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()))),
            if (hasUnread)
              Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 1.5)))),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEARCH BAR
// ═══════════════════════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  const _SearchBar({required this.controller, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Search for cleaning, repair...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                  onPressed: () {
                    controller.clear();
                    FocusScope.of(context).unfocus();
                  })
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROMO BANNER
// ═══════════════════════════════════════════════════════════════════════════════

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('promotions')
          .doc('active')
          .snapshots(),
      builder: (context, snapshot) {
        String title = 'Home Cleaning';
        String discount = '20% OFF';
        String validity = 'Valid until Oct 30';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            title = data['title'] ?? title;
            discount = data['discount'] ?? discount;
            validity = data['validity'] ?? validity;
          }
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withOpacity(0.75)
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(discount,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5))),
                    const SizedBox(height: 8),
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            height: 1.2)),
                    const SizedBox(height: 6),
                    Text(validity,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.local_offer_rounded,
                      color: Colors.white, size: 28)),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _ServiceCard extends StatelessWidget {
  final ServiceCategory category;
  const _ServiceCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        if (category.name == 'More') {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AllCategoriesScreen()));
        } else {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      BookServiceScreen(categoryName: category.name)));
        }
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Center(
                  child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: category.color.withOpacity(0.12),
                          shape: BoxShape.circle),
                      child: Icon(category.icon,
                          size: 26, color: category.color))),
            ),
          ),
          const SizedBox(height: 8),
          Text(category.name,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIVE BOOKINGS SLIVER
// ═══════════════════════════════════════════════════════════════════════════════

class _ActiveBookingsSliver extends StatelessWidget {
  final String? userId;
  const _ActiveBookingsSliver({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const SliverToBoxAdapter(child: SizedBox());
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('serviceRequests')
          .where('customerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator())));
        if (snapshot.hasError)
          return const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _EmptyStateCard(
                      icon: Icons.error_outline_rounded,
                      message: 'Could not load bookings')));
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty)
          return const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _EmptyStateCard(
                      icon: Icons.calendar_today_outlined,
                      message: 'No bookings yet. Book your first service!')));
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
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyStateCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade100)),
      child: Column(children: [
        Icon(icon, size: 44, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(message,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center)
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATEFUL BOOKING CARD (WITH RAZORPAY & DOUBLE OTP)
// ═══════════════════════════════════════════════════════════════════════════════

class BookingCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String jobId;

  const BookingCard({super.key, required this.data, required this.jobId});

  @override
  State<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  late Razorpay _razorpay;
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // ─── RAZORPAY LOGIC ────────────────────────────────────────────────────────

  void _openCheckout(double price) {
    setState(() => _isProcessingPayment = true);

    // Fallbacks are required: Razorpay UI might fail to load the bottom sheet
    // if contact/email are completely empty.
    final String userPhone =
        FirebaseAuth.instance.currentUser?.phoneNumber ?? '9999999999';
    final String userEmail = FirebaseAuth.instance.currentUser?.email ??
        'customer@servicesphere.com';

    var options = {
      'key': 'rzp_test_SgeGtd2j5DHeOf', // Your exact Test Key
      'amount': (price * 100).toInt(), // Razorpay expects paise (₹100 = 10000)
      'name': 'ServiceSphere',
      'description': 'Payment for ${widget.data['title']}',
      'timeout': 120, // 2 minutes timeout
      'theme': {
        'color': '#0F172A', // Matches your Deep Navy Admin HQ theme!
      },
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
      },
      'notes': {
        'jobId': widget.jobId, // This triggers your Cloud Function Webhook
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isProcessingPayment = false);
      debugPrint('Error opening Razorpay: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch payment gateway: $e')),
        );
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // The Webhook handles the agent payout, but we update locally for instant UI response
    try {
      await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(widget.jobId)
          .update({
        'paymentStatus': 'paid',
        'razorpayPaymentId': response.paymentId,
      });
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Payment Successful!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isProcessingPayment = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessingPayment = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Payment Failed: ${response.message}'),
          backgroundColor: Colors.red),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() => _isProcessingPayment = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('External Wallet Selected: ${response.walletName}')),
    );
  }

  // ─── ACTIONS ───────────────────────────────────────────────────────────────

  Future<void> _callAgent(BuildContext context, String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch dialer')));
    }
  }

  Future<void> _acceptQuote(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(widget.jobId)
          .update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Quote Accepted! ✅'), backgroundColor: Colors.green));
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _rejectQuote(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(widget.jobId)
          .update({
        'status': 'pending_quote',
        'price': 0.0,
        'agentId': FieldValue.delete(),
        'agentName': FieldValue.delete(),
        'agentRating': FieldValue.delete(),
      });
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Quote Rejected.')));
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _cancelJob(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Request?'),
        content:
            const Text('Are you sure you want to cancel this job request?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Cancel',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('serviceRequests')
            .doc(widget.jobId)
            .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': 'customer',
        });
        if (context.mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Request Cancelled')));
      } catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final title = widget.data['title'] ?? 'Service';
    final status = widget.data['status'] ?? 'pending';
    final paymentStatus = widget.data['paymentStatus'] ?? 'pending';
    final price = (widget.data['price'] ?? 0).toDouble();
    final Timestamp? timestamp = widget.data['createdAt'];

    final String? agentName = widget.data['agentName'];
    final String? agentPhone = widget.data['agentPhone'];
    final String? agentId = widget.data['agentId'];
    final double? agentRating = widget.data['agentRating']?.toDouble();
    final bool isRated = widget.data['isRated'] ?? false;

    // Read the securely injected OTPs from the database
    final String? startOtp = widget.data['startOtp'];
    final String? endOtp = widget.data['endOtp'];

    final String dateStr = timestamp != null
        ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
        : 'Just now';
    final statusConfig = _getStatusConfig(status, paymentStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          // ── MAIN ROW ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.work_outline_rounded,
                      color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(dateStr,
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: statusConfig.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(statusConfig.label,
                          style: TextStyle(
                              color: statusConfig.color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3)),
                    ),
                    const SizedBox(height: 6),
                    if (status == 'pending_approval')
                      Text('₹ ${price.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.purple))
                    else if (price > 0)
                      Text('₹ ${price.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14))
                    else
                      Text('Awaiting quote',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
              ],
            ),
          ),

          // ── DYNAMIC STATES ─────────────────────────────────────────────
          if (status == 'pending' || status == 'pending_quote')
            _buildCancelSection(context),
          if (status == 'pending_approval') _buildQuoteSection(context, price),

          // Show START OTP when agent is arriving
          if (status == 'accepted' && startOtp != null)
            _buildOtpSection('Start Code', startOtp, Colors.blue),

          // Show RAZORPAY CHECKOUT when payment is requested
          if (status == 'in_progress' && paymentStatus == 'pending_payment')
            _buildPaymentSection(price),

          // Show END OTP when payment is verified
          if (status == 'in_progress' &&
              paymentStatus == 'paid' &&
              endOtp != null)
            _buildOtpSection('Completion Code', endOtp, Colors.green),

          // ── AGENT INFO SECTION ─────────────────────────────────────────
          if ((status == 'accepted' ||
                  status == 'in_progress' ||
                  status == 'completed') &&
              agentName != null)
            _buildAgentSection(context,
                agentName: agentName,
                agentPhone: agentPhone,
                agentId: agentId,
                agentRating: agentRating,
                isRated: isRated,
                status: status),
        ],
      ),
    );
  }

  // ─── SECTION BUILDERS ──────────────────────────────────────────────────────

  Widget _buildCancelSection(BuildContext context) {
    return Column(
      children: [
        Divider(height: 1, color: Colors.grey.withOpacity(0.15)),
        TextButton.icon(
          onPressed: () => _cancelJob(context),
          icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
          label: const Text('Cancel Request',
              style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            minimumSize: const Size(double.infinity, 0),
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18))),
          ),
        ),
      ],
    );
  }

  Widget _buildQuoteSection(BuildContext context, double price) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.purple.withOpacity(0.15))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_offer_rounded,
                  size: 16, color: Colors.purple),
              const SizedBox(width: 6),
              Text('Agent quoted: ₹${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.purple)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => _rejectQuote(context),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: const Text('Decline'))),
              const SizedBox(width: 10),
              Expanded(
                  child: ElevatedButton(
                      onPressed: () => _acceptQuote(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: const Text('Accept'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtpSection(String label, String otp, MaterialColor color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade200, width: 2),
      ),
      child: Column(
        children: [
          Text('Show this to your agent',
              style: TextStyle(
                  color: color.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$label: ',
                    style: TextStyle(
                        color: color.shade900,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: color.shade300, style: BorderStyle.solid),
                  ),
                  child: Text(
                    otp,
                    style: TextStyle(
                      color: color.shade800,
                      fontWeight: FontWeight.w900,
                      fontSize: 22, // Slightly reduced font size
                      letterSpacing: 4, // Slightly reduced letter spacing
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(double price) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      width: double.infinity,
      child: Column(
        children: [
          // Razorpay Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _isProcessingPayment ? null : () => _openCheckout(price),
              icon: _isProcessingPayment
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.security_rounded, size: 18),
              label: Text('Pay ₹${price.toStringAsFixed(0)} Online',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Pay in Cash Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                // Update Firestore to register a Cash Payment
                await FirebaseFirestore.instance
                    .collection('serviceRequests')
                    .doc(widget.jobId)
                    .update({
                  'paymentStatus':
                      'paid', // Tricks the UI into revealing the OTP
                  'paymentMethod':
                      'cash', // Tells the backend NOT to expect a Razorpay ID
                });
              },
              icon: const Icon(Icons.payments_rounded, size: 18),
              label: const Text('Pay with Cash',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal.shade700,
                side: BorderSide(color: Colors.teal.shade700, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentSection(
    BuildContext context, {
    required String agentName,
    required String? agentPhone,
    required String? agentId,
    required double? agentRating,
    required bool isRated,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: Colors.grey.withOpacity(0.12)))),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[200],
            child: Text(agentName[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(agentName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 12, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                        agentRating != null
                            ? agentRating.toStringAsFixed(1)
                            : 'New',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
          if (status == 'accepted' || status == 'in_progress') ...[
            _AgentActionButton(
                icon: Icons.phone_rounded,
                color: Colors.green,
                onTap: () => _callAgent(context, agentPhone)),
            const SizedBox(width: 8),
            _AgentActionButton(
                icon: Icons.chat_bubble_rounded,
                color: Colors.blue,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ChatScreen(
                            jobId: widget.jobId, otherUserName: agentName)))),
          ],
          if (status == 'completed' && !isRated)
            TextButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RateAgentScreen(
                          jobId: widget.jobId,
                          agentId: agentId ?? '',
                          agentName: agentName))),
              icon: const Icon(Icons.star_outline_rounded,
                  size: 16, color: Colors.amber),
              label: const Text('Rate'),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact),
            ),
          if (status == 'completed' && isRated)
            Text('Rated ⭐',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _AgentActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AgentActionButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS CONFIG HELPER
// ═══════════════════════════════════════════════════════════════════════════════

class _StatusConfig {
  final Color color;
  final String label;
  const _StatusConfig({required this.color, required this.label});
}

_StatusConfig _getStatusConfig(String status, String paymentStatus) {
  switch (status) {
    case 'accepted':
      return const _StatusConfig(color: Colors.blue, label: 'AGENT ARRIVING');
    case 'in_progress':
      if (paymentStatus == 'pending_payment') {
        return const _StatusConfig(
            color: Colors.teal, label: 'PAYMENT REQUIRED');
      } else if (paymentStatus == 'paid') {
        return const _StatusConfig(
            color: Colors.green, label: 'PAYMENT VERIFIED');
      }
      return const _StatusConfig(
          color: Colors.orange, label: 'WORK IN PROGRESS');
    case 'completed':
      return const _StatusConfig(color: Colors.green, label: 'COMPLETED');
    case 'pending_approval':
      return const _StatusConfig(color: Colors.purple, label: 'QUOTE RECEIVED');
    case 'cancelled':
      return const _StatusConfig(color: Colors.red, label: 'CANCELLED');
    default:
      return const _StatusConfig(color: Colors.grey, label: 'PENDING');
  }
}
