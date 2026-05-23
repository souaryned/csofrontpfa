// screens/chef_pupitre/presences_chef_screen.dart
import 'package:flutter/material.dart';
import '../../services/chef_pupitre_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/cso_ui.dart';

/// Présences de la répétition en cours (chef de pupitre).
class PresencesChefScreen extends StatefulWidget {
  final String pupitre;
  final Color color;
  final bool embedded;

  const PresencesChefScreen({
    super.key,
    required this.pupitre,
    required this.color,
    this.embedded = false,
  });

  @override
  State<PresencesChefScreen> createState() => _PresencesChefScreenState();
}

class _PresencesChefScreenState extends State<PresencesChefScreen> {
  final ChefPupitreService _service = ChefPupitreService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  bool _validating = false;
  bool _validated = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.getActiveRepetitionPresences();
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().contains('404') || e.toString().contains('Aucune')
            ? 'Aucune répétition en cours pour le moment.'
            : 'Impossible de charger les présences.\n${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> _toggleStatus(Map choriste) async {
    final current = choriste['presenceStatus'] as String;
    final newStatus = current == 'present' ? 'absent' : 'present';
    final repId = _data!['repetition']['_id'] as String;

    String? reason;
    if (newStatus == 'absent') {
      reason = await _showReasonDialog();
      if (reason == null) return;
    }

    try {
      await _service.updateChoristPresence(
        repetitionId: repId,
        userId: choriste['_id'] as String,
        status: newStatus,
        reason: reason,
      );
      setState(() {
        choriste['presenceStatus'] = newStatus;
        choriste['absenceReason'] = reason;
        final list = _data!['choristes'] as List;
        _data!['summary'] = {
          'total':   list.length,
          'present': list.where((c) => c['presenceStatus'] == 'present').length,
          'absent':  list.where((c) => c['presenceStatus'] == 'absent').length,
          'unknown': list.where((c) => c['presenceStatus'] == 'unknown').length,
        };
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${choriste['firstName']} → $newStatus'),
          backgroundColor:
              newStatus == 'present' ? AppColors.success : AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<String?> _showReasonDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Raison de l'absence", style: AppTextStyles.title),
        content: TextField(
          controller: controller,
          style: AppTextStyles.subtitle,
          decoration: const InputDecoration(
            hintText: 'Ex : Congé médical…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: AppTextStyles.body),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx,
                controller.text.trim().isEmpty ? 'Absent (chef de pupitre)' : controller.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _openMessageDialog(Map choriste) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _MessageBottomSheet(
        choriste: choriste,
        color: widget.color,
        repetitionId: _data?['repetition']?['_id'],
        service: _service,
      ),
    );
  }

  Future<void> _validate() async {
    final repId = _data!['repetition']['_id'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Valider la liste ?', style: AppTextStyles.title),
        content: const Text(
          'La liste sera envoyée au chef de chœur avec les présences et absences de votre pupitre.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: AppTextStyles.body),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Envoyer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _validating = true);
    try {
      await _service.validateAndSendPresenceList(repId);
      setState(() { _validated = true; _validating = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Liste validée et envoyée au chef de chœur'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _validating = false);
    }
  }

  PreferredSizeWidget? get _standaloneAppBar => widget.embedded
      ? null
      : AppBar(
          title: Row(
            children: [
              const Text('Présences répétition'),
              if (widget.pupitre.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    AppColors.pupitreLabel(widget.pupitre),
                    style: AppTextStyles.label.copyWith(color: widget.color),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              onPressed: _load,
              tooltip: 'Actualiser',
            ),
          ],
        );

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? CsoUi.loading()
        : _error != null
            ? _buildError()
            : _buildContent();

    if (widget.embedded) {
      return CsoUi.screenBody(child: body);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _standaloneAppBar,
      body: body,
    );
  }

  Widget _buildContent() {
    final rep      = _data!['repetition'] as Map;
    final choristes = _data!['choristes'] as List;
    final summary  = _data!['summary'] as Map;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: CsoUi.card(accent: widget.color),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.repAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.library_music_outlined,
                    color: AppColors.repAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rep['title'] ?? 'Répétition',
                        style: AppTextStyles.subtitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${rep['location'] ?? ''} · ${_fmtTime(rep['startTime'])} – ${_fmtTime(rep['endTime'])}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: CsoUi.card(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip(
                  label: 'Total',
                  value: '${summary['total']}',
                  color: AppColors.textSecondary,
                ),
                _StatChip(
                  label: 'Présents',
                  value: '${summary['present']}',
                  color: AppColors.success,
                ),
                _StatChip(
                  label: 'Absents',
                  value: '${summary['absent']}',
                  color: AppColors.warning,
                ),
                _StatChip(
                  label: 'Inconnus',
                  value: '${summary['unknown']}',
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),

        // ── Liste choristes ──
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: widget.color,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: choristes.length,
              itemBuilder: (ctx, i) {
                final c = choristes[i] as Map;
                return _ChoristePresenceTile(
                  choriste: c,
                  color: widget.color,
                  onToggle: () => _toggleStatus(c),
                  onMessage: () => _openMessageDialog(c),
                );
              },
            ),
          ),
        ),

        // ── Bouton valider ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _validated ? AppColors.success : AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _validated || _validating ? null : _validate,
              icon: _validating
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_validated ? Icons.check_circle_rounded : Icons.send_rounded),
              label: Text(
                _validated ? 'Liste envoyée ✓' : 'Valider & envoyer la liste',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return CsoUi.emptyState(
      message: _error!,
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.textMuted,
    );
  }

  String _fmtTime(dynamic raw) {
    if (raw == null) return '--:--';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return raw.toString(); }
  }

}

// ── Stat chip ─────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: AppTextStyles.caption),
    ],
  );
}

// ── Tile choriste ─────────────────────────────────────────────────────────────
class _ChoristePresenceTile extends StatelessWidget {
  final Map choriste;
  final Color color;
  final VoidCallback onToggle;
  final VoidCallback onMessage;

