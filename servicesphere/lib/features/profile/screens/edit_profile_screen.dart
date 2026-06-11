import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicesphere/features/profile/services/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentUserData;
  const EditProfileScreen({super.key, required this.currentUserData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  XFile? _newImageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.currentUserData['displayName']);
    _phoneController =
        TextEditingController(text: widget.currentUserData['phone']);
    _addressController =
        TextEditingController(text: widget.currentUserData['address']);
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _profileService.pickImage();
    if (pickedFile != null) {
      setState(() {
        _newImageFile = pickedFile;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? newPhotoUrl;
      if (_newImageFile != null)
        newPhotoUrl =
            await _profileService.uploadProfilePicture(_newImageFile!);

      await _profileService.updateProfileData(
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        photoUrl: newPhotoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA);
    final textColor = isDark ? Colors.white : Colors.black87;

    String currentPhotoUrl = widget.currentUserData['photoUrl'] ?? '';
    if (currentPhotoUrl.isEmpty)
      currentPhotoUrl = FirebaseAuth.instance.currentUser?.photoURL ?? '';

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 100.0,
                pinned: true,
                backgroundColor: bgColor,
                elevation: 0,
                leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: textColor, size: 20),
                    onPressed: () => Navigator.pop(context)),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text("Edit Profile",
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          fontSize: 18)),
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
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark
                                        ? const Color(0xFF2A2A2A)
                                        : Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black
                                              .withOpacity(isDark ? 0.3 : 0.08),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8))
                                    ]),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: isDark
                                      ? const Color(0xFF1E1E1E)
                                      : const Color(0xFFF1F5F9),
                                  backgroundImage: _newImageFile != null
                                      ? FileImage(File(_newImageFile!.path))
                                      : (currentPhotoUrl.isNotEmpty
                                          ? NetworkImage(currentPhotoUrl)
                                          : null) as ImageProvider?,
                                  child: (_newImageFile == null &&
                                          currentPhotoUrl.isEmpty)
                                      ? Icon(Icons.person_rounded,
                                          size: 60,
                                          color: isDark
                                              ? Colors.white24
                                              : const Color(0xFFCBD5E1))
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: theme.primaryColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: isDark
                                                ? const Color(0xFF2A2A2A)
                                                : Colors.white,
                                            width: 4),
                                        boxShadow: [
                                          BoxShadow(
                                              color: theme.primaryColor
                                                  .withOpacity(0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4))
                                        ]),
                                    child: const Icon(Icons.camera_alt_rounded,
                                        size: 20, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),
                        _buildTextField(
                            context: context,
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person_outline_rounded,
                            validator: (v) => v!.isEmpty ? 'Required' : null),
                        const SizedBox(height: 20),
                        _buildTextField(
                            context: context,
                            controller: _phoneController,
                            label: 'Phone Number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone),
                        const SizedBox(height: 20),
                        _buildTextField(
                            context: context,
                            controller: _addressController,
                            label: 'Address',
                            icon: Icons.location_on_outlined,
                            maxLines: 2),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 4,
                                shadowColor:
                                    theme.primaryColor.withOpacity(0.5)),
                            child: const Text("Save Changes",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5)),
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
          if (_isLoading)
            Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildTextField(
      {required BuildContext context,
      required TextEditingController controller,
      required String label,
      required IconData icon,
      int maxLines = 1,
      TextInputType? keyboardType,
      String? Function(String?)? validator}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
        ),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E293B)),
          decoration: InputDecoration(
            filled: true,
            fillColor: inputBgColor,
            prefixIcon: Icon(icon,
                color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
            hintText: "Enter $label",
            hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : const Color(0xFFCBD5E1),
                fontWeight: FontWeight.w400),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: Theme.of(context).primaryColor, width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.redAccent)),
          ),
        ),
      ],
    );
  }
}
