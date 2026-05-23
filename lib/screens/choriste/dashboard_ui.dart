part of 'dashboard_screen.dart';

extension _DashboardUi on _DashboardScreenState {
  BoxDecoration _cardDecoration({Color? accent}) => BoxDecoration(
        color: _DashboardScreenState._surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent?.withValues(alpha: 0.12) ?? _DashboardScreenState._border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  Widget _buildLogoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: _cardDecoration(),
      child: Center(
        child: Image.asset(
          'assets/images/logo.png',
          height: 64,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildQuickStats({
    required int taux,
    required int unread,
    required int surveys,
    required int concerts,
    required int reps,
    required Color pupitreColor,
  }) {
    Widget stat(String label, String value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: _cardDecoration(accent: color),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: _DashboardScreenState._textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        stat('Sondages', '$surveys', Icons.poll_outlined,
            const Color(0xFF0D9488)),
        const SizedBox(width: 8),
        stat('Messages', '$unread', Icons.chat_bubble_outline_rounded,
            const Color(0xFF7C3AED)),
        const SizedBox(width: 8),
        stat('À venir', '${concerts + reps}', Icons.event_outlined,
            const Color(0xFFD97706)),
        const SizedBox(width: 8),
        stat('Présence', '$taux%', Icons.verified_outlined, pupitreColor),
      ],
    );
  }

  /// Bandeau unique quand aucune action en attente (sondages + messages).
  Widget _buildAllClearBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF16A34A),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Rien en attente — vous êtes à jour',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF166534),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color, {
    int badge = 0,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _DashboardScreenState._textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (badge > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$badge',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPresenceCard(int taux, String userId, Color color) {
    Color statusColor;
    String label;
    IconData icon;

    if (taux >= 80) {
      statusColor = const Color(0xFF16A34A);
      label = 'Excellente assiduité';
      icon = Icons.emoji_events_outlined;
    } else if (taux >= 60) {
      statusColor = const Color(0xFFD97706);
      label = 'Assiduité correcte';
      icon = Icons.trending_up_rounded;
    } else {
      statusColor = const Color(0xFFDC2626);
      label = 'À améliorer';
      icon = Icons.info_outline_rounded;
    }

    int total = 0, present = 0;
    for (final r in _allRepetitions) {
      final d = _parseDate(r['date']);
      if (d == null || d.isAfter(DateTime.now())) continue;
      total++;
      if (_repStatus(r, userId) == 'present') present++;
    }

    return GestureDetector(
      onTap: _openPresencesTab,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(accent: color),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.08),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      value: taux / 100,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  Text(
                    '$taux%',
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$present sur $total répétition${total > 1 ? 's' : ''} assistée${present > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: _DashboardScreenState._textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Voir le détail →',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesSection(dynamic user, Color pColor) {
    final unread = _messages.where((m) => m['readAt'] == null).toList();

    return Column(
      children: [
        ...unread.take(3).map((msg) {
          final sender = msg['senderId'] as Map?;
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesChoristScreen()),
            ).then((_) => _loadDashboard()),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(accent: pColor),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: pColor.withValues(alpha: 0.12),
                    child: Text(
                      '${sender?['firstName']?[0] ?? '?'}',
                      style: TextStyle(
                        color: pColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${sender?['firstName'] ?? ''} ${sender?['lastName'] ?? ''}'
                              .trim(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _DashboardScreenState._textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['content'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _DashboardScreenState._textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: pColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatMsgDate(msg['createdAt']),
                        style: const TextStyle(
                          fontSize: 10,
                          color: _DashboardScreenState._textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (unread.length > 3)
          _buildSeeAllButton(
            'Voir tous les messages',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesChoristScreen()),
            ).then((_) => _loadDashboard()),
            pColor,
          ),
      ],
    );
  }

  Widget _buildSurveysSection(Color accent) {
    final items = <Widget>[
      ..._pendingSurveys.take(3).map((survey) {
        return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurveyDetailScreen(survey: survey),
          ),
        ).then((_) => _loadDashboard()),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(accent: const Color(0xFF0D9488)),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.poll_outlined,
                  color: Color(0xFF0D9488),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      survey.titre,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _DashboardScreenState._textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (survey.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        survey.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _DashboardScreenState._textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: const Text(
                        'Réponse requise',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFC2410C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _DashboardScreenState._textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      );
      }),
    ];

    if (_pendingSurveys.length > 3) {
      items.add(
        _buildSeeAllButton(
          'Voir tous les sondages',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SondagesScreen()),
          ).then((_) => _loadDashboard()),
          const Color(0xFF0D9488),
        ),
      );
    }

    return Column(children: items);
  }

  Widget _buildConcertsSection(List<dynamic> concerts, String userId) {
    void openProgramme() => HomeScreen.of(context)?.selectTab(2);

    return Column(
      children: [
        for (var i = 0; i < concerts.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          if (i == 0)
            Builder(
              builder: (context) {
                final status =
                    ConcertCards.availabilityStatus(concerts[i], userId);
                return ConcertFeaturedCard(
                  concert: concerts[i],
                  height: 188,
                  onTap: openProgramme,
                  topRightLabel: status.label,
                  topRightTextColor: Colors.white,
                  topRightBackground: status.color,
                );
              },
            )
          else
            ConcertCompactCard(
              concert: concerts[i],
              onTap: openProgramme,
            ),
        ],
        if (concerts.length >= 2) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: openProgramme,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Voir tout le programme'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFBE185D),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRepetitionsSection(List<dynamic> reps, String userId) {
    return Column(
      children: reps.map((rep) {
        final d = _parseDate(rep['date']);
        final isToday = d != null && _isSameDay(d, DateTime.now());
        final repId = rep['_id'].toString();
        final reminders = _getReminders(repId);
        final hasReminders = reminders.isNotEmpty;

        return GestureDetector(
          onTap: _openPresencesTab,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(
              accent: isToday
                  ? const Color(0xFFD97706)
                  : const Color(0xFFE8ECF4),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.library_music_outlined,
                    color: Color(0xFFD97706),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Répétition',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _DashboardScreenState._textPrimary,
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Aujourd\'hui',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (rep['concert']?['title'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          rep['concert']['title'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: _DashboardScreenState._textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${_formatDate(rep['date'])} · ${rep['startTime'] ?? ''} – ${rep['endTime'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _DashboardScreenState._textSecondary,
                        ),
                      ),
                      if (rep['location'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          rep['location'],
                          style: const TextStyle(
                            fontSize: 11,
                            color: _DashboardScreenState._textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (hasReminders) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: reminders
                              .map((m) => _inlineReminderBadge(m))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showReminderSheet(context, rep),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasReminders
                          ? _DashboardScreenState._accent
                              .withValues(alpha: 0.1)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      hasReminders
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_outlined,
                      size: 18,
                      color: hasReminders
                          ? _DashboardScreenState._accent
                          : _DashboardScreenState._textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: _cardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color.withValues(alpha: 0.45)),
          const SizedBox(width: 10),
          Text(
            message,
            style: const TextStyle(
              color: _DashboardScreenState._textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeeAllButton(String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
