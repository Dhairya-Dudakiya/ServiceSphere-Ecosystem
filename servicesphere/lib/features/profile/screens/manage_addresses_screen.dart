import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
// Ensure this path matches your project structure
import 'package:servicesphere/features/booking/location_picker_screen.dart';

class ManageAddressesScreen extends StatefulWidget {
  const ManageAddressesScreen({super.key});

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // --- DELETE ADDRESS LOGIC ---
  Future<void> _deleteAddress(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('addresses')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Address removed successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error removing address: $e")),
        );
      }
    }
  }

  // --- OPEN BOTTOM SHEET ---
  void _openAddAddressSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Allows rounded corners to show
      builder: (ctx) => const _AddAddressSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please login")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Manage Addresses",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddAddressSheet,
        label: const Text("Add New"),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('addresses')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "No saved addresses",
                    style: TextStyle(color: Colors.grey[600], fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap 'Add New' to save your location",
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _AddressCard(
                data: data,
                onDelete: () => _deleteAddress(doc.id),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// WIDGET 1: THE ADDRESS CARD (Improved Styling)
// ============================================================================
class _AddressCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDelete;

  const _AddressCard({required this.data, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.location_on, color: Colors.blue, size: 24),
        ),
        title: Text(
          data['label'] ?? 'Address',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black, // <--- FIXED: BLACK COLOR
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            data['fullAddress'] ?? '',
            style: const TextStyle(
              color: Colors.black87, // <--- FIXED: DARK COLOR
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ),
        trailing: IconButton(
          icon:
              const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text("Delete Address"),
                content: const Text(
                    "Are you sure you want to remove this location?"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel")),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onDelete();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Delete"),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET 2: THE BOTTOM SHEET FORM (Extracted for better state management)
// ============================================================================
class _AddAddressSheet extends StatefulWidget {
  const _AddAddressSheet();

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  GeoPoint? _selectedGeoPoint;

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('addresses')
          .add({
        'label': _labelController.text.trim(),
        'fullAddress': _addressController.text.trim(),
        'location': _selectedGeoPoint,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Address saved successfully!")),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result != null && result is LatLng) {
      setState(() {
        _selectedGeoPoint = GeoPoint(result.latitude, result.longitude);
      });

      // Reverse Geocoding
      try {
        List<Placemark> placemarks =
            await placemarkFromCoordinates(result.latitude, result.longitude);

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String formattedAddress =
              "${place.name}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}";
          // Remove leading commas if any field was null/empty
          formattedAddress = formattedAddress.replaceAll(RegExp(r'^, | ,'), '');
          _addressController.text = formattedAddress;
        } else {
          _addressController.text = "Pinned Location (Address not found)";
        }
      } catch (e) {
        _addressController.text =
            "Pinned Location (${result.latitude}, ${result.longitude})";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Add New Address",
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 20),

            // LABEL INPUT
            TextFormField(
              controller: _labelController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: "Label",
                hintText: "e.g. Home, Office, Parents' House",
                prefixIcon: const Icon(Icons.bookmark_border),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? "Please enter a label" : null,
            ),
            const SizedBox(height: 16),

            // ADDRESS INPUT
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Full Address",
                hintText: "Enter address or pick from map",
                prefixIcon: const Icon(Icons.map_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  onPressed: _pickLocation,
                  icon:
                      const Icon(Icons.location_searching, color: Colors.blue),
                  tooltip: "Pick on Map",
                ),
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? "Please enter an address" : null,
            ),
            const SizedBox(height: 24),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        "Save Address",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
