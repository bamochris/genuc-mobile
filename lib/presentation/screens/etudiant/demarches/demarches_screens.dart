import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/fichiers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/commun_service.dart';
import '../../../../data/services/etudiant_academique_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';
import '../../commun/ecran_ressource.dart';
import 'transfert_demande_screen.dart';

/// Module « Démarches » du portail étudiant.
///
/// Regroupe ce qu'on demande à l'administration : changer de filière ou de
/// vacation, être transféré, obtenir une attestation, faire reconnaître un
/// diplôme étranger — et suivre l'état de tout cela.

/// Libellés des statuts du circuit de visa, repris de
/// `GestionDemandesAcademiques.jsx` (l'emoji du web est écarté : la pastille
/// porte déjà la couleur).
(String, Color)? statutDemande(String code) => switch (code.toUpperCase()) {
      'BROUILLON' => ('Brouillon', AppTheme.statutNavy),
      'SOUMISE' => ('Soumise', AppTheme.statutOrange),
      'EN_VERIFICATION_ADMIN' => ('Vérification', AppTheme.statutBleu),
      'COMPLEMENTS_DEMANDES' => ('Compléments demandés', AppTheme.statutOrange),
      'EN_AVIS_DEPARTEMENT' => ('Avis département', AppTheme.statutViolet),
      'EN_AVIS_DOYEN' => ('Avis doyen', AppTheme.statutViolet),
      'EN_VALIDATION_SG' => ('Validation SG', AppTheme.statutBleu),
      'VALIDEE' || 'VALIDE' => ('Validée', AppTheme.statutVert),
      'REFUSEE' || 'REFUSE' || 'REJETE' => ('Refusée', AppTheme.statutRouge),
      'ANNULEE' => ('Annulée', AppTheme.statutNavy),
      '' => null,
      _ => (code.replaceAll('_', ' '), AppTheme.statutNavy),
    };

/// Libellés de `TransfertDemande.StatutTransfert`, repris de
/// `SECRETAIRE_ACADEMIQUE/statutsTransfert.jsx`.
///
/// Le circuit de transfert a SON propre jeu de statuts, sans rapport avec
/// celui des demandes académiques : l'écran leur appliquait pourtant
/// [statutDemande], qui n'en connaît aucun. Chaque pastille retombait donc sur
/// le repli « code brut » et affichait « Bouche », « Soumis », « En
/// verification origine » — le nom interne, en l'état.
///
/// `BOUCHE` est bien la valeur déclarée par le serveur, et son sens ne se
/// suppose pas : `TransfertService` la pose à la création en journalisant
/// « Demande créée en brouillon », et les deux seules opérations qu'elle
/// autorise sont la soumission et la suppression. On affiche donc
/// « Brouillon » — le mot que l'application emploie partout ailleurs.
(String, Color)? statutTransfert(String code) => switch (code.toUpperCase()) {
      'BOUCHE' => ('Brouillon', AppTheme.statutNavy),
      'SOUMIS' => ('Soumise', AppTheme.statutOrange),
      'EN_VERIFICATION_ORIGINE' =>
        ('Vérification à l\'origine', AppTheme.statutBleu),
      'QUITUS_DELIVRE' => ('Quitus délivré', AppTheme.statutVert),
      'QUITUS_REFUSE' => ('Quitus refusé', AppTheme.statutRouge),
      'EN_EXAMEN_DESTINATION' =>
        ('Examen à destination', AppTheme.statutBleu),
      'EQUIVALENCES_EN_COURS' =>
        ('Équivalences en cours', AppTheme.statutBleu),
      'DECISION_FINALE' => ('Décision finale', AppTheme.statutBleu),
      'ACCEPTE' => ('Acceptée', AppTheme.statutVert),
      'ACCEPTE_SOUS_CONDITION' =>
        ('Acceptée sous condition', AppTheme.statutOrange),
      'REFUSE' => ('Refusée', AppTheme.statutRouge),
      'ESCALADE_MINISTERIELLE' =>
        ('Escalade ministérielle', AppTheme.statutRouge),
      'CLOTURE' => ('Clôturée', AppTheme.statutNavy),
      '' => null,
      _ => (code.replaceAll('_', ' '), AppTheme.statutNavy),
    };

