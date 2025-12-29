import 'dart:io'; // Required for File
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Required for Upload
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart'; // Required for Image
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
  final _phoneController = TextEditingController();

  // Scheduling Variables
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Location Variable
  GeoPoint? _selectedGeoPoint;

  // Image Variable
  XFile? _selectedImage;

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

  // --- 1. PICK IMAGE ---
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Picture'),
              onTap: () async {
                Navigator.pop(ctx);
                final XFile? image =
                    await picker.pickImage(source: ImageSource.camera);
                if (image != null) setState(() => _selectedImage = image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final XFile? image =
                    await picker.pickImage(source: ImageSource.gallery);
                if (image != null) setState(() => _selectedImage = image);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const LocationPickerScreen()));

    if (result != null && result is LatLng) {
      setState(() => _isLoading = true);
      try {
        _selectedGeoPoint = GeoPoint(result.latitude, result.longitude);
        List<Placemark> placemarks =
            await placemarkFromCoordinates(result.latitude, result.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String formattedAddress =
              "${place.name}, ${place.subLocality}, ${place.locality}";
          formattedAddress = formattedAddress.replaceAll(RegExp(r'^, | ,'), '');
          _addressController.text = formattedAddress;
        } else {
          _addressController.text = "Pinned Location";
        }
      } catch (e) {
        _addressController.text = "Pinned Location";
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

      // --- 2. UPLOAD IMAGE TO FIREBASE STORAGE ---
      String? imageUrl;
      if (_selectedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('job_images')
            .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(File(_selectedImage!.path));
        imageUrl = await storageRef.getDownloadURL();
      }

      final scheduledDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // --- 3. SAVE TO FIRESTORE ---
      await FirebaseFirestore.instance.collection('serviceRequests').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'address': _addressController.text.trim(),
        // 'price' is 0 because Agent will Quote
        'price': 0.0,
        'customerPhone': _phoneController.text.trim(),
        'category': widget.categoryName,
        // Status is 'pending_quote' so Agent App shows "Quote Price" button
        'status': 'pending_quote',
        'customerId': user.uid,
        'customerName': user.displayName ?? 'Valued Customer',
        'createdAt': FieldValue.serverTimestamp(),
        'scheduledTime': Timestamp.fromDate(scheduledDateTime),
        'location': _selectedGeoPoint,
        'imageUrl': imageUrl, // Save image link
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Request Sent! Waiting for Agent Quotes."),
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
                        "Describe the issue. Agents will review and send a price quote.",
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey[600])),
                    const SizedBox(height: 32),

                    // --- 4. IMAGE PICKER UI ---
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(File(_selectedImage!.path)),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: _selectedImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo,
                                      size: 40, color: theme.primaryColor),
                                  const SizedBox(height: 8),
                                  const Text("Add Photo (Optional)",
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold)),
                                ],
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),

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

                    // Address
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

                    // Phone Number
                    _buildTextField(
                      context: context,
                      controller: _phoneController,
                      label: "Phone Number",
                      hint: "10-digit mobile number",
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Required";
                        if (v.length != 10) return "Must be 10 digits";
                        return null;
                      },
                    ),

                    // --- REMOVED BUDGET FIELD (Agent will quote) ---

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
                            : const Text("Request Quote",
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

  // --- Helper Widgets ---
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
    int? maxLength,
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
          maxLength: maxLength,
          buildCounter: (context,
                  {required currentLength, required isFocused, maxLength}) =>
              null,
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
