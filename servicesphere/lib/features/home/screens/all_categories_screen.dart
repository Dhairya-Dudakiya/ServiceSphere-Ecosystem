import 'package:flutter/material.dart';
import 'package:servicesphere/features/home/models/service_category_model.dart';
import 'package:servicesphere/features/booking/book_service_screen.dart';

class AllCategoriesScreen extends StatelessWidget {
  const AllCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We get the *full list* of services from our model file
    final categories = allServiceCategories;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F9FA), // Professional light grey background
      appBar: AppBar(
        title: Text(
          'All Categories',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: ListView.separated(
        // Use the full list of categories
        itemCount: categories.length,
        padding: const EdgeInsets.all(16),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final category = categories[index];

          // Use a specialized Container for a clean, professional list view
          return Container(
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
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, color: category.color, size: 24),
              ),
              title: Text(
                category.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right,
                    size: 20, color: Colors.grey),
              ),
              onTap: () {
                // When tapped, navigate to the BookServiceScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookServiceScreen(
                      categoryName: category.name,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
