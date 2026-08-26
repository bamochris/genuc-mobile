import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../data/models/etudiant/dashboard_data_backend.dart';
import '../../../../../data/models/etudiant/paiement.dart';
import '../../../../widgets/portail_widgets.dart';

/// Carte de bienvenue avec informations étudiant
class WelcomeCard extends StatelessWidget {
  final DashboardData dashboardData;

  const WelcomeCard({
    super.key,
    required this.dashboardData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: dashboardData.photo != null
                    ? ClipOval(
                        child: Image.network(
                          dashboardData.photo!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenue, ${_getPrenom(dashboardData.nomComplet)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dashboardData.nomComplet,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dashboardData.matricule,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.school_rounded, dashboardData.universite),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.book_rounded, dashboardData.filiere),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.calendar_today_rounded, dashboardData.promotion),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.badge_rounded, dashboardData.anneeAcademique),
                if (dashboardData.typeVacation != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    dashboardData.typeVacation == 'SOIR' ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                    dashboardData.typeVacation == 'SOIR' ? '🌙 Vacation Soir' : '☀️ Vacation Jour',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPrenom(String nomComplet) {
    final parts = nomComplet.split(' ');
    return parts.isNotEmpty ? parts[0] : 'Étudiant';
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// Carte des statistiques académiques (moyenne + crédits), équivalent du
/// bloc supérieur de la section « Progression académique » du portail web.
class StatsCard extends StatelessWidget {
  final DashboardData dashboardData;

  const StatsCard({
    super.key,
    required this.dashboardData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistiques',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  Icons.school_rounded,
                  'Moyenne',
                  '${dashboardData.moyenneGenerale.toStringAsFixed(2)}/20',
                  AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  context,
                  Icons.workspace_premium_rounded,
                  'Crédits',
                  '${dashboardData.creditsValides}',
                  AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  Icons.trending_up_rounded,
                  'Progression',
                  dashboardData.progressionFormatted,
                  AppTheme.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  context,
                  Icons.account_balance_wallet_rounded,
                  'Solde',
                  '${dashboardData.soldeAPayer.toStringAsFixed(0)} USD',
                  dashboardData.hasDebts ? AppTheme.error : AppTheme.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final accent = AppTheme.accentLisible(context, color);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section « Situation financière » : total attendu, déjà payé et reste à
/// payer, avec une jauge de couverture. Équivalent de `EtudiantDashboard.jsx`
/// (bloc Situation financière + DonutPaiement).
class SituationFinanciereCard extends StatelessWidget {
  final SituationFinanciere situation;

  const SituationFinanciereCard({
    super.key,
    required this.situation,
  });

  // Le backend ne renvoie pas la devise dans la situation : le portail web
  // la résout via `useDevise()`. On garde USD par défaut, comme l'écran
  // précédent le faisait pour le solde.
  String _montant(double valeur) =>
      '${valeur.toStringAsFixed(0)} USD'.trim();

  @override
  Widget build(BuildContext context) {
    final couleurReste = situation.totalReste > 0
        ? AppTheme.errorText
        : AppTheme.success;
    final pourcentage = situation.pourcentage.clamp(0, 100).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Situation financière',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _JaugeCirculaire(pourcentage: pourcentage),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _LigneMontant(
                      icon: Icons.receipt_long_rounded,
                      libelle: 'Total attendu',
                      valeur: _montant(situation.totalAttendu),
                      couleur: AppTheme.textPrimaryOf(context),
                    ),
                    const SizedBox(height: 10),
                    _LigneMontant(
                      icon: Icons.check_circle_rounded,
                      libelle: 'Déjà payé',
                      valeur: _montant(situation.totalPaye),
                      couleur: AppTheme.success,
                    ),
                    const SizedBox(height: 10),
                    _LigneMontant(
                      icon: situation.totalReste > 0
                          ? Icons.warning_amber_rounded
                          : Icons.verified_rounded,
                      libelle: situation.totalReste > 0
                          ? 'Reste à payer'
                          : 'Soldé ✓',
                      valeur: _montant(situation.totalReste),
                      couleur: couleurReste,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LigneMontant extends StatelessWidget {
  final IconData icon;
  final String libelle;
  final String valeur;
  final Color couleur;

  const _LigneMontant({
    required this.icon,
    required this.libelle,
    required this.valeur,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentLisible(context, couleur);

    return Row(
      children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            libelle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
        ),
        Text(
          valeur,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: accent,
              ),
        ),
      ],
    );
  }
}

/// Jauge circulaire (équivalent du `DonutPaiement` / `CircularGauge` du web).
class _JaugeCirculaire extends StatelessWidget {
  final double pourcentage;

  const _JaugeCirculaire({required this.pourcentage});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: pourcentage / 100,
            strokeWidth: 9,
            backgroundColor: AppTheme.borderOf(context),
            color: AppTheme.accentLisible(
              context,
              pourcentage >= 80
                  ? AppTheme.success
                  : pourcentage >= 50
                      ? AppTheme.info
                      : AppTheme.errorText,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${pourcentage.round()}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                ),
                Text(
                  'couverture',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 9,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section « Progression académique » : jauges crédits validés, taux de
/// présence et couverture financière — équivalent de la section homonyme du
/// portail web.
class ProgressionAcademiqueCard extends StatelessWidget {
  final DashboardData dashboardData;
  final SituationFinanciere? situation;

  const ProgressionAcademiqueCard({
    super.key,
    required this.dashboardData,
    this.situation,
  });

  @override
  Widget build(BuildContext context) {
    final creditsPct =
        (dashboardData.creditsValides / 240 * 100).clamp(0, 100).toDouble();
    final presencePct = dashboardData.stats.totalSeances > 0
        ? (dashboardData.stats.seancesSuivies /
                dashboardData.stats.totalSeances *
                100)
            .clamp(0, 100)
            .toDouble()
        : 0.0;
    final financePct = (situation?.pourcentage ??
            dashboardData.progressionGlobale.toDouble())
        .clamp(0, 100)
        .toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progression académique',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _JaugeLabel(
                pourcentage: creditsPct,
                couleur: AppTheme.primary,
                libelle: 'Crédits validés',
                valeur:
                    '${dashboardData.creditsValides} / 240',
              ),
              _JaugeLabel(
                pourcentage: presencePct,
                couleur: AppTheme.success,
                libelle: 'Taux de présence',
                valeur: '${presencePct.round()}%',
              ),
              _JaugeLabel(
                pourcentage: financePct,
                couleur: financePct >= 80
                    ? AppTheme.success
                    : AppTheme.errorText,
                libelle: 'Couverture financière',
                valeur: '${financePct.round()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JaugeLabel extends StatelessWidget {
  final double pourcentage;
  final Color couleur;
  final String libelle;
  final String valeur;

  const _JaugeLabel({
    required this.pourcentage,
    required this.couleur,
    required this.libelle,
    required this.valeur,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentLisible(context, couleur);

    return Column(
      children: [
        SizedBox(
          width: 70,
          height: 70,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: (pourcentage / 100).clamp(0, 1),
                strokeWidth: 7,
                backgroundColor: AppTheme.borderOf(context),
                color: accent,
              ),
              Center(
                child: Text(
                  '${pourcentage.round()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: accent,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          libelle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: AppTheme.textSecondaryOf(context),
              ),
        ),
        const SizedBox(height: 2),
        Text(
          valeur,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

/// Carte « Événements à venir » (prochains examens) — équivalent du bloc
/// « Événements à venir » du portail web.
class EvenementsCard extends StatelessWidget {
  final List<ExamenSimpleDto> evenements;

  const EvenementsCard({
    super.key,
    required this.evenements,
  });

  static const _moisFr = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  @override
  Widget build(BuildContext context) {
    if (evenements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Événements à venir',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...evenements.take(4).map((e) => _buildItem(context, e)),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, ExamenSimpleDto e) {
    final date = DateTime.tryParse(e.date ?? '');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderOf(context)),
        ),
      ),
      child: Row(
        children: [
          if (date != null)
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentLisible(context, AppTheme.primary)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentLisible(context, AppTheme.primary),
                    ),
                  ),
                  Text(
                    _moisFr[date.month - 1],
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.accentLisible(context, AppTheme.primary),
                    ),
                  ),
                ],
              ),
            )
          else
            Icon(
              Icons.event_rounded,
              color: AppTheme.iconAccent(context),
              size: 24,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.titre,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  e.salle == null || e.salle!.isEmpty
                      ? 'Salle à définir'
                      : e.salle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          if (e.nbJoursRestant != null)
            Text(
              e.nbJoursRestant == 0
                  ? 'Aujourd\'hui'
                  : 'J-${e.nbJoursRestant}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
            ),
        ],
      ),
    );
  }
}

/// Carte des dettes financières
class DettesCard extends StatelessWidget {
  final DashboardData dashboardData;

  const DettesCard({
    super.key,
    required this.dashboardData,
  });

  @override
  Widget build(BuildContext context) {
    if (!dashboardData.hasDebts) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Situation financière',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Solde: ${dashboardData.soldeAPayer.toStringAsFixed(0)} USD',
                  style: TextStyle(
                    color: AppTheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Vous avez un solde à payer. Veuillez régulariser votre situation financière.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte des notifications
class NotificationsCard extends StatelessWidget {
  final DashboardData dashboardData;

  const NotificationsCard({
    super.key,
    required this.dashboardData,
  });

  @override
  Widget build(BuildContext context) {
    final notifications = dashboardData.notifications;

    if (notifications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...notifications.take(3).map((notif) => _buildNotificationItem(context, notif)),
          if (notifications.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${notifications.length - 3} autres notifications',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, NotificationDto notif) {
    final isUrgent = notif.type == 'URGENT';
    final color = isUrgent ? AppTheme.error : AppTheme.info;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderOf(context),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  notif.date,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte des cours du jour
class CoursDuJourCard extends StatelessWidget {
  final DashboardData dashboardData;

  const CoursDuJourCard({
    super.key,
    required this.dashboardData,
  });

  @override
  Widget build(BuildContext context) {
    final cours = dashboardData.prochainsCours;

    if (cours.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prochains cours',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...cours.take(3).map((cours) => _buildCoursItem(context, cours)),
        ],
      ),
    );
  }

  Widget _buildCoursItem(BuildContext context, CoursSimpleDto cours) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderOf(context),
          ),
        ),
      ),
      child: Row(
        children: [
          const IconePlaque(
            icone: Icons.class_rounded,
            couleur: AppTheme.primary,
            taille: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cours.titre,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (cours.professeur != null)
                  Text(
                    cours.professeur!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (cours.progression != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${cours.progression}%',
                style: TextStyle(
                  color: AppTheme.success,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Carte d'invitation à choisir sa vacation pour les étudiants existants
class VacationChoiceCard extends StatefulWidget {
  final DashboardData dashboardData;
  final Function(int vacationId) onVacationChoisie;

  const VacationChoiceCard({
    super.key,
    required this.dashboardData,
    required this.onVacationChoisie,
  });

  @override
  State<VacationChoiceCard> createState() => _VacationChoiceCardState();
}

class _VacationChoiceCardState extends State<VacationChoiceCard> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    if (widget.dashboardData.vacationChoisie || widget.dashboardData.vacationsDisponibles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_filled_rounded, color: AppTheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choix de vacation obligatoire',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sélectionnez votre vacation (Jour / Soir) pour finaliser votre affectation de classe.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: widget.dashboardData.vacationsDisponibles.map((v) {
              final isSoir = v.type == 'SOIR';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isSoir ? Colors.indigo : Colors.amber).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isSoir ? Colors.indigo : Colors.amber).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      isSoir ? '🌙' : '☀️',
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSoir ? 'Vacation Soir' : 'Vacation Jour',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isSoir ? Colors.indigo : Colors.amber.shade900,
                            ),
                          ),
                          Text(
                            v.nom,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSoir ? Colors.indigo : AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _submitting
                          ? null
                          : () async {
                              setState(() => _submitting = true);
                              await widget.onVacationChoisie(v.id);
                              if (mounted) setState(() => _submitting = false);
                            },
                      child: Text(_submitting ? '...' : 'Choisir'),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}