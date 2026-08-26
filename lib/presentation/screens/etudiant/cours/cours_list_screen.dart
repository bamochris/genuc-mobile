import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/etudiant/cours.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/etat_widgets.dart';
import '../../../widgets/portail_widgets.dart';
import 'cours_detail_screen.dart';

/// Liste des cours de l'étudiant avec progression.
///
/// Correspond à `MesCours.jsx` du portail web (`mesCoursAvecProgression`) :
/// recherche, code, titre, professeur, crédits et barre de progression.
class CoursListScreen extends StatefulWidget {
  const CoursListScreen({super.key});

  @override
  State<CoursListScreen> createState() => _CoursListScreenState();
}

class _CoursListScreenState extends State<CoursListScreen> {
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final studentProvider = context.read<StudentProvider>();
    final inscriptionId = context.read<AuthProvider>().user?.inscriptionId;
    if (inscriptionId != null && inscriptionId.isNotEmpty) {
      await studentProvider.loadCourses(inscriptionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();
    final cours = studentProvider.courses;

    final filtres = _recherche.trim().toLowerCase();
    final coursFiltres = filtres.isEmpty
        ? cours
        : cours.where((c) {
            return c.titre.toLowerCase().contains(filtres) ||
                c.code.toLowerCase().contains(filtres) ||
                (c.enseignant?.toLowerCase().contains(filtres) ?? false);
          }).toList();

    return PagePortail(
      titre: 'Mes cours',
      corps: studentProvider.isLoading
          ? const EtatChargement(message: 'Chargement de vos cours…')
          : studentProvider.error != null
              ? EtatErreur(message: studentProvider.error!, onRetry: _charger)
              : RefreshIndicator(
                  onRefresh: _charger,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ChampRecherche(
                        valeur: _recherche,
                        onChanged: (v) => setState(() => _recherche = v),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${cours.length} cours disponible${cours.length > 1 ? 's' : ''}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryOf(context),
                            ),
                      ),
                      const SizedBox(height: 12),
                      if (coursFiltres.isEmpty)
                        const EtatVide(
                          icon: Icons.menu_book_rounded,
                          titre: 'Aucun cours',
                          message:
                              'Les cours apparaîtront ici une fois publiés par vos professeurs.',
                        )
                      else
                        ...coursFiltres.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CoursCard(
                              cours: c,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CoursDetailScreen(
                                      coursId: c.id.toString(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _ChampRecherche extends StatefulWidget {
  final String valeur;
  final ValueChanged<String> onChanged;

  const _ChampRecherche({required this.valeur, required this.onChanged});

  @override
  State<_ChampRecherche> createState() => _ChampRechercheState();
}

class _ChampRechercheState extends State<_ChampRecherche> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.valeur);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: const InputDecoration(
        hintText: 'Rechercher un cours…',
        prefixIcon: Icon(Icons.search_rounded),
      ),
    );
  }
}

class _CoursCard extends StatelessWidget {
  final Cours cours;
  final VoidCallback onTap;

  const _CoursCard({required this.cours, required this.onTap});

  Color _couleurProgression() {
    switch (cours.couleurProgression) {
      case ColorProgression.excellent:
        return AppTheme.success;
      case ColorProgression.bon:
        return AppTheme.primary;
      case ColorProgression.enCours:
        return AppTheme.warning;
      case ColorProgression.aCommencer:
        return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final couleur = _couleurProgression();
    final progression = cours.progression ?? 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                        cours.code,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cours.titre,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (cours.estComplete)
                  const PillBadge(label: 'Terminé', color: AppTheme.success),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '👨‍🏫 ${cours.enseignant ?? 'Professeur non assigné'}'
              '${cours.credits > 0 ? '  •  ${cours.credits} crédits' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
            if (cours.description != null && cours.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                cours.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progression',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '$progression% — ${cours.couleurProgression.libelle}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: couleur,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progression.clamp(0, 100) / 100,
                minHeight: 8,
                backgroundColor: AppTheme.borderOf(context),
                color: couleur,
              ),
            ),
            if (cours.nbLecons != null) ...[
              const SizedBox(height: 6),
              Text(
                '${cours.leconsCompletees ?? 0} leçons complétées / ${cours.nbLecons}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                      fontSize: 11,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
