import 'package:flutter/material.dart';

// --- DATA MODEL FOR YOUR SERVICES ---
class ServiceCategory {
  final String name;
  final IconData icon;
  final Color color;

  ServiceCategory({
    required this.name,
    required this.icon,
    required this.color,
  });
}

// --- YOUR MASTER LIST OF SERVICES ---
// Add all your services here. The home screen will show the first 7.
final List<ServiceCategory> allServiceCategories = [
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

  // --- ADD MORE SERVICES HERE ---
  // These will appear on the "All Categories" page
  ServiceCategory(
      name: 'Pest Control', icon: Icons.pest_control, color: Colors.green),
  ServiceCategory(
      name: 'Home Security', icon: Icons.security, color: Colors.grey),
  ServiceCategory(
      name: 'Gardening', icon: Icons.local_florist, color: Colors.lightGreen),
  ServiceCategory(
      name: 'Moving', icon: Icons.local_shipping, color: Colors.deepOrange),
];

// --- DATA FOR THE HOME SCREEN GRID ---
// This list automatically takes the first 7 services
// and adds a "More" button at the end.
List<ServiceCategory> getHomeScreenCategories() {
  final homeCategories = allServiceCategories.take(7).toList();
  homeCategories.add(
    ServiceCategory(name: 'More', icon: Icons.grid_view, color: Colors.grey),
  );
  return homeCategories;
}
