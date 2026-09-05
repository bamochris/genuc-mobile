import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/etudiant_academique_service.dart';
import '../../../../data/services/supports_cours.dart';
import '../../../../data/models/etudiant/cours.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/etat_widgets.dart';
import '../../../widgets/portail_widgets.dart';
import '../lms/apprendre_cours_screen.dart';

/// Détail d'un cours : progression globale et liste des leçons.
///
/// Correspond à `DetailCours.jsx` du portail web (`detailCours`) : leçons
/// triées par ordre, type (VIDEO, DOCUMENT, TEXTE, QUIZ...), marquage
/// « complétée » via `POST .../lecon/{id}/complete`.
class CoursDetailScreen extends StatefulWidget {
  final String coursId;

  const CoursDetailScreen({super.key, required this.coursId});

  @override
  State<CoursDetailScreen> createState() => _CoursDetailScreenState();
}

class _CoursDetailScreenState extends State<CoursDetailScreen> {
  /// Supports déposés par l'enseignant sur CE cours.
  ///
  /// Cet écran ne couvre que les cours publiés au catalogue en ligne. Les
  /// supports des cours de l'emploi du temps se lisent depuis
  /// `SupportsEtudiantScreen` (`/etudiant/supports`), qui part des séances de
  /// l'inscription — le seul chemin qui les relie à l'étudiant.
  List<Fiche> _supports = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final studentProvider = context.read<StudentProvider>();
    final inscriptionId = context.read<AuthProvider>().user?.inscriptionId;
    // Le service est saisi AVANT le premier `await` : passé celui-ci, le
    // widget peut avoir quitté l'arbre et le contexte n'est plus lisible.
    final academique = context.read<EtudiantAcademiqueService>();

    if (inscriptionId != null && inscriptionId.isNotEmpty) {
      await studentProvider.loadCoursDetail(inscriptionId, widget.coursId);
    }

    // Échec silencieux : un cours sans support est le cas ordinaire, et une
    // erreur ici ne doit pas emporter la page du cours.
    try {
      final supports = await academique.supportsDuCours(widget.coursId);
      if (mounted) setState(() => _supports = supports);
    } catch (_) {
      if (mounted) setState(() => _supports = const []);
    }
  }

  /// Télécharge le support avec le jeton, puis le confie au lecteur système.
  Future<void> _ouvrirSupport(Fiche support) async {
    final academique = context.read<EtudiantAcademiqueService>();
    final messager = ScaffoldMessenger.of(context);
    messager
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Ouverture du support…'),
        duration: Duration(seconds: 2),
      ));
    try {
      await academique.ouvrirSupport(support);
    } on ApiException catch (e) {
      if (!mounted) return;
      messager
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _marquerComplete(Lecon lecon) async {
    final studentProvider = context.read<StudentProvider>();
    final inscriptionId = context.read<AuthProvider>().user?.inscriptionId;
    if (inscriptionId == null || inscriptionId.isEmpty) return;

    if (lecon.estComplete) return;

    await studentProvider.marquerLeconComplete(
      inscriptionId,
      widget.coursId,
      lecon.id,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Leçon marquée comme complétée ✓'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();

    return PagePortail(
      titre: 'Détail du cours',
      actions: [
        IconButton(
          icon: const Icon(Icons.auto_stories_rounded),
          tooltip: 'Suivre ce cours en ligne',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ApprendreCoursScreen(
                coursId: widget.coursId,
                coursTitre: studentProvider.coursDetail?.cours.titre,
              ),
            ),
          ),
        ),
      ],
      corps: studentProvider.coursDetailLoading
          ? const EtatChargement(message: 'Chargement du cours…')
          : studentProvider.coursDetailError != null
              ? EtatErreur(
                  message: studentProvider.coursDetailError!,
                  onRetry: _charger,
                )
              : studentProvider.coursDetail != null
                  ? _Contenu(
                      detail: studentProvider.coursDetail!,
                      onMarquerComplete: _marquerComplete,
                      supports: _supports,
                      onOuvrirSupport: _ouvrirSupport,
                    )
                  : const EtatVide(
                      icon: Icons.menu_book_rounded,
                      titre: 'Cours indisponible',
                    ),
    );
  }
}

