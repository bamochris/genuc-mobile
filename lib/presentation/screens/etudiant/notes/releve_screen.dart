import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/etudiant/note.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/etat_widgets.dart';
import '../../../widgets/genuc_scaffold.dart';

/// Relevé de notes officiel (consultation).
///
/// Correspond à `GET /api/etudiant/portal/{inscriptionId}/releve`
/// (`EtudiantPortalService.releveNotes`) : matricule, nom, université, année
/// puis la même liste de notes que l'écran résultats.
class ReleveScreen extends StatefulWidget {
  const ReleveScreen({super.key});

  @override
  State<ReleveScreen> createState() => _ReleveScreenState();
}

class _ReleveScreenState extends State<ReleveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final studentProvider = context.read<StudentProvider>();
    final inscriptionId = context.read<AuthProvider>().user?.inscriptionId;
    if (inscriptionId != null && inscriptionId.isNotEmpty) {
      await studentProvider.loadReleve(inscriptionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();

    return GenucScaffold(
      appBar: AppBar(title: const Text('Relevé de notes')),
      body: studentProvider.isLoading
          ? const EtatChargement(message: 'Génération du relevé…')
          : studentProvider.error != null
              ? EtatErreur(
                  message: studentProvider.error!,
                  onRetry: _charger,
                )
              : _ContenuReleve(
                  releve: studentProvider.releve,
                  onRetry: _charger,
                ),
    );
  }
}

class _ContenuReleve extends StatelessWidget {
  final ReleveNotes? releve;
  final Future<void> Function() onRetry;

  const _ContenuReleve({required this.releve, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (releve == null || releve!.notes.isEmpty) {
      return const EtatVide(
        icon: Icons.description_rounded,
        titre: 'Relevé indisponible',
        message: 'Aucune note publiée pour le relevé.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EnTete(releve: releve!),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Détail des notes',
            icon: Icons.receipt_long_rounded,
            children: [
              ...releve!.notes.map(
                (n) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _LigneNote(note: n),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnTete extends StatelessWidget {
  final ReleveNotes releve;

  const _EnTete({required this.releve});

  @override
  Widget build(BuildContext context) {
    final nomComplet =
        '${releve.etudiantPrenom} ${releve.etudiantNom}'.trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nomComplet.isEmpty ? 'Relevé de notes' : nomComplet,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Matricule : ${releve.matricule}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          if (releve.filiere.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              releve.filiere,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _EnTeteStat(
                  label: 'Moyenne',
                  valeur: releve.moyenneGenerale.toStringAsFixed(2),
                ),
              ),
              Expanded(
                child: _EnTeteStat(
                  label: 'Crédits',
                  valeur:
                      '${releve.creditsValides}/${releve.creditsTotal}',
                ),
              ),
            ],
          ),
          if (releve.mentionGenerale != null) ...[
            const SizedBox(height: 12),
            PillBadge(
              label: 'Mention : ${libelleMention(releve.mentionGenerale)}',
              color: releve.moyenneGenerale >= 10
                  ? AppTheme.secondaryLight
                  : AppTheme.error,
            ),
          ],
        ],
      ),
    );
  }
}

class _EnTeteStat extends StatelessWidget {
  final String label;
  final String valeur;

  const _EnTeteStat({required this.label, required this.valeur});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          valeur,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LigneNote extends StatelessWidget {
  final Note note;

  const _LigneNote({required this.note});

  @override
  Widget build(BuildContext context) {
    final couleur = note.estValide ? AppTheme.success : AppTheme.error;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.coursTitre,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${note.coursCode} • ${note.credits} crédits',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              note.noteAffichee,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: couleur,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (note.mention != null && note.mention != '—')
              Text(
                libelleMention(note.mention),
                style: TextStyle(color: couleur, fontSize: 10),
              ),
          ],
        ),
      ],
    );
  }
}