/// Types réellement PROPOSÉS à la création.
///
/// « Inter-vacation » n'y figure plus, et c'était la valeur par défaut du
/// formulaire : `TransfertDemande` n'a jamais porté ni vacation d'origine ni
/// vacation de destination, aucun service ne traitait ce cas, et le serveur le
/// refuse désormais à la création. Un candidat pressé envoyait une demande
/// inexploitable sans avoir rien choisi, puis attendait une réponse qui ne
/// pouvait pas venir.
///
/// Le changement de vacation se demande par les DEMANDES ACADÉMIQUES
/// (`CHANGEMENT_VACATION`, ci-dessus), où le circuit est complet : vacation
/// actuelle, vacation souhaitée, instruction et visa.
const Map<String, String> typesTransfertProposes = {
  'INTER_FILIERE': 'Inter-filière (changer de filière)',
  'INTER_UNIVERSITAIRE': 'Inter-universitaire (changer d\'établissement)',
};

/// Libellés de TOUS les types, y compris celui qu'on ne propose plus : une
/// demande archivée doit rester lisible, et non afficher « INTER_VACATION »
/// brut dans l'historique.
String libelleTypeTransfert(String code) => switch (code.toUpperCase()) {
      'INTER_VACATION' => 'Inter-vacation',
      'INTER_FILIERE' => 'Inter-filière',
      'INTER_UNIVERSITAIRE' => 'Inter-universitaire',
      '' => 'Transfert',
      _ => code.replaceAll('_', ' '),
    };

/// Titre d'une demande de transfert dans la liste de suivi.
///
/// Le titre ne portait que l'établissement d'accueil. Depuis que le dépôt
/// exige la cascade complète (établissement → filière → promotion), deux
/// demandes vers le même établissement — le cas COURANT, puisqu'un
/// inter-filière n'en change pas — s'affichaient à l'identique : la liste ne
/// les distinguait plus. C'est la filière qui les sépare, elle passe devant.
///
/// Le serveur n'impose aucun des deux champs : `verifierCoherenceDestination`
/// ne vérifie que leur cohérence entre eux, afin que les dossiers anciens
/// restent relisibles. Chaque niveau peut donc manquer, et le titre se replie.
String titreTransfert(Fiche f) {
  final filiere = f.texte('filiereDestinationNom');
  final etablissement = f.texte(
    'universiteDestinationNom',
    alias: const ['universiteDestination', 'destination'],
  );
  if (filiere.isNotEmpty && etablissement.isNotEmpty) {
    return '$filiere — $etablissement';
  }
  if (filiere.isNotEmpty) return filiere;
  if (etablissement.isNotEmpty) return etablissement;
  return 'Demande de transfert';
}

/// Les deux seuls types qu'un étudiant peut introduire lui-même.
///
/// Réorientation, réintégration et suspension existent aussi côté serveur mais
/// sont ouvertes à l'administration (`ROLES_CREATION_MOUVEMENT`) : les
/// proposer ici produirait un refus systématique.
const Map<String, String> _typesOuvertsAEtudiant = {
  'CHANGEMENT_FILIERE': 'Changement de filière',
  'CHANGEMENT_VACATION': 'Changement de vacation',
};

// ─────────────────────────────────────────────────────────────
// Suivi des demandes
// ─────────────────────────────────────────────────────────────

class MesDemandesScreen extends StatelessWidget {
  const MesDemandesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EtudiantAcademiqueService>();

    return EcranRessource(
      titre: 'Suivi de mes demandes',
      sousTitre: 'Où en sont mes démarches',
      messageVide: 'Vous n\'avez introduit aucune demande.',
      charger: service.mesDemandes,
      description: DescriptionFiche(
        icone: Icons.fact_check_rounded,
        titre: (f) => _libelleType(f.texte('typeDemande')),
        sousTitre: (f) => f.texteOuNul('numeroDemande'),
        statut: (f) => statutDemande(f.texte('statut')),
        details: (f) => [
          LigneDetail(
            libelle: 'Introduite le',
            valeur: formatDate(f.texteOuNul('creeLe', alias: const ['dateCreation'])),
          ),
          if (f.texte('motif').isNotEmpty)
            LigneDetail(libelle: 'Motif', valeur: f.texte('motif')),
        ],
      ),
    );
  }

  static String _libelleType(String code) =>
      _typesOuvertsAEtudiant[code] ??
      switch (code) {
        'REORIENTATION' => 'Réorientation',
        'REINTEGRATION' => 'Réintégration',
        'SUSPENSION' => 'Suspension',
        'REINSCRIPTION' => 'Réinscription',
        '' => 'Demande',
        _ => code.replaceAll('_', ' '),
      };
}

