import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/professeur/professeur_models.dart';
import '../../../domain/entities/user.dart';
import '../../navigation/portail_shell.dart';
import '../../providers/auth_provider.dart';
import '../../providers/professeur_provider.dart';
import '../../widgets/portail_widgets.dart';

/// Tableau de bord du professeur.
///
/// Reproduit la présentation de `ProfesseurDashboard.jsx` (genuc-frontend) :
/// carte de bienvenue avec la date du jour, statistiques clés (cours
/// attribués, étudiants, taux de présence, notes à corriger), emploi du temps
/// du jour, alertes & actions urgentes, puis actions rapides. Toutes les
/// données viennent du backend via [ProfesseurProvider] — aucune donnée
/// fictive.
class ProfesseurDashboardScreen extends StatefulWidget {
  final User user;

  const ProfesseurDashboardScreen({super.key, required this.user});

  @override
  State<ProfesseurDashboardScreen> createState() =>
      _ProfesseurDashboardScreenState();
}

class _ProfesseurDashboardScreenState extends State<ProfesseurDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Après la frame : `ProfesseurProvider` notifie dès l'entrée de
    // `loadDashboard`, ce qui pendant la construction lève « setState()
    // called during build ».
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final provider = context.read<ProfesseurProvider>();
    final professeurId = widget.user.id;
    if (professeurId != null && professeurId.isNotEmpty) {
      await provider.loadDashboard(professeurId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfesseurProvider>();

    // `PagePortail` et non un `GenucScaffold` nu : c'est par lui que la page
    // reçoit le tiroir, la barre basse et les actions globales du portail
    // (dont la bascule de thème, désormais posée une seule fois par le shell).
    return PagePortail(
      titre: 'Tableau de bord',
      onRafraichir: _charger,
      corps: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
              ? _ErreurState(message: provider.error!, onRetry: _charger)
              : _ContenuDashboard(
                  stats: provider.stats,
                  presences: provider.presences,
                  scheduleToday: provider.scheduleToday,
                  alertes: provider.alertes,
                ),
    );
  }
}

class _ContenuDashboard extends StatelessWidget {
  final StatsProfesseur? stats;
  final ResumePresences? presences;
  final List<SeanceProfesseur> scheduleToday;
  final List<AlerteProfesseur> alertes;

  const _ContenuDashboard({
    required this.stats,
    required this.presences,
    required this.scheduleToday,
    required this.alertes,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final provider = context.read<ProfesseurProvider>();
        final auth = context.read<AuthProvider>();
        final id = auth.user?.id;
        if (id != null && id.isNotEmpty) {
          await provider.loadDashboard(id);
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CarteBienvenue(),
          const SizedBox(height: 24),
          _StatsSection(stats: stats, presences: presences),
          const SizedBox(height: 24),
          _ScheduleSection(seances: scheduleToday),
          const SizedBox(height: 24),
          _AlertesSection(alertes: alertes),
          const SizedBox(height: 24),
          _ActionsRapides(),
        ],
      ),
    );
  }
}

