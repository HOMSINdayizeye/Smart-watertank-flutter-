import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../screens/user_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _totalUsers = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    final notificationService = context.read<NotificationService>();
    setState(() => _isLoading = true);
    
    try {
      _totalUsers = await notificationService.getTotalUsers();
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => Navigator.pushNamed(context, '/create'),
            tooltip: 'Create Account',
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserManagementScreen(),
                ),
              );
            },
            tooltip: 'User Management',
          ),
          StreamBuilder<QuerySnapshot>(
            stream: context.read<NotificationService>().getNotifications(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () => _showNotificationsDialog(),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 20,// added width ##############
                        height: 20,// added height ################
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
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
                  // Statistics Cards
                  Row(
                    children: [
                      _buildStatCard(
                        'Total Users',
                        _totalUsers.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: context.read<NotificationService>().getNotifications(),
                        builder: (context, snapshot) {
                          final alertCount = snapshot.data?.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final type = data['type'] as String? ?? '';
                            return type == 'emergency' || 
                                   type == 'water_quality_alert' || 
                                   type == 'water_level_alert' || 
                                   type == 'maintenance_alert';
                          }).length ?? 0;
                          
                          return _buildStatCard(
                            'Total Alerts',
                            alertCount.toString(),
                            Icons.warning,
                            Colors.orange,
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: context.read<NotificationService>().getMaintenanceRequests(),
                        builder: (context, snapshot) {
                          final requestCount = snapshot.data?.docs.length ?? 0;
                          
                          return _buildStatCard(
                            'Maintenance Requests',
                            requestCount.toString(),
                            Icons.build,
                            Colors.green,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Notifications Section
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: context.read<NotificationService>().getNotifications(),
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
                  
                  const SizedBox(height: 24),
                  
                  // Maintenance Requests Section
                  const Text(
                    'Maintenance Requests',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: context.read<NotificationService>().getMaintenanceRequests(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final requests = snapshot.data?.docs ?? [];
                      if (requests.isEmpty) {
                        return const Center(
                          child: Text('No maintenance requests yet'),
                        );
                      }
                      
                      // Sort the requests by createdAt timestamp and filter if needed
                      final sortedRequests = requests.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return {
                          'id': doc.id,
                          ...data,
                        };
                      }).where((request) {
                        // Add any filtering logic here if needed
                        return true; // Show all requests for admin
                      }).toList()
                        ..sort((a, b) {
                          final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                          final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
                          return bTime.compareTo(aTime); // Sort in descending order
                        });
                      
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedRequests.length,
                        itemBuilder: (context, index) {
                          final request = sortedRequests[index];
                          return _buildMaintenanceRequestCard(request['id'] as String, request);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, String notificationId) {
    final timestamp = notification['createdAt'] as Timestamp?;
    final date = timestamp?.toDate();
    final formattedDate = date != null
        ? DateFormat('MMM dd, yyyy HH:mm').format(date)
        : 'Unknown date';

    final isUnread = notification['status'] == 'unread';
    final type = notification['type'] as String? ?? 'general';
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final priority = data['priority'] as String? ?? 'medium';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isUnread ? Colors.blue.shade50 : null,
      child: ListTile(
        leading: Stack(
          children: [
            Icon(
              _getNotificationTypeIcon(type),
              color: _getNotificationTypeColor(type),
            ),
            if (priority == 'high')
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 20,   //added width @##########
                  height: 20, //added height @############
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 8,
                    minHeight: 8,
                  ),
                ),
              ),
          ],
        ),
        title: Text(notification['title'] ?? 'No title'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification['message'] ?? 'No message'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (priority != 'medium') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(priority),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUnread)
              IconButton(
                icon: const Icon(Icons.mark_email_read),
                onPressed: () => _markAsRead(notificationId),
                tooltip: 'Mark as Read',
              ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteNotification(notificationId),
              tooltip: 'Delete Notification',
            ),
          ],
        ),
        onTap: () => _showNotificationDetails(notificationId),
      ),
    );
  }

  Widget _buildMaintenanceRequestCard(String id, Map<String, dynamic> request) {
    final timestamp = request['createdAt'] as Timestamp?;
    final date = timestamp?.toDate();
    final formattedDate = date != null
        ? DateFormat('MMM dd, yyyy HH:mm').format(date)
        : 'Unknown date';

    final status = request['status'] as String? ?? 'pending';
    final description = request['description'] as String? ?? 'No description';
    final priority = (request['priority'] as String? ?? 'medium').toLowerCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          _getPriorityIcon(priority),
          color: _getPriorityColor(priority),
        ),
        title: Text(description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${status.toUpperCase()}'),
            Text(
              formattedDate,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              onSelected: (value) {
                _handleMaintenanceRequestAction(id, value);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'assign',
                  child: Text('Assign to Team'),
                ),
                const PopupMenuItem(
                  value: 'complete',
                  child: Text('Mark as Completed'),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteMaintenanceRequest(id, description),
              tooltip: 'Delete Request',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNotificationsDialog() async {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => Dialog(
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.8,
          height: MediaQuery.of(dialogContext).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: Provider.of<NotificationService>(dialogContext, listen: false).getNotifications(),
                  builder: (BuildContext streamContext, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final notifications = snapshot.data?.docs ?? [];
                    if (notifications.isEmpty) {
                      return const Center(
                        child: Text('No notifications yet'),
                      );
                    }

                    return ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (BuildContext listContext, int index) {
                        final notification = notifications[index].data() as Map<String, dynamic>;
                        return _buildNotificationCard(notification, notifications[index].id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNotificationDetails(String notificationId) async {
    final notificationService = context.read<NotificationService>();
    
    // Show loading dialog while fetching details
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      final notification = await notificationService.getNotificationDetails(notificationId);
      
      // Remove loading dialog
      if (mounted) Navigator.pop(context);
      
      if (notification != null && mounted) {
        final data = notification['data'] as Map<String, dynamic>? ?? {};
        final priority = data['priority'] as String? ?? 'medium';
        final status = data['status'] as String? ?? 'pending';
        final agentId = data['agentId'] as String?;
        
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(notification['title'] ?? 'Notification Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['message'] ?? 'No message',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Type: ${notification['type']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Priority: ${priority.toUpperCase()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getPriorityColor(priority),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: ${status.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (agentId != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'From Agent ID: $agentId',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (notification['createdAt'] != null)
                    Text(
                      'Received: ${DateFormat('MMM dd, yyyy HH:mm').format(
                        (notification['createdAt'] as Timestamp).toDate(),
                      )}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
            actions: [
              if (notification['status'] == 'unread')
                TextButton(
                  onPressed: () {
                    _markAsRead(notificationId);
                    Navigator.pop(context);
                  },
                  child: const Text('Mark as Read'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Remove loading dialog if there's an error
      if (mounted) Navigator.pop(context);
      
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to load notification details: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    final notificationService = context.read<NotificationService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await notificationService.deleteNotification(notificationId);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Notification deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error deleting notification: $e')),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    final notificationService = context.read<NotificationService>();
    try {
      await notificationService.markAsRead(notificationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking notification as read: $e')),
        );
      }
    }
  }

  IconData _getNotificationTypeIcon(String type) {
    switch (type) {
      case 'maintenance':
        return Icons.build;
      case 'alert':
        return Icons.warning;
      case 'support':
        return Icons.help;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationTypeColor(String type) {
    switch (type) {
      case 'maintenance':
        return Colors.orange;
      case 'alert':
        return Colors.red;
      case 'support':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Icons.error;
      case 'medium':
        return Icons.warning;
      case 'low':
        return Icons.info;
      default:
        return Icons.help;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleMaintenanceRequestAction(String requestId, String action) async {
    final notificationService = context.read<NotificationService>();
    
    switch (action) {
      case 'assign':
        // Show dialog to select maintenance team member
        final result = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Assign to Team Member'),
            content: const Text('Select a maintenance team member to assign this request to.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'team_member_id'),
                child: const Text('Assign'),
              ),
            ],
          ),
        );
        
        if (result != null) {
          await notificationService.updateMaintenanceRequestStatus(
            requestId,
            'in_progress',
            result,
          );
        }
        break;
        
      case 'complete':
        await notificationService.updateMaintenanceRequestStatus(
          requestId,
          'completed',
          null,
        );
        break;
    }
  }

  Future<void> _deleteMaintenanceRequest(String requestId, String description) async {
    final notificationService = context.read<NotificationService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this maintenance request?\n\n"$description"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await notificationService.deleteMaintenanceRequest(requestId);
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Maintenance request deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error deleting maintenance request: $e')),
          );
        }
      }
    }
  }
} 