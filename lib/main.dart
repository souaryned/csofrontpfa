import 'package:cso_mobile/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ FIX : charger le user AVANT de lancer l'app
  final authProvider = AuthProvider();
  await authProvider.loadUser(); // await obligatoire !

  runApp(MyApp(authProvider: authProvider));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  const MyApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ✅ On passe l'instance déjà initialisée, pas une nouvelle
        ChangeNotifierProvider.value(value: authProvider),
      ],
      child: MaterialApp(
        title: 'CSO Mobile',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2DD4BF),
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}