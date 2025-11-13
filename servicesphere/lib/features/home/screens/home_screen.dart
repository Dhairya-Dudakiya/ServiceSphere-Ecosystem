import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicesphere/features/auth/services/auth_services.dart';
// 1. --- IMPORT YOUR NEW FILES ---
import 'package:servicesphere/features/home/models/service_category_model.dart';
import 'package:servicesphere/features/home/screens/agent_list_screen.dart';
import 'package:servicesphere/features/home/screens/all_categories_screen.dart';

// 2. --- THE OLD ServiceCategory CLASS AND LIST ARE REMOVED ---
// (They are now in 'service_category_model.dart')

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final User? _user = FirebaseAuth.instance.currentUser;

  // 3. --- GET CATEGORIES FROM THE NEW FUNCTION ---
  final List<ServiceCategory> homeCategories = getHomeScreenCategories();

  String getGreeting() {
    final hour = TimeOfDay.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final String displayName = _user?.displayName?.split(' ').first ?? 'User';

    return Scaffold(
      appBar: AppBar(
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
              _buildSearchBar(context),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Categories'),
              const SizedBox(height: 16),
              _buildServiceGrid(context),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Your Bookings'),
              const SizedBox(height: 16),
              _buildEmptyStateCard(context, 'No active bookings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
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
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildServiceGrid(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      // 4. --- USE THE NEW 'homeCategories' LIST ---
      itemCount: homeCategories.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final category = homeCategories[index];
        return ServiceCard(
          category: category,
        );
      },
    );
  }

  Widget _buildEmptyStateCard(BuildContext context, String text) {
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

// --- UPDATED SERVICE CARD WIDGET ---
class ServiceCard extends StatelessWidget {
  final ServiceCategory category;

  const ServiceCard({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 5. --- THIS IS THE NEW LOGIC ---
        // If the card is "More", go to AllCategoriesScreen.
        // Otherwise, go to the AgentListScreen.
        if (category.name == 'More') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AllCategoriesScreen(),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AgentListScreen(
                categoryName: category.name,
              ),
            ),
          );
        }
        // --- END OF NEW LOGIC ---
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
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
