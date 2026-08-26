import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/etudiant/dashboard_data_backend.dart';
import '../../../../data/models/etudiant/paiement.dart';
import '../../../navigation/portail_shell.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/portail_widgets.dart';
import 'widgets/dashboard_widgets.dart';

/// Écran complet du dashboard étudiant
class EtudiantDashboardScreen extends StatefulWidget {
  const EtudiantDashboardScreen({super.key});

  @override
  State<EtudiantDashboardScreen> createState() => _EtudiantDashboardScreenState();
}

class _EtudiantDashboardScreenState extends State<EtudiantDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Après la frame, jamais pendant : le chargement fait notifier
    // `StudentProvider` dès sa première ligne, et une notification émise
    // pendant la construction de l'arbre lève « setState() called during
    // build » — l'écran d'accueil s'ouvrait sur cette erreur.
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final studentProvider = context.read<StudentProvider>();
    final authProvider = context.read<AuthProvider>();
    final inscriptionId = authProvider.user?.inscriptionId;

    if (inscriptionId != null && inscriptionId.isNotEmpty) {
      await studentProvider.loadEssentiels(inscriptionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();

    // `PagePortail` et non un `GenucScaffold` nu : c'est par lui que la page
    // reçoit le tiroir, la barre basse et les actions globales du portail.
    // Construire son propre échafaudage la coupait de la navigation — et
    // dupliquait la bascule de thème, désormais posée une seule fois par le
    // shell.
    return PagePortail(
      titre: 'Tableau de bord',
      onRafraichir: _charger,
      corps: studentProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : studentProvider.error != null
              ? _ErreurState(
                  message: studentProvider.error!,
                  onRetry: _charger,
                )
              : studentProvider.dashboard != null
                  ? _ContenuDashboard(
                      dashboardData: studentProvider.dashboard!,
                      situation: studentProvider.situationFinanciere,
                    )
                  : _ContenuVide(),
    );
  }
}

class _ContenuDashboard extends StatelessWidget {
  final DashboardData dashboardData;
  final SituationFinanciere? situation;

  const _ContenuDashboard({
    required this.dashboardData,
    this.situation,
  });

  @override
  Widget build(BuildContext context) {
    // Même ordre que le portail web : bienvenue → situation financière →
    // dettes TachPay → cours du jour → actions rapides → progression →
    // notifications + événements.
    return RefreshIndicator(
      onRefresh: () async {
        final studentProvider = context.read<StudentProvider>();
        final authProvider = context.read<AuthProvider>();
        final inscriptionId = authProvider.user?.inscriptionId;
        if (inscriptionId != null) {
          await studentProvider.loadEssentiels(inscriptionId);
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WelcomeCard(dashboardData: dashboardData),
          if (!dashboardData.vacationChoisie && dashboardData.vacationsDisponibles.isNotEmpty) ...[
            const SizedBox(height: 16),
            VacationChoiceCard(
              dashboardData: dashboardData,
              onVacationChoisie: (vId) async {
                final studentProvider = context.read<StudentProvider>();
                final authProvider = context.read<AuthProvider>();
                final inscriptionId = authProvider.user?.inscriptionId;
                if (inscriptionId != null) {
                  await studentProvider.choisirVacation(inscriptionId, vId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vacation enregistrée avec succès !'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                }
              },
            ),
          ],
          const SizedBox(height: 24),
          StatsCard(dashboardData: dashboardData),
          const SizedBox(height: 24),
          if (situation != null) ...[
            SituationFinanciereCard(situation: situation!),
            const SizedBox(height: 24),
          ],
          if (dashboardData.hasDebts) ...[
            DettesCard(dashboardData: dashboardData),
            const SizedBox(height: 24),
          ],
          if (dashboardData.prochainsCours.isNotEmpty) ...[
            CoursDuJourCard(dashboardData: dashboardData),
            const SizedBox(height: 24),
          ],
          if (dashboardData.emploiTemps != null && dashboardData.emploiTemps!.isNotEmpty) ...[
            HoraireSemaineCard(dashboardData: dashboardData),
            const SizedBox(height: 24),
          ],
          _ActionsRapides(dashboardData: dashboardData),
          const SizedBox(height: 24),
          ProgressionAcademiqueCard(
            dashboardData: dashboardData,
            situation: situation,
          ),
          const SizedBox(height: 24),
          if (dashboardData.notifications.isNotEmpty) ...[
            NotificationsCard(dashboardData: dashboardData),
            const SizedBox(height: 24),
          ],
          EvenementsCard(evenements: dashboardData.prochainsExamens),
        ],
      ),
    );
  }
}

class _ActionsRapides extends StatelessWidget {
  final DashboardData dashboardData;

  const _ActionsRapides({
    required this.dashboardData,
  });

  @override
  Widget build(BuildContext context) {
    // Mêmes actions que la grille `QuickActionsGrid` du portail web, dans le
    // même ordre. Chacune vise un chemin de la table de routes : c'est le
    // portail qui ouvre l'écran, pas la tuile qui pousse une classe — huit
    // d'entre elles renvoyaient « écran à venir » alors que la destination
    // existait.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
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
              icon: Icons.payment_rounded,
              label: 'Payer mes frais',
              color: AppTheme.success,
              chemin: '/etudiant/frais',
            ),
            _ActionTile(
              icon: Icons.download_rounded,
              label: 'Mes bulletins',
              color: AppTheme.primary,
              chemin: '/etudiant/bulletins',
            ),
            _ActionTile(
              icon: Icons.assessment_rounded,
              label: 'Mes résultats',
              color: AppTheme.warning,
              chemin: '/etudiant/resultats',
            ),
            _ActionTile(
              icon: Icons.menu_book_rounded,
              label: 'Mes cours',
              color: AppTheme.primary,
              chemin: '/etudiant/mes-cours',
            ),
            _ActionTile(
              icon: Icons.mail_rounded,
              label: 'Messagerie',
              color: AppTheme.info,
              chemin: '/etudiant/messagerie',
            ),
            _ActionTile(
              icon: Icons.person_rounded,
              label: 'Mon profil',
              color: AppTheme.primary,
              chemin: '/etudiant/profil',
            ),
            _ActionTile(
              icon: Icons.note_alt_rounded,
              label: 'Demander attestation',
              color: AppTheme.success,
              chemin: '/etudiant/attestations',
            ),
            _ActionTile(
              icon: Icons.gavel_rounded,
              label: 'Recours',
              color: AppTheme.errorText,
              chemin: '/etudiant/recours',
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String chemin;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.chemin,
  });

  @override
  Widget build(BuildContext context) {
    // `accentLisible` éclaircit les couleurs sombres de marque (bleu nuit,
    // rouge foncé) sur fond ardoise : sans lui, les icônes d'action
    // disparaissaient en mode sombre.
    final accent = AppTheme.accentLisible(context, color);

    return InkWell(
      onTap: () => PortailScope.naviguer(context, chemin),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accent.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accent, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: accent,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContenuVide extends StatelessWidget {
  const _ContenuVide();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 64,
            color: AppTheme.textSecondaryOf(context),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune donnée disponible',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos informations académiques apparaîtront ici',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErreurState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErreurState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_rounded,
              size: 64,
              color: AppTheme.error,
            ),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
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