import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/fichiers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/fichiers_prives.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';

/// Travaux et devoirs, côté enseignant : publier un sujet, y joindre ses
/// consignes, relever les copies et les corriger.
///
/// ── Pourquoi cet écran n'existait pas ───────────────────────────────────
///
/// Les quatre routes qu'il appelle existaient toutes côté serveur, sans
/// qu'aucun client ne les appelle — ni ce portail, ni le web. Le circuit était
/// instrumenté du côté qui REND (l'étudiant dépose sa copie depuis « Travaux et
/// devoirs ») et muet du côté qui demande et qui corrige. La conséquence se
/// lisait dans les dossiers : `urlConsignes` vide partout, et l'état
/// « Corrigé » d'un travail inatteignable, note comprise.
class TravauxProfesseurScreen extends StatefulWidget {
  const TravauxProfesseurScreen({super.key});

  @override
  State<TravauxProfesseurScreen> createState() =>
      _TravauxProfesseurScreenState();
}

/// Barème d'une copie. `coefficient` est un POIDS dans la moyenne, pas un
/// barème : la note sur vingt est la convention de tous les écrans de notes.
const double _noteMax = 20;

const Map<String, String> _types = {
  'DEVOIR': 'Devoir',
  'TP': 'Travaux pratiques',
  'PROJET': 'Projet',
  'EXERCICE': 'Exercice',
};

class _TravauxProfesseurScreenState extends State<TravauxProfesseurScreen> {
  Map<String, String> _cours = const {};
  List<Fiche> _travaux = const [];

  bool _chargement = true;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  ProfesseurPedagogieService get _service =>
      context.read<ProfesseurPedagogieService>();

  String get _professeurId => context.read<AuthProvider>().user?.id ?? '';

