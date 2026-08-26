import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/services/etudiant_academique_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';
import '../../commun/ecran_ressource.dart';
import '../demarches/demarches_screens.dart' show statutDemande;

/// Dossier social et demande de bourse.
///
/// Transposition de `etudiant/DossierSocialEtudiant.jsx`. Le web propose en
/// plus une simulation de bourse (`/api/social/calcul-bourse`) : elle est
/// gardée, en action de la page, car c'est elle qui décide l'étudiant à
/// déposer — la retirer aurait fait de l'écran un simple formulaire.
class DossierSocialScreen extends StatelessWidget {
  const DossierSocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EtudiantAcademiqueService>();
    final user = context.read<AuthProvider>().user;
    final etudiantId = user?.id ?? '';

    return EcranRessource(
      titre: 'Dossier social & bourse',
      sousTitre: 'Situation familiale et demande d\'aide',
      libelleCreation: 'Déposer un dossier',
      messageVide: 'Aucun dossier social déposé.',
      charger: () => service.dossiersSociaux(etudiantId),
      entete: (contexte) => _CarteSimulation(service: service),
      description: DescriptionFiche(
        icone: Icons.volunteer_activism_rounded,
        titre: (f) => f.texte('numeroDossier', defaut: 'Dossier social'),
        sousTitre: (f) => _libelleSituation(f.texte('situationFamiliale')),
        statut: (f) => statutDemande(f.texte('statut')),
        details: (f) => [
          if (f.decimalOuNul('revenuMensuelFoyer') != null)
            LigneDetail(
              libelle: 'Revenu du foyer',
              valeur: formatMontant(f.decimal('revenuMensuelFoyer')),
            ),
          LigneDetail(
            libelle: 'Personnes à charge',
            valeur: '${f.entier('nombrePersonnesCharge')}',
          ),
          if (f.booleen('demandeBourse'))
            LigneDetail(
              libelle: 'Bourse demandée',
              valeur: f.texte('typeBourseDemandee', defaut: 'Oui'),
            ),
          if (f.decimalOuNul('montantDemande') != null)
            LigneDetail(
              libelle: 'Montant demandé',
              valeur: formatMontant(f.decimal('montantDemande')),
            ),
          if (f.texte('commentaireAdmin').isNotEmpty)
            LigneDetail(
              libelle: 'Réponse du service',
              valeur: f.texte('commentaireAdmin'),
            ),
        ],
      ),
      champsCreation: const [
        ChampFormulaire(
          cle: 'situationFamiliale',
          libelle: 'Situation familiale',
          type: TypeChamp.liste,
          obligatoire: true,
          options: {
            'ORPHELIN_TOTAL': 'Orphelin de père et de mère',
            'ORPHELIN_PARTIEL': 'Orphelin d\'un parent',
            'PARENTS_VIVANTS': 'Parents vivants',
            'AUTRE': 'Autre',
          },
        ),
        ChampFormulaire(
          cle: 'professionParent',
          libelle: 'Profession du parent / tuteur',
        ),
        ChampFormulaire(
          cle: 'revenuMensuelFoyer',
          libelle: 'Revenu mensuel du foyer (USD)',
          type: TypeChamp.decimal,
          obligatoire: true,
          minimum: 0,
        ),
        ChampFormulaire(cle: 'sourceRevenu', libelle: 'Source du revenu'),
        ChampFormulaire(
          cle: 'nombrePersonnesCharge',
          libelle: 'Personnes à charge',
          type: TypeChamp.nombre,
          minimum: 0,
        ),
        ChampFormulaire(
          cle: 'nombreEnfants',
          libelle: 'Nombre d\'enfants',
          type: TypeChamp.nombre,
          minimum: 0,
        ),
        ChampFormulaire(
          cle: 'typeLogement',
          libelle: 'Logement',
          type: TypeChamp.liste,
          options: {
            'FAMILIAL': 'Chez la famille',
            'LOCATION': 'En location',
            'CAMPUS': 'Résidence universitaire',
            'AUTRE': 'Autre',
          },
        ),
        ChampFormulaire(
          cle: 'handicap',
          libelle: 'Situation de handicap',
          type: TypeChamp.bascule,
        ),
        ChampFormulaire(cle: 'typeHandicap', libelle: 'Nature du handicap'),
        ChampFormulaire(
          cle: 'problemesSante',
          libelle: 'Problèmes de santé',
          type: TypeChamp.multiligne,
        ),
        ChampFormulaire(
          cle: 'demandeBourse',
          libelle: 'Je demande une bourse',
          type: TypeChamp.bascule,
        ),
        ChampFormulaire(
          cle: 'typeBourseDemandee',
          libelle: 'Type de bourse',
          type: TypeChamp.liste,
          options: {
            'EXCELLENCE': 'Bourse d\'excellence',
            'SOCIALE': 'Bourse sociale',
            'HANDICAP': 'Bourse handicap',
            'MERITE': 'Bourse au mérite',
          },
        ),
        ChampFormulaire(
          cle: 'montantDemande',
          libelle: 'Montant demandé (USD)',
          type: TypeChamp.decimal,
          minimum: 0,
        ),
      ],
      onCreer: (valeurs) => service.deposerDossierSocial({
        ...valeurs,
        'etudiantId': etudiantId,
        'universiteId': user?.universiteId,
      }),
    );
  }

  static String _libelleSituation(String code) => switch (code) {
        'ORPHELIN_TOTAL' => 'Orphelin de père et de mère',
        'ORPHELIN_PARTIEL' => 'Orphelin d\'un parent',
        'PARENTS_VIVANTS' => 'Parents vivants',
        '' => '',
        _ => code.replaceAll('_', ' '),
      };
}

