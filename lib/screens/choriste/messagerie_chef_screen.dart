// screens/chef_pupitre/messagerie_chef_screen.dart
import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../services/chef_pupitre_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/cso_ui.dart';

/// Messagerie chef de pupitre — envoyer + boîte d'envoi.
class MessagerieChefScreen extends StatefulWidget {
  final String pupitre;
  final Color color;
  final bool embedded;

  const MessagerieChefScreen({
    super.key,
    required this.pupitre,
    required this.color,
    this.embedded = false,
  });

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Message envoyé'),
          backgroundColor: AppColors.success,
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
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Widget _tabBar() {
    return Material(
      color: AppColors.surface,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(icon: Icon(Icons.edit_outlined, size: 18), text: 'Envoyer'),
          Tab(icon: Icon(Icons.inbox_outlined, size: 18), text: 'Boîte'),
        ],
      ),
    );
  }

  Widget _tabBody() {
    return TabBarView(
      controller: _tabController,
      children: [_buildSendTab(), _buildInboxTab()],
    );
  }

  PreferredSizeWidget? get _standaloneAppBar => widget.embedded
      ? null
      : AppBar(
          title: Row(
            children: [
              const Text('Messagerie pupitre'),
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
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.edit_outlined, size: 18), text: 'Envoyer'),
              Tab(icon: Icon(Icons.inbox_outlined, size: 18), text: 'Boîte'),
            ],
          ),
        );

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return CsoUi.screenBody(
        child: Column(
          children: [
            _tabBar(),
            Expanded(child: _tabBody()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _standaloneAppBar,
      body: _tabBody(),
    );
  }

  // ── Tab Envoyer ───────────────────────────────────────────────────────────
  Widget _buildSendTab() {
    if (_loadingChoristes) {
      return CsoUi.loading();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sélection choristes ──
          _SectionLabel(label: 'Destinataires', color: widget.color),
          const SizedBox(height: 10),

          if (_choristes.isEmpty)
            CsoUi.emptyState(
              message: 'Aucun choriste disponible',
              icon: Icons.person_off_outlined,
              iconColor: AppColors.textMuted,
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
                  if (selected) {
                    _selectedIds.remove(id);
                  } else {
                    _selectedIds.add(id);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: CsoUi.card(
                    accent: selected ? widget.color : null,
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
                            Text(
                              '${c['firstName']} ${c['lastName']}',
                              style: AppTextStyles.subtitle.copyWith(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: selected ? widget.color : AppColors.textMuted,
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
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Votre message pour le pupitre…',
            ),
          ),
          const SizedBox(height: 16),

          // ── Bouton envoyer ──
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

  // ── Tab Boîte (messages envoyés, groupés par destinataire) ───────────────
  List<_MessageThread> _threadsFromMessages() {
    final byRecipient = <String, List<Map>>{};
    for (final raw in _messages) {
      final msg = raw as Map;
      final recipient = msg['recipientId'] as Map?;
      final id = recipient?['_id']?.toString() ?? '_unknown';
      byRecipient.putIfAbsent(id, () => []).add(msg);
    }

    final threads = byRecipient.entries.map((e) {
      final msgs = List<Map>.from(e.value)
        ..sort((a, b) => _messageDate(b).compareTo(_messageDate(a)));
      return _MessageThread(
        recipientId: e.key,
        recipient: msgs.first['recipientId'] as Map? ?? {},
        messages: msgs,
      );
    }).toList();

    threads.sort(
      (a, b) => _messageDate(b.latest).compareTo(_messageDate(a.latest)),
    );
    return threads;
  }

  void _openThread(BuildContext context, _MessageThread thread) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ThreadDetailSheet(thread: thread, color: widget.color),
    );
  }

  Widget _buildInboxTab() {
    if (_loadingMessages) {
      return CsoUi.loading();
    }

    if (_messages.isEmpty) {
      return CsoUi.emptyState(
        message: 'Les messages envoyés apparaîtront ici',
        icon: Icons.inbox_outlined,
        iconColor: widget.color,
      );
    }

    final threads = _threadsFromMessages();

    return RefreshIndicator(
      onRefresh: _loadMessages,
      color: AppColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: threads.length,
        itemBuilder: (ctx, i) => _RecipientThreadTile(
          thread: threads[i],
          color: widget.color,
          onTap: () => _openThread(context, threads[i]),
        ),
      ),
    );
  }

}

DateTime _messageDate(Map msg) {
  try {
    return DateTime.parse(msg['createdAt'].toString()).toLocal();
  } catch (_) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

String _formatMessageDate(dynamic raw) {
  if (raw == null) return '';
  try {
    final dt = DateTime.parse(raw.toString()).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

class _MessageThread {
  final String recipientId;
  final Map recipient;
  final List<Map> messages;

  const _MessageThread({
    required this.recipientId,
    required this.recipient,
    required this.messages,
  });

  Map get latest => messages.first;

  int get count => messages.length;

  int get unreadCount =>
      messages.where((m) => m['readAt'] == null).length;

  bool get allRead => unreadCount == 0;
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
      Text(
        label,
        style: AppTextStyles.label.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    ],
  );
}

// ── Fil groupé par destinataire (liste) ───────────────────────────────────────
class _RecipientThreadTile extends StatelessWidget {
  final _MessageThread thread;
  final Color color;
  final VoidCallback onTap;

  const _RecipientThreadTile({
    required this.thread,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = thread.recipient;
    final latest = thread.latest;
    final preview = (latest['content'] ?? '').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: CsoUi.card(accent: thread.allRead ? null : color),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${r['firstName']?[0] ?? '?'}${r['lastName']?[0] ?? ''}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${r['firstName'] ?? ''} ${r['lastName'] ?? ''}',
                            style: AppTextStyles.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatMessageDate(latest['createdAt']),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      style: AppTextStyles.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (thread.count > 1) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${thread.count} messages',
                              style: AppTextStyles.label.copyWith(color: color),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            thread.allRead
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            size: 14,
                            color: thread.allRead ? color : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            thread.allRead ? 'Tout lu' : 'En attente',
                            style: AppTextStyles.label.copyWith(
                              color: thread.allRead
                                  ? color
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            latest['readAt'] != null
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            size: 14,
                            color: latest['readAt'] != null
                                ? color
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            latest['readAt'] != null ? 'Lu' : 'Envoyé',
                            style: AppTextStyles.label.copyWith(
                              color: latest['readAt'] != null
                                  ? color
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Détail d'une conversation (bottom sheet) ──────────────────────────────────
class _ThreadDetailSheet extends StatelessWidget {
  final _MessageThread thread;
  final Color color;

  const _ThreadDetailSheet({
    required this.thread,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final r = thread.recipient;
    final maxH = MediaQuery.of(context).size.height * 0.72;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Text(
                        '${r['firstName']?[0] ?? '?'}${r['lastName']?[0] ?? ''}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r['firstName'] ?? ''} ${r['lastName'] ?? ''}',
                          style: AppTextStyles.subtitle,
                        ),
                        Text(
                          '${thread.count} message${thread.count > 1 ? 's' : ''} envoyé${thread.count > 1 ? 's' : ''}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: thread.messages.length,
                itemBuilder: (ctx, i) {
                  final msg = thread.messages[i];
                  final isRead = msg['readAt'] != null;
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(ctx).size.width * 0.82,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(4),
                        ),
                        border: Border.all(
                          color: color.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            msg['content'] ?? '',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatMessageDate(msg['createdAt']),
                                style: AppTextStyles.caption,
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                isRead
                                    ? Icons.done_all_rounded
                                    : Icons.done_rounded,
                                size: 14,
                                color: isRead ? color : AppColors.textMuted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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

  List<_ChoristSenderThread> get _choristThreads =>
      _choristThreadsFromMessages(_messages);

  void _openConversation(_ChoristSenderThread thread) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChoristConversationScreen(thread: thread),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final threads = _choristThreads;
    final single = threads.length == 1 ? threads.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          single?.displayName ?? 'Messages de mon chef',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? CsoUi.loading()
          : _messages.isEmpty
              ? CsoUi.emptyState(
                  message:
                      "Votre chef de pupitre n'a pas encore envoyé de message.",
                  icon: Icons.mark_chat_unread_outlined,
                  iconColor: AppColors.messageAccent,
                )
              : single != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ChoristChefProfileHeader(thread: single),
                        Expanded(
                          child: _ChoristConversationView(thread: single),
                        ),
                      ],
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.accent,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        itemCount: threads.length,
                        itemBuilder: (ctx, i) => _ChoristInboxTile(
                          thread: threads[i],
                          onTap: () => _openConversation(threads[i]),
                        ),
                      ),
                    ),
    );
  }
}

List<_ChoristSenderThread> _choristThreadsFromMessages(List<dynamic> raw) {
  final bySender = <String, List<Map>>{};
  for (final item in raw) {
    final msg = item as Map;
    final sender = msg['senderId'] as Map?;
    final id = sender?['_id']?.toString() ?? '_unknown';
    bySender.putIfAbsent(id, () => []).add(msg);
  }

  final threads = bySender.entries.map((e) {
    final msgs = List<Map>.from(e.value)
      ..sort((a, b) => _messageDate(b).compareTo(_messageDate(a)));
    return _ChoristSenderThread(
      sender: msgs.first['senderId'] as Map? ?? {},
      pupitre: msgs.first['pupitre'] as String? ?? '',
      messages: msgs,
    );
  }).toList();

  threads.sort(
    (a, b) =>
        _messageDate(b.messages.first).compareTo(_messageDate(a.messages.first)),
  );
  return threads;
}

class _ChoristSenderThread {
  final Map sender;
  final String pupitre;
  final List<Map> messages;

  const _ChoristSenderThread({
    required this.sender,
    required this.pupitre,
    required this.messages,
  });

  Map get latest => messages.first;

  int get unreadCount =>
      messages.where((m) => m['readAt'] == null).length;

  bool get hasUnread => unreadCount > 0;

  String get displayName {
    final n =
        '${sender['firstName'] ?? ''} ${sender['lastName'] ?? ''}'.trim();
    return n.isEmpty ? 'Chef de pupitre' : n;
  }
}

/// Ligne inbox (aperçu) — un chef = ouverture directe en conversation.
class _ChoristInboxTile extends StatelessWidget {
  final _ChoristSenderThread thread;
  final VoidCallback onTap;

  const _ChoristInboxTile({
    required this.thread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pColor = AppColors.pupitre(thread.pupitre);
    final latest = thread.latest;
    final preview = (latest['content'] ?? '').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: CsoUi.card(accent: thread.hasUnread ? pColor : null),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: pColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${thread.sender['firstName']?[0] ?? '?'}',
                    style: TextStyle(
                      color: pColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.displayName,
                            style: AppTextStyles.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatMessageDate(latest['createdAt']),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chef · ${AppColors.pupitreLabel(thread.pupitre)}',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preview,
                      style: AppTextStyles.body.copyWith(
                        fontWeight:
                            thread.hasUnread ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (thread.hasUnread)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${thread.unreadCount}',
                    style: AppTextStyles.label.copyWith(color: Colors.white),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Écran conversation plein (style messagerie).
class _ChoristConversationScreen extends StatelessWidget {
  final _ChoristSenderThread thread;

  const _ChoristConversationScreen({required this.thread});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(thread.displayName),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChoristChefProfileHeader(thread: thread),
          Expanded(child: _ChoristConversationView(thread: thread)),
        ],
      ),
    );
  }
}

/// Bandeau identité du chef de pupitre.
class _ChoristChefProfileHeader extends StatelessWidget {
  final _ChoristSenderThread thread;

  const _ChoristChefProfileHeader({required this.thread});

  @override
  Widget build(BuildContext context) {
    final sender = thread.sender;
    final pupitre = thread.pupitre.isNotEmpty
        ? thread.pupitre
        : (sender['pupitre'] as String? ?? '');
    final pColor = AppColors.pupitre(pupitre);
    final avatarPath = sender['avatar'] as String?;
    final avatarUrl = avatarPath != null && avatarPath.isNotEmpty
        ? '${ApiConfig.baseUrl}$avatarPath'
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            pColor.withValues(alpha: 0.12),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: pColor.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarImage(
            avatarUrl: avatarUrl,
            fullName: thread.displayName,
            radius: 30,
            backgroundColor: pColor.withValues(alpha: 0.15),
            textColor: pColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 14, color: pColor),
                    const SizedBox(width: 4),
                    Text(
                      'Chef de pupitre',
                      style: AppTextStyles.label.copyWith(color: pColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  thread.displayName,
                  style: AppTextStyles.title.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _infoChip(
                      Icons.music_note_rounded,
                      AppColors.pupitreLabel(pupitre),
                      pColor,
                    ),
                    _infoChip(
                      Icons.forum_outlined,
                      '${thread.messages.length} message${thread.messages.length > 1 ? 's' : ''}',
                      AppColors.textSecondary,
                    ),
                    if (thread.hasUnread)
                      _infoChip(
                        Icons.mark_chat_unread_outlined,
                        '${thread.unreadCount} non lu${thread.unreadCount > 1 ? 's' : ''}',
                        AppColors.error,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTextStyles.label.copyWith(
              color: color,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoristConversationView extends StatefulWidget {
  final _ChoristSenderThread thread;

  const _ChoristConversationView({required this.thread});

  @override
  State<_ChoristConversationView> createState() =>
      _ChoristConversationViewState();
}

class _ChoristConversationViewState extends State<_ChoristConversationView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  _ChoristSenderThread get thread => widget.thread;

  static const _months = [
    '',
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return 'Aujourd\'hui';
    if (day == today.subtract(const Duration(days: 1))) return 'Hier';
    return '${dt.day} ${_months[dt.month]} ${dt.year}';
  }

  String _timeLabel(dynamic raw) {
    final dt = _messageDate({'createdAt': raw});
    if (dt.millisecondsSinceEpoch == 0) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  bool _sameGroup(DateTime a, DateTime b) {
    return a.difference(b).inMinutes.abs() <= 10;
  }

  List<_ChoristChatItem> _chatItems() {
    final sorted = List<Map>.from(thread.messages)
      ..sort((a, b) => _messageDate(a).compareTo(_messageDate(b)));

    final items = <_ChoristChatItem>[];
    DateTime? lastDay;
    List<Map>? currentGroup;

    void flushGroup() {
      if (currentGroup != null && currentGroup!.isNotEmpty) {
        items.add(_ChoristChatItem.group(currentGroup!));
        currentGroup = null;
      }
    }

    for (final msg in sorted) {
      final dt = _messageDate(msg);
      final day = DateTime(dt.year, dt.month, dt.day);
      if (lastDay == null || day != lastDay) {
        flushGroup();
        items.add(_ChoristChatItem.date(_dateLabel(dt)));
        lastDay = day;
      }

      if (currentGroup == null || currentGroup!.isEmpty) {
        currentGroup = [msg];
      } else {
        final lastDt = _messageDate(currentGroup!.last);
        if (_sameGroup(dt, lastDt)) {
          currentGroup!.add(msg);
        } else {
          flushGroup();
          currentGroup = [msg];
        }
      }
    }
    flushGroup();
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final pupitre = thread.pupitre.isNotEmpty
        ? thread.pupitre
        : (thread.sender['pupitre'] as String? ?? '');
    final pColor = AppColors.pupitre(pupitre);
    final sender = thread.sender;
    final avatarPath = sender['avatar'] as String?;
    final avatarUrl = avatarPath != null && avatarPath.isNotEmpty
        ? '${ApiConfig.baseUrl}$avatarPath'
        : null;
    final items = _chatItems();

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 24),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        if (item.isDate) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  item.dateLabel!,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }

        final group = item.messages!;
        final hasUnread = group.any((m) => m['readAt'] == null);
        final lastMsg = group.last;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: AvatarImage(
                  avatarUrl: avatarUrl,
                  fullName: thread.displayName,
                  radius: 16,
                  backgroundColor: pColor.withValues(alpha: 0.12),
                  textColor: pColor,
                ),
              ),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(ctx).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: hasUnread
                        ? pColor.withValues(alpha: 0.07)
                        : AppColors.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(
                      color: hasUnread
                          ? pColor.withValues(alpha: 0.2)
                          : AppColors.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var j = 0; j < group.length; j++) ...[
                        if (j > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Divider(
                              height: 1,
                              color: AppColors.border.withValues(alpha: 0.8),
                            ),
                          ),
                        Text(
                          group[j]['content'] ?? '',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _timeLabel(lastMsg['createdAt']),
                          style: AppTextStyles.caption.copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChoristChatItem {
  final bool isDate;
  final String? dateLabel;
  final List<Map>? messages;

  const _ChoristChatItem._({
    required this.isDate,
    this.dateLabel,
    this.messages,
  });

  factory _ChoristChatItem.date(String label) =>
      _ChoristChatItem._(isDate: true, dateLabel: label);

  factory _ChoristChatItem.group(List<Map> msgs) =>
      _ChoristChatItem._(isDate: false, messages: msgs);
}