  Future<void> _charger() async {
    final service = _service;
    final professeurId = _professeurId;
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final cours = await service.mesCours(professeurId);
      final travaux = await service.travaux(professeurId);
      if (!mounted) return;
      setState(() {
        _cours = {
          for (final c in cours)
            c.id: [c.texte('code'), c.texte('titre')]
                .where((v) => v.isNotEmpty)
                .join(' – '),
        };
        _travaux = travaux;
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

  void _annoncer(String message, {bool succes = true}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageSucces = succes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: 'Travaux et devoirs',
      sousTitre: 'Publier un sujet, relever et corriger les copies',
      onRafraichir: _charger,
      floatingActionButton: _cours.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _publier,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouveau travail'),
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
            if (_travaux.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Vous n\'avez encore publié aucun travail.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else
              for (final travail in _travaux) ...[
                _CarteTravail(
                  travail: travail,
                  onCopies: () => _ouvrirCopies(travail),
                  onConsignes: () => _joindreConsignes(travail),
                  onOuvrirConsignes: () => _ouvrirConsignes(travail),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _publier() async {
    final valeurs = await DialogueFormulaire.ouvrir(
      context,
      titre: 'Nouveau travail',
      libelleValidation: 'Publier',
      champs: [
        ChampFormulaire(
          cle: 'coursId',
          libelle: 'Cours',
          type: TypeChamp.liste,
          obligatoire: true,
          options: _cours,
        ),
        const ChampFormulaire(
          cle: 'titre',
          libelle: 'Titre',
          obligatoire: true,
        ),
        const ChampFormulaire(
          cle: 'type',
          libelle: 'Type',
          type: TypeChamp.liste,
          valeurInitiale: 'DEVOIR',
          options: _types,
        ),
        const ChampFormulaire(
          cle: 'description',
          libelle: 'Énoncé',
          type: TypeChamp.multiligne,
        ),
        const ChampFormulaire(
          cle: 'dateEcheance',
          libelle: 'À rendre avant le',
          type: TypeChamp.date,
          obligatoire: true,
        ),
        const ChampFormulaire(
          cle: 'coefficient',
          libelle: 'Coefficient',
          type: TypeChamp.decimal,
          minimum: 0,
        ),
        const ChampFormulaire(
          cle: 'consignes',
          libelle: 'Consignes (facultatif)',
          type: TypeChamp.fichier,
          indice: 'Joindre l\'énoncé — 10 Mo maximum',
        ),
      ],
    );
    if (valeurs == null || !mounted) return;

    final consignes = valeurs['consignes'] as FichierChoisi?;
    if (consignes != null && consignes.taille > Fichiers.tailleMaxOctets) {
      _annoncer(
        'Consignes trop lourdes (${consignes.tailleLisible}). '
        'La limite est de ${Fichiers.tailleMaxLisible}.',
        succes: false,
      );
      return;
    }

    final service = _service;
    final utilisateur = context.read<AuthProvider>().user;
    try {
      final travail = await service.creerTravail(
        coursId: valeurs['coursId'].toString(),
        professeurId: utilisateur?.id ?? '',
        professeurNom: utilisateur?.nomComplet,
        titre: valeurs['titre']?.toString() ?? '',
        description: valeurs['description']?.toString() ?? '',
        type: valeurs['type']?.toString() ?? 'DEVOIR',
        dateEcheance: valeurs['dateEcheance'].toString(),
        coefficient: valeurs['coefficient'] is num
            ? (valeurs['coefficient'] as num).toDouble()
            : null,
      );

      // Les consignes suivent la création : le travail doit exister pour porter
      // son fichier. L'échec du second envoi ne défait pas le premier — on le
      // dit, plutôt que de laisser croire que rien n'a été créé.
      if (consignes != null && travail.id.isNotEmpty) {
        try {
          await service.joindreConsignes(
            travailId: travail.id,
            cheminFichier: consignes.chemin,
            nomFichier: consignes.nom,
          );
        } on ApiException catch (e) {
          _annoncer(
            'Le travail est créé, mais ses consignes n\'ont pas pu être '
            'jointes : ${e.message}',
            succes: false,
          );
          await _charger();
          return;
        }
      }

      _annoncer('Travail publié.');
      await _charger();
    } on ApiException catch (e) {
      _annoncer(e.message, succes: false);
    }
  }

  Future<void> _joindreConsignes(Fiche travail) async {
    final fichier = await Fichiers.choisir();
    if (fichier == null || !mounted) return;

    if (fichier.taille > Fichiers.tailleMaxOctets) {
      _annoncer(
        'Fichier trop lourd (${fichier.tailleLisible}). '
        'La limite est de ${Fichiers.tailleMaxLisible}.',
        succes: false,
      );
      return;
    }

    try {
      await _service.joindreConsignes(
        travailId: travail.id,
        cheminFichier: fichier.chemin,
        nomFichier: fichier.nom,
      );
      _annoncer('Consignes jointes.');
      await _charger();
    } on ApiException catch (e) {
      _annoncer(e.message, succes: false);
    }
  }

  Future<void> _ouvrirConsignes(Fiche travail) async {
    try {
      await _service.ouvrirRessource(
        travail.texte('urlTelechargementConsignes',
            alias: const ['urlConsignes']),
        nomPropose: travail.texte('nomFichierConsignes'),
      );
    } on ApiException catch (e) {
      _annoncer(e.message, succes: false);
    }
  }

  Future<void> _ouvrirCopies(Fiche travail) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _CopiesScreen(travail: travail)),
    );
    // Les compteurs du travail changent avec les corrections rendues.
    await _charger();
  }
}

/// Un travail : son cours, son échéance, l'état de ses copies et ses consignes.
class _CarteTravail extends StatelessWidget {
  final Fiche travail;
  final VoidCallback onCopies;
  final VoidCallback onConsignes;
  final VoidCallback onOuvrirConsignes;

  const _CarteTravail({
    required this.travail,
    required this.onCopies,
    required this.onConsignes,
    required this.onOuvrirConsignes,
  });

  @override
  Widget build(BuildContext context) {
    final soumissions = _entier(travail.donnees['nombreSoumissions']);
    final corrigees = _entier(travail.donnees['nombreCorrigees']);
    final aCorriger = soumissions - corrigees;
    final consignes = travail.texte('urlConsignes');
    final echeance = travail.date('dateEcheance');

    return CartePortail(
      onTap: onCopies,
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
                      travail.texte('titre', defaut: 'Travail'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      [
                        _types[travail.texte('type')] ?? travail.texte('type'),
                        travail.texte('coursCode'),
                        travail.texte('coursTitre'),
                      ].where((v) => v.isNotEmpty).join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMutedOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Pastille(
                texte: aCorriger > 0 ? '$aCorriger à corriger' : 'Tout corrigé',
                couleur:
                    aCorriger > 0 ? AppTheme.statutOrange : AppTheme.statutVert,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Meta(
                icone: Icons.event_rounded,
                texte: echeance == null
                    ? 'Échéance non fixée'
                    : 'Avant le ${formatDateObjet(echeance)}',
              ),
              _Meta(
                icone: Icons.assignment_turned_in_rounded,
                texte: '$soumissions copie${soumissions > 1 ? 's' : ''} rendue'
                    '${soumissions > 1 ? 's' : ''}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (consignes.isEmpty)
                TextButton.icon(
                  onPressed: onConsignes,
                  icon: const Icon(Icons.attach_file_rounded, size: 16),
                  label: const Text('Joindre les consignes',
                      style: TextStyle(fontSize: 12)),
                )
              else ...[
                TextButton.icon(
                  onPressed: onOuvrirConsignes,
                  icon: const Icon(Icons.description_rounded, size: 16),
                  label: Text(
                    travail.texte('nomFichierConsignes', defaut: 'Consignes'),
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: onConsignes,
                  child: const Text('Remplacer', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static int _entier(dynamic v) => v is num ? v.toInt() : 0;
}

/// Les copies rendues pour un travail, et leur correction.
class _CopiesScreen extends StatefulWidget {
  final Fiche travail;

  const _CopiesScreen({required this.travail});

  @override
  State<_CopiesScreen> createState() => _CopiesScreenState();
}

class _CopiesScreenState extends State<_CopiesScreen> {
  List<Fiche> _copies = const [];
  bool _chargement = true;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  ProfesseurPedagogieService get _service =>
      context.read<ProfesseurPedagogieService>();

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final copies = await _service.soumissions(widget.travail.id);
      if (!mounted) return;
      setState(() {
        _copies = copies;
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

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: 'Copies rendues',
      sousTitre: widget.travail.texte('titre'),
      onRafraichir: _charger,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _copies.isEmpty,
        onReessayer: _charger,
        iconeVide: Icons.assignment_rounded,
        messageVide: 'Aucune copie rendue pour l\'instant.',
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_message != null)
              BandeauMessage(
                message: _message!,
                succes: _messageSucces,
                onFermer: () => setState(() => _message = null),
              ),
            for (final copie in _copies) ...[
              _CarteCopie(
                copie: copie,
                onOuvrir: () => _ouvrir(copie, 'fichierUrl', 'nomFichier'),
                onOuvrirCorrection: () => _ouvrir(
                  copie,
                  'urlTelechargementCorrection',
                  'nomFichierCorrection',
                  repli: 'urlCorrection',
                ),
                onCorriger: () => _corriger(copie),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _ouvrir(
    Fiche copie,
    String cle,
    String cleNom, {
    String? repli,
  }) async {
    try {
      await _service.ouvrirRessource(
        copie.texte(cle, alias: repli == null ? const [] : [repli]),
        nomPropose: copie.texte(cleNom),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _messageSucces = false;
      });
    }
  }

  Future<void> _corriger(Fiche copie) async {
    final noteActuelle = copie.decimalOuNul('note');
    final valeurs = await DialogueFormulaire.ouvrir(
      context,
      titre: 'Corriger la copie',
      libelleValidation: 'Enregistrer',
      champs: [
        ChampFormulaire(
          cle: 'note',
          libelle: 'Note sur ${_noteMax.toStringAsFixed(0)}',
          type: TypeChamp.decimal,
          obligatoire: true,
          minimum: 0,
          maximum: _noteMax,
          valeurInitiale: noteActuelle,
        ),
        ChampFormulaire(
          cle: 'commentaire',
          libelle: 'Appréciation',
          type: TypeChamp.multiligne,
          valeurInitiale: copie.texte('commentaireCorrection'),
        ),
        const ChampFormulaire(
          cle: 'fichier',
          libelle: 'Copie annotée (facultatif)',
          type: TypeChamp.fichier,
          indice: 'Sans elle, celle déjà rendue est conservée',
        ),
      ],
    );
    if (valeurs == null || !mounted) return;

    final note = valeurs['note'];
    if (note is! num) {
      setState(() {
        _message = 'La note est obligatoire pour corriger une copie.';
        _messageSucces = false;
      });
      return;
    }

    final annotee = valeurs['fichier'] as FichierChoisi?;
    if (annotee != null && annotee.taille > Fichiers.tailleMaxOctets) {
      setState(() {
        _message = 'Copie annotée trop lourde (${annotee.tailleLisible}). '
            'La limite est de ${Fichiers.tailleMaxLisible}.';
        _messageSucces = false;
      });
      return;
    }

    try {
      await _service.corrigerCopie(
        soumissionId: copie.id,
        note: note.toDouble(),
        commentaire: valeurs['commentaire']?.toString(),
        cheminFichier: annotee?.chemin,
        nomFichier: annotee?.nom,
      );
      if (!mounted) return;
      setState(() {
        _message = 'Copie corrigée.';
        _messageSucces = true;
      });
      await _charger();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _messageSucces = false;
      });
    }
  }
}

class _CarteCopie extends StatelessWidget {
  final Fiche copie;
  final VoidCallback onOuvrir;
  final VoidCallback onOuvrirCorrection;
  final VoidCallback onCorriger;

  const _CarteCopie({
    required this.copie,
    required this.onOuvrir,
    required this.onOuvrirCorrection,
    required this.onCorriger,
  });

  @override
  Widget build(BuildContext context) {
    final note = copie.decimalOuNul('note');
    final rendu = copie.date('dateSoumission');
    final appreciation = copie.texte('commentaireCorrection');
    final aCorrection = copie.texte('urlCorrection').isNotEmpty;

    return CartePortail(
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
                      copie.texte('etudiant', defaut: 'Étudiant'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      [
                        copie.texte('matricule'),
                        if (rendu != null)
                          'rendu le ${formatDateObjet(rendu)}',
                      ].where((v) => v.isNotEmpty).join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMutedOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Pastille(
                texte: note == null
                    ? 'Non corrigée'
                    : '${note.toStringAsFixed(1)}/${_noteMax.toStringAsFixed(0)}',
                couleur: note == null
                    ? AppTheme.statutOrange
                    : (note >= 10 ? AppTheme.statutVert : AppTheme.statutRouge),
              ),
            ],
          ),
          if (appreciation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              appreciation,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: onOuvrir,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('La copie', style: TextStyle(fontSize: 12)),
              ),
              if (aCorrection)
                TextButton.icon(
                  onPressed: onOuvrirCorrection,
                  icon: const Icon(Icons.rate_review_rounded, size: 16),
                  label: const Text('Copie annotée',
                      style: TextStyle(fontSize: 12)),
                ),
              TextButton.icon(
                onPressed: onCorriger,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text(
                  note == null ? 'Corriger' : 'Reprendre',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icone;
  final String texte;

  const _Meta({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 14, color: AppTheme.textMutedOf(context)),
        const SizedBox(width: 4),
        Text(
          texte,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textMutedOf(context),
          ),
        ),
      ],
    );
  }
}