class _Contenu extends StatelessWidget {
  final CoursDetail detail;
  final void Function(Lecon) onMarquerComplete;
  final List<Fiche> supports;
  final void Function(Fiche) onOuvrirSupport;

  const _Contenu({
    required this.detail,
    required this.onMarquerComplete,
    required this.onOuvrirSupport,
    this.supports = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cours = detail.cours;

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EnTeteCours(detail: detail),
          const SizedBox(height: 16),
          if (supports.isNotEmpty) ...[
            SectionCard(
              title: 'Supports de cours (${supports.length})',
              icon: Icons.attach_file_rounded,
              children: [
                for (final support in supports)
                  _LigneSupport(
                    support: support,
                    onOuvrir: () => onOuvrirSupport(support),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (cours.description != null && cours.description!.isNotEmpty) ...[
            SectionCard(
              title: 'Description',
              icon: Icons.info_rounded,
              children: [
                Text(
                  cours.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          SectionCard(
            title: 'Leçons (${detail.leconsCompletees}/${detail.totalLecons})',
            icon: Icons.play_circle_rounded,
            children: detail.lecons.isEmpty
                ? [
                    Text(
                      'Aucune leçon publiée pour ce cours.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryOf(context),
                          ),
                    ),
                  ]
                : detail.lecons
                    .map(
                      (l) => _LeconTile(
                        lecon: l,
                        onMarquerComplete: () => onMarquerComplete(l),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }
}

/// Un support : on le télécharge, puis le système choisit l'application.
///
/// L'ancien code passait `support.url` — le chemin de STOCKAGE, sans schéma ni
/// hôte — au lanceur système, qui ne pouvait rien en faire ; son échec ne
/// remontait qu'un `false` que personne ne lisait. Aucun support ne s'est
/// jamais ouvert depuis cet écran.
class _LigneSupport extends StatelessWidget {
  final Fiche support;
  final VoidCallback onOuvrir;

  const _LigneSupport({required this.support, required this.onOuvrir});

  @override
  Widget build(BuildContext context) {
    final titre = support.texte('titre',
        alias: const ['nomFichierOriginal'], defaut: 'Support');
    final description = support.texte('description');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onOuvrir,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.description_rounded,
                  size: 22, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    if (description.isNotEmpty)
                      Text(description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context))),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded,
                  size: 18, color: AppTheme.textMutedOf(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnTeteCours extends StatelessWidget {
  final CoursDetail detail;

  const _EnTeteCours({required this.detail});

  @override
  Widget build(BuildContext context) {
    final cours = detail.cours;
    final progression = detail.progression.clamp(0, 100);

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
            cours.code,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            cours.titre,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (cours.enseignant != null) ...[
            const SizedBox(height: 4),
            Text(
              cours.enseignant!,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progression',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
              Text(
                '${progression.round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progression / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: AppTheme.secondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeconTile extends StatelessWidget {
  final Lecon lecon;
  final VoidCallback onMarquerComplete;

  const _LeconTile({required this.lecon, required this.onMarquerComplete});

  IconData _iconeType() {
    switch (lecon.type) {
      case 'VIDEO':
        return Icons.play_circle_rounded;
      case 'DOCUMENT':
        return Icons.description_rounded;
      case 'QUIZ':
        return Icons.quiz_rounded;
      case 'MIXTE':
        return Icons.dashboard_customize_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final couleur = lecon.estComplete ? AppTheme.success : AppTheme.primary;

    return InkWell(
      onTap: lecon.estComplete ? null : onMarquerComplete,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            IconePlaque(icone: _iconeType(), couleur: couleur, taille: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${lecon.ordre}. ${lecon.titre}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: lecon.estComplete
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: AppTheme.textSecondaryOf(context),
                        ),
                  ),
                  if (lecon.dureeAffichee.isNotEmpty ||
                      lecon.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [lecon.dureeAffichee, lecon.description]
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryOf(context),
                            fontSize: 11,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (lecon.estComplete)
              const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20)
            else
              IconButton(
                icon: const Icon(Icons.done_rounded, size: 18),
                tooltip: 'Marquer complétée',
                color: AppTheme.primary,
                onPressed: onMarquerComplete,
              ),
          ],
        ),
      ),
    );
  }
}
