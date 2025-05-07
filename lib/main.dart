import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/create_account_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/agent_dashboard.dart';
import 'screens/client_dashboard.dart';
import 'services/auth_service.dart';
import 'services/tank_service.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';

void main() async {
  // Initialize logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    if (kDebugMode) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    }
  });
  final log = Logger('MainApp');

  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  log.info('Flutter initialized');
  
  // Initialize Firebase
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDujvBpSrNEcm_X0CP-EH8JYAMdZYdB_lY",
          authDomain: "watertankmanagement-37ed2.firebaseapp.com",
          projectId: "watertankmanagement-37ed2",
          storageBucket: "watertankmanagement-37ed2.firebasestorage.app",
          messagingSenderId: "942242565145",
          appId: "1:942242565145:web:7c6c128ef6f9f2bbea6e88",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    log.info('Firebase initialized successfully');
  } catch (e) {
    log.severe('Error initializing Firebase: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('Building MyApp widget');
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<TankService>(
          create: (_) => TankService(),
        ),
        Provider<NotificationService>(
          create: (_) => NotificationService(),
        ),
        // Stream provider for authentication state
        StreamProvider(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'Smart Water Tank',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            primary: Colors.blue,
          ),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const WelcomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/create_account': (context) => const CreateAccountScreen(),
          '/admin': (context) => const AdminScreen(),
          '/admin_dashboard': (context) => const AdminDashboard(),
          '/agent_dashboard': (context) => const AgentDashboard(),
          '/client_dashboard': (context) => const ClientDashboard(),
          '/create': (context) => const CreateAccountScreen(),
        },
      ),
    );
  }
}

Stream<QuerySnapshot> getNotifications() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('User not authenticated');
  
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('recipientId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .snapshots();
}
