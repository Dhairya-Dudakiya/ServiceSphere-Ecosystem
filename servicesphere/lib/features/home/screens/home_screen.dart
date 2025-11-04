import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicesphere/features/auth/services/auth_services.dart';

// --- DATA MODEL FOR YOUR SERVICES ---
class ServiceCategory {
  final String name;
  final IconData icon;
  final Color color;

  ServiceCategory(
      {required this.name, required this.icon, required this.color});
}

// --- YOUR LIST OF SERVICES ---
// You can (and should) load this from Firestore later!
final List<ServiceCategory> serviceCategories = [
  ServiceCategory(name: 'Plumbing', icon: Icons.water_drop, color: Colors.blue),
  ServiceCategory(
      name: 'Cleaning', icon: Icons.cleaning_services, color: Colors.cyan),
  ServiceCategory(
      name: 'Electrical',
      icon: Icons.electrical_services,
      color: Colors.orange),
  ServiceCategory(
      name: 'Painting', icon: Icons.format_paint, color: Colors.purple),
  ServiceCategory(name: 'Appliance', icon: Icons.microwave, color: Colors.red),
  ServiceCategory(
      name: 'Carpentry', icon: Icons.carpenter, color: Colors.brown),
  ServiceCategory(
      name: 'AC Repair', icon: Icons.ac_unit, color: Colors.lightBlue),
  ServiceCategory(name: 'More', icon: Icons.grid_view, color: Colors.grey),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final User? _user = FirebaseAuth.instance.currentUser;

  String getGreeting() {
    final hour = TimeOfDay.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    // Get the user's first name, or "User" if not available
    final String displayName = _user?.displayName?.split(' ').first ?? 'User';

    return Scaffold(
      appBar: AppBar(
        // The theme in main.dart will style this
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              getGreeting(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Text(
              displayName,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SEARCH BAR ---
              _buildSearchBar(context),
              const SizedBox(height: 24),

              // --- CATEGORIES SECTION ---
              _buildSectionHeader(context, 'Categories'),
              const SizedBox(height: 16),
              _buildServiceGrid(context),
              const SizedBox(height: 24),

              // --- BOOKINGS SECTION ---
              _buildSectionHeader(context, 'Your Bookings'),
              const SizedBox(height: 16),
              _buildEmptyStateCard(context, 'No active bookings'),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDER METHODS ---

  Widget _buildSearchBar(BuildContext context) {
    // This search bar style is pulled from your inputDecorationTheme
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Search for a service...',
          icon: Icon(Icons.search),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    // A clean header for different sections
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildServiceGrid(BuildContext context) {
    // The main grid of services
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 4 icons in a row
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: serviceCategories.length,
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(), // Grid is inside SingleChildScrollView
      itemBuilder: (context, index) {
        final category = serviceCategories[index];
        return ServiceCard(category: category);
      },
    );
  }

  Widget _buildEmptyStateCard(BuildContext context, String text) {
    // A placeholder card for sections without content
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

// --- THE NEW, PROFESSIONAL SERVICE CARD WIDGET ---
class ServiceCard extends StatelessWidget {
  final ServiceCategory category;

  const ServiceCard({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to this category's page
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tapped on ${category.name}')),
        );
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                // Use the category's color with low opacity for a modern look
                color: category.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                category.icon,
                size: 30,
                color: category.color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.name,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
