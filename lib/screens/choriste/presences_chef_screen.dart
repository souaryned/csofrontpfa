// screens/chef_pupitre/presences_chef_screen.dart
import 'package:flutter/material.dart';
import '../../services/chef_pupitre_service.dart';

/// Page autonome : présences de la répétition en cours
class PresencesChefScreen extends StatefulWidget {
  final String pupitre;
  final Color color;
  const PresencesChefScreen({super.key, required this.pupitre, required this.color});

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
          backgroundColor: newStatus == 'present' ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Raison de l'absence",
            style: TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: 'Ex : Congé médical…',
            hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: const Color(0xFFE2E8F0))),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: widget.color, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF94A3B8))),
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
      backgroundColor: Colors.white,
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Valider la liste ?',
            style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w700)),
        content: const Text(
          'La liste sera envoyée au chef de chœur avec les présences et absences de votre pupitre.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
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
          content: Text('✅ Liste validée et envoyée au chef de chœur'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      setState(() => _validating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── FOND CLAIR ──
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Présences répétition',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(_pupitreLabel(widget.pupitre),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: widget.color))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final rep      = _data!['repetition'] as Map;
    final choristes = _data!['choristes'] as List;
    final summary  = _data!['summary'] as Map;

    return Column(
      children: [
        // ── Carte répétition ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: Colors.white,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.music_note_rounded, color: widget.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rep['title'] ?? 'Répétition',
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      '${rep['location'] ?? ''} · ${_fmtTime(rep['startTime'])} – ${_fmtTime(rep['endTime'])}',
                      style: TextStyle(color: widget.color, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: const Color(0xFFE2E8F0)),

        // ── Résumé chiffres ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(label: 'Total',    value: '${summary['total']}',   color: const Color(0xFF64748B)),
              _StatChip(label: 'Présents', value: '${summary['present']}', color: const Color(0xFF16A34A)),
              _StatChip(label: 'Absents',  value: '${summary['absent']}',  color: const Color(0xFFF97316)),
              _StatChip(label: 'Inconnus', value: '${summary['unknown']}', color: const Color(0xFF94A3B8)),
            ],
          ),
        ),
        Container(height: 1, color: const Color(0xFFE2E8F0)),

        // ── Liste choristes ──
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: widget.color,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _validated ? const Color(0xFF16A34A) : widget.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.info_outline_rounded, color: const Color(0xFF94A3B8), size: 40),
            ),
            const SizedBox(height: 20),
            Text(_error!,
                style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(dynamic raw) {
    if (raw == null) return '--:--';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return raw.toString(); }
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
      Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
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
        ? const Color(0xFF16A34A)
        : status == 'absent'
            ? const Color(0xFFF97316)
            : const Color(0xFF94A3B8);
    final statusIcon  = status == 'present'
        ? Icons.check_circle_rounded
        : status == 'absent'
            ? Icons.cancel_rounded
            : Icons.help_outline_rounded;
    final statusLabel = status == 'present' ? 'Présent' : status == 'absent' ? 'Absent' : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 5, offset: const Offset(0, 1)),
        ],
      ),
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
                Text('${choriste['firstName']} ${choriste['lastName']}',
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    )),
                if (status == 'absent' && choriste['absenceReason'] != null)
                  Text(
                    choriste['absenceReason'],
                    style: const TextStyle(color: Color(0xFFF97316), fontSize: 11),
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
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, color: const Color(0xFF64748B), size: 16),
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
          backgroundColor: Colors.green,
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
                color: const Color(0xFFE2E8F0),
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
              style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w700, fontSize: 14),
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
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(msg, style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            style: const TextStyle(color: Color(0xFF1E293B)),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Votre message…',
              hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.color, width: 1.5),
              ),
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