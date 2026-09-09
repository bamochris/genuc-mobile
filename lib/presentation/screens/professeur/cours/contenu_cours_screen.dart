import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';
import '../../commun/ecran_ressource.dart';

/// Contenu d'un cours : les leçons que l'enseignant y dépose.
///
/// S'ouvre depuis un cours (`cours/:id/contenu` sur le web) : cet écran ne
/// figure pas au menu, un contenu de cours n'ayant pas de sens hors du cours.
///
/// ─── Pourquoi il ne parle plus au « LMS » ───────────────────────────────────
///
/// Il lisait et écrivait `/api/lms/cours/{id}/chapitres`, servi par
/// `LMSService` : une façade qui rend toujours une liste vide et LÈVE sur toute
/// écriture. L'enseignant remplissait le formulaire pour recevoir une erreur,
/// et ce qu'il croyait avoir déposé n'existait nulle part — pendant que
/// l'étudiant lisait, lui, `cours.lecons`, alimenté par
/// `POST /api/cours/{id}/lecons` qu'aucun écran n'appelait.
///
/// Les deux bouts sont désormais reliés : ce que l'enseignant dépose ici est ce
/// que l'étudiant voit sur la fiche du cours.
class ContenuCoursScreen extends StatelessWidget {
  final String coursId;
  final String? coursTitre;

  const ContenuCoursScreen({
    super.key,
    required this.coursId,
    this.coursTitre,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();

    return EcranRessource(
      titre: 'Contenu du cours',
      sousTitre: coursTitre,
      libelleCreation: 'Nouvelle leçon',
      messageVide: 'Aucune leçon déposée pour ce cours.',
      // Le serveur rend les leçons dans l'ordre où il les trouve : on les
      // range par `ordre`, qui est ce que l'enseignant a saisi et ce que
      // l'étudiant lit.
      charger: () async {
        final lecons = await service.lecons(coursId);
        return [...lecons]
          ..sort((a, b) => a.entier('ordre').compareTo(b.entier('ordre')));
      },
      entete: (context) => const _RappelAvancement(),
      description: DescriptionFiche(
        icone: Icons.auto_stories_rounded,
        titre: (f) => f.texte('titre', defaut: 'Leçon'),
        sousTitre: (f) => f.texteOuNul('description'),
        statut: (f) => f.booleen('actif', defaut: true)
            ? ('Visible', AppTheme.statutVert)
            : ('Masquée', AppTheme.statutNavy),
        details: (f) => [
          if (f.contient('ordre'))
            LigneDetail(libelle: 'Ordre', valeur: '${f.entier('ordre')}'),
          if (f.texteOuNul('documentNom') != null)
            LigneDetail(
              libelle: 'Document',
              valeur: f.texte('documentNom'),
            ),
        ],
      ),
      onSupprimer: (fiche) => service.supprimerLecon(fiche.id),
      champsCreation: const [
        ChampFormulaire(cle: 'titre', libelle: 'Titre', obligatoire: true),
        ChampFormulaire(
          cle: 'description',
          libelle: 'Description',
          type: TypeChamp.multiligne,
          indice: 'Objectifs de la leçon…',
        ),
        ChampFormulaire(
          cle: 'ordre',
          libelle: 'Ordre d\'affichage',
          type: TypeChamp.nombre,
          minimum: 1,
          indice: 'Laisser vide pour ajouter à la fin',
        ),
      ],
      // `type` est imposé : `POST /api/cours/{id}/lecons` fait
      // `TypeLecon.valueOf(data.getOrDefault("type", "VIDEO"))` — sans lui, une
      // leçon écrite au clavier naîtrait « VIDEO » et se présenterait à
      // l'étudiant comme une vidéo qui n'existe pas. Un fichier, lui, se dépose
      // en SUPPORT du cours ; cette route-ci n'accepte que du JSON.
      onCreer: (valeurs) => service.ajouterLecon(coursId, {
        ...valeurs,
        'type': 'TEXTE',
      }),
    );
  }
}

/// Ce que l'enseignant n'a PAS à faire ici.
///
/// L'écran portait autrefois un curseur d'ouverture des leçons et un onglet
/// « Devoirs ». Le premier lui demandait de déclarer à la main un avancement
/// que la base connaît déjà — le nombre de jours distincts où il a pris les
/// présences EST l'avancement du cours. Le second postait vers une route qui
/// ne persiste rien.
class _RappelAvancement extends StatelessWidget {
  const _RappelAvancement();

  @override
  Widget build(BuildContext context) {
    return CartePortail(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_rounded,
            size: 20,
            // Calculée sur le fond de la carte : le bleu de marque posé en
            // dur descend sous 3:1 en thème sombre.
            color: AppTheme.accentGraphique(context, AppTheme.statutBleu),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'L\'avancement de ce cours se calcule tout seul, à partir des '
              'présences que vous prenez à chaque séance : vous n\'avez rien à '
              'régler ici. Ce que vous déposez ci-dessous, ce sont les '
              'contenus que vos étudiants liront sur la page du cours. Les '
              'devoirs, eux, se publient depuis « Travaux ».',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