/// Simulateur de bourse : trois chiffres suffisent à donner une estimation,
/// avant d'engager la saisie du dossier complet.
class _CarteSimulation extends StatefulWidget {
  final EtudiantAcademiqueService service;

  const _CarteSimulation({required this.service});

  @override
  State<_CarteSimulation> createState() => _CarteSimulationState();
}

class _CarteSimulationState extends State<_CarteSimulation> {
  String? _resultat;
  bool _enCours = false;

  @override
  Widget build(BuildContext context) {
    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calculate_rounded,
                size: 18,
                color: AppTheme.iconAccent(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Simuler mon éligibilité',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Estimation indicative : seule la commission sociale décide.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          if (_resultat != null) ...[
            const SizedBox(height: 10),
            Text(
              _resultat!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.accentLisible(context, AppTheme.statutVert),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _enCours ? null : _simuler,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(_enCours ? 'Calcul…' : 'Lancer la simulation'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _simuler() async {
    final valeurs = await DialogueFormulaire.ouvrir(
      context,
      titre: 'Simulation de bourse',
      libelleValidation: 'Calculer',
      champs: const [
        ChampFormulaire(
          cle: 'revenuMensuelFoyer',
          libelle: 'Revenu mensuel du foyer (USD)',
          type: TypeChamp.decimal,
          obligatoire: true,
          minimum: 0,
        ),
        ChampFormulaire(
          cle: 'nombrePersonnesCharge',
          libelle: 'Personnes à charge',
          type: TypeChamp.nombre,
          minimum: 0,
        ),
        ChampFormulaire(
          cle: 'situationFamiliale',
          libelle: 'Situation familiale',
          type: TypeChamp.liste,
          obligatoire: true,
          options: {
            'ORPHELIN_TOTAL': 'Orphelin de père et de mère',
            'ORPHELIN_PARTIEL': 'Orphelin d\'un parent',
            'PARENTS_VIVANTS': 'Parents vivants',
            'AUTRE': 'Autre',
          },
        ),
      ],
    );
    if (valeurs == null || !mounted) return;

    setState(() => _enCours = true);
    try {
      final estimation = await widget.service.simulerBourse(valeurs);
      if (!mounted) return;
      final montant = estimation.decimalOuNul('montantEstime');
      final type = estimation.texte('type');
      final details = estimation.texte('details');
      setState(() {
        _resultat = montant == null
            ? (details.isEmpty ? 'Aucune estimation disponible.' : details)
            : '${formatMontant(montant)}'
                '${type.isEmpty ? '' : ' · $type'}'
                '${details.isEmpty ? '' : '\n$details'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _resultat = 'Simulation indisponible : ${e.runtimeType}');
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }
}
