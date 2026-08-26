import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/fichiers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';

/// Supports de cours : sélection d'un cours, liste de ses supports, dépôt et
/// suppression.
///
/// Le web scinde l'écran en deux colonnes (cours à gauche, supports à droite).
/// Sur téléphone, les deux sont empilées : le cours devient une liste
/// déroulante, ses supports occupent toute la largeur.
class SupportsCoursScreen extends StatefulWidget {
  /// Cours présélectionné quand on arrive depuis la fiche d'un cours.
  final String? coursIdInitial;

  const SupportsCoursScreen({super.key, this.coursIdInitial});

  @override
  State<SupportsCoursScreen> createState() => _SupportsCoursScreenState();
}

class _SupportsCoursScreenState extends State<SupportsCoursScreen> {
  Map<String, String> _cours = const {};
  String? _coursId;
  List<Fiche> _supports = const [];

  bool _chargement = true;
  bool _envoiEnCours = false;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  @override
  void initState() {
    super.initState();
    _coursId = widget.coursIdInitial;
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  ProfesseurPedagogieService get _service =>
      context.read<ProfesseurPedagogieService>();

  Future<void> _charger() async {
    final professeurId = context.read<AuthProvider>().user?.id ?? '';
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final cours = await _service.mesCours(professeurId);
      if (!mounted) return;
      setState(() {
        _cours = {
          for (final c in cours)
            c.id: [c.texte('code'), c.texte('titre')]
                .where((v) => v.isNotEmpty)
                .join(' – '),
        };
        _chargement = false;
      });
      if (_coursId != null) await _chargerSupports();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _chargement = false;
      });
    }
  }

  Future<void> _chargerSupports() async {
    final coursId = _coursId;
    if (coursId == null) return;
    try {
      final supports = await _service.supports(coursId);
      if (!mounted) return;
      setState(() => _supports = supports);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _supports = const [];
        _message = e.message;
        _messageSucces = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: 'Supports de cours',
      sousTitre: 'Documents mis à disposition des étudiants',
      onRafraichir: _charger,
      floatingActionButton: _coursId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _envoiEnCours ? null : _publier,
              icon: _envoiEnCours
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(_envoiEnCours ? 'Envoi…' : 'Ajouter'),
            ),
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _cours.isEmpty,
        onReessayer: _charger,
        iconeVide: Icons.menu_book_rounded,
        messageVide: 'Aucun cours ne vous est attribué.',
        enfant: ListView(
          padding: Responsive.margePage(context).copyWith(bottom: 96),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_message != null)
              BandeauMessage(
                message: _message!,
                succes: _messageSucces,
                onFermer: () => setState(() => _message = null),
              ),
            SelecteurCours(
              valeur: _coursId,
              cours: _cours,
              onChange: (v) {
                setState(() {
                  _coursId = v;
                  _supports = const [];
                });
                _chargerSupports();
              },
            ),
            const SizedBox(height: 20),
            if (_coursId == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Sélectionnez un cours pour voir ses supports.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else if (_supports.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Aucun support publié pour ce cours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else
              for (final support in _supports) ...[
                _CarteSupport(
                  support: support,
                  onOuvrir: () => _ouvrir(support),
                  onSupprimer: () => _supprimer(support),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _publier() async {
    final coursId = _coursId;
    if (coursId == null) return;

    final valeurs = await DialogueFormulaire.ouvrir(
      context,
      titre: 'Publier un support',
      libelleValidation: 'Choisir le fichier',
      champs: const [
        ChampFormulaire(cle: 'titre', libelle: 'Titre', obligatoire: true),
        ChampFormulaire(
          cle: 'type',
          libelle: 'Type',
          type: TypeChamp.liste,
          valeurInitiale: 'PDF',
          options: {
            'PDF': 'PDF',
            'VIDEO': 'Vidéo',
            'DOCUMENT': 'Document',
            'PPT': 'Présentation',
          },
        ),
        ChampFormulaire(
          cle: 'description',
          libelle: 'Description',
          type: TypeChamp.multiligne,
        ),
      ],
    );
    if (valeurs == null || !mounted) return;

    final fichier = await Fichiers.choisir();
    if (fichier == null || !mounted) return;

    if (fichier.taille > Fichiers.tailleMaxOctets) {
      setState(() {
        _message = 'Fichier trop lourd (${fichier.tailleLisible}). '
            'La limite est de 50 Mo.';
        _messageSucces = false;
      });
      return;
    }

    setState(() => _envoiEnCours = true);
    try {
      await _service.publierSupport(
        coursId: coursId,
        titre: valeurs['titre']?.toString() ?? '',
        description: valeurs['description']?.toString() ?? '',
        type: valeurs['type']?.toString() ?? 'PDF',
        cheminFichier: fichier.chemin,
        nomFichier: fichier.nom,
      );
      if (!mounted) return;
      setState(() {
        _message = 'Support publié.';
        _messageSucces = true;
        _envoiEnCours = false;
      });
      await _chargerSupports();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _messageSucces = false;
        _envoiEnCours = false;
      });
    }
  }

  Future<void> _ouvrir(Fiche support) async {
    final url = support.texte('url', alias: const ['lien', 'cheminFichier']);
    if (url.isEmpty) {
      setState(() {
        _message = 'Ce support ne porte aucun lien de téléchargement.';
        _messageSucces = false;
      });
      return;
    }
    final ouvert = await Fichiers.ouvrirLien(url);
    if (!ouvert && mounted) {
      setState(() {
        _message = 'Le support n\'a pas pu être ouvert.';
        _messageSucces = false;
      });
    }
  }

  Future<void> _supprimer(Fiche support) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le support'),
        content: const Text(
          'Supprimer ce support de cours ? Les étudiants n\'y auront plus accès.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    try {
      await _service.supprimerSupport(support.id);
      if (!mounted) return;
      setState(() {
        _message = 'Support supprimé.';
        _messageSucces = true;
      });
      await _chargerSupports();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _messageSucces = false;
      });
    }
  }
}

class _CarteSupport extends StatelessWidget {
  final Fiche support;
  final VoidCallback onOuvrir;
  final VoidCallback onSupprimer;

  const _CarteSupport({
    required this.support,
    required this.onOuvrir,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    final type = support.texte('type', defaut: 'DOCUMENT');
    final creeLe = support.date('creeLe', alias: const ['dateCreation']);

    return CartePortail(
      onTap: onOuvrir,
      child: Row(
        children: [
          IconePlaque(
            icone: _icone(type),
            couleur: AppTheme.statutBleu,
            taille: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  support.texte('titre', defaut: 'Support'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  [
                    type,
                    if (creeLe != null) formatDateObjet(creeLe),
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
                if (support.texte('description').isNotEmpty)
                  Text(
                    support.texte('description'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, size: 20),
            color: AppTheme.accentLisible(context, AppTheme.error),
            tooltip: 'Supprimer',
            onPressed: onSupprimer,
          ),
        ],
      ),
    );
  }

  IconData _icone(String type) => switch (type) {
        'PDF' => Icons.picture_as_pdf_rounded,
        'VIDEO' => Icons.play_circle_rounded,
        'PPT' => Icons.slideshow_rounded,
        _ => Icons.description_rounded,
      };
}
