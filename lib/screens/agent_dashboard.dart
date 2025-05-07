import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/permissions_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'agent_clients_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_account_screen.dart';
import 'package:badges/badges.dart' as badges;

class AgentDashboard extends StatefulWidget {
  const AgentDashboard({Key? key}) : super(key: key);

  @override
  State<AgentDashboard> createState() => _AgentDashboardState();
}

class _AgentDashboardState extends State<AgentDashboard> {
  int _totalClients = 0;
  bool _isLoading = true;
  final PermissionsService _permissionsService = PermissionsService();
  Map<String, bool> _permissions = {};
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadStatistics();
  }

  Future<void> _loadPermissions() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final permissions = await _permissionsService.getAgentPermissions(currentUser.uid);
    if (permissions == null) return;

    setState(() {
      _permissions = {
        'canDeleteClients': permissions.canDeleteClients,
        'canEditClientInfo': permissions.canEditClientInfo,
        'canViewClientInfo': permissions.canViewClientInfo,
        'canEditTankInfo': permissions.canEditTankInfo,
        'canViewNotifications': permissions.canViewNotifications,
        'canManageMaintenance': permissions.canManageMaintenance,
        'canViewReports': permissions.canViewReports,
        'canEditReports': permissions.canEditReports,
        'canManageAlerts': permissions.canManageAlerts,
        'canViewAlerts': permissions.canViewAlerts,
        'canManageUsers': permissions.canManageUsers,
        'canViewUsers': permissions.canViewUsers,
        'canManageSettings': permissions.canManageSettings,
        'canViewSettings': permissions.canViewSettings,
        'canCreateClients': permissions.canCreateClients,
      };
    });
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final clientsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'client')
            .where('createdBy', isEqualTo: currentUser.uid)
            .get();
        
        setState(() {
          _totalClients = clientsSnapshot.docs.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _deleteNotification(String notificationId) async {
    if (!(_permissions['canViewNotifications'] ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to delete notifications')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting notification: $e')),
        );
      }
    }
  }

  // Add this new method to handle Create Client navigation
  void _navigateToCreateClient() {
    if (_permissions['canCreateClients'] ?? false) {
      // Use a direct approach with MaterialPageRoute
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const CreateAccountScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to create clients'),
        ),
      );
    }
  }

  Future<void> _showSendRequestDialog() async {
    final requestTitleController = TextEditingController();
    final requestMessageController = TextEditingController();
    String selectedPriority = 'normal';
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Send Request to Admin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: requestTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Request Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: requestMessageController,
                  decoration: const InputDecoration(
                    labelText: 'Request Message',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedPriority = value);
                    }
                  },
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (requestTitleController.text.trim().isEmpty) {
                                setState(() => errorMessage = 'Title cannot be empty');
                                return;
                              }

                              if (requestMessageController.text.trim().isEmpty) {
                                setState(() => errorMessage = 'Message cannot be empty');
                                return;
                              }

                              setState(() {
                                isLoading = true;
                                errorMessage = null;
                              });

                              try {
                                final currentUser = FirebaseAuth.instance.currentUser;
                                if (currentUser == null) throw Exception('No user logged in');

                                await _notificationService.sendAgentRequest(
                                  title: requestTitleController.text.trim(),
                                  message: requestMessageController.text.trim(),
                                  agentId: currentUser.uid,
                                  priority: selectedPriority,
                                );

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Request sent successfully')),
                                  );
                                }
                              } catch (e) {
                                setState(() {
                                  errorMessage = 'Error sending request: $e';
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
                          : const Text('Send Request'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _showSendRequestDialog,
            tooltip: 'Send Request to Admin',
          ),
          if (_permissions['canViewNotifications'] ?? false)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientId', isEqualTo: currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                return badges.Badge(
                  showBadge: count > 0,
                  badgeContent: Text(
                    count.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () => _showNotificationsDialog(context),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthService>().signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              if (_permissions['canViewClientInfo'] ?? false)
                                Expanded(
                                  child: _buildQuickActionButton(
                                    'View Clients',
                                    Icons.people,
                                    Colors.blue,
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const AgentClientsScreen(),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_permissions['canCreateClients'] ?? false) ...[
                                if (_permissions['canViewClientInfo'] ?? false)
                                  const SizedBox(width: 8),
                                Expanded(
                                  child: _buildQuickActionButton(
                                    'Create Client',
                                    Icons.person_add,
                                    Colors.green,
                                    _navigateToCreateClient,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Statistics Card
                  if (_permissions['canViewClientInfo'] ?? false)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Statistics',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildStatCard(
                                  'Total Clients',
                                  _totalClients.toString(),
                                  Icons.people,
                                  Colors.blue,
                                ),
                                if (_permissions['canViewNotifications'] ?? false) ...[
                                  const SizedBox(width: 16),
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('notifications')
                                        .where('recipientId', isEqualTo: currentUser?.uid)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      return _buildStatCard(
                                        'Notifications',
                                        (snapshot.data?.docs.length ?? 0).toString(),
                                        Icons.notifications,
                                        Colors.orange,
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Recent Notifications
                  if (_permissions['canViewNotifications'] ?? false) ...[
                    const Text(
                      'Recent Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('notifications')
                          .where('recipientId', isEqualTo: currentUser?.uid)
                          .orderBy('createdAt', descending: true)
                          .limit(5)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final notifications = snapshot.data?.docs ?? [];
                        if (notifications.isEmpty) {
                          return const Center(
                            child: Text('No notifications yet'),
                          );
                        }
                        
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notification = notifications[index].data() as Map<String, dynamic>;
                            return _buildNotificationCard(notification, notifications[index].id);
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, String notificationId) {
    final title = notification['title'] as String? ?? 'No Title';
    final message = notification['message'] as String? ?? 'No Message';
    final createdAt = notification['createdAt'] as Timestamp?;
    final type = notification['type'] as String? ?? 'info';

    Color getTypeColor() {
      switch (type) {
        case 'emergency':
          return Colors.red;
        case 'warning':
          return Colors.orange;
        case 'success':
          return Colors.green;
        default:
          return Colors.blue;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: getTypeColor(),
          child: const Icon(Icons.notifications, color: Colors.white),
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (createdAt != null)
              Text(
                DateFormat.yMMMd().add_jm().format(createdAt.toDate()),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _deleteNotification(notificationId),
        ),
      ),
    );
  }

  Future<void> _showNotificationsDialog(BuildContext context) async {
    if (!(_permissions['canViewNotifications'] ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to view notifications')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('recipientId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final notifications = snapshot.data?.docs ?? [];
              if (notifications.isEmpty) {
                return const Center(
                  child: Text('No notifications yet'),
                );
              }
              
              return ListView.builder(
                shrinkWrap: true,
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index].data() as Map<String, dynamic>;
                  return _buildNotificationCard(notification, notifications[index].id);
                },
              );
            },
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
} 