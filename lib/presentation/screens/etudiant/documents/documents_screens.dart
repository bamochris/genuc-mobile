import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/fichiers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/etudiant_academique_service.dart';
import '../../../../data/services/fichiers_prives.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';
import '../../commun/ecran_ressource.dart';

/// Documents de l'étudiant : pièces personnelles téléversées, documents
/// officiels générés par l'établissement, et carte d'étudiant.

// ─────────────────────────────────────────────────────────────
// Mes documents (pièces téléversées)
// ─────────────────────────────────────────────────────────────

class MesDocumentsScreen extends StatefulWidget {
  const MesDocumentsScreen({super.key});

  @override
  State<MesDocumentsScreen> createState() => _MesDocumentsScreenState();
}

class _MesDocumentsScreenState extends State<MesDocumentsScreen> {
  /// Les pieces que l'etablissement exige de cet etudiant.
  ///
  /// L'ecran ecrivait sa PROPRE liste de natures, et deux de ses six choix
  /// n'existaient meme pas cote serveur : `DIPLOME` et `PHOTO` (l'enumeration
  /// dit `DIPLOME_ETAT` et `PHOTO_IDENTITE`). Le depot partait en 400 —
  /// televerser son diplome ou sa photo depuis le telephone n'a jamais
  /// fonctionne. Rien n'etant plus ecrit ici, ces deux choix disparaissent
  /// d'eux-memes.
  List<Fiche> _exigees = const [];

  @override
  void initState() {
    super.initState();
    _chargerExigences();
  }

  Future<void> _chargerExigences() async {
    try {
      final liste = await context.read<EtudiantAcademiqueService>().piecesExigees();
      if (!mounted) return;
      setState(() => _exigees = liste);
    } catch (_) {
      // Sans la liste, l'ecran ne PRETEND rien : il n'affiche pas une exigence
      // vide, qui se lirait « on ne vous demande rien ».
      if (mounted) setState(() => _exigees = const []);
    }
  }

  /// Nature de depot -> libelle de l'etablissement.
  Map<String, String> get _libelles => {
        for (final f in _exigees)
          if (f.texte('typeEtudiant').isNotEmpty)
            f.texte('typeEtudiant'): f.texte('libelle'),
      };

  @override
  Widget build(BuildContext context) {
    final service = context.read<EtudiantAcademiqueService>();
    final inscriptionId =
        context.read<AuthProvider>().user?.inscriptionId ?? '';
    final libelles = _libelles;

    return EcranRessource(
      titre: 'Mes documents',
      sousTitre: 'Pièces de mon dossier',
      libelleCreation: 'Téléverser',
      messageVide: 'Aucune pièce déposée.',
      charger: () => service.documentsPersonnels(inscriptionId),
      description: DescriptionFiche(
        icone: Icons.folder_rounded,
        titre: (f) => f.texte(
          'nomFichier',
          alias: const ['nom', 'libelle'],
          defaut: 'Document',
        ),
        sousTitre: (f) => _libelleType(f.texte('type'), libelles),
        statut: (f) {
          final valide = f.texte('statut', alias: const ['statutValidation']);
          return valide.isEmpty ? null : _statut(valide);
        },
        details: (f) => [
          LigneDetail(
            libelle: 'Déposé le',
            valeur: formatDate(
              f.texteOuNul('dateDepot', alias: const ['creeLe', 'dateUpload']),
            ),
          ),
        ],
      ),
      onSupprimer: (fiche) => service.supprimerDocument(fiche.id),
      // Le formulaire déclaratif ne sait pas choisir un fichier : le dépôt
      // passe par le bouton dédié, seul geste où l'utilisateur voit ce qu'il
      // envoie avant de l'envoyer.
      champsCreation: const [],
      actions: [
        // La pièce porte son chemin de STOCKAGE (« /uploads/documents/… »),
        // que le serveur refuse en accès direct : elle ne s'obtient que par
        // `/api/fichiers/**`, avec le jeton. Passé à `launchUrl`, ce chemin
        // n'ouvrait rien — et son échec ne remontait qu'un `false` ignoré.
        ActionFiche(
          libelle: 'Ouvrir',
          icone: Icons.open_in_new_rounded,
          visiblePour: (f) => f.texte('url', alias: const ['lien']).isNotEmpty,
          executer: (contexte, fiche) async {
            await service.ouvrirRessource(
              fiche.texte('url', alias: const ['lien']),
              nomPropose: fiche.texte('nomFichier', alias: const ['nom']),
            );
          },
        ),
      ],
      entete: (contexte) => _BoutonTeleverser(
        service: service,
        inscriptionId: inscriptionId,
        exigees: _exigees,
      ),
    );
  }

