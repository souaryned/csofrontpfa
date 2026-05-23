import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'presences_chef_screen.dart';
import 'messagerie_chef_screen.dart';

/// Module Chef de pupitre — présences + messagerie (style dashboard).
class ChefPupitreScreen extends StatelessWidget {
  const ChefPupitreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final pupitre = user?.pupitre ?? '';
    final color = AppColors.pupitre(pupitre);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Row(
            children: [
              const Text('Chef de pupitre'),
              if (pupitre.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    AppColors.pupitreLabel(pupitre),
                    style: AppTextStyles.label.copyWith(color: color),
                  ),
                ),
              ],
            ],
          ),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.how_to_reg_outlined, size: 20),
                text: 'Présences',
              ),
              Tab(
                icon: Icon(Icons.chat_bubble_outline, size: 20),
                text: 'Messages',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            PresencesChefScreen(
              pupitre: pupitre,
              color: color,
              embedded: true,
            ),
            MessagerieChefScreen(
              pupitre: pupitre,
              color: color,
              embedded: true,
            ),
          ],
        ),
      ),
    );
  }
}
