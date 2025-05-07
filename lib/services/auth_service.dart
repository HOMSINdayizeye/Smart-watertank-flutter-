import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to track authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      debugPrint('Attempting to sign in with email: $email');
      
      if (email.isEmpty || password.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-input',
          message: 'Email and password cannot be empty',
        );
      }

      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      
      debugPrint('Successfully signed in user: ${userCredential.user?.uid}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Exception during sign in: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during sign in: $e');
      rethrow;
    }
  }

  // Register new user with email and password
  Future<UserCredential?> registerWithEmailAndPassword(
    String email,
    String password, {
    required String role,
    required String fullName,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': email,
          'role': role,
          'fullName': fullName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdBy': currentUser?.uid ?? 'system',
        });
      }

      return userCredential;
    } catch (e) {
      debugPrint('Error registering user: $e');
      rethrow;
    }
  }
  
  // Get user details from Firestore
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      debugPrint('Fetching user details for user: $userId');
      final DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists) {
        final userData = doc.data() as Map<String, dynamic>;
        debugPrint('Found user details: $userData');
        return userData;
      } else {
        debugPrint('No user details found for user: $userId');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting user details: $e');
      return null;
    }
  }
  
  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      debugPrint('Updating user profile for user: $userId');
      await _firestore.collection('users').doc(userId).update(data);
      debugPrint('Successfully updated user profile');
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      debugPrint('Attempting to sign out user');
      await _auth.signOut();
      debugPrint('Successfully signed out user');
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }
  
  // Password reset
  Future<void> resetPassword(String email) async {
    try {
      debugPrint('Attempting to reset password for email: $email');
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('Successfully sent password reset email');
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    }
  }

  // Get current user's role
  Future<String?> getCurrentUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      return doc.data()?['role'] as String?;
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return null;
    }
  }
} 