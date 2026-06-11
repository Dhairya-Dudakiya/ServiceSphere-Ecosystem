import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../auth/screens/admin_login_screen.dart';

// --- FEATURE SCREENS IMPORTS ---
import '../../agents/screens/agent_verification_screen.dart';
import '../../job/screens/all_jobs_screen.dart';
import '../../categories/screens/categories_screen.dart';
import '../../agents/screens/all_agents_screen.dart';
import '../../job/screens/active_jobs_screen.dart';
import 'revenue_details_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  final _key = GlobalKey<ScaffoldState>();

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Close the drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _key,
      backgroundColor: const Color(0xFFF1F5F9), // Slate background
      drawer: _buildPremiumDrawer(),
      body: _getScreen(_selectedIndex),
    );
  }

  // --- PREMIUM DRAWER ---
  Widget _buildPremiumDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: const Text(
              "Super Admin",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            accountEmail: const Text(
              "admin@servicesphere.com",
              style: TextStyle(color: Colors.white70),
            ),
            currentAccountPicture: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                color: const Color(0xFF334155),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _buildDrawerItem(0, "Dashboard", Icons.dashboard_rounded),
                _buildDrawerItem(
                  1,
                  "Verifications",
                  Icons.verified_user_rounded,
                ),
                _buildDrawerItem(2, "All Jobs", Icons.work_rounded),
                _buildDrawerItem(3, "Categories", Icons.category_rounded),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: Colors.red.shade50,
              leading: Icon(
                Icons.logout_rounded,
                color: Colors.red.shade600,
                size: 22,
              ),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: _logout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : const Color(0xFF64748B),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF334155),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        onTap: () => _onItemTapped(index),
      ),
    );
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return const _DashboardHome();
      case 1:
        return const AgentVerificationScreen();
      case 2:
        return const AllJobsScreen();
      case 3:
        return const CategoriesScreen();
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }
}

