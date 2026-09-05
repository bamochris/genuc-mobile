import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/fichiers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/etudiant_academique_service.dart';
import '../../../widgets/portail_widgets.dart';

/// Suivre un cours en ligne : chapitres, progression, devoirs à rendre.
///
/// Transposition de `etudiant/lms/ApprendreCours.jsx`. Elle s'ouvre depuis la
/// fiche d'un cours, pas depuis le menu — c'est aussi ce que fait le web, dont
/// la route est `cours/:id/apprendre`.
class ApprendreCoursScreen extends StatefulWidget {
  final String coursId;
  final String? coursTitre;

  const ApprendreCoursScreen({
    super.key,
    required this.coursId,
    this.coursTitre,
  });

  @override
  State<ApprendreCoursScreen> createState() => _ApprendreCoursScreenState();
}

class _ApprendreCoursScreenState extends State<ApprendreCoursScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _onglets = TabController(length: 2, vsync: this);

  List<Fiche> _chapitres = const [];
  List<Fiche> _devoirs = const [];
  Fiche _progression = const Fiche({});
  bool _chargement = true;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final service = context.read<EtudiantAcademiqueService>();
    try {
      final chapitres = await service.chapitres(widget.coursId);
      // Progression et devoirs sont accessoires : un cours sans devoir ni
      // suivi doit quand même afficher son contenu.
      final progression = await service
          .maProgression(widget.coursId)
          .catchError((_) => const Fiche({}));
      final devoirs = await service
          .devoirsDuCours(widget.coursId)
          .catchError((_) => <Fiche>[]);
      if (!mounted) return;
      setState(() {
        _chapitres = chapitres;
        _progression = progression;
        _devoirs = devoirs;
        _chargement = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _chargement = false;
      });
    }
  }

  /// Part du pourcentage rendu par le serveur ; à défaut, le déduit des
  /// chapitres marqués vus — le serveur ne sert cette valeur que si le module
  /// LMS suit le cours.
  double get _tauxProgression {
    final annonce = _progression.decimalOuNul(
      'pourcentage',
      alias: const ['progression'],
    );
    if (annonce != null) return (annonce / 100).clamp(0.0, 1.0);
    if (_chapitres.isEmpty) return 0;
    final vus = _chapitres.where((c) => c.booleen('vu', alias: const ['complete'])).length;
    return vus / _chapitres.length;
  }

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: widget.coursTitre ?? 'Apprendre',
      sousTitre: 'Contenu du cours',
      onRafraichir: _charger,
      bottomAppBar: TabBar(
        controller: _onglets,
        tabs: const [Tab(text: 'Chapitres'), Tab(text: 'Devoirs')],
      ),
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: false,
        onReessayer: _charger,
        enfant: Column(
          children: [
            if (_message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: BandeauMessage(
                  message: _message!,
                  succes: _messageSucces,
                  onFermer: () => setState(() => _message = null),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: CartePortail(
                child: BarreProgression(
                  valeur: _tauxProgression,
                  libelle: 'Ma progression',
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _onglets,
                children: [_listeChapitres(), _listeDevoirs()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listeChapitres() {
    if (_chapitres.isEmpty) {
      return ListView(
        padding: Responsive.margePage(context),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 40),
          Text(
            'Aucun chapitre publié pour ce cours.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMutedOf(context)),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: Responsive.margePage(context),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _chapitres.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final chapitre = _chapitres[i];
        final vu = chapitre.booleen('vu', alias: const ['complete']);
        final lien = chapitre.texte('url', alias: const ['lien', 'ressource']);

        return CartePortail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    vu ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: vu
                        ? AppTheme.accentLisible(context, AppTheme.statutVert)
                        : AppTheme.textMutedOf(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${i + 1}. ${chapitre.texte('titre', defaut: 'Chapitre')}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
              if (chapitre.texte('description').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  chapitre.texte('description'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (lien.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => Fichiers.ouvrirLien(lien),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Ouvrir'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  // Un chapitre déjà vu ne se remarque pas : le serveur
                  // enregistrerait un doublon de progression.
                  if (!vu)
                    TextButton.icon(
                      onPressed: () => _marquerVu(chapitre),
                      icon: const Icon(Icons.done_rounded, size: 16),
                      label: const Text('Marquer comme vu'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.accentLisible(
                          context,
                          AppTheme.statutVert,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _listeDevoirs() {
    if (_devoirs.isEmpty) {
      return ListView(
        padding: Responsive.margePage(context),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 40),
          Text(
            'Aucun devoir pour ce cours.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMutedOf(context)),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: Responsive.margePage(context),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _devoirs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final devoir = _devoirs[i];
        final rendu = devoir.texteOuNul('dateSoumission') != null ||
            devoir.booleen('soumis');

        return CartePortail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      devoir.texte('titre', defaut: 'Devoir'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Pastille(
                    texte: rendu ? 'Rendu' : 'À rendre',
                    couleur:
                        rendu ? AppTheme.statutVert : AppTheme.statutOrange,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LigneDetail(
                libelle: 'Échéance',
                valeur: formatDate(
                  devoir.texteOuNul('dateEcheance'),
                  avecHeure: true,
                ),
              ),
              if (devoir.decimalOuNul('note') != null)
                LigneDetail(
                  libelle: 'Note',
                  valeur: '${devoir.decimal('note').toStringAsFixed(1)} / 20',
                ),
              if (!rendu) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _soumettre(devoir),
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: const Text('Déposer'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          AppTheme.accentLisible(context, AppTheme.statutBleu),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _marquerVu(Fiche chapitre) async {
    try {
      await context
          .read<EtudiantAcademiqueService>()
          .marquerChapitreVu(chapitre.id);
      if (!mounted) return;
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
    }
  }

  Future<void> _soumettre(Fiche devoir) async {
    final fichier = await Fichiers.choisir();
    if (fichier == null || !mounted) return;

    if (fichier.taille > Fichiers.tailleMaxOctets) {
      setState(() {
        _message = 'Fichier trop lourd (${fichier.tailleLisible}). '
            'Maximum accepté : ${Fichiers.tailleMaxLisible}.';
        _messageSucces = false;
      });
      return;
    }

    try {
      await context.read<EtudiantAcademiqueService>().soumettreDevoir(
            devoirId: devoir.id,
            cheminFichier: fichier.chemin,
            nomFichier: fichier.nom,
          );
      if (!mounted) return;
      setState(() {
        _message = 'Devoir déposé.';
        _messageSucces = true;
      });
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
    }
  }
}
