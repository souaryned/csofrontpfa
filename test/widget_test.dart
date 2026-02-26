import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cso_mobile/main.dart';
import 'package:cso_mobile/providers/auth_provider.dart';

void main() {
  testWidgets('App smoke test - launches without crashing', (WidgetTester tester) async {
    // ✅ Créer un AuthProvider vide (pas de token, user = null)
    final authProvider = AuthProvider();

    // ✅ MyApp attend maintenant un authProvider en paramètre
    await tester.pumpWidget(MyApp(authProvider: authProvider));
    await tester.pump();

    // ✅ Vérifier que l'app démarre sans crash (SplashScreen s'affiche)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}