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
      backgroundColor: const Color(0xFFF3F4F6), // Soft Grey Background
      // --- APP BAR ---
      appBar: AppBar(
        title: const Text(
          "ServiceSphere HQ",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black87,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // --- DRAWER ---
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.black87,
                image: DecorationImage(
                  image: AssetImage(
                    'assets/images/pattern.png',
                  ), // Optional pattern if you have one
                  fit: BoxFit.cover,
                  opacity: 0.1,
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
                  color: Colors.white,
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  size: 40,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),

            _buildDrawerItem(0, "Dashboard", Icons.dashboard_outlined),
            _buildDrawerItem(1, "Verifications", Icons.verified_user_outlined),
            _buildDrawerItem(2, "All Jobs", Icons.work_outline),
            _buildDrawerItem(3, "Categories", Icons.category_outlined),

            const Divider(height: 32),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout, color: Colors.red, size: 20),
              ),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _getScreen(_selectedIndex),
    );
  }

  // Helper for Drawer Items
  Widget _buildDrawerItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1E293B).withOpacity(0.05) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF1E293B) : Colors.grey[600],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: const Color(0xFF1E293B),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        selected: isSelected,
        onTap: () => _onItemTapped(index),
      ),
    );
  }

  // --- SCREEN SWITCHER LOGIC ---
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

// --- DASHBOARD HOME WIDGET ---
class _DashboardHome extends StatelessWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Overview",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    "Live platform metrics",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.green),
                    SizedBox(width: 6),
                    Text(
                      "Live",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- REAL-TIME DATA STREAMS ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('serviceRequests')
                .snapshots(),
            builder: (context, jobSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('agents')
                    .snapshots(),
                builder: (context, agentSnapshot) {
                  if (!jobSnapshot.hasData || !agentSnapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  // 1. CALCULATE STATS
                  int activeJobs = 0;
                  int pendingAgents = 0;
                  double totalRevenue = 0.0;
                  int totalAgents = agentSnapshot.data!.docs.length;

                  // For Chart
                  List<Map<String, dynamic>> completedJobs = [];

                  for (var doc in jobSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'];
                    final price = (data['price'] ?? 0).toDouble();

                    if ([
                      'accepted',
                      'in_progress',
                      'pending_approval',
                    ].contains(status)) {
                      activeJobs++;
                    }
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
                        data['isVerified'] == false) {
                      pendingAgents++;
                    }
                  }

                  // 2. CHART DATA PREP
                  completedJobs.sort(
                    (a, b) => (a['date'] as DateTime).compareTo(
                      b['date'] as DateTime,
                    ),
                  );
                  List<FlSpot> spots = [const FlSpot(0, 0)];
                  List<String> dateLabels = [""];
                  double runningTotal = 0;

                  for (int i = 0; i < completedJobs.length; i++) {
                    runningTotal += (completedJobs[i]['revenue'] as double);
                    spots.add(FlSpot((i + 1).toDouble(), runningTotal));
                    DateTime d = completedJobs[i]['date'];
                    dateLabels.add(DateFormat('d MMM').format(d));
                  }

                  return Column(
                    children: [
                      // --- STATS GRID ---
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio:
                            1.0, // FIX: Make cards square to prevent overflow
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RevenueDetailsScreen(),
                              ),
                            ),
                            child: _buildStatCard(
                              title: "Total Revenue",
                              value:
                                  "₹ ${NumberFormat('#,##0').format(totalRevenue)}",
                              icon: Icons.currency_rupee,
                              color: Colors.green,
                              isClickable: true,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ActiveJobsScreen(),
                              ),
                            ),
                            child: _buildStatCard(
                              title: "Active Jobs",
                              value: "$activeJobs",
                              icon: Icons.work_outline,
                              color: Colors.blue,
                              isClickable: true,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AgentVerificationScreen(),
                              ),
                            ),
                            child: _buildStatCard(
                              title: "Pending Agents",
                              value: "$pendingAgents",
                              icon: Icons.verified_user,
                              color: Colors.orange,
                              isClickable: true,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AllAgentsScreen(),
                              ),
                            ),
                            child: _buildStatCard(
                              title: "Total Agents",
                              value: "$totalAgents",
                              icon: Icons.people_outline,
                              color: Colors.purple,
                              isClickable: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- CHART SECTION ---
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Revenue Growth",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Icon(Icons.show_chart, color: Colors.green),
                              ],
                            ),
                            const Divider(height: 30),
                            SizedBox(
                              height: 250,
                              child: spots.length > 1
                                  ? LineChart(
                                      LineChartData(
                                        gridData: FlGridData(
                                          show: true,
                                          drawVerticalLine: false,
                                          getDrawingHorizontalLine: (value) =>
                                              FlLine(
                                                color: Colors.grey.shade100,
                                                strokeWidth: 1,
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
                                                          top: 8.0,
                                                        ),
                                                    child: Text(
                                                      dateLabels[index],
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey[600],
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  );
                                                }
                                                return const SizedBox();
                                              },
                                              interval: 1,
                                            ),
                                          ),
                                        ),
                                        borderData: FlBorderData(show: false),
                                        lineBarsData: [
                                          LineChartBarData(
                                            spots: spots,
                                            isCurved: true,
                                            color: Colors.green,
                                            barWidth: 4,
                                            isStrokeCapRound: true,
                                            dotData: const FlDotData(
                                              show: true,
                                            ),
                                            belowBarData: BarAreaData(
                                              show: true,
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.green.withOpacity(0.3),
                                                  Colors.green.withOpacity(0.0),
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
                                            Icons.bar_chart_rounded,
                                            size: 48,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Data will appear after first job",
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isClickable = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        // FIX: Prevent overflow
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (isClickable)
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 16,
                    color: Colors.grey[400],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