  /// Libellé d'une nature de pièce.
  ///
  /// Cette table traduisait `DIPLOME`, `PHOTO` et `ATTESTATION` — trois codes
  /// que le serveur n'émet pas — et laissait les vrais retomber sur
  /// `code.replaceAll('_', ' ')` : l'étudiant lisait « DIPLOME ETAT » en
  /// capitales. Les libellés viennent désormais des pièces exigées, donc du
  /// vocabulaire de l'établissement ; ce qui suit n'est que le repli, mis en
  /// forme au lieu d'être rendu brut.
  static String _libelleType(String code, [Map<String, String> depuisServeur = const {}]) {
    if (code.isEmpty) return '';
    final duServeur = depuisServeur[code];
    if (duServeur != null && duServeur.isNotEmpty) return duServeur;
    if (code == 'AUTRE') return 'Autre document';
    final mots = code.toLowerCase().replaceAll('_', ' ');
    return mots.isEmpty ? '' : '${mots[0].toUpperCase()}${mots.substring(1)}';
  }

  static (String, Color) _statut(String code) => switch (code.toUpperCase()) {
        'VALIDE' || 'VALIDEE' || 'ACCEPTE' => ('Validé', AppTheme.statutVert),
        'REJETE' || 'REFUSE' => ('Rejeté', AppTheme.statutRouge),
        _ => ('En attente', AppTheme.statutOrange),
      };
}

class _BoutonTeleverser extends StatefulWidget {
  final EtudiantAcademiqueService service;
  final String inscriptionId;

  /// Les pièces exigées, telles que l'établissement les a configurées.
  final List<Fiche> exigees;

  const _BoutonTeleverser({
    required this.service,
    required this.inscriptionId,
    required this.exigees,
  });

  @override
  State<_BoutonTeleverser> createState() => _BoutonTeleverserState();
}

