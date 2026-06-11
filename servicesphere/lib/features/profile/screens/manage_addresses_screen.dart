import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:servicesphere/features/booking/location_picker_screen.dart';

class ManageAddressesScreen extends StatefulWidget {
  const ManageAddressesScreen({super.key});

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  Future<void> _deleteAddress(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('addresses')
          .doc(docId)
          .delete();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Address removed successfully")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error removing address: $e")));
    }
  }

  void _openAddAddressSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddAddressSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null)
      return const Scaffold(body: Center(child: Text("Please login")));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Manage Addresses",
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: textColor, size: 20),
            onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddAddressSheet,
        elevation: 4,
        label: const Text("Add New",
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        icon: const Icon(Icons.add_location_alt_rounded),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('addresses')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF2A2A2A) : Colors.white,
                          shape: BoxShape.circle),
                      child: Icon(Icons.location_off_rounded,
                          size: 64,
                          color: isDark ? Colors.white24 : Colors.grey[300])),
                  const SizedBox(height: 24),
                  Text("No saved addresses",
                      style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text("Tap 'Add New' to save your location",
                      style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              return _AddressCard(
                  data: doc.data() as Map<String, dynamic>,
                  onDelete: () => _deleteAddress(doc.id));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final String label = data['label'] ?? 'Address';

    return Container(
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ]),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(
                label.toLowerCase() == 'home'
                    ? Icons.home_rounded
                    : label.toLowerCase() == 'office'
                        ? Icons.work_rounded
                        : Icons.location_on_rounded,
                color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                size: 24)),
        title: Text(label.toUpperCase(),
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 13,
                letterSpacing: 1.0)),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(data['fullAddress'] ?? '',
                style: TextStyle(
                    color: isDark ? Colors.grey[300] : const Color(0xFF64748B),
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500))),
        trailing: IconButton(
            icon:
                Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
            onPressed: onDelete),
      ),
    );
  }
}

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

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('addresses')
          .add({
        'label': _labelController.text.trim(),
        'fullAddress': _addressController.text.trim(),
        'location': _selectedGeoPoint,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Address saved successfully!")));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const LocationPickerScreen()));
    if (result != null && result is LatLng) {
      setState(() {
        _selectedGeoPoint = GeoPoint(result.latitude, result.longitude);
      });
      try {
        List<Placemark> placemarks =
            await placemarkFromCoordinates(result.latitude, result.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String formattedAddress =
              "${place.name}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}";
          _addressController.text =
              formattedAddress.replaceAll(RegExp(r'^, | ,'), '');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final inputBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Container(
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 12),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 32),
            Text("Add New Address",
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    fontSize: 24,
                    letterSpacing: -0.5)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _labelController,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
              decoration: InputDecoration(
                labelText: "Label (e.g. Home, Office)",
                labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500),
                prefixIcon: Icon(Icons.bookmark_outline_rounded,
                    color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2)),
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? "Please enter a label" : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
              decoration: InputDecoration(
                labelText: "Full Address",
                labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500),
                prefixIcon: Icon(Icons.map_outlined,
                    color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
                filled: true,
                fillColor: inputBg,
                suffixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10)),
                    child: IconButton(
                        onPressed: _pickLocation,
                        icon: Icon(Icons.my_location_rounded,
                            color: isDark
                                ? Colors.blue.shade300
                                : Colors.blue.shade700))),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2)),
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? "Please enter an address" : null,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAddress,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor:
                        Theme.of(context).primaryColor.withOpacity(0.5)),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text("Save Address",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
