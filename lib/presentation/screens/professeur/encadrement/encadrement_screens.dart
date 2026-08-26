import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';
import '../../commun/ecran_ressource.dart';

/// Module « Encadrement » du portail enseignant : sujets de TFC, encadrements,
/// suivi des mémoires, et validation des stages.
///
/// Six pages web pour un même métier — accompagner un étudiant sur un travail
/// long. Elles reposent toutes sur [EcranRessource] et ne déclarent que leur
/// contrat : source, colonnes, actions.

// ─────────────────────────────────────────────────────────────
// TFC : sujets proposés
// ─────────────────────────────────────────────────────────────

class SujetsTfcScreen extends StatelessWidget {
  const SujetsTfcScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Sujets de fin de cycle',
      sousTitre: 'Sujets que je propose aux étudiants',
      libelleCreation: 'Proposer un sujet',
      messageVide: 'Aucun sujet proposé.',
      charger: () => service.sujetsTfc(professeurId),
      description: DescriptionFiche(
        icone: Icons.lightbulb_rounded,
        titre: (f) => f.texte('titre', defaut: 'Sujet'),
        sousTitre: (f) => f.texteOuNul('description'),
        statut: (f) => _statutSujet(f),
        details: (f) => [
          LigneDetail(libelle: 'Domaine', valeur: f.texte('domaine')),
          LigneDetail(
            libelle: 'Places',
            valeur: '${f.entier('placesDisponibles', alias: const ['places'])}',
          ),
          if (f.texte('etudiantNom').isNotEmpty)
            LigneDetail(libelle: 'Attribué à', valeur: f.texte('etudiantNom')),
        ],
      ),
      actions: [
        ActionFiche(
          libelle: 'Valider',
          icone: Icons.check_circle_rounded,
          couleur: AppTheme.statutVert,
          // Un sujet déjà validé ne se revalide pas : le serveur rejette
          // l'appel, et le bouton laisserait croire à une action possible.
          visiblePour: (f) => !f.booleen('valide') &&
              f.texte('statut').toUpperCase() != 'VALIDE',
          executer: (contexte, fiche) => service.validerSujet(fiche.id),
        ),
      ],
      champsCreation: const [
        ChampFormulaire(cle: 'titre', libelle: 'Titre du sujet', obligatoire: true),
        ChampFormulaire(
          cle: 'description',
          libelle: 'Description',
          type: TypeChamp.multiligne,
          obligatoire: true,
        ),
        ChampFormulaire(cle: 'domaine', libelle: 'Domaine'),
        ChampFormulaire(
          cle: 'placesDisponibles',
          libelle: 'Places disponibles',
          type: TypeChamp.nombre,
          valeurInitiale: 1,
          minimum: 1,
          maximum: 10,
        ),
        ChampFormulaire(
          cle: 'prerequis',
          libelle: 'Prérequis',
          type: TypeChamp.multiligne,
        ),
      ],
      onCreer: (valeurs) => service.proposerSujet({
        ...valeurs,
        'professeurId': professeurId,
      }),
    );
  }

  static (String, Color)? _statutSujet(Fiche f) {
    final statut = f.texte('statut').toUpperCase();
    if (f.booleen('valide') || statut == 'VALIDE') {
      return ('Validé', AppTheme.statutVert);
    }
    return switch (statut) {
      'ATTRIBUE' => ('Attribué', AppTheme.statutBleu),
      'DISPONIBLE' => ('Disponible', AppTheme.statutOrange),
      '' => ('En attente', AppTheme.statutOrange),
      _ => (statut.replaceAll('_', ' '), AppTheme.statutNavy),
    };
  }
}

// ─────────────────────────────────────────────────────────────
// TFC : encadrements
// ─────────────────────────────────────────────────────────────

class EncadrementsScreen extends StatelessWidget {
  const EncadrementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Mes encadrements',
      sousTitre: 'Étudiants dont j\'encadre le travail',
      messageVide: 'Aucun encadrement en cours.',
      charger: () => service.encadrements(professeurId),
      description: DescriptionFiche(
        icone: Icons.supervisor_account_rounded,
        titre: (f) => f.texte(
          'etudiantNom',
          alias: const ['etudiant', 'nomEtudiant'],
          defaut: 'Étudiant',
        ),
        sousTitre: (f) => f.texteOuNul('sujet', alias: const ['titre']),
        statut: (f) => _statutEncadrement(f.texte('statut')),
        details: (f) => [
          LigneDetail(libelle: 'Promotion', valeur: f.texte('promotion')),
          LigneDetail(
            libelle: 'Demandé le',
            valeur: formatDate(f.texteOuNul('dateDemande', alias: const ['creeLe'])),
          ),
        ],
      ),
      actions: [
        ActionFiche(
          libelle: 'Accepter',
          icone: Icons.check_rounded,
          couleur: AppTheme.statutVert,
          visiblePour: (f) => f.texte('statut').toUpperCase() == 'EN_ATTENTE',
          executer: (contexte, fiche) =>
              service.changerStatutEncadrement(fiche.id, 'ACCEPTE'),
        ),
        ActionFiche(
          libelle: 'Refuser',
          icone: Icons.close_rounded,
          couleur: AppTheme.statutRouge,
          visiblePour: (f) => f.texte('statut').toUpperCase() == 'EN_ATTENTE',
          executer: (contexte, fiche) =>
              service.changerStatutEncadrement(fiche.id, 'REFUSE'),
        ),
        ActionFiche(
          libelle: 'Terminer',
          icone: Icons.flag_rounded,
          couleur: AppTheme.statutNavy,
          visiblePour: (f) => f.texte('statut').toUpperCase() == 'ACCEPTE',
          executer: (contexte, fiche) =>
              service.changerStatutEncadrement(fiche.id, 'TERMINE'),
        ),
      ],
    );
  }

  static (String, Color)? _statutEncadrement(String code) =>
      switch (code.toUpperCase()) {
        'EN_ATTENTE' => ('En attente', AppTheme.statutOrange),
        'ACCEPTE' => ('Accepté', AppTheme.statutVert),
        'REFUSE' => ('Refusé', AppTheme.statutRouge),
        'TERMINE' => ('Terminé', AppTheme.statutNavy),
        '' => null,
        _ => (code.replaceAll('_', ' '), AppTheme.statutNavy),
      };
}

