import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// --- SIGN IN WITH EMAIL AND PASSWORD ---
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e));
    } catch (e) {
      throw Exception("An unexpected error occurred. Please try again.");
    }
  }

  /// --- SIGN UP WITH EMAIL AND PASSWORD ---
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;

      // Update display name in Firebase Auth
      await user.updateDisplayName(fullName);

      // Create user document in Firestore
      await _createUserDocument(
        uid: user.uid,
        email: email,
        displayName: fullName,
        photoUrl: null,
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e));
    } catch (e) {
      throw Exception("Sign-up failed. Please try again later.");
    }
  }

  /// --- SIGN IN WITH GOOGLE ---
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception("Google sign-in was cancelled.");
      }

      // Obtain Google authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      // Check if user document exists, create if new
      final userDoc = _firestore.collection('users').doc(user.uid);
      final snapshot = await userDoc.get();

      if (!snapshot.exists) {
        await _createUserDocument(
          uid: user.uid,
          email: user.email!,
          displayName: user.displayName ?? 'User',
          photoUrl: user.photoURL,
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e));
    } catch (e) {
      throw Exception("Google sign-in failed: ${e.toString()}");
    }
  }

  /// --- CREATE USER DOCUMENT IN FIRESTORE ---
  Future<void> _createUserDocument({
    required String uid,
    required String email,
    required String displayName,
    required String? photoUrl,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'userType': 'customer',
        'location': null,
      });
    } catch (e) {
      throw Exception("Failed to create user profile: ${e.toString()}");
    }
  }

  /// --- SEND PASSWORD RESET EMAIL ---
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseErrorMessage(e));
    } catch (e) {
      throw Exception("Failed to send reset email. Please try again.");
    }
  }

  /// --- GET CURRENT USER ---
  User? get currentUser => _auth.currentUser;

  /// --- GET USER STREAM ---
  Stream<User?> get userStream => _auth.userChanges();

  /// --- GET USER DOCUMENT STREAM ---
  Stream<DocumentSnapshot> getUserDocumentStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// --- UPDATE USER PROFILE ---
  Future<void> updateUserProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("No user logged in");

      // Update in Firebase Auth
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }

      // Update in Firestore
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (displayName != null) updateData['displayName'] = displayName;
      if (photoUrl != null) updateData['photoUrl'] = photoUrl;

      await _firestore.collection('users').doc(user.uid).update(updateData);
    } catch (e) {
      throw Exception("Failed to update profile: ${e.toString()}");
    }
  }

  /// --- SIGN OUT USER ---
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
      await _auth.signOut();
    } catch (e) {
      throw Exception("Sign out failed: ${e.toString()}");
    }
  }

  /// --- DELETE USER ACCOUNT ---
  Future<void> deleteUserAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("No user logged in");

      // Delete from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete from Firebase Auth
      await user.delete();
    } catch (e) {
      throw Exception("Failed to delete account: ${e.toString()}");
    }
  }

  /// --- HELPER: Convert FirebaseAuth errors to readable messages ---
  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak. Try a stronger one.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
}
