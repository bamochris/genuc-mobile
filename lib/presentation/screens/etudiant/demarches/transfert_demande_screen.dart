import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/commun_service.dart';
import '../../../../data/services/etudiant_academique_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/portail_widgets.dart';
import 'demarches_screens.dart' show typesTransfertProposes;

/// Dépôt d'une demande de transfert, tel que l'ESU l'exige.
///
/// <h3>Pourquoi cet écran n'est pas un simple formulaire de plus</h3>
///
/// Le circuit d'un transfert est : soumission → vérification à l'origine
/// (quitus) → **examen à destination** → équivalences → décision finale. Deux
/// de ces étapes dépendent matériellement de la destination :
///
/// - l'examen à destination est **routé** par
///   `findByUniversiteDestinationIdAndStatutIn` : sans établissement
///   d'accueil, le dossier n'arrive sur le bureau de personne ;
/// - la commission d'équivalences compare les UE d'un programme à celles d'un
///   **autre** programme, année par année : sans filière ni promotion
///   d'accueil, il n'y a rien à comparer.
///
/// La saisie précédente ne demandait que l'établissement et le motif. Le
/// serveur accepte ces champs nuls — il doit rester capable de relire les
/// dossiers anciens — c'est donc ici qu'il faut les exiger, et c'est pourquoi
/// cet écran remplace la boîte de dialogue générique : les trois niveaux
/// s'enchaînent, chacun ne pouvant être proposé qu'une fois le précédent
/// choisi.
class TransfertDemandeScreen extends StatefulWidget {
  const TransfertDemandeScreen({super.key});

  @override
  State<TransfertDemandeScreen> createState() => _TransfertDemandeScreenState();
}

class _TransfertDemandeScreenState extends State<TransfertDemandeScreen> {
  final _cleFormulaire = GlobalKey<FormState>();
  final _motif = TextEditingController();
  final _anneeAccueil = TextEditingController();

  /// Dossier d'inscription : porte `etudiantId` et l'établissement d'origine,
  /// que la session ne connaît pas.
  Fiche? _dossier;

  Map<String, String> _universites = const {};
  Map<String, String> _filieres = const {};
  Map<String, String> _promotions = const {};

  String _type = 'INTER_FILIERE';
  String? _universiteDestination;
  String? _filiereDestination;
  String? _promotionDestination;
  String? _semestreAccueil;

