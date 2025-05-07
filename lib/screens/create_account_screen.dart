import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/permissions_service.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({Key? key}) : super(key: key);

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  String _selectedRole = 'client'; // Default to client
  bool _isLoading = false;
  String _errorMessage = '';
  String? _currentUserRole;
  bool _isAddingTankToExisting = false; // New field to track if adding tank to existing client
  String? _selectedClientId; // Store selected client's ID
  String? _selectedClientName; // Store selected client's name
  bool _addTank = false; // New field to track if adding tank to new client
  
  // Text controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  // Tank information controllers
  final TextEditingController _tankNameController = TextEditingController();
  final TextEditingController _tankCapacityController = TextEditingController();
  final TextEditingController _tankLocationController = TextEditingController();
  
  final PermissionsService _permissionsService = PermissionsService();
  bool _canManageUsers = false;
  bool _canCreateClients = false;

  @override
  void initState() {
    super.initState();
    _getCurrentUserRole();
    _checkPermissions();
  }
  
  Future<void> _checkPermissions() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final permissions = await _permissionsService.getAgentPermissions(currentUser.uid);
    if (permissions != null) {
      setState(() {
        _canManageUsers = permissions.canManageUsers;
        _canCreateClients = permissions.canCreateClients;
      });
    }
  }

  Future<void> _getCurrentUserRole() async {
    final authService = context.read<AuthService>();
    final role = await authService.getCurrentUserRole();
    setState(() {
      _currentUserRole = role;
      // Set default role based on current user's role
      if (role == 'admin') {
        _selectedRole = 'agent'; // Admin can create any type, default to agent
      } else if (role == 'agent') {
        _selectedRole = 'client'; // Agent can only create client accounts
      }
    });
  }
  
  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _tankNameController.dispose();
    _tankCapacityController.dispose();
    _tankLocationController.dispose();
    super.dispose();
  }

  // Get available roles based on current user's role
  List<String> _getAvailableRoles() {
    if (_currentUserRole == 'admin') {
      return ['admin', 'agent', 'client'];
    } else if (_currentUserRole == 'agent' && (_canManageUsers || _canCreateClients)) {
      return ['client'];
    }
    return [];
  }

  // Show dialog to select existing client
  Future<void> _showSelectClientDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Get the current user's role to determine which clients to show
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final userRole = userDoc.data()?['role'] as String?;

    // Query to get clients
    Query clientsQuery = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'client');

    // If agent, only show their clients
    if (userRole == 'agent') {
      clientsQuery = clientsQuery.where('createdBy', isEqualTo: currentUser.uid);
    }

    final clientsSnapshot = await clientsQuery.get();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Client'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: clientsSnapshot.docs.length,
            itemBuilder: (context, index) {
              final client = clientsSnapshot.docs[index];
              final clientData = client.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(clientData['fullName'] ?? 'Unknown'),
                subtitle: Text(clientData['email'] ?? ''),
                onTap: () {
                  setState(() {
                    _selectedClientId = client.id;
                    _selectedClientName = clientData['fullName'];
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Handle registration
  Future<void> _handleRegistration() async {
    if (_isAddingTankToExisting) {
      // Validate tank information
      if (_tankNameController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please enter tank name';
        });
        return;
      }
      if (_tankCapacityController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please enter tank capacity';
        });
        return;
      }
      if (_tankLocationController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please enter tank location';
        });
        return;
      }
      if (_selectedClientId == null) {
        setState(() {
          _errorMessage = 'Please select a client';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        // Add tank to existing client
        await FirebaseFirestore.instance.collection('tanks').add({
          'userId': _selectedClientId,
          'name': _tankNameController.text.trim(),
          'capacity': double.parse(_tankCapacityController.text.trim()),
          'location': _tankLocationController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'waterLevel': 0.0,
          'status': 'active',
        });

        if (!mounted) return;

        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Tank Added Successfully'),
            content: Text('New tank has been added to ${_selectedClientName}\'s account.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to previous screen
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } catch (e) {
        setState(() {
          _errorMessage = 'An error occurred while adding the tank. Please try again.';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      return;
    }

    // Original registration logic for new clients
    if (_fullNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your full name';
      });
      return;
    }
    
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email';
      });
      return;
    }
    
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a password';
      });
      return;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }
    
    if (_passwordController.text.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters long';
      });
      return;
    }
    
    // Validate tank information if adding tank to new client
    if (_addTank) {
      if (_tankNameController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please enter tank name';
        });
        return;
      }
      if (_tankCapacityController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please enter tank capacity';
        });
        return;
      }
      if (_tankLocationController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please enter tank location';
        });
        return;
      }
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final AuthService authService = context.read<AuthService>();
      
      final UserCredential? userCredential = await authService.registerWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        role: _selectedRole,
        fullName: _fullNameController.text.trim(),
      );
      
      if (userCredential != null && userCredential.user != null) {
        // If adding tank to new client, create tank document
        if (_addTank && _selectedRole == 'client') {
          await FirebaseFirestore.instance.collection('tanks').add({
            'userId': userCredential.user!.uid,
            'name': _tankNameController.text.trim(),
            'capacity': double.parse(_tankCapacityController.text.trim()),
            'location': _tankLocationController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'waterLevel': 0.0,
            'status': 'active',
          });
        }
        
        if (!mounted) return;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Registration Successful'),
            content: Text('Account has been created as ${_selectedRole.toUpperCase()}${_addTank ? ' with a tank' : ''}.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'weak-password') {
          _errorMessage = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = 'An account already exists for that email.';
        } else {
          _errorMessage = 'Registration error: ${e.message}';
        }
      });
    } catch (e) {
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
    if (_currentUserRole == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_currentUserRole != 'admin' && 
        (_currentUserRole != 'agent' || (!_canManageUsers && !_canCreateClients))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/create_account');//hereeeeeeeeeeeeeeeeeee
      });
      return const SizedBox.shrink();
    }

    final availableRoles = _getAvailableRoles();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle between new client and add tank to existing
            if (_selectedRole == 'client') ...[
              Row(
                children: [
                  const Text('Action:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  Switch(
                    value: _isAddingTankToExisting,
                    onChanged: (value) {
                      setState(() {
                        _isAddingTankToExisting = value;
                        if (value) {
                          _showSelectClientDialog();
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(_isAddingTankToExisting ? 'Add Tank to Existing Client' : 'Create New Client'),
                ],
              ),
              const SizedBox(height: 24),
            ],

            if (_isAddingTankToExisting) ...[
              // Show selected client info
              if (_selectedClientName != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selected Client:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(_selectedClientName!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _showSelectClientDialog,
                          child: const Text('Change Client'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              
              // Tank information fields
              const Text(
                'Tank Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tankNameController,
                decoration: const InputDecoration(
                  labelText: 'Tank Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tankCapacityController,
                decoration: const InputDecoration(
                  labelText: 'Tank Capacity (Liters)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tankLocationController,
                decoration: const InputDecoration(
                  labelText: 'Tank Location',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              // Original registration form fields
              TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              if (availableRoles.isNotEmpty) ...[
                const Text('Select Role:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...availableRoles.map((role) => RadioListTile<String>(
                  title: Text(role.toUpperCase()),
                  value: role,
                  groupValue: _selectedRole,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                      });
                    }
                  },
                )),
              ],
              
              // Add tank option for new clients
              if (_selectedRole == 'client') ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text('Add Tank:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Switch(
                      value: _addTank,
                      onChanged: (value) {
                        setState(() {
                          _addTank = value;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text('Create Tank for Client'),
                  ],
                ),
                
                if (_addTank) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Tank Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tankNameController,
                    decoration: const InputDecoration(
                      labelText: 'Tank Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tankCapacityController,
                    decoration: const InputDecoration(
                      labelText: 'Tank Capacity (Liters)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tankLocationController,
                    decoration: const InputDecoration(
                      labelText: 'Tank Location',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ],
            
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleRegistration,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(_isAddingTankToExisting ? 'Add Tank' : 'Create Account'),
            ),
          ],
        ),
      ),
    );
  }
} 