import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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

  // Scheduling
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Location
  GeoPoint? _selectedGeoPoint;

  // Image
  XFile? _selectedImage;

  bool _isLoading = false;

  // ─── LIFECYCLE ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ─── CATEGORY HINTS ────────────────────────────────────────────────────────

  Map<String, String> _getCategoryHints() {
    final category = widget.categoryName.toLowerCase();

    if (category.contains('clean')) {
      return {
        'title': 'e.g. Deep Cleaning 2BHK',
        'desc': 'Need kitchen and 2 bathrooms deep cleaned...',
      };
    } else if (category.contains('plumb')) {
      return {
        'title': 'e.g. Fix Leaking Sink',
        'desc': 'Water leaking from the pipe under the kitchen sink...',
      };
    } else if (category.contains('electr')) {
      return {
        'title': 'e.g. Fix Power Outlet',
        'desc': 'Socket in the bedroom not working, needs inspection...',
      };
    } else if (category.contains('paint')) {
      return {
        'title': 'e.g. Paint Living Room',
        'desc': 'Living room walls need repainting, approx 400 sq ft...',
      };
    } else if (category.contains('ac') || category.contains('repair')) {
      return {
        'title': 'e.g. AC Not Cooling',
        'desc': 'Split AC in bedroom not cooling, making noise...',
      };
    } else if (category.contains('carpent')) {
      return {
        'title': 'e.g. Fix Broken Cabinet',
        'desc': 'Kitchen cabinet door hinge broken, needs replacement...',
      };
    } else if (category.contains('appliance')) {
      return {
        'title': 'e.g. Washing Machine Repair',
        'desc': 'Washing machine not spinning, making loud noise...',
      };
    } else if (category.contains('pest')) {
      return {
        'title': 'e.g. Cockroach Treatment',
        'desc': 'Cockroach infestation in kitchen and bathroom...',
      };
    } else if (category.contains('garden')) {
      return {
        'title': 'e.g. Garden Trimming',
        'desc': 'Need lawn mowed and plants trimmed in backyard...',
      };
    } else if (category.contains('secur')) {
      return {
        'title': 'e.g. Install CCTV Camera',
        'desc': 'Need 2 CCTV cameras installed at entrance and backyard...',
      };
    } else if (category.contains('mov')) {
      return {
        'title': 'e.g. Move 2BHK Furniture',
        'desc': 'Need help moving furniture from 2BHK to new flat nearby...',
      };
    }

    return {
      'title': 'e.g. General Service',
      'desc': 'Describe the issue or service you need...',
    };
  }

  // ─── PICK IMAGE ────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.camera_alt_rounded,
                      color: Theme.of(context).primaryColor),
                ),
                title: const Text('Take a Picture',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? image =
                      await picker.pickImage(source: ImageSource.camera);
                  if (image != null) setState(() => _selectedImage = image);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.photo_library_rounded,
                      color: Theme.of(context).primaryColor),
                ),
                title: const Text('Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? image =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) setState(() => _selectedImage = image);
                },
              ),
              if (_selectedImage != null) ...[
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red),
                  ),
                  title: const Text('Remove Photo',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _selectedImage = null);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── COMPRESS & UPLOAD IMAGE ───────────────────────────────────────────────

  Future<String?> _uploadImage(String userId) async {
    if (_selectedImage == null) return null;

    try {
      // Compress before uploading — reduces size by ~70%
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        _selectedImage!.path,
        minWidth: 800,
        minHeight: 800,
        quality: 75,
      );

      if (compressedBytes == null) return null;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('job_images')
          .child('${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putData(compressedBytes);
      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  // ─── PICK LOCATION ─────────────────────────────────────────────────────────

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );

    if (result != null && result is LatLng) {
      setState(() => _isLoading = true);
      try {
        _selectedGeoPoint = GeoPoint(result.latitude, result.longitude);
        final placemarks = await placemarkFromCoordinates(
          result.latitude,
          result.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          String formatted =
              '${place.name}, ${place.subLocality}, ${place.locality}';
          formatted = formatted.replaceAll(RegExp(r'^, | ,'), '').trim();
          _addressController.text = formatted;
        } else {
          _addressController.text = 'Pinned Location';
        }
      } catch (e) {
        _addressController.text = 'Pinned Location';
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // ─── DATE & TIME ───────────────────────────────────────────────────────────

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

  // ─── POST JOB ──────────────────────────────────────────────────────────────

  Future<void> _postJob() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Date and Time.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedGeoPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please pin your location on the map for accurate agent matching.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to book!')),
        );
        return;
      }

      final String? imageUrl = await _uploadImage(user.uid);

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
        'price': 0.0,
        'customerPhone': _phoneController.text.trim(),
        'category': widget.categoryName,
        'status': 'pending_quote',
        'customerId': user.uid,
        'customerName': user.displayName ?? 'Valued Customer',
        'createdAt': FieldValue.serverTimestamp(),
        'scheduledTime': Timestamp.fromDate(scheduledDateTime),
        'location': _selectedGeoPoint,
        'latitude': _selectedGeoPoint!.latitude,
        'longitude': _selectedGeoPoint!.longitude,
        'imageUrl': imageUrl,
        'isReadByUser': false,
        'isHiddenFromUser': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request Sent! Waiting for Agent Quotes.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting job: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hints = _getCategoryHints();
    final isDark = theme.brightness == Brightness.dark;

    // Premium Colors
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FC);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // ── APP BAR ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 100.0,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : bgColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: textColor,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                'Book ${widget.categoryName}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  fontSize: 18,
                ),
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
                    // ── HEADER ─────────────────────────────────────────
                    Text(
                      'Describe your task',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Describe the issue clearly. Verified nearby agents will review your post and offer precise price quotes.',
                      style: TextStyle(
                        color:
                            isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── IMAGE PICKER ───────────────────────────────────
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(File(_selectedImage!.path)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _selectedImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.add_photo_alternate_rounded,
                                      size: 32,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Add Reference Photo (Optional)',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : const Color(0xFF64748B),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              )
                            : Stack(
                                children: [
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _selectedImage = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── JOB TITLE ──────────────────────────────────────
                    _buildTextField(
                      context: context,
                      controller: _titleController,
                      label: 'Job Title',
                      hint: hints['title']!,
                      icon: Icons.assignment_outlined,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),

                    // ── DESCRIPTION ────────────────────────────────────
                    _buildTextField(
                      context: context,
                      controller: _descController,
                      label: 'Detailed Description',
                      hint: hints['desc']!,
                      icon: Icons.description_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // ── DATE & TIME ────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDate,
                            child: _buildPickerContainer(
                              context,
                              icon: Icons.calendar_today_rounded,
                              label: 'Scheduled Date',
                              value: _selectedDate == null
                                  ? 'Select Date'
                                  : DateFormat('MMM dd, yyyy')
                                      .format(_selectedDate!),
                              isSelected: _selectedDate != null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickTime,
                            child: _buildPickerContainer(
                              context,
                              icon: Icons.access_time_rounded,
                              label: 'Preferred Time',
                              value: _selectedTime == null
                                  ? 'Select Time'
                                  : _selectedTime!.format(context),
                              isSelected: _selectedTime != null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── ADDRESS ────────────────────────────────────────
                    _buildTextField(
                      context: context,
                      controller: _addressController,
                      label: 'Service Address',
                      hint: 'Type address or drop map pin',
                      icon: Icons.map_outlined,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                      suffixIcon: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            )
                          : Container(
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.pin_drop_rounded,
                                    color: Colors.blue),
                                onPressed: _pickLocationOnMap,
                                tooltip: 'Pin on Map',
                              ),
                            ),
                    ),

                    // Location pin status indicator
                    Padding(
                      padding: const EdgeInsets.only(top: 10, left: 4),
                      child: _selectedGeoPoint != null
                          ? Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Colors.green, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Precise GPS coordinate locked ✓',
                                  style: TextStyle(
                                    color: Colors.green[600],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    color: Colors.orange[700], size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Drop a map pin to locate nearby pros',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),

                    // ── PHONE NUMBER ───────────────────────────────────
                    _buildTextField(
                      context: context,
                      controller: _phoneController,
                      label: 'Contact Number',
                      hint: '10-digit mobile number',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (v.trim().length != 10) return 'Must be 10 digits';
                        return null;
                      },
                    ),

                    const SizedBox(height: 48),

                    // ── SUBMIT BUTTON ──────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _postJob,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          disabledBackgroundColor:
                              theme.colorScheme.primary.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor:
                              theme.colorScheme.primary.withOpacity(0.4),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Request Quotes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPER WIDGETS ────────────────────────────────────────────────────────

  Widget _buildPickerContainer(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.primary
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isSelected
                  ? (isDark ? Colors.white : const Color(0xFF1E293B))
                  : const Color(0xFFCBD5E1),
            ),
          ),
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
    Widget? suffixIcon,
    int? maxLength,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inputBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          maxLength: maxLength,
          buildCounter: (context,
                  {required currentLength, required isFocused, maxLength}) =>
              null,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: inputBg,
            prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
            suffixIcon: suffixIcon,
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
