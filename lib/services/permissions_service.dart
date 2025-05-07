import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/agent_permissions.dart';

class PermissionsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get permissions for an agent
  Future<AgentPermissions?> getAgentPermissions(String agentId) async {
    try {
      final doc = await _firestore.collection('agent_permissions').doc(agentId).get();
      if (doc.exists) {
        return AgentPermissions.fromFirestore(doc);
      }
      // If no permissions document exists, create one with default values
      final defaultPermissions = AgentPermissions(agentId: agentId);
      await _firestore.collection('agent_permissions').doc(agentId).set(defaultPermissions.toMap());
      return defaultPermissions;
    } catch (e) {
      print('Error getting agent permissions: $e');
      return null;
    }
  }

  // Update permissions for an agent
  Future<bool> updateAgentPermissions(AgentPermissions permissions) async {
    try {
      await _firestore.collection('agent_permissions').doc(permissions.agentId).set(permissions.toMap());
      return true;
    } catch (e) {
      print('Error updating agent permissions: $e');
      return false;
    }
  }

  // Check if an agent has a specific permission
  Future<bool> hasPermission(String agentId, String permission) async {
    try {
      final permissions = await getAgentPermissions(agentId);
      if (permissions == null) return false;

      switch (permission) {
        case 'canDeleteClients':
          return permissions.canDeleteClients;
        case 'canEditClientInfo':
          return permissions.canEditClientInfo;
        case 'canViewClientInfo':
          return permissions.canViewClientInfo;
        case 'canEditTankInfo':
          return permissions.canEditTankInfo;
        case 'canViewNotifications':
          return permissions.canViewNotifications;
        case 'canManageMaintenance':
          return permissions.canManageMaintenance;
        case 'canViewReports':
          return permissions.canViewReports;
        case 'canEditReports':
          return permissions.canEditReports;
        case 'canManageAlerts':
          return permissions.canManageAlerts;
        case 'canViewAlerts':
          return permissions.canViewAlerts;
        case 'canManageUsers':
          return permissions.canManageUsers;
        case 'canViewUsers':
          return permissions.canViewUsers;
        case 'canManageSettings':
          return permissions.canManageSettings;
        case 'canViewSettings':
          return permissions.canViewSettings;
        default:
          return false;
      }
    } catch (e) {
      print('Error checking permission: $e');
      return false;
    }
  }

  // Get all permissions for all agents
  Stream<QuerySnapshot> getAllAgentPermissions() {
    return _firestore.collection('agent_permissions').snapshots();
  }
} 