// ─────────────────────────────────────────────────────────────
// Changement de filière / de vacation
// ─────────────────────────────────────────────────────────────

/// Formulaire de changement de filière ou de vacation.
///
/// Le web en fait deux pages (`NouvelleDemandeFiliere`,
/// `NouvelleDemandeVacation`) mais elles suivent le même circuit : créer un
/// brouillon, puis le soumettre. Seule la cible change — une filière ou une
/// vacation. Elles partagent donc cet écran, paramétré par [type].
class NouvelleDemandeScreen extends StatefulWidget {
  final String type;

  const NouvelleDemandeScreen({super.key, required this.type});

  @override
  State<NouvelleDemandeScreen> createState() => _NouvelleDemandeScreenState();
}

class _NouvelleDemandeScreenState extends State<NouvelleDemandeScreen> {
  final _cleFormulaire = GlobalKey<FormState>();
  final _motif = TextEditingController();

  Map<String, String> _cibles = const {};
  String? _cibleActuelle;
  String? _cibleSouhaitee;
  bool _chargement = true;
  bool _envoiEnCours = false;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  bool get _estFiliere => widget.type == 'CHANGEMENT_FILIERE';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final universiteId = context.read<AuthProvider>().user?.universiteId;
    if (universiteId == null || universiteId.isEmpty) {
      setState(() {
        _chargement = false;
        _erreur = 'Établissement inconnu : impossible de charger les options.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final commun = context.read<CommunService>();
    try {
      final fiches = _estFiliere
          ? await commun.filieres(universiteId)
          : await commun.vacationsActives(universiteId);
      if (!mounted) return;
      setState(() {
        _cibles = {
          for (final f in fiches)
            f.id: f.texte('nom', alias: const ['libelle', 'intitule'], defaut: '—'),
        };
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.toString();
        _chargement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final libelleCible = _estFiliere ? 'filière' : 'vacation';

    return PagePortail(
      titre: _estFiliere ? 'Changement de filière' : 'Changement de vacation',
      sousTitre: 'Demande adressée à votre établissement',
      onRafraichir: _charger,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: false,
        onReessayer: _charger,
        enfant: Form(
          key: _cleFormulaire,
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (_message != null)
                BandeauMessage(
                  message: _message!,
                  succes: _messageSucces,
                  onFermer: () => setState(() => _message = null),
                ),
              CartePortail(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Votre demande passe par le département, le doyen puis '
                      'le secrétariat général académique. Vous pourrez en '
                      'suivre l\'avancement dans « Suivi de mes demandes ».',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _cibleActuelle,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: '${_capitaliser(libelleCible)} actuelle *',
                ),
                items: _optionsMenu,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Champ obligatoire' : null,
                onChanged: (v) => setState(() => _cibleActuelle = v),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _cibleSouhaitee,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: '${_capitaliser(libelleCible)} souhaitée *',
                ),
                items: _optionsMenu,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Champ obligatoire';
                  // Contrôle repris du web : sans lui, le serveur accepte une
                  // demande qui ne change rien et le dossier part en visa.
                  if (v == _cibleActuelle) {
                    return 'Choisissez une $libelleCible différente.';
                  }
                  return null;
                },
                onChanged: (v) => setState(() => _cibleSouhaitee = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _motif,
                maxLines: 5,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Motif de la demande *',
                  alignLabelWithHint: true,
                  hintText: 'Expliquez les raisons de votre demande.',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Le motif est obligatoire.' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _envoiEnCours ? null : _soumettre,
                icon: _envoiEnCours
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_envoiEnCours ? 'Envoi…' : 'Soumettre ma demande'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> get _optionsMenu => _cibles.entries
      .map((e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ))
      .toList();

  static String _capitaliser(String texte) =>
      texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);

  Future<void> _soumettre() async {
    if (!(_cleFormulaire.currentState?.validate() ?? false)) return;

    final user = context.read<AuthProvider>().user;
    final service = context.read<EtudiantAcademiqueService>();

    setState(() => _envoiEnCours = true);
    try {
      final corps = <String, dynamic>{
        'typeDemande': widget.type,
        'motif': _motif.text.trim(),
        'universiteId': user?.universiteId,
        'etudiantId': user?.id,
        if (_estFiliere) ...{
          'filiereActuelleId': _cibleActuelle,
          'filiereSouhaiteeId': _cibleSouhaitee,
        } else ...{
          'vacationActuelleId': _cibleActuelle,
          'vacationSouhaiteeId': _cibleSouhaitee,
        },
      };

      // Deux temps, comme le web : la création rend un BROUILLON, qui ne part
      // en visa qu'une fois soumis. Sans le second appel, la demande reste
      // invisible pour l'administration.
      final creee = await service.creerDemande(corps);
      final id = creee.id;
      if (id.isNotEmpty) await service.soumettreDemande(id);

      if (!mounted) return;
      setState(() {
        _message = 'Demande soumise. Suivez-la dans « Suivi de mes demandes ».';
        _messageSucces = true;
        _motif.clear();
        _cibleActuelle = null;
        _cibleSouhaitee = null;
      });
      _cleFormulaire.currentState?.reset();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString();
        _messageSucces = false;
      });
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Transfert inter-établissements
// ─────────────────────────────────────────────────────────────

/// Suivi des demandes de transfert de l'étudiant.
///
/// Le DÉPÔT vit dans `TransfertDemandeScreen` : la destination est une cascade
/// (établissement → filière → promotion) que la boîte de dialogue déclarative
/// ne sait pas enchaîner.
///
/// Trois défauts corrigés ici le 28/08/2026, dont aucun ne se voyait :
///
/// 1. La LISTE tapait `GET /api/transfert/demandes`, réservée aux rôles
///    d'instruction : l'étudiant recevait un 403 et lisait « aucune demande »
///    quoi qu'il ait déposé. Son dossier vit sous `/mon-dossier`.
/// 2. Les statuts affichés étaient ceux des demandes académiques, qui ne
///    connaissent aucun des états du circuit de transfert : chaque pastille
///    retombait sur le nom interne, et « BOUCHE » s'affichait tel quel.
/// 3. Une demande créée restait un BROUILLON que personne n'instruit : rien
///    ne permettait de la SOUMETTRE.
class TransfertScreen extends StatelessWidget {
  const TransfertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EtudiantAcademiqueService>();

    return EcranRessource(
      titre: 'Transfert',
      sousTitre: 'Changer de filière ou d\'établissement',
      libelleCreation: 'Demander un transfert',
      messageVide: 'Aucune demande de transfert.',
      charger: service.mesTransferts,
      description: DescriptionFiche(
        icone: Icons.swap_horiz_rounded,
        titre: titreTransfert,
        // `TransfertDemandeDTO` nomme ce champ `numeroDemande`. On lisait
        // `numeroTransfert`, qui n'existe nulle part : la référence du dossier
        // — la seule chose que le secrétariat demande au guichet — n'a jamais
        // été affichée.
        sousTitre: (f) => f.texteOuNul('numeroDemande'),
        statut: (f) => statutTransfert(f.texte('statut')),
        details: (f) => [
          LigneDetail(
            libelle: 'Type',
            valeur: libelleTypeTransfert(f.texte('typeTransfert')),
          ),
          // Troisième niveau de la cascade : le titre porte les deux premiers,
          // la promotion d'accueil n'avait nulle part où s'afficher alors
          // qu'elle est exigée au dépôt.
          if (f.texte('promotionDestinationLibelle').isNotEmpty)
            LigneDetail(
              libelle: 'Promotion d\'accueil',
              valeur: f.texte('promotionDestinationLibelle'),
            ),
          LigneDetail(
            libelle: 'Introduite le',
            valeur: formatDate(
              f.texteOuNul('creeLe', alias: const ['dateDemande']),
            ),
          ),
          if (f.texte('motif').isNotEmpty)
            LigneDetail(libelle: 'Motif', valeur: f.texte('motif')),
        ],
      ),
      actions: [
        ActionFiche(
          libelle: 'Soumettre',
          icone: Icons.send_rounded,
          couleur: AppTheme.statutVert,
          visiblePour: _estBrouillon,
          executer: (ctx, f) => service.soumettreTransfert(f.id),
        ),
        ActionFiche(
          libelle: 'Supprimer',
          icone: Icons.delete_rounded,
          couleur: AppTheme.error,
          // Une demande soumise ne se retire plus : le serveur la refuse
          // (« Seule une demande en brouillon peut être supprimée ») et
          // n'expliquerait rien de plus qu'un « Requête invalide ».
          visiblePour: _estBrouillon,
          executer: (ctx, f) async {
            final confirme = await showDialog<bool>(
              context: ctx,
              builder: (d) => AlertDialog(
                title: const Text('Supprimer le brouillon'),
                content: const Text(
                  'Cette demande de transfert sera définitivement retirée.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(d, false),
                    child: const Text('Annuler'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(d, true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.error,
                    ),
                    child: const Text('Supprimer'),
                  ),
                ],
              ),
            );
            if (confirme == true) await service.supprimerTransfert(f.id);
          },
        ),
      ],
      // La saisie est confiée à un ÉCRAN, pas à la boîte de dialogue
      // générique : la destination est une cascade — établissement, puis
      // filière, puis promotion —, et le formulaire déclaratif résout ses
      // options une fois pour toutes avant l'ouverture. Voir
      // `TransfertDemandeScreen` pour ce que l'ESU exige de ces trois niveaux.
      onNouveau: (ctx) => Navigator.of(ctx).push<String>(
        MaterialPageRoute(builder: (_) => const TransfertDemandeScreen()),
      ),
    );
  }

  static bool _estBrouillon(Fiche f) =>
      f.texte('statut').toUpperCase() == 'BOUCHE';

}

// ─────────────────────────────────────────────────────────────
// Attestations
// ─────────────────────────────────────────────────────────────

class AttestationsScreen extends StatelessWidget {
  const AttestationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EtudiantAcademiqueService>();
    final user = context.read<AuthProvider>().user;
    final inscriptionId = user?.inscriptionId ?? '';

    return EcranRessource(
      titre: 'Attestations',
      sousTitre: 'Demander et récupérer mes attestations',
      libelleCreation: 'Demander une attestation',
      messageVide: 'Aucune attestation demandée.',
      charger: () => service.attestations(inscriptionId),
      description: DescriptionFiche(
        icone: Icons.note_alt_rounded,
        titre: (f) => _libelleType(f.texte('type')),
        sousTitre: (f) => f.texteOuNul('numeroAttestation'),
        statut: (f) => statutDemande(f.texte('statut')),
        details: (f) => [
          LigneDetail(
            libelle: 'Demandée le',
            valeur: formatDate(f.texteOuNul('dateDemande')),
          ),
          if (f.texteOuNul('dateEmission') != null)
            LigneDetail(
              libelle: 'Émise le',
              valeur: formatDate(f.texteOuNul('dateEmission')),
            ),
          if (f.texte('motif').isNotEmpty)
            LigneDetail(libelle: 'Motif', valeur: f.texte('motif')),
        ],
      ),
      actions: [
        ActionFiche(
          libelle: 'Télécharger',
          icone: Icons.download_rounded,
          couleur: AppTheme.statutVert,
          // Le PDF n'existe qu'une fois l'attestation émise : proposer le
          // téléchargement d'une demande en attente ne rend qu'un 404.
          visiblePour: (f) => f.texteOuNul('dateEmission') != null ||
              f.texte('statut').toUpperCase().startsWith('VALID'),
          executer: (contexte, fiche) async {
            final octets = await service.attestationPdf(fiche.id);
            await Fichiers.enregistrerEtOuvrir(
              octets,
              'attestation-${fiche.texte('numeroAttestation', defaut: fiche.id)}.pdf',
            );
          },
        ),
      ],
      champsCreation: const [
        ChampFormulaire(
          cle: 'type',
          libelle: 'Type d\'attestation',
          type: TypeChamp.liste,
          obligatoire: true,
          valeurInitiale: 'INSCRIPTION',
          options: {
            'INSCRIPTION': 'Attestation d\'inscription',
            'FREQUENTATION': 'Attestation de fréquentation',
            'REUSSITE': 'Attestation de réussite',
            'DIPLOME': 'Attestation de diplôme',
            'AUTRE': 'Autre',
          },
        ),
        ChampFormulaire(
          cle: 'motif',
          libelle: 'Motif de la demande',
          type: TypeChamp.multiligne,
          obligatoire: true,
          indice: 'À quoi cette attestation va-t-elle servir ?',
        ),
      ],
      onCreer: (valeurs) => service.demanderAttestation({
        ...valeurs,
        'inscriptionId': inscriptionId,
      }),
    );
  }

  static String _libelleType(String code) => switch (code) {
        'INSCRIPTION' => 'Attestation d\'inscription',
        'FREQUENTATION' => 'Attestation de fréquentation',
        'REUSSITE' => 'Attestation de réussite',
        'DIPLOME' => 'Attestation de diplôme',
        '' => 'Attestation',
        _ => code.replaceAll('_', ' '),
      };
}

// ─────────────────────────────────────────────────────────────
// Équivalences de diplômes
// ─────────────────────────────────────────────────────────────

class EquivalencesScreen extends StatelessWidget {
  const EquivalencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EtudiantAcademiqueService>();
    final user = context.read<AuthProvider>().user;
    final utilisateurId = user?.id ?? '';

    return EcranRessource(
      titre: 'Équivalences de diplômes',
      sousTitre: 'Faire reconnaître un diplôme obtenu ailleurs',
      libelleCreation: 'Demander une équivalence',
      messageVide: 'Aucune demande d\'équivalence.',
      charger: () => service.equivalences(utilisateurId),
      description: DescriptionFiche(
        icone: Icons.workspace_premium_rounded,
        titre: (f) => f.texte('diplomeObtenu', defaut: 'Diplôme'),
        sousTitre: (f) => f.texteOuNul('etablissementOrigine'),
        statut: (f) => statutDemande(f.texte('statut')),
        details: (f) => [
          LigneDetail(
            libelle: 'Niveau demandé',
            valeur: f.texte('niveauDemande'),
          ),
          if (f.texte('niveauAccorde').isNotEmpty)
            LigneDetail(
              libelle: 'Niveau accordé',
              valeur: f.texte('niveauAccorde'),
            ),
          LigneDetail(
            libelle: 'Déposée le',
            valeur: formatDate(f.texteOuNul('dateSoumission')),
          ),
          if (f.texte('decisionMotif').isNotEmpty)
            LigneDetail(libelle: 'Motif de décision', valeur: f.texte('decisionMotif')),
        ],
      ),
      onSupprimer: (fiche) =>
          service.annulerEquivalence(fiche.id, utilisateurId: utilisateurId),
      champsCreation: [
        const ChampFormulaire(
          cle: 'diplomeObtenu',
          libelle: 'Diplôme obtenu',
          obligatoire: true,
        ),
        const ChampFormulaire(
          cle: 'etablissementOrigine',
          libelle: 'Établissement d\'origine',
          obligatoire: true,
        ),
        const ChampFormulaire(
          cle: 'paysOrigine',
          libelle: 'Pays d\'origine',
          obligatoire: true,
        ),
        ChampFormulaire(
          cle: 'anneeObtention',
          libelle: 'Année d\'obtention',
          type: TypeChamp.nombre,
          minimum: 1950,
          maximum: DateTime.now().year,
        ),
        const ChampFormulaire(cle: 'domaineEtude', libelle: 'Domaine d\'étude'),
        const ChampFormulaire(
          cle: 'niveauDemande',
          libelle: 'Niveau demandé',
          type: TypeChamp.liste,
          obligatoire: true,
          options: {
            'L1': 'Licence 1',
            'L2': 'Licence 2',
            'L3': 'Licence 3',
            'M1': 'Master 1',
            'M2': 'Master 2',
          },
        ),
        const ChampFormulaire(
          cle: 'diplome',
          libelle: 'Diplôme scanné',
          type: TypeChamp.fichier,
          obligatoire: true,
          indice: 'Copie scannée du diplôme (PDF ou image)',
          extensions: ['pdf', 'jpg', 'jpeg', 'png'],
        ),
      ],
      onCreer: (valeurs) => service.demanderEquivalence({
        ...valeurs,
        'userId': utilisateurId,
        'universiteId': user?.universiteId,
      }),
    );
  }
}
