import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/oeuvre_provider.dart';
import '../../models/oeuvre_model.dart';
import 'oeuvre_detail_screen.dart';
import 'oeuvre_form_screen.dart';

class OeuvreListScreen extends StatefulWidget {
  const OeuvreListScreen({super.key});

  @override
  State<OeuvreListScreen> createState() => _OeuvreListScreenState();
}

class _OeuvreListScreenState extends State<OeuvreListScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OeuvreProvider>().loadOeuvres();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final provider = context.watch<OeuvreProvider>();
    final isPrivileged = auth.user?.role == 'admin' ||
        auth.user?.isChefDePupitre == true;

    final filtered = provider.oeuvres.where((o) {
      final q = _search.toLowerCase();
      return o.title.toLowerCase().contains(q) ||
          o.composers.any((c) => c.toLowerCase().contains(q)) ||
          o.genre.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Œuvres',
          style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 17,
              fontWeight: FontWeight.w700),
        ),
        actions: [
          if (isPrivileged)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OeuvreFormScreen()),
                ).then((_) => provider.loadOeuvres()),
                icon: const Icon(Icons.add_rounded,
                    size: 18, color: Color(0xFF3B82F6)),
                label: const Text('Ajouter',
                    style: TextStyle(
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Barre de recherche ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Rechercher une œuvre…',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF94A3B8), size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF3B82F6), width: 1.5)),
              ),
            ),
          ),

          // ── Liste ───────────────────────────────────────────────────
          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF3B82F6)))
                : provider.error != null
                    ? _ErrorView(
                        message: provider.error!,
                        onRetry: provider.loadOeuvres)
                    : filtered.isEmpty
                        ? _EmptyView(isPrivileged: isPrivileged)
                        : RefreshIndicator(
                            onRefresh: provider.loadOeuvres,
                            color: const Color(0xFF3B82F6),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => _OeuvreCard(
                                oeuvre: filtered[i],
                                isPrivileged: isPrivileged,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OeuvreDetailScreen(
                                        oeuvre: filtered[i]),
                                  ),
                                ),
                                onEdit: isPrivileged
                                    ? () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => OeuvreFormScreen(
                                                oeuvre: filtered[i]),
                                          ),
                                        ).then((_) => provider.loadOeuvres())
                                    : null,
                                onToggle: isPrivileged
                                    ? () => provider
                                        .toggleVisibility(filtered[i].id)
                                    : null,
                                onDelete: auth.user?.role == 'admin'
                                    ? () =>
                                        _confirmDelete(context, filtered[i])
                                    : null,
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext ctx, OeuvreModel o) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        title: const Text('Supprimer l\'œuvre',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Supprimer « ${o.title} » définitivement ?',
            style: const TextStyle(color: Color(0xFF64748B))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true && ctx.mounted) {
      await ctx.read<OeuvreProvider>().deleteOeuvre(o.id);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card œuvre
// ─────────────────────────────────────────────────────────────────────────────
class _OeuvreCard extends StatelessWidget {
  final OeuvreModel oeuvre;
  final bool isPrivileged;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  const _OeuvreCard({
    required this.oeuvre,
    required this.isPrivileged,
    required this.onTap,
    this.onEdit,
    this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasMedia = oeuvre.partition.isNotEmpty ||
        oeuvre.lyrics.isNotEmpty ||
        oeuvre.audio.isNotEmpty ||
        oeuvre.video.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Bandeau masqué ──────────────────────────────────────
            if (isPrivileged && !oeuvre.isVisible)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF7ED),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.visibility_off_rounded,
                        size: 13, color: Color(0xFFD97706)),
                    SizedBox(width: 6),
                    Text('Masquée aux choristes',
                        style: TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.music_note_rounded,
                        color: Color(0xFF3B82F6), size: 22),
                  ),
                  const SizedBox(width: 12),

                  // Infos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(oeuvre.title,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B))),
                        const SizedBox(height: 3),
                        Text(
                          oeuvre.composers.join(', '),
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            _Chip(oeuvre.genre,
                                const Color(0xFFEFF6FF),
                                const Color(0xFF3B82F6)),
                            _Chip(oeuvre.year,
                                const Color(0xFFF0FDF4),
                                const Color(0xFF16A34A)),
                            if (oeuvre.requiresChoir)
                              _Chip('Chœur requis',
                                  const Color(0xFFFEF3C7),
                                  const Color(0xFFD97706)),
                          ],
                        ),
                        // Indicateurs médias
                        if (hasMedia) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (oeuvre.partition.isNotEmpty)
                                _MediaDot(Icons.picture_as_pdf_rounded,
                                    const Color(0xFFEF4444)),
                              if (oeuvre.lyrics.isNotEmpty)
                                _MediaDot(Icons.article_rounded,
                                    const Color(0xFF8B5CF6)),
                              if (oeuvre.audio.isNotEmpty)
                                _MediaDot(Icons.headphones_rounded,
                                    const Color(0xFF0EA5E9)),
                              if (oeuvre.video.isNotEmpty)
                                _MediaDot(Icons.play_circle_rounded,
                                    const Color(0xFF10B981)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Actions
                  if (isPrivileged)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: Color(0xFF94A3B8), size: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit_rounded,
                                  size: 16, color: Color(0xFF3B82F6)),
                              SizedBox(width: 10),
                              Text('Modifier'),
                            ])),
                        PopupMenuItem(
                            value: 'toggle',
                            child: Row(children: [
                              Icon(
                                oeuvre.isVisible
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 16,
                                color: const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 10),
                              Text(oeuvre.isVisible
                                  ? 'Masquer'
                                  : 'Afficher'),
                            ])),
                        if (onDelete != null)
                          const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_rounded,
                                    size: 16, color: Color(0xFFEF4444)),
                                SizedBox(width: 10),
                                Text('Supprimer',
                                    style: TextStyle(
                                        color: Color(0xFFEF4444))),
                              ])),
                      ],
                      onSelected: (v) {
                        if (v == 'edit') onEdit?.call();
                        if (v == 'toggle') onToggle?.call();
                        if (v == 'delete') onDelete?.call();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Chip(this.label, this.bg, this.fg);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(5)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
      );
}

class _MediaDot extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _MediaDot(this.icon, this.color);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Icon(icon, size: 14, color: color),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFEF4444), size: 40),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: onRetry,
              child: const Text('Réessayer')),
        ]),
      );
}

class _EmptyView extends StatelessWidget {
  final bool isPrivileged;
  const _EmptyView({required this.isPrivileged});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.library_music_rounded,
              size: 52, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          const Text('Aucune œuvre',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),
          if (isPrivileged) ...[
            const SizedBox(height: 6),
            const Text('Appuyez sur + Ajouter pour commencer.',
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF94A3B8))),
          ],
        ]),
      );
}