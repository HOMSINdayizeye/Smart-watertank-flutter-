import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import '../models/agent_permissions.dart';
import '../services/permissions_service.dart';
//import 'package:provider/provider.dart';
//import 'package:provider/provider.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name'; // Options: 'name', 'email', 'role'
  bool _sortAscending = true;
  final PermissionsService _permissionsService = PermissionsService();
  String _selectedRole = 'all';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filterAndSortUsers(List<QueryDocumentSnapshot> users) {
    // Filter users based on search query
    var filteredUsers = users.where((user) {
      final userData = user.data() as Map<String, dynamic>;
      final searchLower = _searchQuery.toLowerCase();
      final name = (userData['fullName'] as String? ?? '').toLowerCase();
      final email = (userData['email'] as String? ?? '').toLowerCase();
      final role = (userData['role'] as String? ?? '').toLowerCase();
      
      return name.contains(searchLower) ||
             email.contains(searchLower) ||
             role.contains(searchLower);
    }).toList();

    // Sort users
    filteredUsers.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      
      String aValue = '';
      String bValue = '';
      
      switch (_sortBy) {
        case 'name':
          aValue = aData['fullName'] as String? ?? '';
          bValue = bData['fullName'] as String? ?? '';
          break;
        case 'email':
          aValue = aData['email'] as String? ?? '';
          bValue = bData['email'] as String? ?? '';
          break;
        case 'role':
          aValue = aData['role'] as String? ?? '';
          bValue = bData['role'] as String? ?? '';
          break;
      }
      
      return _sortAscending
          ? aValue.compareTo(bValue)
          : bValue.compareTo(aValue);
    });

    return filteredUsers;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                if (_sortBy == value) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = value;
                  _sortAscending = true;
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'name',
                child: Text('Sort by Name'),
              ),
              const PopupMenuItem(
                value: 'email',
                child: Text('Sort by Email'),
              ),
              const PopupMenuItem(
                value: 'role',
                child: Text('Sort by Role'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final userRole = userData?['role'] as String?;

          if (userRole != 'admin') {
            return const Center(
              child: Text('You do not have permission to access this page'),
            );
          }

          return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text('Filter by Role: '),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _selectedRole,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'agent', child: Text('Agent')),
                        DropdownMenuItem(value: 'client', child: Text('Client')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedRole = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
                  stream: _selectedRole == 'all'
                      ? FirebaseFirestore.instance.collection('users').snapshots()
                      : FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: _selectedRole)
                          .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data?.docs ?? [];
                final filteredUsers = _filterAndSortUsers(users);

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Total Users: ${filteredUsers.length}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                                final user = filteredUsers[index].data() as Map<String, dynamic>;
                                final userId = filteredUsers[index].id;
                                final role = user['role'] as String? ?? 'unknown';
                                final fullName = user['fullName'] as String? ?? 'Unknown';
                                final email = user['email'] as String? ?? 'No email';
                                final createdAt = user['createdAt'] as Timestamp?;
                                final lastLogin = user['lastLogin'] as Timestamp?;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text(fullName),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('$email\nRole: ${role.toUpperCase()}'),
                                        if (createdAt != null)
                                          Text(
                                            'Created: ${DateFormat.yMMMd().add_jm().format(createdAt.toDate())}',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        if (lastLogin != null)
                                          Text(
                                            'Last Login: ${DateFormat.yMMMd().add_jm().format(lastLogin.toDate())}',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility),
                                          onPressed: () => _showViewUserDialog(userId, user),
                                          tooltip: 'View User',
                                        ),
                                        if (role == 'agent')
                                          IconButton(
                                            icon: const Icon(Icons.security),
                                            onPressed: () => _showPermissionsDialog(userId, fullName),
                                            tooltip: 'Manage Permissions',
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _showEditUserDialog(userId, user),
                                          tooltip: 'Edit User',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () => _showDeleteConfirmation(userId, fullName),
                                          tooltip: 'Delete User',
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (role == 'client')
                                    FutureBuilder<List<Map<String, dynamic>>>(
                                      future: _fetchUserTanks(userId),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Center(child: CircularProgressIndicator()),
                                          );
                                        }

                                        if (snapshot.hasError) {
                                          return Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              'Error loading tanks: ${snapshot.error}',
                                              style: const TextStyle(color: Colors.red),
                                            ),
                                          );
                                        }

                                        final tanks = snapshot.data ?? [];
                                        if (tanks.isEmpty) {
                                          return const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Text('No tanks found for this client'),
                                          );
                                        }

                                        return Column(
                                          children: [
                                            const Divider(),
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Text(
                                                        'Tanks',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      TextButton.icon(
                                                        icon: const Icon(Icons.add),
                                                        label: const Text('Add Tank'),
                                                        onPressed: () => _showAddTankDialog(userId),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ListView.builder(
                                                    shrinkWrap: true,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    itemCount: tanks.length,
                                                    itemBuilder: (context, index) {
                                                      final tank = tanks[index];
                                                      return Card(
                                                        margin: const EdgeInsets.only(bottom: 8),
                                                        child: ListTile(
                                                          title: Text(tank['name'] ?? 'Unnamed Tank'),
                                                          subtitle: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text('Capacity: ${tank['capacity']}L'),
                                                              Text('Location: ${tank['location']}'),
                                                            ],
                                                          ),
                                                          trailing: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              IconButton(
                                                                icon: const Icon(Icons.edit),
                                                                onPressed: () => _showEditTankDialog(tank['id'], tank),
                                                                tooltip: 'Edit Tank',
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(Icons.delete),
                                                                onPressed: () async {
                                                                  final confirm = await showDialog<bool>(
                                                                    context: context,
                                                                    builder: (context) => AlertDialog(
                                                                      title: const Text('Confirm Delete'),
                                                                      content: const Text('Are you sure you want to delete this tank?'),
                                                                      actions: [
                                                                        TextButton(
                                                                          onPressed: () => Navigator.pop(context, false),
                                                                          child: const Text('Cancel'),
                                                                        ),
                                                                        TextButton(
                                                                          onPressed: () => Navigator.pop(context, true),
                                                                          child: const Text('Delete'),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  );
                                                                  if (confirm == true) {
                                                                    await FirebaseFirestore.instance
                                                                        .collection('tanks')
                                                                        .doc(tank['id'])
                                                                        .delete();
                                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                                      const SnackBar(content: Text('Tank deleted successfully')),
                                                                    );
                                                                  }
                                                                },
                                                                tooltip: 'Delete Tank',
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
          );
        },
      ),
    );
  }

  Future<bool> _verifyEmailChange(BuildContext context, String newEmail) async {
    final TextEditingController passwordController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Verify Email Change'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please enter your admin password to verify this email change',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Admin Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        setState(() => errorMessage = 'Please enter your password');
                        return;
                      }

                      setState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      try {
                        // Get current user email
                        final currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser == null || currentUser.email == null) {
                          throw Exception('No admin user found or email is missing');
                        }

                        // Get admin credentials
                        final credential = EmailAuthProvider.credential(
                          email: currentUser.email!, // We know it's non-null here
                          password: passwordController.text,
                        );

                        // Reauthenticate
                        await currentUser.reauthenticateWithCredential(credential);
                        
                        if (mounted) {
                          Navigator.of(context).pop(true);
                        }
                      } on FirebaseAuthException catch (e) {
                        setState(() {
                          isLoading = false;
                          errorMessage = e.message ?? 'Authentication failed';
                        });
                      } catch (e) {
                        setState(() {
                          isLoading = false;
                          errorMessage = 'An error occurred: $e';
                        });
                      }
                    },
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updateEmail(newEmail);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'email': newEmail});
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Email updated successfully')),
            );
          }
          return true;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update email: $e')),
          );
        }
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> _fetchUserTanks(String userId) async {
    try {
      final tanksSnapshot = await FirebaseFirestore.instance
          .collection('tanks')
          .where('userId', isEqualTo: userId)
          .get();
      
      return tanksSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error loading tanks: $e');
      return [];
    }
  }

  Future<void> _showViewUserDialog(String userId, Map<String, dynamic> userData) async {
    final role = userData['role'] as String? ?? 'unknown';
    final fullName = userData['fullName'] as String? ?? 'Unknown';
    final email = userData['email'] as String? ?? 'No email';
    final createdAt = userData['createdAt'] as Timestamp?;
    final lastLogin = userData['lastLogin'] as Timestamp?;
    List<Map<String, dynamic>> tanks = [];
    bool isLoadingTanks = true;

    // Load tanks if user is a client
    if (role == 'client') {
      try {
        final tanksSnapshot = await FirebaseFirestore.instance
            .collection('tanks')
            .where('userId', isEqualTo: userId)
            .get();
        
        tanks = tanksSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      } catch (e) {
        debugPrint('Error loading tanks: $e');
      } finally {
        isLoadingTanks = false;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details: $fullName'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email: $email', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Role: ${role.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (createdAt != null)
                        Text('Created: ${DateFormat.yMMMd().add_jm().format(createdAt.toDate())}'),
                      if (lastLogin != null)
                        Text('Last Login: ${DateFormat.yMMMd().add_jm().format(lastLogin.toDate())}'),
                    ],
                  ),
                ),
              ),
              if (role == 'client') ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tanks',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Tank'),
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddTankDialog(userId);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isLoadingTanks)
                  const Center(child: CircularProgressIndicator())
                else if (tanks.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No tanks found for this client'),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tanks.length,
                    itemBuilder: (context, index) {
                      final tank = tanks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(tank['name'] ?? 'Unnamed Tank'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Capacity: ${tank['capacity']}L'),
                              Text('Location: ${tank['location']}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditTankDialog(tank['id'], tank);
                            },
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditUserDialog(String userId, Map<String, dynamic> userData) async {
    final nameController = TextEditingController(text: userData['fullName'] as String? ?? '');
    final emailController = TextEditingController(text: userData['email'] as String? ?? '');
    String selectedRole = userData['role'] as String? ?? 'client';
    String? errorMessage;
    bool isLoading = false;
    List<Map<String, dynamic>> tanks = [];
    bool isLoadingTanks = true;

    // Load tanks if user is a client
    if (selectedRole == 'client') {
      tanks = await _fetchUserTanks(userId);
      isLoadingTanks = false;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'agent', child: Text('Agent')),
                    DropdownMenuItem(value: 'client', child: Text('Client')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedRole = value);
                    }
                  },
                ),
                if (selectedRole == 'client') ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tanks',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Tank'),
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddTankDialog(userId);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isLoadingTanks)
                    const Center(child: CircularProgressIndicator())
                  else if (tanks.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No tanks found for this client'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tanks.length,
                      itemBuilder: (context, index) {
                        final tank = tanks[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(tank['name'] ?? 'Unnamed Tank'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Capacity: ${tank['capacity']}L'),
                                Text('Location: ${tank['location']}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showEditTankDialog(tank['id'], tank);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Confirm Delete'),
                                        content: const Text('Are you sure you want to delete this tank?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await FirebaseFirestore.instance
                                          .collection('tanks')
                                          .doc(tank['id'])
                                          .delete();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Tank deleted successfully')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) {
                        setState(() => errorMessage = 'Name cannot be empty');
                        return;
                      }

                      if (emailController.text.trim().isEmpty) {
                        setState(() => errorMessage = 'Email cannot be empty');
                        return;
                      }

                      setState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .update({
                          'fullName': nameController.text.trim(),
                          'email': emailController.text.trim(),
                          'role': selectedRole,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User updated successfully')),
                          );
                        }
                      } catch (e) {
                        setState(() {
                          errorMessage = 'Error updating user: $e';
                          isLoading = false;
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  // Show dialog to add a new tank
  Future<void> _showAddTankDialog(String userId) async {
    final tankNameController = TextEditingController();
    final tankCapacityController = TextEditingController();
    final tankLocationController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Tank'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tankNameController,
                  decoration: const InputDecoration(
                    labelText: 'Tank Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tankCapacityController,
                  decoration: const InputDecoration(
                    labelText: 'Tank Capacity (Liters)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tankLocationController,
                  decoration: const InputDecoration(
                    labelText: 'Tank Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (tankNameController.text.trim().isEmpty) {
                        setState(() => errorMessage = 'Tank name cannot be empty');
                        return;
                      }

                      if (tankCapacityController.text.trim().isEmpty) {
                        setState(() => errorMessage = 'Tank capacity cannot be empty');
                        return;
                      }

                      if (tankLocationController.text.trim().isEmpty) {
                        setState(() => errorMessage = 'Tank location cannot be empty');
                        return;
                      }

                      try {
                        setState(() => isLoading = true);
                        
                        await FirebaseFirestore.instance.collection('tanks').add({
                          'userId': userId,
                          'name': tankNameController.text.trim(),
                          'capacity': double.parse(tankCapacityController.text.trim()),
                          'location': tankLocationController.text.trim(),
                          'createdAt': FieldValue.serverTimestamp(),
                          'status': 'active',
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tank added successfully')),
                          );
                        }
                      } catch (e) {
                        setState(() {
                          errorMessage = 'Error adding tank: $e';
                          isLoading = false;
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Tank'),
            ),
          ],
        ),
      ),
    );
  }

  // Show dialog to edit an existing tank
  Future<void> _showEditTankDialog(String tankId, Map<String, dynamic> tankData) async {
    final tankNameController = TextEditingController(text: tankData['name'] as String? ?? '');
    final tankCapacityController = TextEditingController(text: (tankData['capacity'] as num?)?.toString() ?? '');
    final tankLocationController = TextEditingController(text: tankData['location'] as String? ?? '');
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Tank'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tankNameController,
                  decoration: const InputDecoration(
                    labelText: 'Tank Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tankCapacityController,
                  decoration: const InputDecoration(
                    labelText: 'Tank Capacity (Liters)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tankLocationController,
                  decoration: const InputDecoration(
                    labelText: 'Tank Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (tankNameController.text.trim().isEmpty) {
                        setState(() => errorMessage = 'Tank name cannot be empty');
                        return;
                      }

                      if (tankCapacityController.text.trim().isEmpty) {
                        setState(() => errorMessage = 'Tank capacity cannot be empty');
                        return;
                      }

                      if (tankLocationController.text.trim().isEmpty) {
                        setState(() => errorMessage = 'Tank location cannot be empty');
                        return;
                      }

                      try {
                        setState(() => isLoading = true);
                        
                        await FirebaseFirestore.instance
                            .collection('tanks')
                            .doc(tankId)
                            .update({
                          'name': tankNameController.text.trim(),
                          'capacity': double.parse(tankCapacityController.text.trim()),
                          'location': tankLocationController.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tank updated successfully')),
                          );
                        }
                      } catch (e) {
                        setState(() {
                          errorMessage = 'Error updating tank: $e';
                          isLoading = false;
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(String userId, String userName) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('User $userName deleted')),
        );
      }
    }
  }

  Future<void> _showPermissionsDialog(String agentId, String agentName) async {
    final initialPermissions = await _permissionsService.getAgentPermissions(agentId);
    if (initialPermissions == null) return;

    if (!mounted) return;

    // Create a mutable copy of permissions
    var permissions = initialPermissions;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Permissions for $agentName'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPermissionSwitch(
                  'Delete Clients',
                  permissions.canDeleteClients,
                  (value) {
                    setState(() {
                      permissions = permissions.copyWith(canDeleteClients: value);
                    });
                  },
                ),
                _buildPermissionSwitch(
                  'Edit Client Info',
                  permissions.canEditClientInfo,
                  (value) {
                    setState(() {
                      permissions = permissions.copyWith(canEditClientInfo: value);
                    });
                  },
                ),
                _buildPermissionSwitch(
                  'View Client Info',
                  permissions.canViewClientInfo,
                  (value) {
                    setState(() {
                      permissions = permissions.copyWith(canViewClientInfo: value);
                    });
                  },
                ),
                _buildPermissionSwitch(
                  'Edit Tank Info',
                  permissions.canEditTankInfo,
                  (value) {
                    setState(() {
                      permissions = permissions.copyWith(canEditTankInfo: value);
                    });
                  },
                ),
                _buildPermissionSwitch(
                  'View Notifications',
                  permissions.canViewNotifications,
                  (value) {
                    setState(() {
                      permissions = permissions.copyWith(canViewNotifications: value);
                    });
                  },
                ),
                _buildPermissionSwitch(
                  'Manage Maintenance',
                  permissions.canManageMaintenance,
                  (value) {
                    setState(() {
                      permissions = permissions.copyWith(canManageMaintenance: value);
                    });
                  },
                ),
                _buildPermissionSwitch(
                  'View Reports',
                  permissions.canViewReports,
                  (value) {
                    setState(() {
                      permissions = permissions.copyWith(canViewReports: value);
                    });
                  },
                ),
                _buildPermissionSwitch(
                  'Edit Reports',
                  permissions.canEditReports,
                  (value) {
                    setState(() {
                      permissions = permissions.copyWith(canEditReports: value);
                    });
                  },
                ),
                _buildPermissionSwitch(
                  'Manage Alerts',
                  permissions.canManageAlerts,
                  (value) {
                    setState(() {
                      permissions = permissions.copyWith(canManageAlerts: value);
                    });
                  },
                ),
                _buildPermissionSwitch(
                  'View Alerts',
                  permissions.canViewAlerts,
                  (value) {
                    setState(() {
                      permissions = permissions.copyWith(canViewAlerts: value);
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Can Manage Users'),
                  value: permissions.canManageUsers,
                  onChanged: (value) {
                    setState(() {
                      permissions = permissions.copyWith(canManageUsers: value);
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Can Create Clients'),
                  value: permissions.canCreateClients,
                  onChanged: (value) {
                    setState(() {
                      permissions = permissions.copyWith(canCreateClients: value);
                    });
                  },
                ),
                _buildPermissionSwitch(
                  'View Users',
                  permissions.canViewUsers,
                  (value) {
                    setState(() {
                      permissions = permissions.copyWith(canViewUsers: value);
                    });
                  },
                ),
                _buildPermissionSwitch(
                  'Manage Settings',
                  permissions.canManageSettings,
                  (value) {
                    setState(() {
                      permissions = permissions.copyWith(canManageSettings: value);
                    });
                  },
                ),
                _buildPermissionSwitch(
                  'View Settings',
                  permissions.canViewSettings,
                  (value) {
                    setState(() {
                      permissions = permissions.copyWith(canViewSettings: value);
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() => _isLoading = true);
                try {
                  final success = await _permissionsService.updateAgentPermissions(permissions);
                  if (success && mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Permissions updated successfully')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to update permissions')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating permissions: $e')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              },
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSwitch(String label, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
} 