// ─────────────────────────────────────────────────────────────
// TFC : suivi des mémoires
// ─────────────────────────────────────────────────────────────

class SuiviTfcScreen extends StatelessWidget {
  const SuiviTfcScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Suivi des mémoires',
      sousTitre: 'Progression et retours',
      messageVide: 'Aucun mémoire suivi.',
      charger: () => service.suiviMemoires(professeurId),
      description: DescriptionFiche(
        icone: Icons.trending_up_rounded,
        titre: (f) => f.texte(
          'etudiantNom',
          alias: const ['etudiant'],
          defaut: 'Étudiant',
        ),
        sousTitre: (f) => f.texteOuNul('titre', alias: const ['sujet']),
        statut: (f) {
          final progression = f.entier('progression');
          return (
            '$progression %',
            progression >= 80
                ? AppTheme.statutVert
                : progression >= 40
                    ? AppTheme.statutBleu
                    : AppTheme.statutOrange,
          );
        },
        details: (f) => [
          LigneDetail(
            libelle: 'Dernier dépôt',
            valeur: formatDate(f.texteOuNul('dateDepot')),
          ),
          LigneDetail(
            libelle: 'Soutenance',
            valeur: formatDate(f.texteOuNul('dateSoutenance')),
          ),
        ],
      ),
      actions: [
        ActionFiche(
          libelle: 'Progression',
          icone: Icons.tune_rounded,
          executer: (contexte, fiche) async {
            final valeurs = await DialogueFormulaire.ouvrir(
              contexte,
              titre: 'Mettre à jour la progression',
              champs: [
                ChampFormulaire(
                  cle: 'progression',
                  libelle: 'Progression (%)',
                  type: TypeChamp.nombre,
                  obligatoire: true,
                  valeurInitiale: fiche.entier('progression'),
                  minimum: 0,
                  maximum: 100,
                ),
              ],
            );
            if (valeurs == null) return;
            await service.majProgressionMemoire(
              fiche.id,
              (valeurs['progression'] as num).round(),
            );
          },
        ),
        ActionFiche(
          libelle: 'Commenter',
          icone: Icons.comment_rounded,
          couleur: AppTheme.statutViolet,
          executer: (contexte, fiche) async {
            final valeurs = await DialogueFormulaire.ouvrir(
              contexte,
              titre: 'Retour à l\'étudiant',
              libelleValidation: 'Envoyer',
              champs: const [
                ChampFormulaire(
                  cle: 'commentaire',
                  libelle: 'Commentaire',
                  type: TypeChamp.multiligne,
                  obligatoire: true,
                ),
              ],
            );
            if (valeurs == null) return;
            await service.commenterMemoire(
              fiche.id,
              valeurs['commentaire'].toString(),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Stages : validation, suivi, rapports
// ─────────────────────────────────────────────────────────────

class StagesValidationScreen extends StatelessWidget {
  const StagesValidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Stages à valider',
      sousTitre: 'Conventions en attente de mon avis',
      messageVide: 'Aucun stage en attente de validation.',
      charger: () => service.stagesAValider(professeurId),
      description: DescriptionFiche(
        icone: Icons.fact_check_rounded,
        titre: (f) => f.texte('etudiantNom', alias: const ['etudiant'], defaut: 'Étudiant'),
        sousTitre: (f) => f.texteOuNul('entreprise', alias: const ['organisme']),
        statut: (f) => _statutStage(f.texte('statut')),
        details: (f) => [
          LigneDetail(libelle: 'Poste', valeur: f.texte('poste')),
          LigneDetail(
            libelle: 'Période',
            valeur: [
              formatDate(f.texteOuNul('dateDebut')),
              formatDate(f.texteOuNul('dateFin')),
            ].where((d) => d != '—').join(' → '),
          ),
          LigneDetail(libelle: 'Lieu', valeur: f.texte('lieu')),
        ],
      ),
      actions: [
        ActionFiche(
          libelle: 'Valider',
          icone: Icons.check_circle_rounded,
          couleur: AppTheme.statutVert,
          executer: (contexte, fiche) => service.validerStage(fiche.id),
        ),
        ActionFiche(
          libelle: 'Rejeter',
          icone: Icons.cancel_rounded,
          couleur: AppTheme.statutRouge,
          executer: (contexte, fiche) async {
            // Le motif est exigé par le serveur : sans lui, l'étudiant reçoit
            // un refus sans savoir quoi corriger.
            final valeurs = await DialogueFormulaire.ouvrir(
              contexte,
              titre: 'Motif du rejet',
              libelleValidation: 'Rejeter',
              champs: const [
                ChampFormulaire(
                  cle: 'motif',
                  libelle: 'Motif',
                  type: TypeChamp.multiligne,
                  obligatoire: true,
                ),
              ],
            );
            if (valeurs == null) return;
            await service.rejeterStage(fiche.id, valeurs['motif'].toString());
          },
        ),
      ],
    );
  }
}

class StagesSuiviScreen extends StatelessWidget {
  const StagesSuiviScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Suivi des stages',
      sousTitre: 'Stages en cours sous ma responsabilité',
      messageVide: 'Aucun stage en cours.',
      charger: () => service.suiviStages(professeurId),
      description: DescriptionFiche(
        icone: Icons.route_rounded,
        titre: (f) => f.texte('etudiantNom', alias: const ['etudiant'], defaut: 'Étudiant'),
        sousTitre: (f) => f.texteOuNul('entreprise', alias: const ['organisme']),
        statut: (f) => _statutStage(f.texte('statut')),
        details: (f) => [
          LigneDetail(libelle: 'Encadreur entreprise', valeur: f.texte('encadreur')),
          LigneDetail(
            libelle: 'Période',
            valeur: [
              formatDate(f.texteOuNul('dateDebut')),
              formatDate(f.texteOuNul('dateFin')),
            ].where((d) => d != '—').join(' → '),
          ),
          if (f.contient('progression'))
            LigneDetail(
              libelle: 'Progression',
              valeur: '${f.entier('progression')} %',
            ),
        ],
      ),
    );
  }
}

class RapportsStagesScreen extends StatelessWidget {
  const RapportsStagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Rapports de stage',
      sousTitre: 'À lire et à noter',
      messageVide: 'Aucun rapport déposé.',
      charger: () => service.rapportsStages(professeurId),
      description: DescriptionFiche(
        icone: Icons.description_rounded,
        titre: (f) => f.texte('etudiantNom', alias: const ['etudiant'], defaut: 'Étudiant'),
        sousTitre: (f) => f.texteOuNul('titre', alias: const ['entreprise']),
        statut: (f) => f.decimalOuNul('note') != null
            ? ('Noté ${f.decimal('note').toStringAsFixed(1)}', AppTheme.statutVert)
            : ('À évaluer', AppTheme.statutOrange),
        details: (f) => [
          LigneDetail(
            libelle: 'Déposé le',
            valeur: formatDate(f.texteOuNul('dateDepot')),
          ),
          if (f.texte('commentaire').isNotEmpty)
            LigneDetail(libelle: 'Mon retour', valeur: f.texte('commentaire')),
        ],
      ),
      actions: [
        ActionFiche(
          libelle: 'Évaluer',
          icone: Icons.grading_rounded,
          couleur: AppTheme.statutVert,
          visiblePour: (f) => f.decimalOuNul('note') == null,
          executer: (contexte, fiche) async {
            final valeurs = await DialogueFormulaire.ouvrir(
              contexte,
              titre: 'Évaluer ce rapport',
              champs: const [
                ChampFormulaire(
                  cle: 'note',
                  libelle: 'Note sur 20',
                  type: TypeChamp.decimal,
                  obligatoire: true,
                  minimum: 0,
                  maximum: 20,
                ),
                ChampFormulaire(
                  cle: 'commentaire',
                  libelle: 'Commentaire',
                  type: TypeChamp.multiligne,
                ),
              ],
            );
            if (valeurs == null) return;
            await service.validerRapportStage(
              fiche.id,
              note: valeurs['note'] as num?,
              commentaire: valeurs['commentaire']?.toString(),
            );
          },
        ),
      ],
    );
  }
}

(String, Color)? _statutStage(String code) => switch (code.toUpperCase()) {
      'EN_ATTENTE' || 'SOUMIS' => ('En attente', AppTheme.statutOrange),
      'VALIDE' || 'ACCEPTE' => ('Validé', AppTheme.statutVert),
      'EN_COURS' => ('En cours', AppTheme.statutBleu),
      'REJETE' || 'REFUSE' => ('Rejeté', AppTheme.statutRouge),
      'TERMINE' => ('Terminé', AppTheme.statutNavy),
      '' => null,
      _ => (code.replaceAll('_', ' '), AppTheme.statutNavy),
    };