  bool _chargement = true;
  bool _chargementFilieres = false;
  bool _chargementPromotions = false;
  bool _envoiEnCours = false;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  /// Un changement de filière reste DANS l'établissement : le proposer
  /// ailleurs serait un transfert inter-universitaire, qui est l'autre type.
  bool get _resteDansSonEtablissement => _type == 'INTER_FILIERE';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _motif.dispose();
    _anneeAccueil.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final inscriptionId = context.read<AuthProvider>().user?.inscriptionId;
    if (inscriptionId == null || inscriptionId.isEmpty) {
      setState(() {
        _chargement = false;
        _erreur = 'Aucune inscription active : le transfert part de votre '
            'dossier d\'inscription.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    final service = context.read<EtudiantAcademiqueService>();
    final commun = context.read<CommunService>();
    try {
      final dossier = await service.inscription(inscriptionId);
      final universites = await commun.universites();
      if (!mounted) return;

      setState(() {
        _dossier = dossier;
        _universites = {
          for (final u in universites)
            u.id: u.texte('nom', alias: const ['sigle'], defaut: '—'),
        };
        // L'année d'accueil est proposée depuis le référentiel — l'année de
        // l'inscription — et non calculée sur l'horloge : l'année académique
        // bascule en septembre, pas en janvier.
        _anneeAccueil.text = dossier.texte('anneeAcademiqueLibelle');
        _chargement = false;
      });

      // Un changement de filière reste dans l'établissement : on le pose
      // d'emblée, et on enchaîne sur ses filières.
      final origine = dossier.texte('universiteId');
      if (origine.isNotEmpty) {
        await _choisirUniversite(origine);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.toString();
        _chargement = false;
      });
    }
  }

  Future<void> _choisirUniversite(String? universiteId) async {
    setState(() {
      _universiteDestination = universiteId;
      // Les deux niveaux inférieurs deviennent caducs : garder une filière
      // choisie dans un autre établissement enverrait une destination
      // incohérente, que le serveur ne recoupe pas — `verifierCoherence-
      // Destination` ne relie la filière qu'au DÉPARTEMENT, jamais à
      // l'université.
      _filiereDestination = null;
      _promotionDestination = null;
      _filieres = const {};
      _promotions = const {};
      _chargementFilieres = universiteId != null;
    });
    if (universiteId == null || universiteId.isEmpty) return;

    try {
      final filieres = await context.read<CommunService>().filieres(universiteId);
      if (!mounted) return;
      setState(() {
        _filieres = {
          for (final f in filieres)
            f.id: f.texte('nom', alias: const ['libelle', 'intitule'], defaut: '—'),
        };
        _chargementFilieres = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementFilieres = false;
        _message = 'Les filières de cet établissement n\'ont pas pu être '
            'chargées : $e';
        _messageSucces = false;
      });
    }
  }

  Future<void> _choisirFiliere(String? filiereId) async {
    setState(() {
      _filiereDestination = filiereId;
      _promotionDestination = null;
      _promotions = const {};
      _chargementPromotions = filiereId != null;
    });
    if (filiereId == null || filiereId.isEmpty) return;

    try {
      final promotions =
          await context.read<CommunService>().promotionsDeFiliere(filiereId);
      if (!mounted) return;
      setState(() {
        _promotions = {
          for (final p in promotions)
            p.id: p.texte('libelle', alias: const ['nom'], defaut: '—'),
        };
        _chargementPromotions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementPromotions = false;
        _message =
            'Les promotions de cette filière n\'ont pas pu être chargées : $e';
        _messageSucces = false;
      });
    }
  }

  Future<void> _deposer() async {
    if (!(_cleFormulaire.currentState?.validate() ?? false)) return;

    final dossier = _dossier;
    final inscriptionId = context.read<AuthProvider>().user?.inscriptionId;
    if (dossier == null || inscriptionId == null) return;

    // `createDemande` exige les trois, et son garde `peutCreerTransfert` les
    // vérifie un à un. `etudiantId` ne vient pas de la session : ni la réponse
    // de connexion ni `/api/auth/moi` ne le portaient jusqu'au 28/08/2026, et
    // un client ancien ne le recevra pas. Le dossier d'inscription en est la
    // source sûre.
    final etudiantId = dossier.entier('etudiantId', defaut: 0);
    final universiteOrigineId = dossier.entier('universiteId', defaut: 0);
    if (etudiantId == 0 || universiteOrigineId == 0) {
      setState(() {
        _message = 'Votre dossier d\'inscription est incomplet : adressez-vous '
            'au secrétariat académique.';
        _messageSucces = false;
      });
      return;
    }

    setState(() {
      _envoiEnCours = true;
      _message = null;
    });

    try {
      final service = context.read<EtudiantAcademiqueService>();
      final creee = await service.demanderTransfert({
        'etudiantId': etudiantId,
        'inscriptionId': int.tryParse(inscriptionId),
        'universiteOrigineId': universiteOrigineId,
        // Les autres identifiants d'ORIGINE ne sont volontairement pas
        // envoyés : le service les reprend lui-même de l'inscription, et
        // `verifierCoherenceOrigine` refuse tout écart entre ce qu'on affirme
        // et ce qu'elle porte. Ne rien affirmer est ici plus sûr que recopier.
        'universiteDestinationId': int.tryParse(_universiteDestination ?? ''),
        'filiereDestinationId': int.tryParse(_filiereDestination ?? ''),
        'promotionDestinationId': int.tryParse(_promotionDestination ?? ''),
        'typeTransfert': _type,
        'motif': _motif.text.trim(),
        'anneeAcademique': dossier.texteOuNul('anneeAcademiqueLibelle'),
        'anneeAccueil': _anneeAccueil.text.trim().isEmpty
            ? null
            : _anneeAccueil.text.trim(),
        'semestreAccueil': _semestreAccueil,
      });

      if (!mounted) return;
      // La création n'ouvre qu'un BROUILLON : `TransfertService` le journalise
      // ainsi, et les deux seules opérations qu'il autorise ensuite sont la
      // soumission et la suppression. On laisse l'étudiant relire son dossier
      // et le soumettre depuis la liste — c'est aussi le déroulé du portail
      // web, qui sépare « Enregistrer » de « Soumettre ».
      Navigator.of(context).pop(creee.id.isNotEmpty ? creee.id : 'cree');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString();
        _messageSucces = false;
        _envoiEnCours = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: 'Demander un transfert',
      sousTitre: 'Votre dossier sera examiné par l\'établissement d\'accueil',
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
              _carteOrigine(),
              const SizedBox(height: 16),
              _carteDestination(),
              const SizedBox(height: 16),
              _carteMotif(),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _envoiEnCours ? null : _deposer,
                icon: _envoiEnCours
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _envoiEnCours ? 'Enregistrement…' : 'Enregistrer le brouillon',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Votre demande est d\'abord enregistrée en brouillon. Vous '
                'pourrez la relire, puis la soumettre depuis la liste de vos '
                'demandes.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMutedOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// L'origine est LUE, jamais saisie : le serveur refuse toute autre valeur.
  Widget _carteOrigine() {
    final d = _dossier;
    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EnteteSection(
            titre: 'Votre situation actuelle',
            icone: Icons.school_rounded,
          ),
          LigneDetail(
            libelle: 'Établissement',
            valeur: d?.texte('universiteNom', defaut: '—') ?? '—',
          ),
          LigneDetail(
            libelle: 'Filière',
            valeur: d?.texte('filiereNom', defaut: '—') ?? '—',
          ),
          LigneDetail(
            libelle: 'Promotion',
            valeur: d?.texte('promotionLibelle', defaut: '—') ?? '—',
          ),
          LigneDetail(
            libelle: 'Année',
            valeur: d?.texte('anneeAcademiqueLibelle', defaut: '—') ?? '—',
          ),
          const SizedBox(height: 6),
          Text(
            'Ces informations viennent de votre dossier d\'inscription : elles '
            'ne se saisissent pas.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMutedOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteDestination() {
    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EnteteSection(
            titre: 'Où vous souhaitez aller',
            icone: Icons.swap_horiz_rounded,
          ),
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Nature du transfert *',
            ),
            items: [
              for (final e in typesTransfertProposes.entries)
                DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _type = v);
              // Repartir de l'établissement d'origine quand on revient à un
              // changement de filière : garder un autre établissement
              // produirait une demande dont le type contredit la destination.
              if (v == 'INTER_FILIERE') {
                _choisirUniversite(_dossier?.texte('universiteId'));
              }
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _universiteDestination,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Établissement d\'accueil *',
              helperText: _resteDansSonEtablissement
                  ? 'Un changement de filière reste dans votre établissement.'
                  : 'C\'est lui qui examinera votre dossier.',
            ),
            items: [
              for (final e in _universites.entries)
                DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            // Verrouillé sur son propre établissement pour un changement de
            // filière : le laisser modifiable inviterait à composer une
            // demande que le type contredit.
            onChanged: _resteDansSonEtablissement ? null : _choisirUniversite,
            validator: (v) => (v == null || v.isEmpty)
                ? 'Indiquez l\'établissement d\'accueil.'
                : null,
          ),
          const SizedBox(height: 14),
          _listeCascade(
            libelle: 'Filière d\'accueil *',
            aide: 'Les équivalences se calculent par rapport à son programme.',
            valeur: _filiereDestination,
            options: _filieres,
            chargement: _chargementFilieres,
            messageVide: 'Choisissez d\'abord un établissement.',
            onChanged: _choisirFiliere,
            messageManquant: 'Indiquez la filière d\'accueil.',
          ),
          const SizedBox(height: 14),
          _listeCascade(
            libelle: 'Promotion d\'accueil *',
            aide: 'Les équivalences se comparent année par année.',
            valeur: _promotionDestination,
            options: _promotions,
            chargement: _chargementPromotions,
            messageVide: 'Choisissez d\'abord une filière.',
            onChanged: (v) => setState(() => _promotionDestination = v),
            messageManquant: 'Indiquez la promotion d\'accueil.',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _anneeAccueil,
            decoration: const InputDecoration(
              labelText: 'Année d\'accueil prévue',
              hintText: 'Ex. 2026-2027',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _semestreAccueil,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Semestre d\'accueil',
              helperText: 'Facultatif — le système classique enseigne à '
                  'l\'année.',
            ),
            items: const [
              DropdownMenuItem(value: 'S1', child: Text('Premier semestre')),
              DropdownMenuItem(value: 'S2', child: Text('Second semestre')),
            ],
            onChanged: (v) => setState(() => _semestreAccueil = v),
          ),
        ],
      ),
    );
  }

  Widget _carteMotif() {
    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EnteteSection(
            titre: 'Motif de la demande',
            icone: Icons.edit_note_rounded,
          ),
          TextFormField(
            controller: _motif,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Motif *',
              hintText: 'Expliquez les raisons de votre demande.',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Le motif est obligatoire.'
                : null,
          ),
        ],
      ),
    );
  }

  /// Liste dont les options dépendent du niveau supérieur.
  ///
  /// Une liste vide n'est jamais masquée : un champ obligatoire qui
  /// disparaîtrait laisserait croire qu'il ne l'est pas. On affiche le champ
  /// désactivé, en disant ce qu'il attend.
  Widget _listeCascade({
    required String libelle,
    required String aide,
    required String? valeur,
    required Map<String, String> options,
    required bool chargement,
    required String messageVide,
    required ValueChanged<String?> onChanged,
    required String messageManquant,
  }) {
    final vide = options.isEmpty;
    return DropdownButtonFormField<String>(
      initialValue: valeur,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: libelle,
        helperText: chargement
            ? 'Chargement…'
            : (vide ? messageVide : aide),
      ),
      items: [
        for (final e in options.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: vide || chargement ? null : onChanged,
      validator: (v) => (v == null || v.isEmpty) ? messageManquant : null,
    );
  }
}
