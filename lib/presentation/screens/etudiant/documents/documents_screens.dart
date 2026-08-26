import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/fichiers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/etudiant_academique_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';
import '../../commun/ecran_ressource.dart';

/// Documents de l'étudiant : pièces personnelles téléversées, documents
/// officiels générés par l'établissement, et carte d'étudiant.

// ─────────────────────────────────────────────────────────────
// Mes documents (pièces téléversées)
// ─────────────────────────────────────────────────────────────

class MesDocumentsScreen extends StatelessWidget {
  const MesDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<EtudiantAcademiqueService>();
    final inscriptionId =
        context.read<AuthProvider>().user?.inscriptionId ?? '';

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
        sousTitre: (f) => _libelleType(f.texte('type')),
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
        ActionFiche(
          libelle: 'Ouvrir',
          icone: Icons.open_in_new_rounded,
          visiblePour: (f) => f.texte('url', alias: const ['lien']).isNotEmpty,
          executer: (contexte, fiche) async {
            await Fichiers.ouvrirLien(fiche.texte('url', alias: const ['lien']));
          },
        ),
      ],
      entete: (contexte) => _BoutonTeleverser(
        service: service,
        inscriptionId: inscriptionId,
      ),
    );
  }

  static String _libelleType(String code) => switch (code) {
        'CARTE_IDENTITE' => 'Carte d\'identité',
        'DIPLOME' => 'Diplôme',
        'RELEVE_NOTES' => 'Relevé de notes',
        'PHOTO' => 'Photo d\'identité',
        'ACTE_NAISSANCE' => 'Acte de naissance',
        'ATTESTATION' => 'Attestation',
        '' => '',
        _ => code.replaceAll('_', ' '),
      };

  static (String, Color) _statut(String code) => switch (code.toUpperCase()) {
        'VALIDE' || 'VALIDEE' || 'ACCEPTE' => ('Validé', AppTheme.statutVert),
        'REJETE' || 'REFUSE' => ('Rejeté', AppTheme.statutRouge),
        _ => ('En attente', AppTheme.statutOrange),
      };
}

class _BoutonTeleverser extends StatefulWidget {
  final EtudiantAcademiqueService service;
  final String inscriptionId;

  const _BoutonTeleverser({required this.service, required this.inscriptionId});

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
    final type = await DialogueFormulaire.ouvrir(
      context,
      titre: 'Nature de la pièce',
      libelleValidation: 'Choisir le fichier',
      champs: const [
        ChampFormulaire(
          cle: 'type',
          libelle: 'Type de document',
          type: TypeChamp.liste,
          obligatoire: true,
          valeurInitiale: 'CARTE_IDENTITE',
          options: {
            'CARTE_IDENTITE': 'Carte d\'identité',
            'ACTE_NAISSANCE': 'Acte de naissance',
            'DIPLOME': 'Diplôme',
            'RELEVE_NOTES': 'Relevé de notes',
            'PHOTO': 'Photo d\'identité',
            'AUTRE': 'Autre',
          },
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
            'Maximum accepté : 50 Mo.';
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
      libelleCreation: 'Demander un document',
      messageVide: 'Aucun document officiel disponible.',
      charger: () => service.documentsOfficiels(inscriptionId),
      description: DescriptionFiche(
        icone: Icons.verified_rounded,
        titre: (f) => f.texte('libelle', alias: const ['type', 'nom'], defaut: 'Document'),
        sousTitre: (f) => f.texteOuNul('numero', alias: const ['reference']),
        details: (f) => [
          LigneDetail(
            libelle: 'Émis le',
            valeur: formatDate(f.texteOuNul('dateEmission', alias: const ['date'])),
          ),
        ],
      ),
      actions: [
        ActionFiche(
          libelle: 'Télécharger',
          icone: Icons.download_rounded,
          couleur: AppTheme.statutVert,
          executer: (contexte, fiche) async {
            final type = fiche.texte('type', defaut: 'CERTIFICAT_SCOLARITE');
            final octets = await service.genererDocument(inscriptionId, type);
            await Fichiers.enregistrerEtOuvrir(
              octets,
              '${type.toLowerCase()}.pdf',
            );
          },
        ),
      ],
      champsCreation: const [
        ChampFormulaire(
          cle: 'type',
          libelle: 'Type de document',
          type: TypeChamp.liste,
          obligatoire: true,
          valeurInitiale: 'CERTIFICAT_SCOLARITE',
          options: {
            'CERTIFICAT_SCOLARITE': 'Certificat de scolarité',
            'RELEVE_NOTES': 'Relevé de notes officiel',
            'ATTESTATION_REUSSITE': 'Attestation de réussite',
            'CERTIFICAT_INSCRIPTION': 'Certificat d\'inscription',
          },
        ),
      ],
      onCreer: (valeurs) =>
          service.demanderDocument(inscriptionId, valeurs['type'].toString()),
    );
  }
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
