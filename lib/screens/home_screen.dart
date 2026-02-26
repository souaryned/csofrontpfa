import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/api_config.dart';
import '../widgets/avatar_widget.dart';
import 'choriste/dashboard_screen.dart';
import 'choriste/presences_screen.dart';
import 'choriste/conge_screen.dart';
import 'choriste/programme_screen.dart';
import 'choriste/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const PresencesScreen(),
    const ProgrammeScreen(),
    const CongeScreen(),
    const ProfileScreen(),
  ];

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.check_circle_rounded, label: 'Gérer les présences'),
    _NavItem(icon: Icons.calendar_month_rounded, label: 'Programme de la saison'),
_NavItem(icon: Icons.event_available_rounded, label: 'Déclarer un congé'),    _NavItem(icon: Icons.person_rounded, label: 'Mon profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        surfaceTintColor: Colors.white,
        leading: Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B), size: 20),
            ),
          ),
        ),
        // ✅ AppBar : titre vide — le CSO est seulement dans le dashboard
        title: const SizedBox.shrink(),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1E293B), size: 20),
          ),
        ],
      ),
      drawer: _buildDrawer(context, auth, user),
      body: _screens[_currentIndex],
    );
  }

  Widget _buildDrawer(BuildContext context, AuthProvider auth, dynamic user) {
    final String? avatarUrl = user?.avatar != null
        ? '${ApiConfig.baseUrl}${user!.avatar}'
        : null;

    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      width: MediaQuery.of(context).size.width * 0.78,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            decoration: const BoxDecoration(color: Color(0xFF0F172A)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFF2DD4BF), Color(0xFF3B82F6)]),
                      ),
                      child: AvatarImage(
                        avatarUrl: avatarUrl,
                        fullName: user?.fullName,
                        radius: 30,
                        backgroundColor: const Color(0xFF1E293B),
                        textColor: const Color(0xFF2DD4BF),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.fullName ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(user?.email ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF2DD4BF), Color(0xFF3B82F6)]),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  user?.role?.toUpperCase() ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text('Actif', style: TextStyle(color: const Color(0xFF22C55E).withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      const Color(0xFF2DD4BF).withValues(alpha: 0.5),
                      const Color(0xFF3B82F6).withValues(alpha: 0.3),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('NAVIGATION', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = _currentIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() => _currentIndex = index);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF2DD4BF).withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.2)) : null,
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 3,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2DD4BF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(item.icon, color: isSelected ? const Color(0xFF2DD4BF) : Colors.white.withValues(alpha: 0.4), size: 20),
                        const SizedBox(width: 12),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF2DD4BF) : Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.15)),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
              title: const Text('Déconnexion', style: TextStyle(color: Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.w600)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(context);
                await auth.logout();
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}