import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart'; // REQUIRED: flutter pub add fl_chart
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
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _key,
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "ServiceSphere HQ",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.black87,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.black87),
              accountName: const Text(
                "Admin",
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
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.admin_panel_settings,
                  size: 40,
                  color: Colors.black87,
                ),
              ),
            ),
            _buildDrawerItem(0, "Dashboard", Icons.dashboard_outlined),
            _buildDrawerItem(1, "Verifications", Icons.verified_user_outlined),
            _buildDrawerItem(2, "All Jobs", Icons.work_outline),
            _buildDrawerItem(3, "Categories", Icons.category_outlined),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _getScreen(_selectedIndex),
    );
  }

  Widget _buildDrawerItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.black87 : Colors.grey[700],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.black87.withOpacity(0.1),
      onTap: () => _onItemTapped(index),
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

// --- DASHBOARD HOME WIDGET ---
class _DashboardHome extends StatelessWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Overview",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Welcome back, Admin. Live stats from your platform.",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

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
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 1. CALCULATE BASIC STATS
                  int activeJobs = 0;
                  int pendingAgents = 0;
                  double totalRevenue = 0.0;
                  int totalAgents = agentSnapshot.data!.docs.length;

                  // Map to group revenue by date: "2023-12-25" -> 500.0
                  Map<String, double> dailyRevenueMap = {};

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

                      // Process Chart Data
                      if (data['completedAt'] != null) {
                        final date = (data['completedAt'] as Timestamp)
                            .toDate();
                        final dateKey = DateFormat('yyyy-MM-dd').format(date);

                        if (dailyRevenueMap.containsKey(dateKey)) {
                          dailyRevenueMap[dateKey] =
                              dailyRevenueMap[dateKey]! + commission;
                        } else {
                          dailyRevenueMap[dateKey] = commission;
                        }
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

                  // 2. PREPARE CHART DATA
                  // Convert Map to sorted List
                  List<MapEntry<String, double>> sortedDaily =
                      dailyRevenueMap.entries.toList()
                        ..sort((a, b) => a.key.compareTo(b.key));

                  List<FlSpot> spots = [];
                  List<String> dateLabels = []; // Store date strings for X-axis

                  double runningTotal = 0;

                  // Add initial point
                  spots.add(const FlSpot(0, 0));
                  dateLabels.add(""); // Placeholder for 0

                  for (int i = 0; i < sortedDaily.length; i++) {
                    runningTotal += sortedDaily[i].value;
                    spots.add(FlSpot((i + 1).toDouble(), runningTotal));

                    // Format date for label (e.g., "25 Dec")
                    DateTime d = DateTime.parse(sortedDaily[i].key);
                    dateLabels.add(DateFormat('d MMM').format(d));
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- STATS GRID ---
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const RevenueDetailsScreen(),
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
                                builder: (context) => const ActiveJobsScreen(),
                              ),
                            ),
                            child: _buildStatCard(
                              title: "Active Jobs",
                              value: "$activeJobs",
                              icon: Icons.work_outline,
                              color: Colors.black87,
                              isClickable: true,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AgentVerificationScreen(),
                              ),
                            ),
                            child: _buildStatCard(
                              title: "Pending Agents",
                              value: "$pendingAgents",
                              icon: Icons.person_add_alt_1,
                              color: Colors.orange,
                              isClickable: true,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AllAgentsScreen(),
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

                      const SizedBox(height: 30),
                      const Text(
                        "Revenue Growth",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --- REVENUE CHART WITH DATES ---
                      Container(
                        height: 300,
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 24, 24, 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: spots.length > 1
                            ? LineChart(
                                LineChartData(
                                  gridData: const FlGridData(show: false),
                                  titlesData: FlTitlesData(
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          int index = value.toInt();
                                          if (index > 0 &&
                                              index < dateLabels.length) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child: Text(
                                                dateLabels[index],
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox();
                                        },
                                        interval: 1, // Show every date point
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
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: Colors.green.withOpacity(0.15),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.show_chart,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Chart will appear after first completed job",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 50),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isClickable) ...[
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
