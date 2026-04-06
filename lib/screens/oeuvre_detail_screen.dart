import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/oeuvre_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/oeuvre_service.dart';
import 'pdf_viewer_screen.dart';
import 'video_player_screen.dart';
import 'audio_player_screen.dart';

class OeuvreDetailScreen extends StatelessWidget {
  final OeuvreModel oeuvre;
  const OeuvreDetailScreen({super.key, required this.oeuvre});

  @override
  Widget build(BuildContext context) {
    final isPrivileged = context.watch<AuthProvider>().user?.role == 'admin' ||
        context.watch<AuthProvider>().user?.isChefDePupitre == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E293B), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(oeuvre.title,
            style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── En-tête ────────────────────────────────────────────────
          _InfoCard(oeuvre: oeuvre, isPrivileged: isPrivileged),
          const SizedBox(height: 16),

          // ── Fichiers disponibles ────────────────────────────────────
          const _SectionTitle('Fichiers'),
          const SizedBox(height: 8),

          if (oeuvre.partition.isNotEmpty)
            _FileButton(
              icon: Icons.picture_as_pdf_rounded,
              label: 'Partition (PDF)',
              color: const Color(0xFFEF4444),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfViewerScreen(
                    title: 'Partition — ${oeuvre.title}',
                    url: OeuvreService.buildFileUrl(oeuvre.partition),
                  ),
                ),
              ),
            ),

          if (oeuvre.lyrics.isNotEmpty)
            _FileButton(
              icon: Icons.article_rounded,
              label: 'Paroles (PDF)',
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfViewerScreen(
                    title: 'Paroles — ${oeuvre.title}',
                    url: OeuvreService.buildFileUrl(oeuvre.lyrics),
                  ),
                ),
              ),
            ),

          if (oeuvre.audio.isNotEmpty)
            _FileButton(
              icon: Icons.headphones_rounded,
              label: 'Écouter l\'audio',
              color: const Color(0xFF0EA5E9),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AudioPlayerScreen(
                    title: oeuvre.title,
                    url: OeuvreService.buildFileUrl(oeuvre.audio),
                  ),
                ),
              ),
            ),

          if (oeuvre.video.isNotEmpty)
            _FileButton(
              icon: Icons.play_circle_rounded,
              label: 'Regarder la vidéo',
              color: const Color(0xFF10B981),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoPlayerScreen(
                    title: oeuvre.title,
                    url: OeuvreService.buildFileUrl(oeuvre.video),
                  ),
                ),
              ),
            ),

          if (oeuvre.partition.isEmpty &&
              oeuvre.lyrics.isEmpty &&
              oeuvre.audio.isEmpty &&
              oeuvre.video.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0))),
              child: const Center(
                child: Text('Aucun fichier disponible pour cette œuvre.',
                    style: TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Info card ────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final OeuvreModel oeuvre;
  final bool isPrivileged;
  const _InfoCard({required this.oeuvre, required this.isPrivileged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre + badge masqué
          Row(
            children: [
              Expanded(
                child: Text(oeuvre.title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A))),
              ),
              if (isPrivileged && !oeuvre.isVisible)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_off_rounded,
                          size: 12, color: Color(0xFFD97706)),
                      SizedBox(width: 4),
                      Text('Masquée',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD97706))),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _Row(Icons.person_rounded, 'Compositeur(s)',
              oeuvre.composers.join(', ')),
          if (oeuvre.arrangers.isNotEmpty)
            _Row(Icons.edit_rounded, 'Arrangeur(s)',
                oeuvre.arrangers.join(', ')),
          _Row(Icons.calendar_today_rounded, 'Année', oeuvre.year),
          _Row(Icons.category_rounded, 'Genre', oeuvre.genre),
          _Row(
              oeuvre.requiresChoir
                  ? Icons.group_rounded
                  : Icons.person_outline_rounded,
              'Chœur',
              oeuvre.requiresChoir ? 'Requis' : 'Non requis'),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Text('$label : ',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF64748B))),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B))),
            ),
          ],
        ),
      );
}

// ─── File button ──────────────────────────────────────────────────────────────
class _FileButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FileButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B)))),
              Icon(Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.5), size: 20),
            ],
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.5));
}