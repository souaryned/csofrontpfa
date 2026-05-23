// home_screen.dart — REDESIGN ÉLÉGANT
import 'package:cso/screens/choriste/messagerie_chef_screen.dart';
import 'package:cso/screens/choriste/presences_chef_screen.dart';
import 'package:cso/screens/sondages_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/survey_model.dart';
import '../services/chef_pupitre_service.dart';
import '../services/survey_service.dart';
import 'login_screen.dart';
import '../config/api_config.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar_widget.dart';
import 'choriste/dashboard_screen.dart';
import 'choriste/presences_screen.dart';
import 'choriste/conge_screen.dart';
import 'choriste/programme_screen.dart';
import 'choriste/profile_screen.dart';
import 'oeuvre_list_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  /// Accès à l'état depuis les écrans enfants (ex. dashboard).
  static HomeScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<HomeScreenState>();
  }

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  int _badgeCount = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _refreshNotificationBadge();
  }

  /// Badge cloche : sondages en attente + messages non lus.
  Future<void> _refreshNotificationBadge() async {
    int surveys = 0;
    int messages = 0;

    try {
      final raw = await SurveyService().getSurveys();
      for (final j in raw) {
        final s = SurveyModel.fromJson(j as Map<String, dynamic>);
        if (s.statut != 'actif') continue;
        final rep = await SurveyService().getMaReponse(s.id);
        if (rep == null) surveys++;
      }
    } catch (_) {}

    try {
      final msgs = await ChefPupitreService().getChoristMessages();
      messages = msgs.where((m) => (m as Map)['readAt'] == null).length;
    } catch (_) {}

    if (!mounted) return;
    setState(() => _badgeCount = surveys + messages);
  }

  /// Appelé par le dashboard après chargement.
  void refreshNotificationBadge() => _refreshNotificationBadge();

  /// Change l'onglet principal (0 = dashboard, 1 = présences, …).
  void selectTab(int index) {
    if (index < 0 || index >= _screens.length) return;
    setState(() => _currentIndex = index);
  }

  final List<Widget> _screens = [
    const DashboardScreen(),
    const PresencesScreen(),
    const ProgrammeScreen(),
    const OeuvreListScreen(),
    const CongeScreen(),
    const SondagesScreen(),
    const ProfileScreen(),
  ];

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
    _NavItem(icon: Icons.check_circle_outline_rounded, label: 'Gérer les présences'),
    _NavItem(icon: Icons.calendar_month_outlined, label: 'Programme de la saison'),
    _NavItem(icon: Icons.library_music_outlined, label: 'Œuvres'),
    _NavItem(icon: Icons.event_available_outlined, label: 'Déclarer un congé'),
    _NavItem(icon: Icons.poll_outlined, label: 'Sondages'),
    _NavItem(icon: Icons.person_outline_rounded, label: 'Mon profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final isChef = user?.isChefDePupitre == true;
    final pupitre = user?.pupitre ?? '';
    final pupitreColor = Color(user?.pupitreColor as int? ?? 0xFF6366F1);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        surfaceTintColor: Colors.white,
        leading: Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.menu_rounded,
                    color: Color(0xFF1C1C2E), size: 19),
              ),
            ),
          ),
        ),
        // Logo CSO centré dans l'AppBar
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CSO',
              style: TextStyle(
                color: const Color(0xFF1C1C2E),
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                if (_badgeCount > 0) selectTab(5);
              },
              child: SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F5),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Color(0xFF1C1C2E),
                        size: 18,
                      ),
                    ),
                    if (_badgeCount > 0)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surveyAccent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            _badgeCount > 9 ? '9+' : '$_badgeCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, auth, user, isChef, pupitre, pupitreColor),
      body: _screens[_currentIndex],
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    AuthProvider auth,
    dynamic user,
    bool isChef,
    String pupitre,
    Color pupitreColor,
  ) {
    final String? avatarUrl = user?.avatar != null
        ? '${ApiConfig.baseUrl}${user!.avatar}'
        : null;

    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.82,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 20,
              20,
              20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  pupitreColor.withValues(alpha: 0.08),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFE8ECF4)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: pupitreColor.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: AvatarImage(
                        avatarUrl: avatarUrl,
                        fullName: user?.fullName,
                        radius: 26,
                        backgroundColor: pupitreColor.withValues(alpha: 0.12),
                        textColor: pupitreColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? '',
                            style: const TextStyle(
                              color: Color(0xFF1A1D26),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _LightBadge(
                      label: user?.role?.toUpperCase() ?? '',
                      color: pupitreColor,
                    ),
                    const _LightBadge(
                      label: 'Actif',
                      color: Color(0xFF16A34A),
                    ),
                    if ((user?.pupitreLabel as String? ?? '').isNotEmpty)
                      _LightBadge(
                        label: user?.pupitreLabel ?? '',
                        color: pupitreColor,
                      ),
                    if (isChef)
                      const _LightBadge(
                        label: 'Chef de pupitre',
                        color: Color(0xFFD97706),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              children: [
                const _DrawerSectionLabel('Menu'),
                const SizedBox(height: 8),
                ...List.generate(_navItems.length, (i) {
                  final item = _navItems[i];
                  final isSelected = _currentIndex == i;
                  return _DrawerNavItem(
                    icon: item.icon,
                    label: item.label,
                    isSelected: isSelected,
                    accentColor: pupitreColor,
                    onTap: () {
                      setState(() => _currentIndex = i);
                      Navigator.pop(context);
                    },
                  );
                }),
                if (!isChef) ...[
                  const SizedBox(height: 18),
                  const _DrawerSectionLabel('Communication'),
                  const SizedBox(height: 8),
                  _DrawerChefItem(
                    icon: Icons.mark_chat_unread_outlined,
                    label: 'Messages de mon chef',
                    color: const Color(0xFF7C3AED),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MessagesChoristScreen(),
                        ),
                      );
                    },
                  ),
                ],
                if (isChef) ...[
                  const SizedBox(height: 18),
                  const _DrawerSectionLabel('Chef de pupitre'),
                  const SizedBox(height: 8),
                  _DrawerChefItem(
                    icon: Icons.how_to_reg_outlined,
                    label: 'Présences répétition',
                    color: pupitreColor,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PresencesChefScreen(
                            pupitre: pupitre,
                            color: pupitreColor,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  _DrawerChefItem(
                    icon: Icons.chat_outlined,
                    label: 'Messagerie pupitre',
                    color: pupitreColor,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MessagerieChefScreen(
                            pupitre: pupitre,
                            color: pupitreColor,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              0,
              12,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    backgroundColor: Colors.white,
                    title: const Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFDC2626),
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Déconnexion',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1D26),
                          ),
                        ),
                      ],
                    ),
                    content: const Text(
                      'Voulez-vous vraiment vous déconnecter ?',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          'Annuler',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Déconnecter'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFDC2626),
                      size: 18,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Déconnexion',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Composants internes ──────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _DrawerSectionLabel extends StatelessWidget {
  final String text;
  const _DrawerSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DrawerNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _DrawerNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: isSelected
              ? Border.all(color: accentColor.withValues(alpha: 0.2))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? accentColor : const Color(0xFF64748B),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF1A1D26)
                      : const Color(0xFF475569),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerChefItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DrawerChefItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: color.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _LightBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _LightBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}