import 'package:cso_mobile/screens/choriste/messagerie_chef_screen.dart';
import 'package:cso_mobile/screens/choriste/presences_chef_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import '../config/api_config.dart';
import '../widgets/avatar_widget.dart';
import 'choriste/dashboard_screen.dart';
import 'choriste/presences_screen.dart';
import 'choriste/conge_screen.dart';
import 'choriste/programme_screen.dart';
import 'choriste/profile_screen.dart';
// ✅ Import des écrans œuvres
import 'oeuvre_list_screen.dart';

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
    const OeuvreListScreen(), // ✅ AJOUTÉ
    const CongeScreen(),
    const ProfileScreen(),
  ];

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_rounded,       label: 'Dashboard'),
    _NavItem(icon: Icons.check_circle_rounded,    label: 'Gérer les présences'),
    _NavItem(icon: Icons.calendar_month_rounded,  label: 'Programme de la saison'),
    _NavItem(icon: Icons.library_music_rounded,   label: 'Œuvres'),          // ✅ AJOUTÉ
    _NavItem(icon: Icons.event_available_rounded, label: 'Déclarer un congé'),
    _NavItem(icon: Icons.person_rounded,          label: 'Mon profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final isChef = user?.isChefDePupitre == true;
    final pupitre = user?.pupitre ?? '';
    final pupitreColor = Color(user?.pupitreColor as int? ?? 0xFF6B7280);

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
              child: const Icon(Icons.menu_rounded,
                  color: Color(0xFF1E293B), size: 20),
            ),
          ),
        ),
        title: const SizedBox.shrink(),
        actions: const [],
      ),
      drawer: _buildDrawer(
          context, auth, user, isChef, pupitre, pupitreColor),
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
      width: MediaQuery.of(context).size.width * 0.78,
      child: Column(
        children: [
          // ── Header profil ──────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 4, color: pupitreColor),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    MediaQuery.of(context).padding.top + 16,
                    16,
                    16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AvatarImage(
                        avatarUrl: avatarUrl,
                        fullName: user?.fullName,
                        radius: 26,
                        backgroundColor:
                            pupitreColor.withValues(alpha: 0.12),
                        textColor: pupitreColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? '',
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? '',
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              children: [
                                _Badge(
                                  label: user?.role?.toUpperCase() ?? '',
                                  bgColor:
                                      pupitreColor.withValues(alpha: 0.1),
                                  textColor: pupitreColor,
                                ),
                                const _Badge(
                                  label: '● Actif',
                                  bgColor: Color(0xFFDCFCE7),
                                  textColor: Color(0xFF16A34A),
                                ),
                                if ((user?.pupitreLabel as String? ?? '')
                                    .isNotEmpty)
                                  _Badge(
                                    label:
                                        '♪ ${user?.pupitreLabel ?? ''}',
                                    bgColor: pupitreColor
                                        .withValues(alpha: 0.08),
                                    textColor: pupitreColor,
                                  ),
                                if (isChef)
                                  const _Badge(
                                    label: '★ Chef',
                                    bgColor: Color(0xFFFEF3C7),
                                    textColor: Color(0xFFD97706),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Navigation items ───────────────────────────────────────
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Text(
                    'NAVIGATION',
                    style: TextStyle(
                      color: const Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                ...List.generate(_navItems.length, (i) {
                  final item = _navItems[i];
                  final isSelected = _currentIndex == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _currentIndex = i);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFF1F5F9)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(item.icon,
                              color: isSelected
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFF64748B),
                              size: 19),
                          const SizedBox(width: 12),
                          Text(item.label,
                              style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF475569),
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                          if (isSelected) ...[
                            const Spacer(),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF3B82F6),
                                  shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),

                // ── Messages choriste ────────────────────────────────
                if (!isChef) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: Text('MESSAGES',
                        style: TextStyle(
                            color: const Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ),
                  _buildChefItem(
                    icon: Icons.mark_chat_unread_rounded,
                    label: 'Messages de mon chef',
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const MessagesChoristScreen()));
                    },
                  ),
                ],

                // ── Chef de pupitre ──────────────────────────────────
                if (isChef) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: Text('CHEF DE PUPITRE',
                        style: TextStyle(
                            color: const Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ),
                  _buildChefItem(
                    icon: Icons.how_to_reg_rounded,
                    label: 'Présences répétition',
                    color: pupitreColor,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PresencesChefScreen(
                                  pupitre: pupitre,
                                  color: pupitreColor)));
                    },
                  ),
                  const SizedBox(height: 2),
                  _buildChefItem(
                    icon: Icons.chat_rounded,
                    label: 'Messagerie pupitre',
                    color: pupitreColor,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => MessagerieChefScreen(
                                  pupitre: pupitre,
                                  color: pupitreColor)));
                    },
                  ),
                ],
              ],
            ),
          ),

          // ── Déconnexion ────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.logout_rounded,
                  color: Color(0xFFEF4444), size: 18),
              title: const Text('Déconnexion',
                  style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    backgroundColor: Colors.white,
                    title: const Row(children: [
                      Icon(Icons.logout_rounded,
                          color: Color(0xFFEF4444), size: 22),
                      SizedBox(width: 10),
                      Text('Déconnexion',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B))),
                    ]),
                    content: const Text(
                        'Voulez-vous vraiment vous déconnecter ?',
                        style: TextStyle(
                            color: Color(0xFF64748B), fontSize: 14)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Annuler',
                              style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10)),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Déconnecter',
                            style: TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChefItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600))),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _Badge(
      {required this.label,
      required this.bgColor,
      required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(5)),
      child: Text(label,
          style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}