// --- DASHBOARD HOME WIDGET (REBUILT WITH SLIVERS) ---
class _DashboardHome extends StatelessWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('serviceRequests')
          .snapshots(),
      builder: (context, jobSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('agents').snapshots(),
          builder: (context, agentSnapshot) {
            if (!jobSnapshot.hasData || !agentSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF0F172A)),
              );
            }

            // 1. CALCULATE STATS
            int activeJobs = 0;
            int pendingAgents = 0;
            double totalRevenue = 0.0;
            int totalAgents = agentSnapshot.data!.docs.length;
            List<Map<String, dynamic>> completedJobs = [];

            for (var doc in jobSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'];
              final price = (data['price'] ?? 0).toDouble();

              if ([
                'accepted',
                'in_progress',
                'pending_approval',
              ].contains(status))
                activeJobs++;

              if (status == 'completed') {
                double commission = price * 0.10;
                totalRevenue += commission;
                if (data['completedAt'] != null) {
                  completedJobs.add({
                    'date': (data['completedAt'] as Timestamp).toDate(),
                    'revenue': commission,
                  });
                }
              }
            }

            for (var doc in agentSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['verificationSubmitted'] == true &&
                  data['isVerified'] == false)
                pendingAgents++;
            }

            // 2. CHART DATA PREP
            completedJobs.sort(
              (a, b) =>
                  (a['date'] as DateTime).compareTo(b['date'] as DateTime),
            );
            List<FlSpot> spots = [const FlSpot(0, 0)];
            List<String> dateLabels = [""];
            double runningTotal = 0;

            for (int i = 0; i < completedJobs.length; i++) {
              runningTotal += (completedJobs[i]['revenue'] as double);
              spots.add(FlSpot((i + 1).toDouble(), runningTotal));
              dateLabels.add(
                DateFormat('d MMM').format(completedJobs[i]['date']),
              );
            }

            return CustomScrollView(
              slivers: [
                // --- SLIVER APP BAR ---
                SliverAppBar(
                  expandedHeight: 120.0,
                  floating: true,
                  pinned: true,
                  backgroundColor: const Color(0xFF0F172A), // Deep Navy
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
                    title: const Text(
                      "Command Center",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -20,
                            top: -20,
                            child: Icon(
                              Icons.data_usage_rounded,
                              size: 150,
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(
                        right: 16,
                        top: 12,
                        bottom: 12,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.5),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: Colors.greenAccent,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "SYSTEM LIVE",
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // --- STATS GRID ---
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RevenueDetailsScreen(),
                          ),
                        ),
                        child: _buildAnimatedStatCard(
                          title: "Total Revenue",
                          value: totalRevenue,
                          isCurrency: true,
                          icon: Icons.account_balance_wallet_rounded,
                          color: Colors.greenAccent,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ActiveJobsScreen(),
                          ),
                        ),
                        child: _buildAnimatedStatCard(
                          title: "Active Jobs",
                          value: activeJobs.toDouble(),
                          icon: Icons.bolt_rounded,
                          color: Colors.blueAccent,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AgentVerificationScreen(),
                          ),
                        ),
                        child: _buildAnimatedStatCard(
                          title: "Pending Agents",
                          value: pendingAgents.toDouble(),
                          icon: Icons.shield_rounded,
                          color: Colors.orangeAccent,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AllAgentsScreen(),
                          ),
                        ),
                        child: _buildAnimatedStatCard(
                          title: "Total Agents",
                          value: totalAgents.toDouble(),
                          icon: Icons.group_rounded,
                          color: Colors.indigoAccent,
                        ),
                      ),
                    ],
                  ),
                ),

                // --- CHART SECTION ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.auto_graph_rounded,
                                color: Color(0xFF0F172A),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Revenue Trajectory",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 220,
                            child: spots.length > 1
                                ? LineChart(
                                    LineChartData(
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        getDrawingHorizontalLine: (value) =>
                                            FlLine(
                                              color: Colors.grey.shade100,
                                              strokeWidth: 1.5,
                                              dashArray: [5, 5],
                                            ),
                                      ),
                                      titlesData: FlTitlesData(
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        leftTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              int index = value.toInt();
                                              if (index > 0 &&
                                                  index < dateLabels.length) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 10.0,
                                                      ),
                                                  child: Text(
                                                    dateLabels[index],
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Color(0xFF94A3B8),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return const SizedBox();
                                            },
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: spots,
                                          isCurved: true,
                                          curveSmoothness: 0.35,
                                          color: const Color(0xFF3B82F6),
                                          barWidth: 4,
                                          isStrokeCapRound: true,
                                          dotData: FlDotData(
                                            show: true,
                                            getDotPainter:
                                                (
                                                  spot,
                                                  percent,
                                                  barData,
                                                  index,
                                                ) => FlDotCirclePainter(
                                                  radius: 4,
                                                  color: Colors.white,
                                                  strokeWidth: 3,
                                                  strokeColor: const Color(
                                                    0xFF3B82F6,
                                                  ),
                                                ),
                                          ),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(
                                                  0xFF3B82F6,
                                                ).withOpacity(0.3),
                                                const Color(
                                                  0xFF3B82F6,
                                                ).withOpacity(0.0),
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.show_chart_rounded,
                                          size: 48,
                                          color: Colors.grey[300],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Awaiting first transaction data",
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // --- LIVE ACTIVITY FEED ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Live Pulse",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('serviceRequests')
                      .orderBy('createdAt', descending: true)
                      .limit(5)
                      .snapshots(),
                  builder: (context, recentJobs) {
                    if (!recentJobs.hasData)
                      return const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    if (recentJobs.data!.docs.isEmpty)
                      return const SliverToBoxAdapter(
                        child: Center(child: Text("No activity yet")),
                      );

                    return SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final jobData =
                            recentJobs.data!.docs[index].data()
                                as Map<String, dynamic>;
                        final String title =
                            jobData['title'] ?? 'Service Booked';
                        final String status = jobData['status'] ?? 'pending';
                        final Timestamp? time = jobData['createdAt'];
                        final String timeStr = time != null
                            ? DateFormat('h:mm a').format(time.toDate())
                            : 'Now';

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 6.0,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      status,
                                    ).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getStatusIcon(status),
                                    color: _getStatusColor(status),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        status
                                            .replaceAll('_', ' ')
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _getStatusColor(status),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }, childCount: recentJobs.data!.docs.length),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        );
      },
    );
  }

  // --- HELPER: ANIMATED STAT CARD ---
  Widget _buildAnimatedStatCard({
    required String title,
    required double value,
    required IconData icon,
    required MaterialAccentColor color,
    bool isCurrency = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color.shade700, size: 22),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey.shade300,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: value),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                builder: (context, animValue, child) {
                  String displayStr = isCurrency
                      ? "₹ ${NumberFormat('#,##0').format(animValue)}"
                      : animValue.toInt().toString();
                  return Text(
                    displayStr,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'completed') return Colors.green;
    if (status == 'accepted' || status == 'in_progress') return Colors.blue;
    if (status == 'cancelled') return Colors.red;
    return Colors.orange;
  }

  IconData _getStatusIcon(String status) {
    if (status == 'completed') return Icons.check_circle_rounded;
    if (status == 'accepted') return Icons.handshake_rounded;
    if (status == 'in_progress') return Icons.build_circle_rounded;
    if (status == 'cancelled') return Icons.cancel_rounded;
    return Icons.schedule_rounded;
  }
}
