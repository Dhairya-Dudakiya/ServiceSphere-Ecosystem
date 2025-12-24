import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart'; // REQUIRED: flutter pub add geocoding
import 'package:servicesphere/features/booking/location_picker_screen.dart';

class BookServiceScreen extends StatefulWidget {
  final String categoryName;

  const BookServiceScreen({super.key, required this.categoryName});

  @override
  State<BookServiceScreen> createState() => _BookServiceScreenState();
}

class _BookServiceScreenState extends State<BookServiceScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  final _phoneController = TextEditingController();

  // Scheduling Variables
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Location Variable
  GeoPoint? _selectedGeoPoint;

  bool _isLoading = false;

  Map<String, String> _getCategoryHints() {
    final category = widget.categoryName.toLowerCase();
    if (category.contains('clean')) {
      return {
        'title': 'e.g. Deep Cleaning 2BHK',
        'desc': 'Need kitchen and 2 bathrooms deep cleaned...'
      };
    } else if (category.contains('plumb')) {
      return {
        'title': 'e.g. Fix Leaking Sink',
        'desc': 'Water leaking from the pipe under the kitchen sink...'
      };
    }
    return {
      'title': 'e.g. General Repair',
      'desc': 'Describe the issue or service you need...'
    };
  }

  // --- UPDATED: Pick Location & Get Address Name ---
  Future<void> _pickLocationOnMap() async {
    // 1. Navigate to map
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const LocationPickerScreen()));

    // 2. If user picked a spot
    if (result != null && result is LatLng) {
      setState(() => _isLoading = true); // Show loading while fetching address

      try {
        _selectedGeoPoint = GeoPoint(result.latitude, result.longitude);

        // 3. Reverse Geocoding (Coords -> Address)
        List<Placemark> placemarks =
            await placemarkFromCoordinates(result.latitude, result.longitude);

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          // Construct a readable string
          // Example: "Taj Mahal, Dharmapuri, Forest Colony, Agra"
          String formattedAddress =
              "${place.name}, ${place.subLocality}, ${place.locality}";

          // Remove empty parts if any (e.g. if name is missing)
          formattedAddress = formattedAddress.replaceAll(RegExp(r'^, | ,'), '');

          _addressController.text = formattedAddress;
        } else {
          _addressController.text =
              "Pinned Location (${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)})";
        }
      } catch (e) {
        // Fallback if geocoding fails
        _addressController.text =
            "Pinned Location (${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)})";
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Could not fetch address name, but location is saved.")),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _postJob() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a Date and Time.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You must be logged in to book!")));
        return;
      }

      final scheduledDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      await FirebaseFirestore.instance.collection('serviceRequests').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'address': _addressController.text.trim(),
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'customerPhone': _phoneController.text.trim(),
        'category': widget.categoryName,
        'status': 'pending',
        'customerId': user.uid,
        'customerName': user.displayName ?? 'Valued Customer',
        'createdAt': FieldValue.serverTimestamp(),
        'scheduledTime': Timestamp.fromDate(scheduledDateTime),
        'location': _selectedGeoPoint,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Job Scheduled Successfully!"),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hints = _getCategoryHints();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100.0,
            pinned: true,
            backgroundColor: const Color(0xFFF8F9FA),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                "Book ${widget.categoryName}",
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Describe your task",
                        style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 8),
                    Text(
                        "We need a few details to connect you with the right professional.",
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey[600])),
                    const SizedBox(height: 32),

                    _buildTextField(
                        context: context,
                        controller: _titleController,
                        label: "Job Title",
                        hint: hints['title']!,
                        icon: Icons.title,
                        validator: (v) => v!.isEmpty ? "Required" : null),
                    const SizedBox(height: 20),
                    _buildTextField(
                        context: context,
                        controller: _descController,
                        label: "Description",
                        hint: hints['desc']!,
                        icon: Icons.description_outlined,
                        maxLines: 3),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDate,
                            child: _buildPickerContainer(
                              context,
                              icon: Icons.calendar_today,
                              label: "Date",
                              value: _selectedDate == null
                                  ? "Select Date"
                                  : DateFormat('MMM dd, yyyy')
                                      .format(_selectedDate!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickTime,
                            child: _buildPickerContainer(
                              context,
                              icon: Icons.access_time,
                              label: "Time",
                              value: _selectedTime == null
                                  ? "Select Time"
                                  : _selectedTime!.format(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- ADDRESS FIELD WITH MAP ICON ---
                    _buildTextField(
                      context: context,
                      controller: _addressController,
                      label: "Address",
                      hint: "Type address or pick on map",
                      icon: Icons.location_on_outlined,
                      validator: (v) => v!.isEmpty ? "Required" : null,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.map, color: Colors.blue),
                        onPressed: _pickLocationOnMap,
                        tooltip: "Pick on Map",
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildTextField(
                        context: context,
                        controller: _phoneController,
                        label: "Phone Number",
                        hint: "10-digit mobile number",
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            v!.length < 10 ? "Invalid Number" : null),
                    const SizedBox(height: 20),
                    _buildTextField(
                        context: context,
                        controller: _priceController,
                        label: "Budget",
                        hint: "0.00",
                        icon: Icons.currency_rupee,
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? "Required" : null,
                        prefixText: "₹ "),
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _postJob,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 2),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("Schedule Job",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerContainer(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? prefixText,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(icon, color: Colors.grey.shade500),
            prefixText: prefixText,
            suffixIcon: suffixIcon,
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Theme.of(context).primaryColor, width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red)),
          ),
        ),
      ],
    );
  }
}
