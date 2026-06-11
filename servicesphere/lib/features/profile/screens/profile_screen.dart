import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicesphere/features/auth/services/auth_services.dart';
import 'package:servicesphere/features/profile/services/profile_service.dart';

import 'package:servicesphere/features/profile/screens/edit_profile_screen.dart';
import 'package:servicesphere/features/profile/screens/manage_addresses_screen.dart';
import 'package:servicesphere/features/profile/screens/payment_methods_screen.dart';
import 'package:servicesphere/features/profile/screens/help_support_screen.dart';
import 'package:servicesphere/features/notification/notification_screen.dart';
import 'package:servicesphere/features/auth/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _deleteAccount() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Delete Account?"),
          ],
        ),
        content: Text(
          "This is permanent. Your data and bookings will be wiped. Are you sure?",
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel",
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text("Delete Forever"),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
        await user.delete();
        if (mounted)
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Security: Please Log Out and Log In again to delete account.")));
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // User App Colors
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA);
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profileService.getUserDataStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return const Center(child: Text('Error loading profile.'));

          final userData = snapshot.data?.data();
          final String displayName = userData?['displayName'] ?? 'User';
          final String email = userData?['email'] ?? 'No Email';

          String photoUrl = userData?['photoUrl'] ?? '';
          if (photoUrl.isEmpty)
            photoUrl = FirebaseAuth.instance.currentUser?.photoURL ?? '';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220.0,
                pinned: true,
                backgroundColor:
                    isDark ? const Color(0xFF1E1E1E) : Colors.white,
                elevation: 0,
                iconTheme: IconThemeData(color: textColor),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      border: Border(
                          bottom: BorderSide(
                              color: isDark
                                  ? Colors.white10
                                  : const Color(0xFFF1F5F9),
                              width: 1)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        GestureDetector(
                          onTap: () {
                            if (userData != null)
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => EditProfileScreen(
                                          currentUserData: userData)));
                          },
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.2),
                                        width: 3)),
                                child: CircleAvatar(
                                  radius: 45,
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  backgroundImage: photoUrl.isNotEmpty
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: photoUrl.isEmpty
                                      ? Text(
                                          displayName.isNotEmpty
                                              ? displayName[0].toUpperCase()
                                              : 'U',
                                          style: TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary))
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: cardColor, width: 3)),
                                  child: const Icon(Icons.edit_rounded,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(displayName,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: textColor)),
                        const SizedBox(height: 4),
                        Text(email,
                            style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("Account Settings", isDark),
                      _buildMenuGroup([
                        ProfileMenuItem(
                            title: 'Edit Profile',
                            icon: Icons.person_outline_rounded,
                            onTap: () {
                              if (userData != null)
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => EditProfileScreen(
                                            currentUserData: userData)));
                            }),
                        _buildDivider(isDark),
                        ProfileMenuItem(
                            title: 'Manage Addresses',
                            icon: Icons.location_on_outlined,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ManageAddressesScreen()))),
                        _buildDivider(isDark),
                        ProfileMenuItem(
                            title: 'Payment Methods',
                            icon: Icons.credit_card_rounded,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const PaymentMethodsScreen()))),
                      ], cardColor, isDark),
                      const SizedBox(height: 24),
                      _buildSectionTitle("App Settings", isDark),
                      _buildMenuGroup([
                        ProfileMenuItem(
                            title: 'Notifications',
                            icon: Icons.notifications_none_rounded,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const NotificationsScreen()))),
                        _buildDivider(isDark),
                        ProfileMenuItem(
                            title: 'Help & Support',
                            icon: Icons.help_outline_rounded,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const HelpSupportScreen()))),
                      ], cardColor, isDark),
                      const SizedBox(height: 24),
                      _buildMenuGroup([
                        ProfileMenuItem(
                          title: 'Log Out',
                          icon: Icons.logout_rounded,
                          textColor: Colors.red.shade400,
                          iconColor: Colors.red.shade400,
                          isDestructive: true,
                          onTap: () {
                            _authService.signOut();
                            Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const LoginScreen()),
                                (route) => false);
                          },
                        ),
                      ], cardColor, isDark),
                      const SizedBox(height: 32),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: _deleteAccount,
                            icon: const Icon(Icons.delete_forever_rounded,
                                color: Colors.red),
                            label: const Text("Delete Account",
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      const SizedBox(height: 40),
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

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
      child: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              fontSize: 13,
              letterSpacing: 0.5)),
    );
  }

  Widget _buildMenuGroup(List<Widget> children, Color cardColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
        height: 1,
        thickness: 1,
        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
        indent: 56);
  }
}

class ProfileMenuItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;
  final bool isDestructive;

  const ProfileMenuItem(
      {super.key,
      required this.title,
      required this.icon,
      required this.onTap,
      this.textColor,
      this.iconColor,
      this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultColor = isDestructive ? Colors.red : theme.colorScheme.primary;
    final defaultTextColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: (iconColor ?? defaultColor).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor ?? defaultColor, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              color: textColor ?? defaultTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 15)),
      trailing: isDestructive
          ? null
          : Icon(Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? Colors.white30 : const Color(0xFFCBD5E1)),
    );
  }
}
