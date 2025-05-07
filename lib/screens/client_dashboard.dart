import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({Key? key}) : super(key: key);

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Dashboard'),
        actions: [
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSendRequestDialog(),
        label: const Text('Send Request'),
        icon: const Icon(Icons.build),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Action Buttons
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
                        Expanded(
                          child: _buildQuickActionButton(
                            'Maintenance',
                            Icons.build,
                            Colors.orange,
                            () => _showRequestDialog('maintenance', 'agent'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickActionButton(
                            'Support',
                            Icons.help,
                            Colors.green,
                            () => _showRequestDialog('support', 'admin'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickActionButton(
                            'Emergency',
                            Icons.warning,
                            Colors.red,
                            () => _showEmergencyDialog(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // My Requests Section
            const Text(
              'My Requests',
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
                    child: Text('No requests sent yet'),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index].data() as Map<String, dynamic>;
                    return _buildRequestCard(notification);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Future<void> _showEmergencyDialog() async {
    final TextEditingController messageController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will send an emergency notification to both the maintenance agent and admin.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Emergency Details',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (messageController.text.isNotEmpty) {
                final notificationService = context.read<NotificationService>();
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                await notificationService.sendNotification(
                  recipientId: 'agent',
                  title: 'Emergency Alert',
                  message: messageController.text,
                  type: 'emergency',
                  data: {
                    'status': 'pending',
                    'priority': 'high',
                  },
                );
                await notificationService.sendNotification(
                  recipientId: 'admin',
                  title: 'Emergency Alert',
                  message: messageController.text,
                  type: 'emergency',
                  data: {
                    'status': 'pending',
                    'priority': 'high',
                  },
                );
                if (mounted) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Emergency alert sent successfully')),
                  );
                }
              }
            },
            child: const Text('Send Alert', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> notification) {
    final timestamp = notification['createdAt'] as Timestamp?;
    final date = timestamp?.toDate();
    final formattedDate = date != null
        ? DateFormat('MMM dd, yyyy HH:mm').format(date)
        : 'Unknown date';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          _getRequestTypeIcon(notification['type']),
          color: _getRequestTypeColor(notification['type']),
        ),
        title: Text(notification['title'] ?? 'No title'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification['message'] ?? 'No message'),
            Text(
              formattedDate,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: _getStatusIcon(notification['status']),
      ),
    );
  }

  IconData _getRequestTypeIcon(String type) {
    switch (type) {
      case 'tank_info':
        return Icons.info;
      case 'maintenance':
        return Icons.build;
      case 'support':
        return Icons.help;
      default:
        return Icons.message;
    }
  }

  Color _getRequestTypeColor(String type) {
    switch (type) {
      case 'tank_info':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      case 'support':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _getStatusIcon(String? status) {
    switch (status) {
      case 'pending':
        return const Icon(Icons.hourglass_empty, color: Colors.orange);
      case 'in_progress':
        return const Icon(Icons.sync, color: Colors.blue);
      case 'completed':
        return const Icon(Icons.check_circle, color: Colors.green);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  Future<void> _showRequestDialog(String type, String recipient) async {
    final TextEditingController messageController = TextEditingController();
    
    String getTitle() {
      switch (type) {
        case 'tank_info':
          return 'Request Tank Information';
        case 'maintenance':
          return 'Request Maintenance';
        case 'support':
          return 'Request Support';
        default:
          return 'Send Request';
      }
    }

    await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(getTitle()),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            labelText: 'Message',
            hintText: 'Enter your request details...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (messageController.text.isNotEmpty) {
                final notificationService = context.read<NotificationService>();
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                await notificationService.sendNotification(
                  recipientId: recipient,
                  title: getTitle(),
                  message: messageController.text,
                  type: type,
                  data: {
                    'status': 'pending',
                    'requestType': type,
                  },
                );

                if (mounted) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Request sent successfully')),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSendRequestDialog() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String priority = 'medium';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Tank Maintenance'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter request title',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your maintenance request',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    priority = value;
                  }
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
              if (titleController.text.isNotEmpty && descriptionController.text.isNotEmpty) {
                final notificationService = context.read<NotificationService>();
                final currentUser = context.read<AuthService>().currentUser;
                
                if (currentUser != null) {
                  // Create maintenance request
                  await notificationService.createMaintenanceRequest(
                    tankId: 'default', // You might want to let the user select a tank
                    description: descriptionController.text,
                    priority: priority,
                  );
                  
                  // Send notification to agents
                  await notificationService.sendNotification(
                    recipientId: 'agent', // This will be handled by the service to find available agents
                    title: titleController.text,
                    message: descriptionController.text,
                    type: 'maintenance_request',
                    data: {
                      'priority': priority,
                      'status': 'pending',
                      'clientId': currentUser.uid,
                      'tankId': 'default', // You might want to let the user select a tank
                    },
                  );
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Maintenance request sent successfully')),
                    );
                  }
                }
              }
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
} 