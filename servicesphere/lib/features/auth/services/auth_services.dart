import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Added for Notifications

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // --- PRIVATE HELPER: Save FCM Token ---
  // This is the "Magic" that fixes your missing fcmToken field.
  Future<void> _saveDeviceToken(String uid) async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      
      // Request permission (Required for iOS, good practice for Android)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();

        if (token != null) {
          // Save or Update the token in the 'users' collection
          await _firestore.collection('users').doc(uid).set({
            'fcmToken': token,
          }, SetOptions(merge: true));
          print("FCM Token updated for user: $uid");
        }
      }
    } catch (e) {
      print("Error saving FCM token: $e");
    }
  }

  // --- Sign In with Email ---
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save token on successful login
      if (userCredential.user != null) {
        await _saveDeviceToken(userCredential.user!.uid);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // --- Sign Up with Email ---
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user?.updateDisplayName(fullName);

      // Create the user document
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'displayName': fullName,
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'userType': 'customer',
        'location': null,
      });

      // Save token on successful registration
      await _saveDeviceToken(userCredential.user!.uid);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // --- Sign In with Google ---
  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in was cancelled.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        throw Exception("Failed to sign in with Google.");
      }

      final userDoc = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'userType': 'customer',
          'location': null,
        });
      }

      // Save token on successful Google login
      await _saveDeviceToken(user.uid);

      return userCredential;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // --- Send Password Reset Email ---
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // --- SIGN OUT ---
  Future<void> signOut() async {
    try {
      // It's good practice to clear the token on logout 
      // so the user doesn't get notifications after logging out.
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });
      }

      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("Error during sign out: $e");
      // Still attempt Firebase sign out even if Google fails
      await _auth.signOut();
    }
  }
}