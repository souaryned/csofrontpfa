import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'cso_ui.dart';

/// Cartes concert partagées (Programme + Dashboard).
abstract final class ConcertCards {
  static const monthsShort = [
    '',
    'JAN',
    'FÉV',
    'MAR',
    'AVR',
    'MAI',
    'JUN',
    'JUL',
    'AOÛ',
    'SEP',
    'OCT',
    'NOV',
    'DÉC',
  ];

  static const monthsLong = [
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

  static const days = [
    '',
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];

  static DateTime? parseDate(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  static int? daysUntil(dynamic concert) {
    final d = parseDate(concert['dateHeure']);
    if (d == null) return null;
    final today = DateTime.now();
    final eventDay = DateTime(d.year, d.month, d.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    return eventDay.difference(todayOnly).inDays;
  }

  static String formatDateLong(dynamic raw) {
    final date = parseDate(raw);
    if (date == null) return '';
    final hour = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '${days[date.weekday]} ${date.day} ${monthsLong[date.month]} ${date.year} · $hour:$min';
  }

  static String titleCase(String? title) {
    if (title == null || title.isEmpty) return 'Concert';
    final t = title.trim();
    if (t.isEmpty) return 'Concert';
    return t[0].toUpperCase() + t.substring(1);
  }

  static String buildPosterUrl(String? poster) {
    if (poster == null || poster.trim().isEmpty) return '';
    if (poster.startsWith('http://') || poster.startsWith('https://')) {
      return poster;
    }
    if (poster.startsWith('/uploads')) {
      return '${ApiConfig.baseUrl}$poster';
    }
    if (poster.contains('.')) {
      return '${ApiConfig.baseUrl}/uploads/posters/$poster';
    }
    return '';
  }

  /// Disponibilité choriste pour un concert (dashboard).
  static ({String label, Color color}) availabilityStatus(
    dynamic concert,
    String userId,
  ) {
    final dispo = (concert['availableChoristes'] as List?)?.any(
          (c) => (c['_id'] ?? c) == userId,
        ) ??
        false;
    final indispo = (concert['absentChoristes'] as List?)?.any(
          (a) => (a['choriste']?['_id'] ?? a) == userId,
        ) ??
        false;

    if (dispo) {
      return (label: 'Disponible', color: AppColors.success);
    }
    if (indispo) {
      return (label: 'Indisponible', color: AppColors.error);
    }
    return (label: 'À confirmer', color: AppColors.warning);
  }
}

class ConcertFeaturedCard extends StatelessWidget {
  const ConcertFeaturedCard({
    super.key,
    required this.concert,
    this.onTap,
    this.height = 200,
    this.topRightLabel,
    this.topRightTextColor,
    this.topRightBackground,
  });

  final dynamic concert;
  final VoidCallback? onTap;
  final double height;
  final String? topRightLabel;
  final Color? topRightTextColor;
  final Color? topRightBackground;

  @override
  Widget build(BuildContext context) {
    final posterUrl = ConcertCards.buildPosterUrl(concert['poster'] as String?);
    final hasPoster = posterUrl.isNotEmpty;
    final date = ConcertCards.parseDate(concert['dateHeure']);
    final days = ConcertCards.daysUntil(concert);
    final cornerLabel = topRightLabel ?? 'À venir';
    final cornerText = topRightTextColor ?? Colors.white;
    final cornerBg =
        topRightBackground ?? AppColors.concertAccent.withValues(alpha: 0.9);

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.concertAccent.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPoster)
                Image.network(
                  posterUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _PosterFallback(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const _PosterFallback(loading: true);
                  },
                )
              else
                const _PosterFallback(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
              if (days != null && days >= 0)
                Positioned(
                  top: 14,
                  left: 14,
                  child: _CountdownBadge(days: days),
                ),
              Positioned(
                top: 14,
                right: 14,
                child: CsoUi.statusBadge(cornerLabel, cornerText, cornerBg),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ConcertCards.titleCase(concert['title'] as String?),
                      style: AppTextStyles.title.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (date != null) ...[
                      const SizedBox(height: 8),
                      _InfoChip(
                        icon: Icons.schedule_rounded,
                        text: ConcertCards.formatDateLong(concert['dateHeure']),
                        onDark: true,
                      ),
                    ],
                    if (concert['location'] != null &&
                        concert['location'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _InfoChip(
                        icon: Icons.place_rounded,
                        text: concert['location'].toString(),
                        onDark: true,
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

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

class ConcertCompactCard extends StatelessWidget {
  const ConcertCompactCard({
    super.key,
    required this.concert,
    this.isPast = false,
    this.onTap,
  });

  final dynamic concert;
  final bool isPast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final date = ConcertCards.parseDate(concert['dateHeure']);
    final posterUrl = ConcertCards.buildPosterUrl(concert['poster'] as String?);
    final hasPoster = posterUrl.isNotEmpty;
    final days = ConcertCards.daysUntil(concert);
    final accent =
        isPast ? AppColors.textMuted : AppColors.concertAccent;

    final card = Opacity(
      opacity: isPast ? 0.72 : 1,
      child: Container(
        decoration: CsoUi.card(accent: accent),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DateColumn(date: date, isPast: isPast),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ConcertCards.titleCase(concert['title'] as String?),
                              style: AppTextStyles.subtitle.copyWith(
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CsoUi.statusBadge(
                            isPast ? 'Passé' : 'À venir',
                            isPast ? AppColors.textSecondary : Colors.white,
                            isPast ? AppColors.border : AppColors.concertAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!isPast && days != null && days >= 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            days == 0
                                ? "Aujourd'hui"
                                : days == 1
                                    ? 'Demain'
                                    : 'Dans $days jours',
                            style: AppTextStyles.accent(AppColors.concertAccent),
                          ),
                        ),
                      if (date != null)
                        _InfoChip(
                          icon: Icons.schedule_outlined,
                          text: ConcertCards.formatDateLong(
                            concert['dateHeure'],
                          ),
                        ),
                      if (concert['location'] != null &&
                          concert['location'].toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _InfoChip(
                          icon: Icons.place_outlined,
                          text: concert['location'].toString(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (hasPoster)
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(16),
                  ),
                  child: Image.network(
                    posterUrl,
                    width: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _MiniPosterFallback(isPast: isPast),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return _MiniPosterFallback(isPast: isPast);
                    },
                  ),
                )
              else
                _MiniPosterFallback(isPast: isPast),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

class _DateColumn extends StatelessWidget {
  const _DateColumn({required this.date, required this.isPast});

  final DateTime? date;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final accent =
        isPast ? AppColors.textMuted : AppColors.concertAccent;
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (date != null) ...[
            Text(
              '${date!.day}',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: accent,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              ConcertCards.monthsShort[date!.month],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent.withValues(alpha: 0.8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date!.year}',
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ] else
            Icon(Icons.event_busy_outlined, color: accent, size: 28),
        ],
      ),
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_outlined,
            size: 16,
            color: AppColors.concertAccent,
          ),
          const SizedBox(width: 6),
          Text(
            days == 0 ? "Aujourd'hui" : 'J-$days',
            style: AppTextStyles.label.copyWith(
              color: AppColors.concertAccent,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
    this.onDark = false,
  });

  final IconData icon;
  final String text;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: onDark
              ? Colors.white.withValues(alpha: 0.9)
              : AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: onDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : AppColors.textSecondary,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF500724), Color(0xFF831843), Color(0xFFBE185D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: loading
            ? const CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 2,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.music_note_rounded,
                    size: 48,
                    color: Colors.white38,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Carthage Symphony Orchestra',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MiniPosterFallback extends StatelessWidget {
  const _MiniPosterFallback({required this.isPast});

  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final color =
        isPast ? AppColors.textMuted : AppColors.concertAccent;
    return Container(
      width: 88,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.35),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: color.withValues(alpha: 0.6),
        size: 28,
      ),
    );
  }
}