  const _ChoristePresenceTile({
    required this.choriste,
    required this.color,
    required this.onToggle,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final status = choriste['presenceStatus'] as String;
    final statusColor = status == 'present'
        ? AppColors.success
        : status == 'absent'
            ? AppColors.warning
            : AppColors.textMuted;
    final statusIcon  = status == 'present'
        ? Icons.check_circle_rounded
        : status == 'absent'
            ? Icons.cancel_rounded
            : Icons.help_outline_rounded;
    final statusLabel = status == 'present' ? 'Présent' : status == 'absent' ? 'Absent' : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: CsoUi.card(accent: color),
      child: Row(
        children: [
          // Avatar initiales
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${(choriste['firstName'] as String).isNotEmpty ? choriste['firstName'][0] : ''}'
                '${(choriste['lastName'] as String).isNotEmpty ? choriste['lastName'][0] : ''}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Nom + raison absence
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${choriste['firstName']} ${choriste['lastName']}',
                  style: AppTextStyles.subtitle,
                ),
                if (status == 'absent' && choriste['absenceReason'] != null)
                  Text(
                    choriste['absenceReason'],
                    style: AppTextStyles.caption.copyWith(color: AppColors.warning),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Bouton message
          GestureDetector(
            onTap: onMessage,
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.accent,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Badge statut cliquable
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, color: statusColor, size: 13),
                  const SizedBox(width: 4),
                  Text(statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet message rapide ───────────────────────────────────────────────
class _MessageBottomSheet extends StatefulWidget {
  final Map choriste;
  final Color color;
  final String? repetitionId;
  final ChefPupitreService service;

  const _MessageBottomSheet({
    required this.choriste,
    required this.color,
    required this.service,
    this.repetitionId,
  });

  @override
  State<_MessageBottomSheet> createState() => _MessageBottomSheetState();
}

class _MessageBottomSheetState extends State<_MessageBottomSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  final _quickMessages = [
    'Merci d\'être là 👍',
    'Merci pour votre présence',
    'Votre absence a été notée',
    'Merci de confirmer votre présence',
  ];

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.service.sendMessage(
        recipientIds: [widget.choriste['_id'] as String],
        content: content,
        repetitionId: widget.repetitionId,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Message envoyé à ${widget.choriste['firstName']}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // En-tête
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(
                '${widget.choriste['firstName'][0]}${widget.choriste['lastName'][0]}',
                style: TextStyle(color: widget.color, fontWeight: FontWeight.w700),
              )),
            ),
            const SizedBox(width: 12),
            Text(
              'Message à ${widget.choriste['firstName']} ${widget.choriste['lastName']}',
              style: AppTextStyles.subtitle,
            ),
          ]),
          const SizedBox(height: 14),
          // Raccourcis
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _quickMessages.map((msg) => GestureDetector(
              onTap: () => setState(() => _controller.text = msg),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(msg, style: AppTextStyles.body),
              ),
            )).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            style: AppTextStyles.subtitle,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Votre message…',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(_sending ? 'Envoi…' : 'Envoyer',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}