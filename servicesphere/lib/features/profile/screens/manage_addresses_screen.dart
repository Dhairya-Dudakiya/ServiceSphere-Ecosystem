import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
// Ensure this path matches where you created the file
import 'package:servicesphere/features/booking/location_picker_screen.dart';

class ManageAddressesScreen extends StatefulWidget {
  const ManageAddressesScreen({super.key});

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // --- ADD ADDRESS LOGIC ---
  void _showAddAddressSheet() {
    final _labelController = TextEditingController();
    final _addressController = TextEditingController();
    final _formKey = GlobalKey<FormState>();
    bool _isSaving = false;
    GeoPoint? _selectedGeoPoint;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
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
                Text(
                  "Add New Address",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Label Input
                TextFormField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: "Label (e.g., Home, Office)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),

                // Address Input with Map Button
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: "Full Address",
                    hintText: "Type or pick on map",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.map, color: Colors.blue),
                      tooltip: "Pick on Map",
                      onPressed: () async {
                        // Navigate to Map
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const LocationPickerScreen()),
                        );

                        if (result != null && result is LatLng) {
                          setModalState(() => _selectedGeoPoint =
                              GeoPoint(result.latitude, result.longitude));

                          // Reverse Geocode
                          try {
                            List<Placemark> placemarks =
                                await placemarkFromCoordinates(
                                    result.latitude, result.longitude);
                            if (placemarks.isNotEmpty) {
                              Placemark place = placemarks[0];
                              String formattedAddress =
                                  "${place.name}, ${place.subLocality}, ${place.locality}";
                              formattedAddress = formattedAddress.replaceAll(
                                  RegExp(r'^, | ,'), '');
                              _addressController.text = formattedAddress;
                            } else {
                              _addressController.text = "Pinned Location";
                            }
                          } catch (e) {
                            _addressController.text = "Pinned Location";
                          }
                        }
                      },
                    ),
                    alignLabelWithHint: true,
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              setModalState(() => _isSaving = true);
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
                                if (mounted) Navigator.pop(ctx);
                              } catch (e) {
                                setModalState(() => _isSaving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error: $e")));
                                }
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Theme.of(context).primaryColor,
                                strokeWidth: 2))
                        : Text("Save Address",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- DELETE ADDRESS LOGIC ---
  Future<void> _deleteAddress(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('addresses')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please login")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Manage Addresses",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAddressSheet,
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
                  Icon(Icons.location_off, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No saved addresses",
                      style: TextStyle(color: Colors.grey[500], fontSize: 16)),
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

class _AddressCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDelete;

  const _AddressCard({required this.data, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.home_work_outlined, color: Colors.blue),
        ),
        title: Text(
          data['label'] ?? 'Address',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(data['fullAddress'] ?? ''),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Delete Address?"),
                content:
                    const Text("Are you sure you want to remove this address?"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel")),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onDelete();
                    },
                    child: const Text("Delete",
                        style: TextStyle(color: Colors.red)),
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
