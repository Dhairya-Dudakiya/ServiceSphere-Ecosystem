import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/screens/agent_login_screen.dart';

// --- IMPORTS FOR SUB-SCREENS ---
import 'edit_profile_screen.dart';
import 'verification_screen.dart';
import 'bank_details_screen.dart';

class AgentProfileScreen extends StatelessWidget {
  const AgentProfileScreen({super.key});

  // --- CONSTANTS FOR PROFESSIONAL LOOK ---
  static const Color kMainText = Color(0xFF111827); // Deep Black for Main Text
  static const Color kSecondaryText = Color(0xFF6B7280); // Cool Gray for Labels

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AgentLoginScreen()),
        (route) => false,
      );
    }
  }

  // --- LOGIC: Calculate Percentage ---
  double _calculateCompletion(Map<String, dynamic> data) {
    int totalFields = 5; // Name, Email, Phone, Category, IsVerified
    int filledFields = 0;

    if ((data['name'] ?? '').toString().isNotEmpty) filledFields++;
    if ((data['email'] ?? '').toString().isNotEmpty) filledFields++;
    if ((data['phone'] ?? '').toString().isNotEmpty) filledFields++;
    if ((data['category'] ?? '').toString().isNotEmpty) filledFields++;
    if (data['isVerified'] == true) filledFields++;

    return filledFields / totalFields;
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    if (user == null) return const Center(child: Text("Not Logged In"));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Very light gray background
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('agents')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Profile not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String name = data['name'] ?? 'Partner';
          final String email = data['email'] ?? user.email ?? '';
          final String category = data['category'] ?? 'General';
          final bool isVerified = data['isVerified'] ?? false;
          final double rating = (data['rating'] ?? 0).toDouble();

          // Calculate Progress
          final double completion = _calculateCompletion(data);
          final int completionPercent = (completion * 100).toInt();

          return CustomScrollView(
            slivers: [
              // --- 1. HEADER SECTION ---
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    padding: const EdgeInsets.only(top: 60, bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Avatar
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.primaryColor.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: theme.primaryColor.withOpacity(
                                  0.1,
                                ),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                  style: TextStyle(
                                    fontSize: 32,
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Name & Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                // UPDATED: Darker, bolder text for Name
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: kMainText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.verified,
                              size: 18,
                              color: isVerified ? Colors.blue : Colors.grey,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Role (Line 1)
                        Text(
                          category,
                          // UPDATED: Darker text for Main Category
                          style: const TextStyle(
                            color: kMainText,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Email (Line 2)
                        Text(
                          email,
                          // UPDATED: Secondary text is lighter
                          style: const TextStyle(
                            color: kSecondaryText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- 2. PROFILE COMPLETION BAR ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Profile Strength",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: kMainText, // UPDATED
                              ),
                            ),
                            Text(
                              "$completionPercent%",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _getProgressColor(completion),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: completion,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getProgressColor(completion),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (completion < 1.0)
                          Text(
                            "Complete your profile to get verified faster.",
                            style: TextStyle(
                              color: kSecondaryText, // UPDATED
                              fontSize: 11,
                            ),
                          )
                        else
                          Text(
                            "Great job! Your profile is complete.",
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- 3. STATS ROW ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          "Rating",
                          rating.toStringAsFixed(1),
                          Icons.star,
                          Colors.orange,
                        ),
                        _buildDivider(),
                        _buildStatItem(
                          "Jobs",
                          "${data['jobsCompleted'] ?? 0}",
                          Icons.work,
                          Colors.blue,
                        ),
                        _buildDivider(),
                        _buildStatItem(
                          "Status",
                          isVerified ? "Verified" : "Pending",
                          Icons.shield,
                          isVerified ? Colors.green : Colors.orange,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- 4. MENU OPTIONS (CONNECTED) ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildSectionTitle("Account"),

                      // -- Personal Info --
                      _buildMenuTile(
                        icon: Icons.person_outline,
                        title: "Personal Information",
                        subtitle: "Edit name, phone, address",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          );
                        },
                      ),

                      // -- Verification --
                      _buildMenuTile(
                        icon: Icons.document_scanner_outlined,
                        title: "Verification Center",
                        subtitle: "Upload ID & Licenses",
                        trailing: isVerified
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              )
                            : const Icon(
                                Icons.error,
                                color: Colors.orange,
                                size: 16,
                              ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VerificationScreen(),
                            ),
                          );
                        },
                      ),

                      // -- Bank Details --
                      _buildMenuTile(
                        icon: Icons.payments_outlined,
                        title: "Bank Details",
                        subtitle: "Manage payout methods",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BankDetailsScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                      _buildSectionTitle("App Settings"),
                      _buildMenuTile(
                        icon: Icons.notifications_outlined,
                        title: "Notifications",
                        onTap: () {
                          // TODO: Add Notification Screen
                        },
                      ),
                      _buildMenuTile(
                        icon: Icons.help_outline,
                        title: "Help & Support",
                        onTap: () {
                          // TODO: Add Help Screen
                        },
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 40),
                        child: TextButton.icon(
                          onPressed: () => _logout(context),
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text(
                            "Log Out",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.red.withOpacity(0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Helper to change color based on percentage ---
  Color _getProgressColor(double percent) {
    if (percent < 0.4) return Colors.red;
    if (percent < 0.7) return Colors.orange;
    if (percent < 1.0) return Colors.blue;
    return Colors.green;
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          // UPDATED: Main Stat Value is Dark & Bold
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: kMainText,
          ),
        ),
        Text(
          label,
          // UPDATED: Label is lighter
          style: const TextStyle(
            color: kSecondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 30, width: 1, color: Colors.grey.shade200);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          // UPDATED: Section Title is Lighter but uppercase/bold
          style: const TextStyle(
            color: kSecondaryText,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: kMainText, size: 20), // Icon dark
        ),
        title: Text(
          title,
          // UPDATED: Menu Title is Dark & SemiBold
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: kMainText,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                // UPDATED: Subtitle is Lighter
                style: const TextStyle(color: kSecondaryText, fontSize: 12),
              )
            : null,
        trailing:
            trailing ??
            const Icon(Icons.chevron_right, color: kSecondaryText, size: 20),
      ),
    );
  }
}
