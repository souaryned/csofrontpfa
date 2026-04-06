// screens/chef_pupitre/chef_pupitre_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/chef_pupitre_service.dart';
import 'presences_chef_screen.dart';
import 'messagerie_chef_screen.dart';

/// Point d'entrée du module Chef de Pupitre.
/// Tab 1 : Présences répétition en cours
/// Tab 2 : Messagerie pupitre
class ChefPupitreScreen extends StatelessWidget {
  const ChefPupitreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final pupitre = user?.pupitre ?? '';
    final color = _pupitreColor(pupitre);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: color,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chef de Pupitre',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(
                _pupitreLabel(pupitre),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
            ],
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(icon: Icon(Icons.how_to_reg), text: 'Présences'),
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Messages'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            PresencesChefScreen(pupitre: pupitre, color: color),
            MessagerieChefScreen(pupitre: pupitre, color: color),
          ],
        ),
      ),
    );
  }

  Color _pupitreColor(String p) {
    switch (p) {
      case 'soprano': return const Color(0xFF7C3AED);
      case 'alto':    return const Color(0xFF0891B2);
      case 'ténor':   return const Color(0xFF059669);
      case 'basse':   return const Color(0xFFB45309);
      default:        return const Color(0xFF6B7280);
    }
  }

  String _pupitreLabel(String p) {
    switch (p) {
      case 'soprano': return 'Soprano';
      case 'alto':    return 'Alto';
      case 'ténor':   return 'Ténor';
      case 'basse':   return 'Basse';
      default:        return p;
    }
  }
}
