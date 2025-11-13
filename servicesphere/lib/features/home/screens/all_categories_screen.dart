import 'package:flutter/material.dart';
import 'package:servicesphere/features/home/models/service_category_model.dart';
import 'package:servicesphere/features/home/screens/agent_list_screen.dart';

class AllCategoriesScreen extends StatelessWidget {
  const AllCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We get the *full list* of services from our model file
    final categories = allServiceCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Categories'),
      ),
      body: ListView.builder(
        // Use the full list of categories
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (context, index) {
          final category = categories[index];

          // Use a Card for a clean, professional list view
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              leading: Icon(category.icon, color: category.color),
              title: Text(
                category.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // When tapped, navigate to the same AgentListScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AgentListScreen(
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