class _BoutonTeleverserState extends State<_BoutonTeleverser> {
  bool _envoiEnCours = false;
  String? _retour;
  bool _succes = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_retour != null)
          BandeauMessage(
            message: _retour!,
            succes: _succes,
            onFermer: () => setState(() => _retour = null),
          ),
        OutlinedButton.icon(
          onPressed: _envoiEnCours ? null : _televerser,
          icon: _envoiEnCours
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_rounded, size: 18),
          label: Text(_envoiEnCours ? 'Envoi en cours…' : 'Téléverser une pièce'),
        ),
      ],
    );
  }

  Future<void> _televerser() async {
    // Les natures proposées sont celles que l'ÉTABLISSEMENT demande, dans son
    // vocabulaire, plus « Autre document » — un étudiant a parfois une pièce à
    // joindre que le règlement n'a pas prévue.
    //
    // La liste écrite en dur ici proposait `DIPLOME` et `PHOTO`, absents de
    // l'énumération du serveur (`DIPLOME_ETAT`, `PHOTO_IDENTITE`) :
    // `TypeDocument.valueOf` levait, et le dépôt repartait en 400. Téléverser
    // son diplôme ou sa photo depuis le téléphone n'a jamais fonctionné.
    final options = <String, String>{
      for (final f in widget.exigees)
        if (f.texte('typeEtudiant').isNotEmpty)
          f.texte('typeEtudiant'): f.booleen('obligatoire')
              ? '${f.texte('libelle')} (obligatoire)'
              : f.texte('libelle'),
      'AUTRE': 'Autre document',
    };

    final type = await DialogueFormulaire.ouvrir(
      context,
      titre: 'Nature de la pièce',
      libelleValidation: 'Choisir le fichier',
      champs: [
        ChampFormulaire(
          cle: 'type',
          libelle: 'Type de document',
          type: TypeChamp.liste,
          obligatoire: true,
          valeurInitiale: options.keys.first,
          options: options,
        ),
      ],
    );
    if (type == null || !mounted) return;

    final fichier = await Fichiers.choisir();
    if (fichier == null || !mounted) return;

    // Contrôle avant l'envoi : au-delà de la limite, la connexion est coupée
    // en amont et l'utilisateur ne voit qu'un « serveur déconnecté ».
    if (fichier.taille > Fichiers.tailleMaxOctets) {
      setState(() {
        _retour = 'Fichier trop lourd (${fichier.tailleLisible}). '
            'Maximum accepté : ${Fichiers.tailleMaxLisible}.';
        _succes = false;
      });
      return;
    }

    setState(() => _envoiEnCours = true);
    try {
      await widget.service.televerserDocument(
        inscriptionId: widget.inscriptionId,
        type: type['type'].toString(),
        cheminFichier: fichier.chemin,
        nomFichier: fichier.nom,
      );
      if (!mounted) return;
      setState(() {
        _retour = 'Pièce déposée. Tirez la liste vers le bas pour l\'y voir.';
        _succes = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _retour = e is ApiException ? e.message : e.toString();
        _succes = false;
      });
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Documents officiels
// ─────────────────────────────────────────────────────────────

/// Documents que l'établissement génère à la demande (certificat de
/// scolarité, relevé officiel…).
/// Documents officiels : le CATALOGUE de l'établissement, ligne par ligne.
///
/// ── Ce que cet écran lisait, et ce que le serveur envoie ────────────────
///
/// `DocumentsOfficielsService.mapperDocument` rend `type`, `label`,
/// `description`, `typeSource`, `fraisCodeRequis`, `statut`, `canDownload`,
/// `canRequest`, `motif`, et — pour un document déjà émis — `documentId` et
/// `dateGeneration`. L'écran lisait `libelle`, `numero` et `dateEmission` :
/// trois clés qui n'existent dans aucune réponse. Le titre retombait donc sur
/// le CODE brut (« CERTIFICAT_SCOLARITE »), le sous-titre et la date restaient
/// vides en permanence.
///
/// Il ignorait surtout `statut` et `canDownload` : « Télécharger » était
/// proposé sur toutes les lignes, y compris celles en attente de paiement ou
/// de traitement — un bouton qui ne pouvait que retourner une erreur.
///
/// ── Pourquoi le formulaire « Demander » disparaît ───────────────────────
///
/// Il proposait quatre types écrits en dur. Or le catalogue est un
/// PARAMÉTRAGE d'établissement (`DocumentOfficielConfig`) : demander un code
/// absent de ce paramétrage renvoie « Document officiel introuvable ». La
/// demande se fait donc sur la ligne du document voulu, comme sur le web —
/// c'est la seule liste qui soit sûrement la bonne.
class DocumentsOfficielsScreen extends StatelessWidget {
  const DocumentsOfficielsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EtudiantAcademiqueService>();
    final inscriptionId =
        context.read<AuthProvider>().user?.inscriptionId ?? '';

    return EcranRessource(
      titre: 'Documents officiels',
      sousTitre: 'Générés et signés par l\'établissement',
      messageVide: 'Aucun document officiel n\'est configuré pour votre '
          'établissement.',
      charger: () => service.documentsOfficiels(inscriptionId),
      description: DescriptionFiche(
        icone: Icons.verified_rounded,
        titre: (f) => f.texte('label', alias: const ['libelle'], defaut: 'Document'),
        sousTitre: (f) => f.texteOuNul('description'),
        statut: (f) => _statutDocument(f.texte('statut')),
        details: (f) => [
          if (f.texteOuNul('dateGeneration') != null)
            LigneDetail(
              libelle: 'Généré le',
              valeur: formatDate(f.texteOuNul('dateGeneration')),
            ),
          if (f.texte('fraisCodeRequis').isNotEmpty)
            LigneDetail(
              libelle: 'Frais lié',
              valeur: f.texte('fraisCodeRequis'),
            ),
          // Le motif dit POURQUOI le document n'est pas disponible : paiement
          // attendu, demande en cours, demande rejetée. Sans lui, un écran qui
          // n'offre aucun bouton n'explique rien.
          if (f.texte('motif').isNotEmpty)
            LigneDetail(libelle: 'À savoir', valeur: f.texte('motif')),
        ],
      ),
      actions: [
        ActionFiche(
          libelle: 'Télécharger',
          icone: Icons.download_rounded,
          couleur: AppTheme.statutVert,
          visiblePour: _peutTelecharger,
          executer: (contexte, fiche) async {
            final type = fiche.texte('type');
            final octets = await service.genererDocument(inscriptionId, type);
            await Fichiers.enregistrerEtOuvrir(
              octets,
              '${type.toLowerCase()}.pdf',
            );
          },
        ),
        ActionFiche(
          libelle: 'Demander',
          icone: Icons.send_rounded,
          visiblePour: (f) => f.donnees['canRequest'] == true,
          executer: (contexte, fiche) =>
              service.demanderDocument(inscriptionId, fiche.texte('type')),
        ),
      ],
    );
  }

  /// `canDownload` fait foi ; `statut` reste en second recours pour une
  /// réponse plus ancienne qui ne porterait pas le drapeau.
  static bool _peutTelecharger(Fiche f) =>
      f.donnees['canDownload'] == true || f.texte('statut') == 'DISPONIBLE';

  static (String, Color)? _statutDocument(String code) => switch (code) {
        'DISPONIBLE' => ('Disponible', AppTheme.statutVert),
        'DEMANDE_EN_COURS' => ('Demande en cours', AppTheme.statutOrange),
        'PAIEMENT_REQUIS' => ('Paiement requis', AppTheme.statutRouge),
        'A_DEMANDER' => ('À demander', AppTheme.statutBleu),
        _ => null,
      };
}

// ─────────────────────────────────────────────────────────────
// Carte d'étudiant
// ─────────────────────────────────────────────────────────────

class CarteEtudiantScreen extends StatefulWidget {
  const CarteEtudiantScreen({super.key});

  @override
  State<CarteEtudiantScreen> createState() => _CarteEtudiantScreenState();
}

class _CarteEtudiantScreenState extends State<CarteEtudiantScreen> {
  Fiche? _carte;
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final inscriptionId = context.read<AuthProvider>().user?.inscriptionId;
    if (inscriptionId == null || inscriptionId.isEmpty) {
      setState(() {
        _chargement = false;
        _erreur = 'Aucune inscription active : carte indisponible.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final carte = await context
          .read<EtudiantAcademiqueService>()
          .carteEtudiant(inscriptionId);
      if (!mounted) return;
      setState(() {
        _carte = carte;
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
    final carte = _carte;

    return PagePortail(
      titre: 'Ma carte d\'étudiant',
      onRafraichir: _charger,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: carte == null || carte.donnees.isEmpty,
        onReessayer: _charger,
        messageVide: 'Votre carte n\'a pas encore été émise.',
        iconeVide: Icons.badge_rounded,
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _VisuelCarte(carte: carte ?? const Fiche({})),
            const SizedBox(height: 20),
            CartePortail(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EnteteSection(
                    titre: 'Informations',
                    icone: Icons.info_rounded,
                  ),
                  LigneDetail(
                    libelle: 'Numéro de carte',
                    valeur: carte?.texte('numeroCarte', alias: const ['numero']) ?? '',
                  ),
                  LigneDetail(
                    libelle: 'Matricule',
                    valeur: carte?.texte('matricule') ?? '',
                  ),
                  LigneDetail(
                    libelle: 'Émise le',
                    valeur: formatDate(carte?.texteOuNul('dateEmission')),
                  ),
                  LigneDetail(
                    libelle: 'Valable jusqu\'au',
                    valeur: formatDate(carte?.texteOuNul('dateExpiration')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recto de la carte, aux couleurs de l'établissement.
class _VisuelCarte extends StatelessWidget {
  final Fiche carte;

  const _VisuelCarte({required this.carte});

  @override
  Widget build(BuildContext context) {
    final nom = carte.texte(
      'nomComplet',
      alias: const ['nom', 'etudiantNom'],
      defaut: context.read<AuthProvider>().user?.nomComplet ?? 'Étudiant',
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  carte.texte('universiteNom', defaut: 'GENUC'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            nom,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              carte.texte('filiere'),
              carte.texte('promotion'),
            ].where((v) => v.isNotEmpty).join(' · '),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ChampCarte(
                libelle: 'Matricule',
                valeur: carte.texte('matricule', defaut: '—'),
              ),
              const SizedBox(width: 24),
              _ChampCarte(
                libelle: 'Année',
                valeur: carte.texte(
                  'anneeAcademique',
                  defaut: anneeAcademiqueCourante(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChampCarte extends StatelessWidget {
  final String libelle;
  final String valeur;

  const _ChampCarte({required this.libelle, required this.valeur});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          libelle.toUpperCase(),
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        Text(
          valeur,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
