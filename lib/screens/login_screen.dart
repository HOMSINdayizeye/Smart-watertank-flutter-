import 'package:flutter/material.dart';
import '../utils/image_placeholders.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _selectedRole = 'admin'; // Default role
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Text controllers for email/password fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Handle login
  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Email and password cannot be empty';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      debugPrint('Starting login process for role: $_selectedRole');
      final AuthService authService = context.read<AuthService>();
      
      // Attempt to sign in with email and password
      final UserCredential? userCredential = await authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      if (userCredential != null && userCredential.user != null) {
        debugPrint('User authenticated, fetching user details');
        // Get user details from Firestore
        final userData = await authService.getUserDetails(userCredential.user!.uid);
        
        if (userData != null) {
          debugPrint('User data retrieved: $userData');
          // Check if user role matches selected role
          final String userRole = userData['role'] as String? ?? '';
          debugPrint('User role: $userRole, Selected role: $_selectedRole');
          
          if (userRole == _selectedRole) {
            debugPrint('Role match, navigating to dashboard');
            // Navigate based on role
            if (!mounted) return;
            
            String route = '';
            switch (_selectedRole) {
              case 'admin':
                route = '/admin_dashboard';
                break;
              case 'agent':
                route = '/agent_dashboard';
                break;
              case 'client':
                route = '/client_dashboard';
                break;
            }
            
            if (route.isNotEmpty) {
              debugPrint('Navigating to route: $route');
              Navigator.of(context).pushReplacementNamed(route);
            }
          } else {
            debugPrint('Role mismatch error');
            setState(() {
              _errorMessage = 'Invalid role selection. Please select the correct role for your account.';
            });
            
            // Sign out since role doesn't match
            await authService.signOut();
          }
        } else {
          debugPrint('No user data found');
          setState(() {
            _errorMessage = 'User data not found. Please contact support.';
          });
          
          // Sign out since we couldn't get user data
          await authService.signOut();
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Exception: ${e.code} - ${e.message}');
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = 'No user found with this email.';
            break;
          case 'wrong-password':
            _errorMessage = 'Wrong password provided.';
            break;
          case 'invalid-email':
            _errorMessage = 'Invalid email address.';
            break;
          case 'user-disabled':
            _errorMessage = 'This account has been disabled.';
            break;
          default:
            _errorMessage = e.message ?? 'An error occurred during login.';
        }
      });
    } catch (e) {
      debugPrint('General error during login: $e');
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.blue, width: 2),
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
              ),
              child: const Text(
                'welcome to smart water tank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 100,
                          width: 100,
                          child: ImagePlaceholders.waterDrop(),
                        ),
                        const SizedBox(height: 20),
                        
                        // Login as text
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'LOGIN AS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Email field
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // Password field
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                          ),
                          obscureText: true,
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Role selection
                        const Text(
                          'Select Your Role:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        
                        // Radio buttons for role selection
                        _buildRadioButton('ADMIN', _selectedRole == 'admin', (value) {
                          setState(() {
                            _selectedRole = 'admin';
                          });
                        }),
                        const SizedBox(height: 10),
                        _buildRadioButton('AGENTS', _selectedRole == 'agent', (value) {
                          setState(() {
                            _selectedRole = 'agent';
                          });
                        }),
                        const SizedBox(height: 10),
                        _buildRadioButton('CLIENTS', _selectedRole == 'client', (value) {
                          setState(() {
                            _selectedRole = 'client';
                          });
                        }),
                        
                        // Error message
                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 15),
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        
                        const SizedBox(height: 20),
                        
                        // Login button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // Create account link
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/login');
                          },
                          child: const Text(
                            'Don\'t have an account? ',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRadioButton(String label, bool isSelected, Function(bool?) onChanged) {
    return InkWell(
      onTap: () => onChanged(true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<bool>(
            value: true,
            groupValue: isSelected,
            onChanged: onChanged,
            activeColor: Colors.blue,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.blue : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
} 