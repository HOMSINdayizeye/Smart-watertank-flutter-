import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collection = 'notifications';
  final String _maintenanceCollection = 'maintenance_requests';
  
  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Initialize notification services
  Future<void> initialize() async {
    try {
      // Request permission for iOS and web
      await _requestPermission();
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Handle notifications when app is in background or terminated
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Handle notifications when app is in foreground
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle when notification is tapped and app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      
      debugPrint('Notification service initialized');
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }
  
  // Request notification permission
  Future<void> _requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    debugPrint('User notification permission status: ${settings.authorizationStatus}');
  }
  
  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('Local notification tapped: ${details.payload}');
        // Handle notification tap
      },
    );
  }
  
  // Get FCM token for the current device
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
  
  // Save token to Firestore for a specific user
  Future<void> saveToken(String userId, String token) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    });
  }
  
  // Subscribe to topics (like specific tank IDs or roles)
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }
  
  // Unsubscribe from topics
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
  
  // Save notification to Firestore
  Future<void> saveNotification(Map<String, dynamic> notificationData) async {
    await _firestore.collection(_collection).add({
      ...notificationData,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }
  
  // Get unread notifications count for a user
  Stream<int> getUnreadCount() {
    return _firestore
        .collection('notifications')
        .where('status', isEqualTo: 'unread')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  
  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Get all notifications for a user
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
  
  // Send water quality alert
  Future<void> sendWaterQualityAlert({
    required String tankId,
    required String tankName,
    required String userId,
    required Map<String, dynamic> qualityData,
    String? customMessage,
  }) async {
    try {
      // Create notification data
      final Map<String, dynamic> notificationData = {
        'type': 'water_quality_alert',
        'tankId': tankId,
        'tankName': tankName,
        'userId': userId,
        'qualityData': qualityData,
        'message': customMessage ?? 'Water quality alert for $tankName',
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      // Save notification to database
      await saveNotification(notificationData);
      
      // This would typically be handled by a Cloud Function that sends
      // the FCM message to the user's device
      debugPrint('Quality alert saved to database, Cloud Function should handle FCM sending');
    } catch (e) {
      debugPrint('Error sending water quality alert: $e');
    }
  }
  
  // Send water level alert
  Future<void> sendWaterLevelAlert({
    required String tankId,
    required String tankName, 
    required String userId,
    required double currentLevel,
    required double thresholdLevel,
    bool isLow = true,
    String? customMessage,
  }) async {
    try {
      // Create notification data
      final Map<String, dynamic> notificationData = {
        'type': 'water_level_alert',
        'tankId': tankId,
        'tankName': tankName,
        'userId': userId,
        'currentLevel': currentLevel,
        'thresholdLevel': thresholdLevel,
        'isLow': isLow,
        'message': customMessage ?? 
          '${isLow ? "Low" : "High"} water level alert for $tankName',
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      // Save notification to database
      await saveNotification(notificationData);
      
      // This would typically be handled by a Cloud Function
      debugPrint('Level alert saved to database, Cloud Function should handle FCM sending');
    } catch (e) {
      debugPrint('Error sending water level alert: $e');
    }
  }
  
  // Send maintenance alert
  Future<void> sendMaintenanceAlert({
    required String tankId,
    required String tankName,
    required String userId,
    required String maintenanceType,
    required DateTime scheduledDate,
    String? customMessage,
  }) async {
    try {
      // Create notification data
      final Map<String, dynamic> notificationData = {
        'type': 'maintenance_alert',
        'tankId': tankId,
        'tankName': tankName,
        'userId': userId,
        'maintenanceType': maintenanceType,
        'scheduledDate': scheduledDate,
        'message': customMessage ?? 'Maintenance scheduled for $tankName',
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      // Save notification to database
      await saveNotification(notificationData);
      
      // This would typically be handled by a Cloud Function
      debugPrint('Maintenance alert saved to database, Cloud Function should handle FCM sending');
    } catch (e) {
      debugPrint('Error sending maintenance alert: $e');
    }
  }

  // Add this new method to get admin ID
  Future<String?> getAdminId() async {
    try {
      final QuerySnapshot adminQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        return adminQuery.docs.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting admin ID: $e');
      return null;
    }
  }

  // Add this new method to get available agents
  Future<List<String>> getAvailableAgentIds() async {
    try {
      final QuerySnapshot agentQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'agent')
          .get();

      return agentQuery.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('Error getting available agents: $e');
      return [];
    }
  }

  // Modify the sendNotification method
  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Handle special recipient IDs
      List<String> recipientIds = [];
      if (recipientId == 'admin') {
        final adminId = await getAdminId();
        if (adminId == null) throw Exception('Admin not found');
        recipientIds = [adminId];
      } else if (recipientId == 'agent') {
        recipientIds = await getAvailableAgentIds();
        if (recipientIds.isEmpty) throw Exception('No agents available');
      } else {
        recipientIds = [recipientId];
      }

      // Send notification to all recipients
      for (final id in recipientIds) {
        await _firestore.collection(_collection).add({
          'senderId': user.uid,
          'recipientId': id,
          'title': title,
          'message': message,
          'type': type,
          'data': data ?? {},
          'status': 'unread',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
      rethrow;
    }
  }

  // Get notifications for the current user
  Stream<QuerySnapshot> getNotifications() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.empty();
    }

    return _firestore
        .collection(_collection)
        .where('recipientId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get maintenance requests stream
  Stream<QuerySnapshot> getMaintenanceRequests() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.empty();
    }

    return _firestore
        .collection(_maintenanceCollection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'status': 'read',
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  // Update maintenance request status
  Future<void> updateMaintenanceRequestStatus(
    String requestId,
    String status,
    String? assignedTo,
  ) async {
    try {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (assignedTo != null) {
        updateData['assignedTo'] = assignedTo;
      }

      await _firestore.collection(_collection).doc(requestId).update(updateData);
    } catch (e) {
      debugPrint('Error updating maintenance request status: $e');
      rethrow;
    }
  }

  // Get notification details
  Future<Map<String, dynamic>?> getNotificationDetails(String notificationId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(notificationId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting notification details: $e');
      return null;
    }
  }

  // Create maintenance request
  Future<void> createMaintenanceRequest({
    required String tankId,
    required String description,
    required String priority,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection(_maintenanceCollection).add({
        'tankId': tankId,
        'description': description,
        'priority': priority,
        'status': 'pending',
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating maintenance request: $e');
      rethrow;
    }
  }

  // Get maintenance requests by status
  Stream<QuerySnapshot> getMaintenanceRequestsByStatus(String status) {
    return _firestore
        .collection(_maintenanceCollection)
        .where('status', isEqualTo: status)
        .snapshots();
  }

  // Get maintenance requests by priority
  Stream<QuerySnapshot> getMaintenanceRequestsByPriority(String priority) {
    return _firestore
        .collection(_maintenanceCollection)
        .where('priority', isEqualTo: priority)
        .snapshots();
  }

  // Get total users count
  Future<int> getTotalUsers() async {
    final QuerySnapshot usersSnapshot = await _firestore
        .collection('users')
        .get();
    return usersSnapshot.docs.length;
  }

  // Get total alerts count
  Future<int> getTotalAlerts() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final QuerySnapshot alertsSnapshot = await _firestore
        .collection(_collection)
        .where('recipientId', isEqualTo: user.uid)
        .where('type', whereIn: ['emergency', 'water_quality_alert', 'water_level_alert', 'maintenance_alert'])
        .get();

    return alertsSnapshot.docs.length;
  }

  // Get total maintenance requests count
  Future<int> getTotalMaintenanceRequests() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final QuerySnapshot requestsSnapshot = await _firestore
        .collection(_maintenanceCollection)
        .where('recipientId', isEqualTo: user.uid)
        .get();
    return requestsSnapshot.docs.length;
  }

  // Add this method to get notifications for agents
  Stream<QuerySnapshot> getAgentNotifications() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    return _firestore
        .collection(_collection)
        .where('recipientId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'maintenance_request')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Delete maintenance request
  Future<void> deleteMaintenanceRequest(String requestId) async {
    try {
      await _firestore.collection(_maintenanceCollection).doc(requestId).delete();
    } catch (e) {
      debugPrint('Error deleting maintenance request: $e');
      rethrow;
    }
  }

  // Get clients created by specific agent
  Stream<QuerySnapshot> getAgentClients(String agentId) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'client')
        .where('createdBy', isEqualTo: agentId)
        .snapshots();
  }

  // Get clients created by admins
  Stream<QuerySnapshot> getAdminClients() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'client')
        .where('createdBy', whereIn: ['admin'])
        .snapshots();
  }

  // Send agent request to admin
  Future<void> sendAgentRequest({
    required String title,
    required String message,
    required String agentId,
    String? priority = 'normal',
  }) async {
    try {
      // Get all admin users
      final adminSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      if (adminSnapshot.docs.isEmpty) {
        throw Exception('No admin users found');
      }

      // Get agent details
      final agentDoc = await _firestore.collection('users').doc(agentId).get();
      final agentData = agentDoc.data();
      if (agentData == null) {
        throw Exception('Agent data not found');
      }

      // Create the request
      final requestData = {
        'title': title,
        'message': message,
        'type': 'agent_request',
        'status': 'pending',
        'priority': priority,
        'senderId': agentId,
        'senderName': agentData['fullName'] ?? 'Unknown Agent',
        'senderRole': 'agent',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      };

      // Send notification to all admins
      for (var adminDoc in adminSnapshot.docs) {
        await _firestore.collection(_collection).add({
          ...requestData,
          'recipientId': adminDoc.id,
        });
      }

      debugPrint('Agent request sent successfully to ${adminSnapshot.docs.length} admin(s)');
    } catch (e) {
      debugPrint('Error sending agent request: $e');
      rethrow;
    }
  }
}

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
  // Here you could save the notification to local storage or database
  // when the app is not running
}

// Handle foreground messages
void _handleForegroundMessage(RemoteMessage message) {
  debugPrint('Got a message whilst in the foreground!');
  debugPrint('Message data: ${message.data}');

  if (message.notification != null) {
    debugPrint('Message also contained a notification: ${message.notification}');
    
    // Show local notification
    _showLocalNotification(
      title: message.notification?.title ?? 'New notification',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
    );
  }
}

// Handle notification tap when app is in background
void _handleNotificationTap(RemoteMessage message) {
  debugPrint('Notification tapped!');
  
  // Here you would typically navigate to the relevant screen
  // based on the notification data
}

// Show a local notification
Future<void> _showLocalNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'water_tank_channel',
    'Water Tank Notifications',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
  );
  
  const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
      
  await flutterLocalNotificationsPlugin.show(
    0, // Notification ID
    title,
    body,
    platformDetails,
    payload: payload,
  );
} 