class _CarteBienvenue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final prenom = user?.nomComplet?.split(' ').first ?? 'Cher';
    final dateDuJour = DateTime.now();

    String jourFr(int w) {
      const jours = [
        'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
      ];
      return jours[w - 1];
    }

    String moisFr(int m) {
      const mois = [
        'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
        'août', 'septembre', 'octobre', 'novembre', 'décembre',
      ];
      return mois[m - 1];
    }

    final dateTexte =
        '${jourFr(dateDuJour.weekday)} ${dateDuJour.day} ${moisFr(dateDuJour.month)} ${dateDuJour.year}';

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
          Text(
            'Bonjour, $prenom ! 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateTexte,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final StatsProfesseur? stats;
  final ResumePresences? presences;

  const _StatsSection({required this.stats, required this.presences});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitre(icon: Icons.query_stats_rounded, texte: 'Vos statistiques clés'),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            _StatCard(
              icon: Icons.menu_book_rounded,
              couleur: AppTheme.primary,
              valeur: '${stats?.totalCours ?? 0}',
              libelle: 'Cours attribués',
              detail: '${stats?.coursAujourdhui ?? 0} aujourd\'hui',
            ),
            _StatCard(
              icon: Icons.person_rounded,
              couleur: AppTheme.success,
              valeur: '${stats?.totalEtudiants ?? 0}',
              libelle: 'Étudiants',
              detail: 'Tous niveaux confondus',
            ),
            _StatCard(
              icon: Icons.fact_check_rounded,
              couleur: AppTheme.info,
              valeur: '${stats?.tauxPresence ?? 0}%',
              libelle: 'Taux de présence',
              detail: '${presences?.total ?? 0} présences relevées',
            ),
            _StatCard(
              icon: Icons.edit_note_rounded,
              couleur: AppTheme.warning,
              valeur: '${stats?.notesACorriger ?? 0}',
              libelle: 'Notes à corriger',
              detail: '${stats?.notesEnAttente ?? 0} en attente de validation',
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color couleur;
  final String valeur;
  final String libelle;
  final String detail;

  const _StatCard({
    required this.icon,
    required this.couleur,
    required this.valeur,
    required this.libelle,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconePlaque(icone: icon, couleur: couleur, taille: 40),
          const SizedBox(height: 10),
          Text(
            valeur,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: couleur,
                  fontSize: 22,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            libelle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                  fontSize: 11,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  final List<SeanceProfesseur> seances;

  const _ScheduleSection({required this.seances});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitre(
          icon: Icons.calendar_month_rounded,
          texte: 'Emploi du temps d\'aujourd\'hui',
        ),
        const SizedBox(height: 12),
        if (seances.isEmpty)
          _CarteVide(message: 'Aucun cours prévu aujourd\'hui.')
        else
          ...seances.map((seance) => _SeanceCard(seance: seance)),
      ],
    );
  }
}

class _SeanceCard extends StatelessWidget {
  final SeanceProfesseur seance;

  const _SeanceCard({required this.seance});

  @override
  Widget build(BuildContext context) {
    final couleurStatut = seance.estEnCours
        ? AppTheme.success
        : seance.estTermine
            ? AppTheme.textSecondaryOf(context)
            : AppTheme.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(Icons.schedule_rounded, color: AppTheme.primary, size: 16),
                const SizedBox(height: 4),
                Text(
                  seance.plageHoraire.isEmpty ? '—' : seance.plageHoraire,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seance.titre,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${seance.salle.isEmpty ? 'Salle à définir' : seance.salle} • '
                  '${seance.nbEtudiants} étudiants',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: couleurStatut.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              seance.libelleStatut,
              style: TextStyle(
                color: couleurStatut,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertesSection extends StatelessWidget {
  final List<AlerteProfesseur> alertes;

  const _AlertesSection({required this.alertes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitre(
          icon: Icons.notifications_active_rounded,
          texte: 'Alertes & Actions urgentes',
        ),
        const SizedBox(height: 12),
        if (alertes.isEmpty)
          _CarteVide(message: 'Aucune alerte pour le moment.')
        else
          ...alertes.map((alerte) => _AlerteCard(alerte: alerte)),
      ],
    );
  }
}

class _AlerteCard extends StatelessWidget {
  final AlerteProfesseur alerte;

  const _AlerteCard({required this.alerte});

  @override
  Widget build(BuildContext context) {
    final couleur = alerte.estUrgente ? AppTheme.warning : AppTheme.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconePlaque(
            icone: alerte.estUrgente
                ? Icons.warning_amber_rounded
                : Icons.info_rounded,
            couleur: couleur,
            taille: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alerte.titre,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  alerte.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  alerte.date,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          if (alerte.action.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                alerte.action,
                style: TextStyle(
                  color: couleur,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionsRapides extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitre(
          icon: Icons.bolt_rounded,
          texte: 'Actions rapides',
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _ActionTile(
              icon: Icons.fact_check_rounded,
              label: 'Saisir les présences',
              color: AppTheme.success,
              onTap: () => PortailScope.naviguer(
                context,
                '/professeur/presences/saisie',
              ),
            ),
            _ActionTile(
              icon: Icons.edit_note_rounded,
              label: 'Encoder les notes',
              color: AppTheme.primary,
              onTap: () =>
                  PortailScope.naviguer(context, '/professeur/notes/saisie'),
            ),
            _ActionTile(
              icon: Icons.menu_book_rounded,
              label: 'Mes cours',
              color: AppTheme.warning,
              onTap: () =>
                  PortailScope.naviguer(context, '/professeur/mes-cours'),
            ),
            _ActionTile(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Smart Présence',
              color: AppTheme.info,
              onTap: () => PortailScope.naviguer(
                context,
                '/professeur/presences/smart',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionTitre extends StatelessWidget {
  final IconData icon;
  final String texte;

  const _SectionTitre({required this.icon, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.iconAccent(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texte,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _CarteVide extends StatelessWidget {
  final String message;

  const _CarteVide({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryOf(context),
            ),
      ),
    );
  }
}

class _ErreurState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErreurState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_rounded, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.error,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
