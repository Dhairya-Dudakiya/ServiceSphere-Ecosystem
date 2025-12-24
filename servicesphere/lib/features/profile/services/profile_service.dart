import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  String get _userId => _auth.currentUser!.uid;

  // --- GET USER DATA ---
  // Get a live stream of the user's document
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserDataStream() {
    return _firestore.collection('users').doc(_userId).snapshots();
  }

  // --- UPLOAD PROFILE PICTURE ---
  Future<String> uploadProfilePicture(XFile imageFile) async {
    try {
      // Create a reference to the file
      File file = File(imageFile.path);
      Reference ref =
          _storage.ref().child('profile_pictures').child('$_userId.jpg');

      // Upload the file
      UploadTask uploadTask = ref.putFile(file);

      // Get the download URL
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // --- UPDATE USER PROFILE DATA ---
  Future<void> updateProfileData({
    required String fullName,
    String? phoneNumber,
    String? address,
    String? photoUrl,
  }) async {
    try {
      Map<String, dynamic> dataToUpdate = {
        'displayName': fullName,
        'phone': phoneNumber,
        'address': address,
      };

      // Only add photoUrl to the map if it's not null
      // This prevents overwriting an existing photo with null
      if (photoUrl != null) {
        dataToUpdate['photoUrl'] = photoUrl;
      }

      // Update the user's document in Firestore
      await _firestore.collection('users').doc(_userId).update(dataToUpdate);

      // Also update the user's profile in Firebase Auth
      await _auth.currentUser?.updateDisplayName(fullName);
      if (photoUrl != null) {
        await _auth.currentUser?.updatePhotoURL(photoUrl);
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // --- PICK IMAGE FROM GALLERY ---
  Future<XFile?> pickImage() async {
    return await _picker.pickImage(source: ImageSource.gallery);
  }
}
