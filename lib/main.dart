import 'package:cso_mobile/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';

// ✅ Le vrai screen de gestion des présences
import 'screens/choriste/presences_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final authProvider = AuthProvider();
  await authProvider.loadUser();

  await NotificationService.initialize();

  runApp(MyApp(authProvider: authProvider));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  const MyApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
      ],
      child: MaterialApp(
        title: 'CSO Mobile',
        debugShowCheckedModeBanner: false,

        // ✅ Clé de navigation globale pour les notifs
        navigatorKey: NotificationService.navigatorKey,

        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2DD4BF)),
          useMaterial3: true,
        ),

        home: const SplashScreen(),

        // ✅ Route vers le screen de présences
        routes: {
          '/repetitions': (context) => Scaffold(
                appBar: AppBar(
                  title: const Text('Répétitions'),
                  backgroundColor: const Color(0xFF2DD4BF),
                  foregroundColor: Colors.white,
                ),
                body: const PresencesScreen(),
              ),
        },
      ),
    );
  }
}