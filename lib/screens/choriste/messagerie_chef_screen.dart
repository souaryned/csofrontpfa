// screens/chef_pupitre/messagerie_chef_screen.dart
import 'package:flutter/material.dart';
import '../../services/chef_pupitre_service.dart';

/// Page messagerie du chef de pupitre — 2 onglets :
///   Tab 0 : Envoyer un message (sélection choriste + composition)
///   Tab 1 : Messages envoyés / reçus
class MessagerieChefScreen extends StatefulWidget {
  final String pupitre;
  final Color color;
  const MessagerieChefScreen({super.key, required this.pupitre, required this.color});

  @override
  State<MessagerieChefScreen> createState() => _MessagerieChefScreenState();
}

class _MessagerieChefScreenState extends State<MessagerieChefScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChefPupitreService _service = ChefPupitreService();

  // ── Données pour "Envoyer" ──
  bool _loadingChoristes = true;
  List<dynamic> _choristes = [];
  final Set<String> _selectedIds = {};
  final TextEditingController _messageCtrl = TextEditingController();
  bool _sending = false;

  // ── Données pour "Messages" ──
  bool _loadingMessages = true;
  List<dynamic> _messages = [];

  final List<String> _quickMessages = [
    'Rappel : répétition demain 🎵',
    'Merci pour votre présence 👏',
    'Votre absence a été notée',
    'Merci de confirmer votre présence',
    'Bien joué aujourd\'hui !',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 1) _loadMessages();
    });
    _loadChoristes();
    _loadMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  // ── FIX : utilise getChoristesForPupitre au lieu de getActiveRepetitionPresences ──
  Future<void> _loadChoristes() async {
    setState(() => _loadingChoristes = true);
    try {
      // On essaie d'abord la répétition active pour avoir les statuts de présence
      final data = await _service.getActiveRepetitionPresences();
      setState(() {
        _choristes = (data['choristes'] as List? ?? []);
        _loadingChoristes = false;
      });
    } catch (_) {
      // Pas de répétition active → on charge tous les choristes du pupitre
      try {
        final choristes = await _service.getChoristesForPupitre();
        setState(() {
          _choristes = choristes;
          _loadingChoristes = false;
        });
      } catch (e) {
        setState(() { _choristes = []; _loadingChoristes = false; });
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _loadingMessages = true);
    try {
      final msgs = await _service.getChefMessages();
      setState(() { _messages = msgs; _loadingMessages = false; });
    } catch (_) {
      setState(() { _messages = []; _loadingMessages = false; });
    }
  }

  Future<void> _sendMessage() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sélectionnez au moins un choriste'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Le message ne peut pas être vide'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _sending = true);
    try {
      await _service.sendMessage(
        recipientIds: _selectedIds.toList(),
        content: _messageCtrl.text.trim(),
      );
      setState(() {
        _selectedIds.clear();
        _messageCtrl.clear();
        _sending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ Message envoyé'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        _tabController.animateTo(1);
        _loadMessages();
      }
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
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
            const Text('Messagerie pupitre', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(_pupitreLabel(widget.pupitre), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.edit_rounded, size: 18), text: 'Envoyer'),
            Tab(icon: Icon(Icons.inbox_rounded, size: 18), text: 'Boîte'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSendTab(),
          _buildInboxTab(),
        ],
      ),
    );
  }

  // ── Tab Envoyer ───────────────────────────────────────────────────────────
  Widget _buildSendTab() {
    if (_loadingChoristes) {
      return Center(child: CircularProgressIndicator(color: widget.color));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sélection choristes ──
          _SectionLabel(label: 'Destinataires', color: widget.color),
          const SizedBox(height: 10),

          if (_choristes.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_off_rounded, color: const Color(0xFF94A3B8), size: 20),
                  const SizedBox(width: 10),
                  const Text('Aucun choriste disponible',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                ],
              ),
            )
          else ...[
            // Sélectionner tout
            GestureDetector(
              onTap: () {
                setState(() {
                  if (_selectedIds.length == _choristes.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(_choristes.map((c) => c['_id'] as String));
                  }
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.color.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedIds.length == _choristes.length
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: widget.color, size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _selectedIds.length == _choristes.length
                          ? 'Désélectionner tout'
                          : 'Sélectionner tout',
                      style: TextStyle(color: widget.color, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const Spacer(),
                    Text('${_choristes.length} choriste(s)',
                        style: TextStyle(color: widget.color.withValues(alpha: 0.6), fontSize: 12)),
                  ],
                ),
              ),
            ),
            // Liste choristes
            ..._choristes.map((c) {
              final id = c['_id'] as String;
              final selected = _selectedIds.contains(id);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) _selectedIds.remove(id);
                  else _selectedIds.add(id);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? widget.color.withValues(alpha: 0.07) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? widget.color.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: selected ? [] : [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: selected ? 0.18 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${c['firstName'][0]}${c['lastName'][0]}',
                            style: TextStyle(color: widget.color, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${c['firstName']} ${c['lastName']}',
                                style: TextStyle(
                                  color: const Color(0xFF1E293B),
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                  fontSize: 13,
                                )),
                            if (c['presenceStatus'] != null)
                              Text(
                                c['presenceStatus'] == 'present'
                                    ? '● Présent'
                                    : c['presenceStatus'] == 'absent'
                                        ? '● Absent'
                                        : '● Inconnu',
                                style: TextStyle(
                                  color: c['presenceStatus'] == 'present'
                                      ? const Color(0xFF16A34A)
                                      : c['presenceStatus'] == 'absent'
                                          ? const Color(0xFFF97316)
                                          : const Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: selected ? widget.color : const Color(0xFFCBD5E1),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 20),

          // ── Message rapide ──
          _SectionLabel(label: 'Message rapide', color: widget.color),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _quickMessages.map((msg) => GestureDetector(
              onTap: () => setState(() => _messageCtrl.text = msg),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.color.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                child: Text(msg, style: TextStyle(color: widget.color, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            )).toList(),
          ),

          const SizedBox(height: 20),

          // ── Zone de saisie ──
          _SectionLabel(label: 'Rédiger', color: widget.color),
          const SizedBox(height: 10),
          TextField(
            controller: _messageCtrl,
            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Votre message pour le pupitre…',
              hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: widget.color, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),

          // ── Bouton envoyer ──
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _sending ? null : _sendMessage,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(
                _sending ? 'Envoi en cours…' : 'Envoyer à ${_selectedIds.length} choriste(s)',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Tab Boîte (messages envoyés) ─────────────────────────────────────────
  Widget _buildInboxTab() {
    if (_loadingMessages) {
      return Center(child: CircularProgressIndicator(color: widget.color));
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_rounded, color: widget.color.withValues(alpha: 0.4), size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Aucun message', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Les messages envoyés apparaîtront ici',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      color: widget.color,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (ctx, i) => _MessageTile(msg: _messages[i] as Map, color: widget.color),
      ),
    );
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

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: const Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    ],
  );
}

// ── Message tile ─────────────────────────────────────────────────────────────
class _MessageTile extends StatelessWidget {
  final Map msg;
  final Color color;
  const _MessageTile({required this.msg, required this.color});

  @override
  Widget build(BuildContext context) {
    final recipient = msg['recipientId'] as Map?;
    final isRead    = msg['readAt'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? const Color(0xFFE2E8F0) : color.withValues(alpha: 0.3),
          width: isRead ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    recipient != null
                        ? '${recipient['firstName']?[0] ?? '?'}${recipient['lastName']?[0] ?? ''}'
                        : '?',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'À : ${recipient?['firstName'] ?? ''} ${recipient?['lastName'] ?? ''}',
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: isRead ? color : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isRead ? 'Lu' : 'Envoyé',
                    style: TextStyle(
                      color: isRead ? color : const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(msg['content'] ?? '',
              style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
          const SizedBox(height: 6),
          Text(_formatDate(msg['createdAt']),
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
        ],
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1)  return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
      if (diff.inHours   < 24) return 'Il y a ${diff.inHours}h';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Écran Messages côté CHORISTE
// ─────────────────────────────────────────────────────────────────────────────
class MessagesChoristScreen extends StatefulWidget {
  const MessagesChoristScreen({super.key});

  @override
  State<MessagesChoristScreen> createState() => _MessagesChoristScreenState();
}

class _MessagesChoristScreenState extends State<MessagesChoristScreen> {
  final ChefPupitreService _service = ChefPupitreService();
  bool _loading = true;
  List<dynamic> _messages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final msgs = await _service.getChoristMessages();
      setState(() { _messages = msgs; _loading = false; });
    } catch (_) {
      setState(() { _messages = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        surfaceTintColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        title: const Text('Messages de mon chef',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _ChoristMessageTile(msg: _messages[i] as Map),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF94A3B8), size: 48),
          ),
          const SizedBox(height: 16),
          const Text('Aucun message',
              style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 6),
          const Text("Votre chef de pupitre n'a pas\nencore envoyé de message.",
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ChoristMessageTile extends StatelessWidget {
  final Map msg;
  const _ChoristMessageTile({required this.msg});

  @override
  Widget build(BuildContext context) {
    final sender  = msg['senderId'] as Map?;
    final isRead  = msg['readAt'] != null;
    final pupitre = msg['pupitre'] as String? ?? '';
    final pColor  = _pupitreColor(pupitre);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? const Color(0xFFE2E8F0) : pColor.withValues(alpha: 0.4),
          width: isRead ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: pColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    sender != null ? '${sender['firstName']?[0] ?? '?'}' : '?',
                    style: TextStyle(color: pColor, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 11, color: const Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        Text(
                          'Chef de pupitre · ${_pupitreLabel(pupitre)}',
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${sender?['firstName'] ?? ''} ${sender?['lastName'] ?? ''}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: pColor, shape: BoxShape.circle),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(msg['content'] ?? '',
              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(_formatDate(msg['createdAt']),
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
        ],
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

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt  = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1)  return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
      if (diff.inHours   < 24) return 'Il y a ${diff.inHours}h';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}