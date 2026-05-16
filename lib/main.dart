import 'package:cso_mobile/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';
import 'screens/choriste/presences_screen.dart';
import 'screens/choriste/reminder_preferences_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase initialisé UNE SEULE FOIS
  await Firebase.initializeApp();

  // 2. Restaurer la session
  //    → lit le token JWT depuis flutter_secure_storage
  //    → valide via GET /auth/me
  //    → si valide  : isLoggedIn = true  → SplashScreen va à HomeScreen
  //    → si invalide : isLoggedIn = false → SplashScreen va à LoginScreen
  final authProvider = AuthProvider();
  await authProvider.loadUser();

  // 3. Initialiser FCM TOUJOURS, même sans connexion
  //    Nécessaire pour recevoir les notifs en background
  //    et maintenir le onTokenRefresh actif
  await NotificationService.initialize();

  // 4. Renvoyer le token FCM au backend si connecté
  //    (loadUser le fait déjà, mais initialize() peut générer un nouveau token)
  if (authProvider.isLoggedIn) {
    await NotificationService.saveTokenAfterLogin();
  }

  runApp(MyApp(authProvider: authProvider));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;

  const MyApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider.value(value: authProvider)],
      child: MaterialApp(
        title: 'CSO Mobile',
        debugShowCheckedModeBanner: false,

        // Clé de navigation globale pour les notifications
        navigatorKey: NotificationService.navigatorKey,

        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2DD4BF)),
          useMaterial3: true,
        ),

        // SplashScreen lit AuthProvider et redirige
        home: const SplashScreen(),

        // Routes nommées pour la navigation depuis les notifications
        routes: {
          '/repetitions': (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Répétitions'),
              backgroundColor: const Color(0xFF2DD4BF),
              foregroundColor: Colors.white,
            ),
            body: const PresencesScreen(),
          ),
          '/reminder-preferences': (context) =>
              const ReminderPreferencesScreen(),
        },
      ),
    );
  }
}
