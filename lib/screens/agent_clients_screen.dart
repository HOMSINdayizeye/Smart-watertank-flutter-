import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AgentClientsScreen extends StatefulWidget {
  const AgentClientsScreen({super.key});

  @override
  State<AgentClientsScreen> createState() => _AgentClientsScreenState();
}

class _AgentClientsScreenState extends State<AgentClientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<QueryDocumentSnapshot>> _filterClients(List<QueryDocumentSnapshot> docs, String currentUserId) async {
    final List<QueryDocumentSnapshot> filtered = [];
    
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final createdBy = data['createdBy'] as String?;
      
      if (createdBy == null) continue;
      if (createdBy == currentUserId) {
        filtered.add(doc);
      }
    }
    
    return filtered;
  }

  Future<void> _deleteNotification(String notificationId) async {
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

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text('Not authenticated'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Clients'),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('recipientId', isEqualTo: currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () => _showNotificationsDialog(context, currentUser.uid),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
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
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (value == _sortBy) {
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
                value: 'createdAt',
                child: Text('Sort by Date'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search clients',
                prefixIcon: const Icon(Icons.search),
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'client')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return FutureBuilder<List<QueryDocumentSnapshot>>(
                  future: _filterClients(snapshot.data!.docs, currentUser.uid),
                  builder: (context, filteredSnapshot) {
                    if (!filteredSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var clients = filteredSnapshot.data!;

                    // Apply search filter
                    if (_searchQuery.isNotEmpty) {
                      final query = _searchQuery.toLowerCase();
                      clients = clients.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['fullName'] as String).toLowerCase();
                        final email = (data['email'] as String).toLowerCase();
                        return name.contains(query) || email.contains(query);
                      }).toList();
                    }

                    // Apply sorting
                    clients.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;

                      if (_sortBy == 'name') {
                        return _sortAscending
                            ? (aData['fullName'] as String)
                                .compareTo(bData['fullName'] as String)
                            : (bData['fullName'] as String)
                                .compareTo(aData['fullName'] as String);
                      } else if (_sortBy == 'email') {
                        return _sortAscending
                            ? (aData['email'] as String)
                                .compareTo(bData['email'] as String)
                            : (bData['email'] as String)
                                .compareTo(aData['email'] as String);
                      } else {
                        // Sort by date
                        final aDate = (aData['createdAt'] as Timestamp).toDate();
                        final bDate = (bData['createdAt'] as Timestamp).toDate();
                        return _sortAscending
                            ? aDate.compareTo(bDate)
                            : bDate.compareTo(aDate);
                      }
                    });

                    if (clients.isEmpty) {
                      return const Center(
                        child: Text('No clients found'),
                      );
                    }

                    return ListView.builder(
                      itemCount: clients.length,
                      itemBuilder: (context, index) {
                        final doc = clients[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final createdAt =
                            (data['createdAt'] as Timestamp).toDate();

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: ListTile(
                            title: Text(data['fullName'] as String),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['email'] as String),
                                Text(
                                  'Created: ${DateFormat.yMMMd().format(createdAt)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditDialog(context, doc),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotificationsDialog(BuildContext context, String agentId) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('recipientId', isEqualTo: agentId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final notifications = snapshot.data!.docs;
                    if (notifications.isEmpty) {
                      return const Center(child: Text('No notifications'));
                    }

                    return ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        final data = notification.data() as Map<String, dynamic>;
                        final timestamp = data['createdAt'] as Timestamp?;
                        final date = timestamp?.toDate();
                        final formattedDate = date != null
                            ? DateFormat('MMM dd, yyyy HH:mm').format(date)
                            : 'Unknown date';

                        return Card(
                          child: ListTile(
                            title: Text(data['title'] ?? 'No title'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['message'] ?? 'No message'),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                _deleteNotification(notification.id);
                                // Optionally close the dialog after deletion
                                // Navigator.of(context).pop();
                              },
                            ),
                          ),
                        );
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

  Future<void> _showEditDialog(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final nameController = TextEditingController(text: data['fullName'] as String);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Client'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await doc.reference.update({
                'fullName': nameController.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameController.dispose();
  }
} 