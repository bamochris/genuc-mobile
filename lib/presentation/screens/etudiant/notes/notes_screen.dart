import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/etudiant/note.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/etat_widgets.dart';
import '../../../widgets/portail_widgets.dart';
import 'releve_screen.dart';

/// Écran Notes et Résultats de l'étudiant.
///
/// Correspond à `Resultats.jsx` du portail web : résumé (moyenne, crédits,
/// mention) puis détail des notes par cours avec les composantes
/// TP / Interrogation / Examen / Finale.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final studentProvider = context.read<StudentProvider>();
    final inscriptionId = context.read<AuthProvider>().user?.inscriptionId;
    if (inscriptionId != null && inscriptionId.isNotEmpty) {
      await studentProvider.loadNotes(inscriptionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();

    return PagePortail(
      titre: 'Mes résultats',
      actions: [
        IconButton(
          icon: const Icon(Icons.description_rounded),
          tooltip: 'Relevé de notes',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReleveScreen()),
            );
          },
        ),
      ],
      corps: studentProvider.isLoading
          ? const EtatChargement(message: 'Chargement de vos résultats…')
          : studentProvider.error != null
              ? EtatErreur(
                  message: studentProvider.error!,
                  onRetry: _charger,
                )
              : _ContenuNotes(
                  resultat: studentProvider.notesResultat,
                  onRetry: _charger,
                ),
    );
  }
}

class _ContenuNotes extends StatelessWidget {
  final NotesResultat? resultat;
  final Future<void> Function() onRetry;

  const _ContenuNotes({required this.resultat, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (resultat == null || resultat!.notes.isEmpty) {
      return const EtatVide(
        icon: Icons.assessment_rounded,
        titre: 'Aucune note publiée',
        message:
            'Vos résultats apparaîtront ici une fois publiés par vos professeurs.',
      );
    }

    final notes = resultat!.notes;

    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ResumeResultats(resultat: resultat!),
          const SizedBox(height: 16),
          Text(
            'Détail des résultats',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ...notes.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NoteTile(note: n),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeResultats extends StatelessWidget {
  final NotesResultat resultat;

  const _ResumeResultats({required this.resultat});

  @override
  Widget build(BuildContext context) {
    final moyenne = resultat.moyenneGenerale;
    final reussie = resultat.estReussi;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.school_rounded,
            label: 'Moyenne générale',
            value: moyenne.toStringAsFixed(2),
            couleur: reussie ? AppTheme.success : AppTheme.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.workspace_premium_rounded,
            label: 'Crédits validés',
            value: '${resultat.creditsValides}',
            couleur: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color couleur;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        children: [
          Icon(icon, color: couleur, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: couleur,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final Note note;

  const _NoteTile({required this.note});

  @override
  Widget build(BuildContext context) {
    final reussie = note.estValide;
    final couleur = reussie ? AppTheme.success : AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.coursTitre,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: couleur,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (note.mention != null && note.mention != '—')
                    PillBadge(
                      label: libelleMention(note.mention),
                      color: couleur,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SousNote(label: 'TP', valeur: note.noteTP),
              _SousNote(label: 'Interro', valeur: note.noteInterrogation),
              _SousNote(label: 'Examen', valeur: note.noteExamen),
            ],
          ),
        ],
      ),
    );
  }
}

class _SousNote extends StatelessWidget {
  final String label;
  final double? valeur;

  const _SousNote({required this.label, this.valeur});

  @override
  Widget build(BuildContext context) {
    final texte = valeur != null ? valeur!.toStringAsFixed(2) : '—';
    return Expanded(
      child: Column(
        children: [
          Text(
            texte,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}
