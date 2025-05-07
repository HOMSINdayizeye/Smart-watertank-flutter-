import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TankService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collection = 'tanks';

  // Get all tanks for the current user
  Stream<QuerySnapshot> getTanks() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    return _firestore
        .collection('tanks')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  // Add a new tank
  Future<void> addTank({
    required String name,
    required double capacity,
    required String location,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore.collection('tanks').add({
      'name': name,
      'capacity': capacity,
      'location': location,
      'userId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Update tank information
  Future<void> updateTank(String tankId, Map<String, dynamic> data) async {
    await _firestore.collection('tanks').doc(tankId).update(data);
  }

  // Add water level measurement
  Future<void> addWaterLevel(String tankId, double level, DateTime timestamp) async {
    await _firestore
        .collection('tanks')
        .doc(tankId)
        .collection('waterLevels')
        .add({
      'level': level,
      'timestamp': timestamp,
    });
  }

  // Add water quality measurement
  Future<void> addWaterQuality(
    String tankId,
    double ph,
    double turbidity,
    double temperature,
    DateTime timestamp,
  ) async {
    await _firestore
        .collection('tanks')
        .doc(tankId)
        .collection('waterQuality')
        .add({
      'ph': ph,
      'turbidity': turbidity,
      'temperature': temperature,
      'timestamp': timestamp,
    });
  }

  // Get water level history
  Stream<QuerySnapshot> getWaterLevelHistory(String tankId) {
    return _firestore
        .collection('tanks')
        .doc(tankId)
        .collection('waterLevels')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get water quality history
  Stream<QuerySnapshot> getWaterQualityHistory(String tankId) {
    return _firestore
        .collection('tanks')
        .doc(tankId)
        .collection('waterQuality')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Create a new tank
  Future<DocumentReference> createTank(Map<String, dynamic> tankData) async {
    try {
      return await _firestore.collection(_collection).add({
        ...tankData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating tank: $e');
      rethrow;
    }
  }

  // Get a specific tank by ID
  Future<Map<String, dynamic>?> getTank(String tankId) async {
    try {
      final DocumentSnapshot doc = await _firestore.collection(_collection).doc(tankId).get();
      return doc.exists ? doc.data() as Map<String, dynamic> : null;
    } catch (e) {
      debugPrint('Error getting tank: $e');
      return null;
    }
  }

  // Delete a tank
  Future<void> deleteTank(String tankId) async {
    try {
      await _firestore.collection(_collection).doc(tankId).delete();
    } catch (e) {
      debugPrint('Error deleting tank: $e');
      rethrow;
    }
  }

  // Get all tanks
  Stream<QuerySnapshot> getAllTanks() {
    return _firestore.collection(_collection).orderBy('createdAt', descending: true).snapshots();
  }

  // Get tanks by client ID
  Stream<QuerySnapshot> getTanksByClient(String clientId) {
    return _firestore
        .collection(_collection)
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get tanks by agent ID
  Stream<QuerySnapshot> getTanksByAgent(String agentId) {
    return _firestore
        .collection(_collection)
        .where('agentId', isEqualTo: agentId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get tanks with alerts/warnings
  Stream<QuerySnapshot> getTanksWithAlerts() {
    return _firestore
        .collection(_collection)
        .where('hasAlert', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }
  
  // Update tank water level
  Future<void> updateWaterLevel(String tankId, double currentLevel, DateTime timestamp) async {
    try {
      // Create a new water level record in the tankLevels subcollection
      await _firestore.collection(_collection).doc(tankId).collection('waterLevels').add({
        'level': currentLevel,
        'timestamp': timestamp,
      });
      
      // Update the main tank document with the current level
      await _firestore.collection(_collection).doc(tankId).update({
        'currentLevel': currentLevel,
        'lastUpdated': timestamp,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating water level: $e');
      rethrow;
    }
  }
  
  // Update tank water quality
  Future<void> updateWaterQuality(String tankId, Map<String, dynamic> qualityData) async {
    try {
      // Create a new water quality record in the waterQuality subcollection
      await _firestore.collection(_collection).doc(tankId).collection('waterQuality').add({
        ...qualityData,
        'timestamp': DateTime.now(),
      });
      
      // Update the main tank document with the latest quality data
      await _firestore.collection(_collection).doc(tankId).update({
        'currentQuality': qualityData,
        'qualityUpdated': DateTime.now(),
        'updatedAt': FieldValue.serverTimestamp(),
        
        // Determine if there are any quality alerts based on parameters
        'hasQualityAlert': _checkQualityAlert(qualityData),
      });
    } catch (e) {
      debugPrint('Error updating water quality: $e');
      rethrow;
    }
  }
  
  // Check if quality parameters trigger an alert
  bool _checkQualityAlert(Map<String, dynamic> qualityData) {
    // Example thresholds based on the UI water quality chart
    final double? ph = qualityData['ph'] as double?;
    final double? chloride = qualityData['chloride'] as double?;
    final double? fluoride = qualityData['fluoride'] as double?;
    final double? nitrate = qualityData['nitrate'] as double?;
    
    // Check if any parameter is outside of the safe range
    if (ph != null && (ph < 6.5 || ph > 8.5)) return true;
    if (chloride != null && chloride > 250) return true;
    if (fluoride != null && fluoride > 1.5) return true;
    if (nitrate != null && nitrate > 50) return true;
    
    return false;
  }
  
  // Get historical water level data for a tank
  Future<List<Map<String, dynamic>>> fetchWaterLevelHistory(String tankId, {int limit = 100}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .doc(tankId)
          .collection('waterLevels')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
          
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting water level history: $e');
      return [];
    }
  }
  
  // Get historical water quality data for a tank
  Future<List<Map<String, dynamic>>> fetchWaterQualityHistory(String tankId, {int limit = 100}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .doc(tankId)
          .collection('waterQuality')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
          
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting water quality history: $e');
      return [];
    }
  }
} 