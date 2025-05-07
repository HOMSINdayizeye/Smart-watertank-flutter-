import 'package:cloud_firestore/cloud_firestore.dart';

class AgentPermissions {
  final String agentId;
  final bool canDeleteClients;
  final bool canEditClientInfo;
  final bool canViewClientInfo;
  final bool canEditTankInfo;
  final bool canViewTankInfo;
  final bool canViewNotifications;
  final bool canManageMaintenance;
  final bool canViewReports;
  final bool canEditReports;
  final bool canManageAlerts;
  final bool canViewAlerts;
  final bool canManageUsers;
  final bool canViewUsers;
  final bool canManageSettings;
  final bool canViewSettings;
  final bool canCreateClients;

  AgentPermissions({
    required this.agentId,
    this.canDeleteClients = false,
    this.canEditClientInfo = false,
    this.canViewClientInfo = false,
    this.canEditTankInfo = false,
    this.canViewTankInfo = false,
    this.canViewNotifications = false,
    this.canManageMaintenance = false,
    this.canViewReports = false,
    this.canEditReports = false,
    this.canManageAlerts = false,
    this.canViewAlerts = false,
    this.canManageUsers = false,
    this.canViewUsers = false,
    this.canManageSettings = false,
    this.canViewSettings = false,
    this.canCreateClients = false,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'agentId': agentId,
      'canDeleteClients': canDeleteClients,
      'canEditClientInfo': canEditClientInfo,
      'canViewClientInfo': canViewClientInfo,
      'canEditTankInfo': canEditTankInfo,
      'canViewTankInfo': canViewTankInfo,
      'canViewNotifications': canViewNotifications,
      'canManageMaintenance': canManageMaintenance,
      'canViewReports': canViewReports,
      'canEditReports': canEditReports,
      'canManageAlerts': canManageAlerts,
      'canViewAlerts': canViewAlerts,
      'canManageUsers': canManageUsers,
      'canViewUsers': canViewUsers,
      'canManageSettings': canManageSettings,
      'canViewSettings': canViewSettings,
      'canCreateClients': canCreateClients,
    };
  }

  // Create from Firestore document
  factory AgentPermissions.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AgentPermissions(
      agentId: data['agentId'] ?? '',
      canDeleteClients: data['canDeleteClients'] ?? false,
      canEditClientInfo: data['canEditClientInfo'] ?? false,
      canViewClientInfo: data['canViewClientInfo'] ?? false,
      canEditTankInfo: data['canEditTankInfo'] ?? false,
      canViewTankInfo: data['canViewTankInfo'] ?? false,
      canViewNotifications: data['canViewNotifications'] ?? false,
      canManageMaintenance: data['canManageMaintenance'] ?? false,
      canViewReports: data['canViewReports'] ?? false,
      canEditReports: data['canEditReports'] ?? false,
      canManageAlerts: data['canManageAlerts'] ?? false,
      canViewAlerts: data['canViewAlerts'] ?? false,
      canManageUsers: data['canManageUsers'] ?? false,
      canViewUsers: data['canViewUsers'] ?? false,
      canManageSettings: data['canManageSettings'] ?? false,
      canViewSettings: data['canViewSettings'] ?? false,
      canCreateClients: data['canCreateClients'] ?? false,
    );
  }

  // Create a copy with some fields updated
  AgentPermissions copyWith({
    String? agentId,
    bool? canDeleteClients,
    bool? canEditClientInfo,
    bool? canViewClientInfo,
    bool? canEditTankInfo,
    bool? canViewTankInfo,
    bool? canViewNotifications,
    bool? canManageMaintenance,
    bool? canViewReports,
    bool? canEditReports,
    bool? canManageAlerts,
    bool? canViewAlerts,
    bool? canManageUsers,
    bool? canViewUsers,
    bool? canManageSettings,
    bool? canViewSettings,
    bool? canCreateClients,
  }) {
    return AgentPermissions(
      agentId: agentId ?? this.agentId,
      canDeleteClients: canDeleteClients ?? this.canDeleteClients,
      canEditClientInfo: canEditClientInfo ?? this.canEditClientInfo,
      canViewClientInfo: canViewClientInfo ?? this.canViewClientInfo,
      canEditTankInfo: canEditTankInfo ?? this.canEditTankInfo,
      canViewTankInfo: canViewTankInfo ?? this.canViewTankInfo,
      canViewNotifications: canViewNotifications ?? this.canViewNotifications,
      canManageMaintenance: canManageMaintenance ?? this.canManageMaintenance,
      canViewReports: canViewReports ?? this.canViewReports,
      canEditReports: canEditReports ?? this.canEditReports,
      canManageAlerts: canManageAlerts ?? this.canManageAlerts,
      canViewAlerts: canViewAlerts ?? this.canViewAlerts,
      canManageUsers: canManageUsers ?? this.canManageUsers,
      canViewUsers: canViewUsers ?? this.canViewUsers,
      canManageSettings: canManageSettings ?? this.canManageSettings,
      canViewSettings: canViewSettings ?? this.canViewSettings,
      canCreateClients: canCreateClients ?? this.canCreateClients,
    );
  }
} 