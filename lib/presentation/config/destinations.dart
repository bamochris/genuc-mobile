import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/portail_shell.dart';
import '../providers/auth_provider.dart';
import '../screens/commun/bibliotheque_screen.dart';
import '../screens/commun/messagerie_screen.dart';
import '../screens/etudiant/cours/cours_list_screen.dart';
import '../screens/etudiant/dashboard/etudiant_dashboard_screen.dart';
import '../screens/etudiant/demarches/demarches_screens.dart';
import '../screens/etudiant/documents/documents_screens.dart';
import '../screens/etudiant/horaire/horaire_screen.dart';
import '../screens/etudiant/notes/notes_screen.dart';
import '../screens/etudiant/notifications/notifications_screen.dart';
import '../screens/etudiant/paiements/paiements_screen.dart';
import '../screens/etudiant/paiements/remboursement_screen.dart';
import '../screens/etudiant/parametres/parametres_screen.dart';
import '../screens/etudiant/presences/presences_screen.dart';
import '../screens/etudiant/profil/etudiant_profil_screen.dart';
import '../screens/etudiant/reinscription/reinscription_screen.dart';
import '../screens/etudiant/resultats/resultats_screens.dart';
import '../screens/etudiant/smart_presence/etudiant_smart_presence_screen.dart';
import '../screens/etudiant/social/dossier_social_screen.dart';
import '../screens/etudiant/travaux/travaux_tfc_stages_screens.dart';
import '../screens/etudiant/vie/vie_universitaire_screens.dart';
import '../screens/home/accueil_generique_screen.dart';
import '../screens/professeur/compte/compte_screens.dart';
import '../screens/professeur/cours/etudiants_cours_screen.dart';
import '../screens/professeur/cours/mes_cours_screen.dart';
import '../screens/professeur/cours/planning_screen.dart';
import '../screens/professeur/cours/supports_screen.dart';
import '../screens/professeur/deliberation/deliberation_screen.dart';
import '../screens/professeur/encadrement/encadrement_screens.dart';
import '../screens/professeur/evaluations/evaluations_screens.dart';
import '../screens/professeur/notes/calculs_historique_screen.dart';
import '../screens/professeur/notes/import_export_notes_screen.dart';
import '../screens/professeur/notes/saisie_notes_screen.dart';
import '../screens/professeur/presences/presences_screens.dart';
import '../screens/professeur/presences/smart_presence_screen.dart';
import '../screens/professeur/professeur_dashboard_screen.dart';
import '../screens/professeur/rapports/rapports_screens.dart';
import '../screens/professeur/recherche/recherche_screens.dart';

/// Table de routes des portails étudiant et enseignant.
///
/// Les chemins sont ceux du portail web (`/etudiant/…`, `/professeur/…`) et
/// servent de clé unique : un lien de menu, un onglet de module, une action
/// rapide d'un tableau de bord et une barre basse désignent tous la même
/// destination par son chemin. C'est ce qui remplace l'ancien aiguillage par
/// libellé de `home_screen.dart`, où renommer une entrée du menu suffisait à
/// la faire retomber sur « écran à venir ».
class Destination {
  /// Chemin web, identifiant de la destination.
  final String chemin;
  final String libelle;

  /// Icône pleine (famille Material Symbols Rounded), état normal partout.
  final IconData icone;

  /// Variante en contour, utilisée par les barres de navigation quand
  /// l'entrée n'est **pas** la page courante.
  ///
  /// C'est la convention des grandes applications mobiles : un onglet éteint
  /// est dessiné au trait, l'onglet allumé est plein et coloré. Sans elle,
  /// cinq glyphes pleins se disputent l'attention et l'onglet actif ne se
  /// distingue plus que par sa couleur. Seules les destinations qui figurent
  /// dans une barre en ont besoin ; ailleurs `icone` suffit.
  final IconData? iconeContour;

  final Color couleur;
  final WidgetBuilder construire;

  const Destination({
    required this.chemin,
    required this.libelle,
    required this.icone,
    required this.couleur,
    required this.construire,
    this.iconeContour,
  });

  /// Glyphe à poser selon l'état dans une barre de navigation.
  IconData glyphe({required bool actif}) =>
      actif ? icone : (iconeContour ?? icone);
}

/// Groupe de destinations affiché sur une seule ligne du menu, ses volets
/// apparaissant en pastilles au-dessus du contenu (les `ModuleTabs` du web).
class ModuleMenu {
  final String cle;
  final String libelle;
  final IconData icone;
  final Color couleur;
  final List<Destination> destinations;

  const ModuleMenu({
    required this.cle,
    required this.libelle,
    required this.icone,
    required this.couleur,
    required this.destinations,
  });
}

sealed class EntreeMenu {
  const EntreeMenu();
}

class EntreeSimple extends EntreeMenu {
  final Destination destination;

  const EntreeSimple(this.destination);
}

class EntreeModule extends EntreeMenu {
  final ModuleMenu module;

  const EntreeModule(this.module);
}

// Couleurs d'icônes, alignées sur `ICON_COLORS` de `Navbar.jsx`.
const Color _bleu = Color(0xFF60A5FA);
const Color _vert = Color(0xFF34D399);
const Color _jaune = Color(0xFFFCD34D);
const Color _rose = Color(0xFFF472B6);
const Color _violet = Color(0xFFA78BFA);
const Color _ambre = Color(0xFFFBBF24);
const Color _gris = Color(0xFF9CA3AF);
const Color _rouge = Color(0xFFF87171);

class MenuPortail {
  MenuPortail._();

  static List<EntreeMenu> pourRole(String role) => switch (role.toUpperCase()) {
        'ETUDIANT' => etudiant,
        'PROFESSEUR' => professeur,
        _ => generique,
      };

  /// Chemin d'accueil du rôle : c'est là que le portail s'ouvre, et là où le
  /// bouton retour ramène.
  static String accueil(String role) => switch (role.toUpperCase()) {
        'ETUDIANT' => '/etudiant/dashboard',
        'PROFESSEUR' => '/professeur/dashboard',
        _ => '/accueil',
      };

  /// Menu de repli des rôles sans portail mobile : les seules destinations
  /// que tout compte peut ouvrir.
  static final List<EntreeMenu> generique = [
    EntreeSimple(
      Destination(
        chemin: '/accueil',
        libelle: 'Accueil',
        icone: Icons.home_rounded,
        couleur: _bleu,
        construire: (_) => const AccueilGeneriqueScreen(),
      ),
    ),
    EntreeSimple(_etudiantCours),
    EntreeSimple(
      Destination(
        chemin: '/etudiant/resultats',
        libelle: 'Notes',
        icone: Icons.bar_chart_rounded,
        couleur: _bleu,
        construire: (_) => const NotesScreen(),
      ),
    ),
    EntreeSimple(
      Destination(
        chemin: '/etudiant/profil',
        libelle: 'Mon profil',
        icone: Icons.person_rounded,
        couleur: _bleu,
        construire: (_) => const EtudiantProfilScreen(),
      ),
    ),
  ];

  /// Toutes les destinations d'un rôle, modules aplatis.
  static List<Destination> toutes(String role) => [
        for (final entree in pourRole(role))
          switch (entree) {
            EntreeSimple(:final destination) => [destination],
            EntreeModule(:final module) => module.destinations,
          },
      ].expand((d) => d).toList();

  /// Destination correspondant à un chemin, quel que soit le rôle.
  ///
  /// La recherche parcourt les deux portails : une action rapide d'un tableau
  /// de bord peut viser un chemin absent du menu du rôle (une page atteignable
  /// mais non listée, comme la carte d'étudiant).
  static Destination? destination(String chemin) {
    for (final d in [
      ...toutes('ETUDIANT'),
      ...toutes('PROFESSEUR'),
      ...toutes('AUTRE'),
      ...horsMenu,
    ]) {
      if (d.chemin == chemin) return d;
    }
    return null;
  }

  /// Module auquel appartient un chemin, s'il y en a un.
  static ModuleMenu? moduleDe(String role, String chemin) {
    for (final entree in pourRole(role)) {
      if (entree is EntreeModule &&
          entree.module.destinations.any((d) => d.chemin == chemin)) {
        return entree.module;
      }
    }
    return null;
  }

  /// Filtre le menu selon les modules ouverts par l'établissement.
  ///
  /// Reprend `MODULE_PAR_MOTIF` de `Navbar.jsx` : un lien appartient à un
  /// module si son chemin contient le motif. **Module absent de la carte =
  /// actif** — c'est la compatibilité ascendante retenue côté web, et
  /// l'inverser masquerait tout le menu des établissements qui n'ont jamais
  /// touché à ce réglage.
  static const Map<String, String> _modulePourMotif = {
    'bibliotheque': 'bibliotheque',
    'palmares': 'palmares',
    'attestation': 'attestations',
    'recours': 'recours',
    'calendrier': 'calendrier',
    'carte': 'cartes',
    'social': 'social',
    'stage': 'stages',
    'emploi': 'emplois',
  };

  static bool destinationActive(String chemin, Map<String, bool> modules) {
    if (modules.isEmpty) return true;
    final minuscule = chemin.toLowerCase();
    for (final entree in _modulePourMotif.entries) {
      if (minuscule.contains(entree.key) && modules[entree.value] == false) {
        return false;
      }
    }
    return true;
  }

  static List<EntreeMenu> filtrer(
    List<EntreeMenu> entrees,
    Map<String, bool> modules,
  ) {
    if (modules.isEmpty) return entrees;

    final resultat = <EntreeMenu>[];
    for (final entree in entrees) {
      switch (entree) {
        case EntreeSimple(:final destination):
          if (destinationActive(destination.chemin, modules)) {
            resultat.add(entree);
          }
        case EntreeModule(:final module):
          final restantes = module.destinations
              .where((d) => destinationActive(d.chemin, modules))
              .toList();
          // Un module dont tous les volets sont fermés disparaît : le laisser
          // afficherait une ligne de menu qui n'ouvre rien.
          if (restantes.isNotEmpty) {
            resultat.add(
              EntreeModule(
                ModuleMenu(
                  cle: module.cle,
                  libelle: module.libelle,
                  icone: module.icone,
                  couleur: module.couleur,
                  destinations: restantes,
                ),
              ),
            );
          }
      }
    }
    return resultat;
  }

  /// Destinations de la barre basse, par rôle.
  ///
  /// Ce ne sont pas les premières entrées du menu mais les gestes répétés —
  /// le choix du web (`BottomNav.jsx`). [racine] garde l'onglet allumé sur
  /// tout un module.
  ///
  /// « Mes cours » n'y figure plus : il occupe déjà une place dans la barre de
  /// raccourcis, en haut de chaque page. Le proposer aux deux bouts de l'écran
  /// coûtait une place sur cinq pour n'ouvrir que la page déjà accessible d'un
  /// geste plus court.
  static List<(Destination, String)> barreBasse(String role) =>
      switch (role.toUpperCase()) {
        'ETUDIANT' => [
            (_etudiantDashboard, '/etudiant/dashboard'),
            (_etudiantMarquerPresence, '/etudiant/presences'),
            (_etudiantFrais, '/etudiant/frais'),
          ],
        'PROFESSEUR' => [
            (_profDashboard, '/professeur/dashboard'),
            (_profSmartPresence, '/professeur/presences'),
            (_profSaisieNotes, '/professeur/notes'),
          ],
        _ => const [],
      };

  // ═══════════════════════════════════════════════════════════
  // Portail étudiant
  // ═══════════════════════════════════════════════════════════

  static final Destination _etudiantDashboard = Destination(
    chemin: '/etudiant/dashboard',
    libelle: 'Tableau de bord',
    icone: Icons.home_rounded,
    iconeContour: Icons.home_outlined,
    couleur: _bleu,
    construire: (_) => const EtudiantDashboardScreen(),
  );

  static final Destination _etudiantCours = Destination(
    chemin: '/etudiant/mes-cours',
    libelle: 'Mes cours',
    icone: Icons.menu_book_rounded,
    iconeContour: Icons.menu_book_outlined,
    couleur: _jaune,
    construire: (_) => const CoursListScreen(),
  );

  static final Destination _etudiantFrais = Destination(
    chemin: '/etudiant/frais',
    libelle: 'Mes paiements',
    icone: Icons.credit_card_rounded,
    iconeContour: Icons.credit_card_outlined,
    couleur: _violet,
    construire: (_) => const PaiementsScreen(),
  );

  static final Destination _etudiantMarquerPresence = Destination(
    chemin: '/etudiant/presences/marquer',
    libelle: 'Marquer ma présence',
    icone: Icons.how_to_reg_rounded,
    iconeContour: Icons.how_to_reg_outlined,
    couleur: _vert,
    construire: (_) => const EtudiantSmartPresenceScreen(),
  );

  static final List<EntreeMenu> etudiant = [
    EntreeSimple(_etudiantDashboard),
    EntreeSimple(_etudiantCours),
    EntreeSimple(
      Destination(
        chemin: '/etudiant/horaire',
        libelle: 'Mon horaire',
        icone: Icons.calendar_month_rounded,
        iconeContour: Icons.calendar_month_outlined,
        couleur: _bleu,
        construire: (_) => const HoraireScreen(),
      ),
    ),
    EntreeModule(
      ModuleMenu(
        cle: 'smart-presence',
        libelle: 'Smart Presence',
        icone: Icons.fingerprint_rounded,
        couleur: _violet,
        destinations: [
          Destination(
            chemin: '/etudiant/presences',
            libelle: 'Mes présences',
            icone: Icons.fact_check_rounded,
            couleur: _vert,
            construire: (_) => const PresencesEtudiantScreen(),
          ),
          // Scanner et marquer ouvrent le même écran : le web les sépare, mais
          // le geste mobile est un seul parcours — la caméra s'y ouvre déjà.
          Destination(
            chemin: '/etudiant/presences/scanner',
            libelle: 'Scanner le QR',
            icone: Icons.qr_code_scanner_rounded,
            couleur: _bleu,
            construire: (_) => const EtudiantSmartPresenceScreen(),
          ),
          _etudiantMarquerPresence,
        ],
      ),
    ),
    EntreeModule(
      ModuleMenu(
        cle: 'resultats',
        libelle: 'Résultats',
        icone: Icons.bar_chart_rounded,
        couleur: _bleu,
        destinations: [
          Destination(
            chemin: '/etudiant/resultats',
            libelle: 'Mes résultats',
            icone: Icons.bar_chart_rounded,
            couleur: _bleu,
            construire: (_) => const NotesScreen(),
          ),
          Destination(
            chemin: '/etudiant/bulletins',
            libelle: 'Mes bulletins',
            icone: Icons.description_rounded,
            couleur: _rouge,
            construire: (_) => const BulletinsScreen(),
          ),
          Destination(
            chemin: '/etudiant/parcours',
            libelle: 'Mon parcours',
            icone: Icons.route_rounded,
            couleur: _ambre,
            construire: (_) => const ParcoursScreen(),
          ),
          Destination(
            chemin: '/etudiant/recours',
            libelle: 'Recours',
            icone: Icons.gavel_rounded,
            couleur: _violet,
            construire: (_) => const RecoursScreen(),
          ),
        ],
      ),
    ),
    EntreeModule(
      ModuleMenu(
        cle: 'finances',
        libelle: 'Finances',
        icone: Icons.credit_card_rounded,
        couleur: _violet,
        destinations: [
          _etudiantFrais,
          Destination(
            chemin: '/etudiant/remboursement',
            libelle: 'Demander un remboursement',
            icone: Icons.replay_rounded,
            couleur: _rose,
            construire: (_) => const RemboursementScreen(),
          ),
          Destination(
            chemin: '/etudiant/dossier-social',
            libelle: 'Dossier social & bourse',
            icone: Icons.volunteer_activism_rounded,
            couleur: _vert,
            construire: (_) => const DossierSocialScreen(),
          ),
        ],
      ),
    ),
    EntreeModule(
      ModuleMenu(
        cle: 'demandes-academiques',
        libelle: 'Démarches',
        icone: Icons.description_rounded,
        couleur: _rose,
        destinations: [
          Destination(
            chemin: '/etudiant/transfert',
            libelle: 'Transfert',
            icone: Icons.swap_horiz_rounded,
            couleur: _ambre,
            construire: (_) => const TransfertScreen(),
          ),
          Destination(
            chemin: '/etudiant/demande-changement-filiere',
            libelle: 'Changement de filière',
            icone: Icons.school_rounded,
            couleur: _bleu,
            construire: (_) =>
                const NouvelleDemandeScreen(type: 'CHANGEMENT_FILIERE'),
          ),
          Destination(
            chemin: '/etudiant/demande-changement-vacation',
            libelle: 'Changement de vacation',
            icone: Icons.schedule_rounded,
            couleur: _bleu,
            construire: (_) =>
                const NouvelleDemandeScreen(type: 'CHANGEMENT_VACATION'),
          ),
          Destination(
            chemin: '/etudiant/demandes-academiques',
            libelle: 'Suivi',
            icone: Icons.fact_check_rounded,
            couleur: _vert,
            construire: (_) => const MesDemandesScreen(),
          ),
          Destination(
            chemin: '/etudiant/attestations',
            libelle: 'Attestations',
            icone: Icons.note_alt_rounded,
            couleur: _bleu,
            construire: (_) => const AttestationsScreen(),
          ),
          Destination(
            chemin: '/etudiant/equivalences-diplomes',
            libelle: 'Équivalences',
            icone: Icons.workspace_premium_rounded,
            couleur: _jaune,
            construire: (_) => const EquivalencesScreen(),
          ),
          // Absente du menu web — sa page y existe pourtant, atteignable par
          // la seule URL. Elle est de la même nature que les autres démarches
          // et trouve sa place ici.
          Destination(
            chemin: '/etudiant/reinscription',
            libelle: 'Réinscription',
            icone: Icons.autorenew_rounded,
            couleur: _vert,
            construire: (_) => const ReinscriptionScreen(),
          ),
        ],
      ),
    ),
    EntreeModule(
      ModuleMenu(
        cle: 'travaux',
        libelle: 'Mes travaux',
        icone: Icons.assignment_rounded,
        couleur: _ambre,
        destinations: [
          Destination(
            chemin: '/etudiant/travaux',
            libelle: 'Travaux et devoirs',
            icone: Icons.assignment_rounded,
            couleur: _ambre,
            construire: (_) => const TravauxScreen(),
          ),
          Destination(
            chemin: '/etudiant/tfc',
            libelle: 'Fin de cycle (TFC/PT)',
            icone: Icons.menu_book_rounded,
            couleur: _violet,
            construire: (_) => const TfcEtudiantScreen(),
          ),
          Destination(
            chemin: '/etudiant/stages',
            libelle: 'Mon stage',
            icone: Icons.business_center_rounded,
            couleur: _vert,
            construire: (_) => const StagesEtudiantScreen(),
          ),
          Destination(
            chemin: '/etudiant/evaluations',
            libelle: 'Évaluer mes cours',
            icone: Icons.star_rounded,
            couleur: _jaune,
            construire: (_) => const EvaluationEnseignantsScreen(),
          ),
        ],
      ),
    ),
    EntreeModule(
      ModuleMenu(
        cle: 'campus',
        libelle: 'Campus',
        icone: Icons.groups_rounded,
        couleur: _vert,
        destinations: [
          Destination(
            chemin: '/etudiant/vie-universitaire',
            libelle: 'Vie universitaire',
            icone: Icons.groups_rounded,
            couleur: _vert,
            construire: (_) => const VieUniversitaireScreen(),
          ),
          Destination(
            chemin: '/etudiant/emploi',
            libelle: 'Jobs universitaires',
            icone: Icons.work_rounded,
            couleur: _ambre,
            construire: (_) => const JobsUniversitairesScreen(),
          ),
        ],
      ),
    ),
    EntreeSimple(
      Destination(
        chemin: '/etudiant/bibliotheque',
        libelle: 'Bibliothèque',
        icone: Icons.local_library_rounded,
        couleur: _jaune,
        construire: (_) => const BibliothequeScreen(),
      ),
    ),
    EntreeSimple(
      Destination(
        chemin: '/etudiant/messagerie',
        libelle: 'Messagerie',
        icone: Icons.mail_rounded,
        iconeContour: Icons.mail_outline_rounded,
        couleur: _bleu,
        construire: (_) => const MessagerieScreen(),
      ),
    ),
    EntreeModule(
      ModuleMenu(
        cle: 'mon-compte',
        libelle: 'Mon compte',
        icone: Icons.person_rounded,
        couleur: _bleu,
        destinations: [
          Destination(
            chemin: '/etudiant/profil',
            libelle: 'Mon profil',
            icone: Icons.person_rounded,
            couleur: _bleu,
            construire: (_) => const EtudiantProfilScreen(),
          ),
          Destination(
            chemin: '/etudiant/profil/documents',
            libelle: 'Mes documents',
            icone: Icons.folder_rounded,
            couleur: _jaune,
            construire: (_) => const MesDocumentsScreen(),
          ),
          Destination(
            chemin: '/etudiant/carte',
            libelle: 'Ma carte',
            icone: Icons.badge_rounded,
            couleur: _violet,
            construire: (_) => const CarteEtudiantScreen(),
          ),
          Destination(
            chemin: '/etudiant/parametres',
            libelle: 'Paramètres',
            icone: Icons.settings_rounded,
            couleur: _gris,
            construire: (_) => const ParametresEtudiantScreen(),
          ),
        ],
      ),
    ),
  ];

  // ═══════════════════════════════════════════════════════════
  // Portail enseignant
  // ═══════════════════════════════════════════════════════════

  static final Destination _profDashboard = Destination(
    chemin: '/professeur/dashboard',
    libelle: 'Tableau de bord',
    icone: Icons.home_rounded,
    iconeContour: Icons.home_outlined,
    couleur: _bleu,
    // Le tableau de bord enseignant a besoin de l'utilisateur : il le prend au
    // shell, qui le porte déjà, et retombe sur `AuthProvider`. Le `user!` de
    // départ faisait planter tout le portail (« Null check operator used on a
    // null value ») dès que la destination était construite avant que la
    // session ne soit posée dans le provider.
    construire: (context) {
      final user = PortailScope.utilisateur(context) ??
          context.read<AuthProvider>().user;
      if (user == null) return const AccueilGeneriqueScreen();
      return ProfesseurDashboardScreen(user: user);
    },
  );

  static final Destination _profCours = Destination(
    chemin: '/professeur/mes-cours',
    libelle: 'Mes cours',
    icone: Icons.menu_book_rounded,
    iconeContour: Icons.menu_book_outlined,
    couleur: _jaune,
    construire: (_) => const MesCoursProfesseurScreen(),
  );

  static final Destination _profSmartPresence = Destination(
    chemin: '/professeur/presences/smart',
    libelle: 'Smart Présence',
    icone: Icons.fingerprint_rounded,
    iconeContour: Icons.fingerprint_outlined,
    couleur: _violet,
    construire: (_) => const SmartPresenceProfesseurScreen(),
  );

  static final Destination _profSaisieNotes = Destination(
    chemin: '/professeur/notes/saisie',
    libelle: 'Saisie',
    icone: Icons.edit_note_rounded,
    iconeContour: Icons.edit_note_outlined,
    couleur: _ambre,
    construire: (_) => const SaisieNotesScreen(),
  );

  static final List<EntreeMenu> professeur = [
    EntreeSimple(_profDashboard),
    EntreeModule(
      ModuleMenu(
        cle: 'prof-cours',
        libelle: 'Mes cours',
        icone: Icons.menu_book_rounded,
        couleur: _jaune,
        destinations: [
          _profCours,
          Destination(
            chemin: '/professeur/mes-cours/supports',
            libelle: 'Supports',
            icone: Icons.folder_rounded,
            couleur: _bleu,
            construire: (_) => const SupportsCoursScreen(),
          ),
          Destination(
            chemin: '/professeur/mes-cours/planning',
            libelle: 'Planning',
            icone: Icons.calendar_month_rounded,
            iconeContour: Icons.calendar_month_outlined,
            couleur: _bleu,
            construire: (_) => const PlanningCoursScreen(),
          ),
          Destination(
            chemin: '/professeur/mes-etudiants',
            libelle: 'Mes étudiants',
            icone: Icons.school_rounded,
            couleur: _vert,
            construire: (_) => const MesEtudiantsScreen(),
          ),
        ],
      ),
    ),
    EntreeModule(
      ModuleMenu(
        cle: 'prof-presences',
        libelle: 'Présences',
        icone: Icons.fingerprint_rounded,
        couleur: _violet,
        destinations: [
          _profSmartPresence,
          Destination(
            chemin: '/professeur/presences/qrcode',
            libelle: 'Présences QR',
            icone: Icons.qr_code_2_rounded,
            couleur: _bleu,
            construire: (_) => const GenererQrScreen(),
          ),
          Destination(
            chemin: '/professeur/presences/saisie',
            libelle: 'Saisie manuelle',
            icone: Icons.fact_check_rounded,
            couleur: _vert,
            construire: (_) => const SaisiePresencesScreen(),
          ),
          Destination(
            chemin: '/professeur/presences/historique',
            libelle: 'Historique',
            icone: Icons.history_rounded,
            couleur: _gris,
            construire: (_) => const HistoriquePresencesScreen(),
          ),
          Destination(
            chemin: '/professeur/presences/statistiques',
            libelle: 'Statistiques',
            icone: Icons.pie_chart_rounded,
            couleur: _ambre,
            construire: (_) =>
                const HistoriquePresencesScreen(statistiques: true),
          ),
        ],
      ),
    ),
    EntreeModule(
      ModuleMenu(
        cle: 'prof-notes',
        libelle: 'Notes',
        icone: Icons.edit_note_rounded,
        couleur: _ambre,
        destinations: [
          _profSaisieNotes,
          Destination(
            chemin: '/professeur/notes/import',
            libelle: 'Import',
            icone: Icons.upload_file_rounded,
            couleur: _bleu,
            construire: (_) => const ImportNotesScreen(),
          ),
          Destination(
            chemin: '/professeur/notes/export',
            libelle: 'Export',
            icone: Icons.download_rounded,
            couleur: _bleu,
            construire: (_) => const ExportNotesScreen(),
          ),
          Destination(
            chemin: '/professeur/notes/calculs',
            libelle: 'Calculs',
            icone: Icons.calculate_rounded,
            couleur: _vert,
            construire: (_) => const CalculsNotesScreen(),
          ),
          Destination(
            chemin: '/professeur/notes/historique',
            libelle: 'Historique',
            icone: Icons.history_rounded,
            couleur: _gris,
            construire: (_) => const HistoriqueNotesScreen(),
          ),
        ],
      ),
    ),
    EntreeModule(
      ModuleMenu(
        cle: 'prof-evaluations',
        libelle: 'Évaluations',
        icone: Icons.assignment_rounded,
        couleur: _rose,
        destinations: [
          Destination(
            chemin: '/professeur/evaluations/interrogations',
            libelle: 'Interrogations',
            icone: Icons.edit_rounded,
            couleur: _rose,
            construire: (_) => const InterrogationsScreen(),
          ),
          Destination(
            chemin: '/professeur/evaluations/tp-td',
            libelle: 'TP / TD',
            icone: Icons.science_rounded,
            couleur: _vert,
            construire: (_) => const TravauxPratiquesScreen(),
          ),
          Destination(
            chemin: '/professeur/evaluations/examens',
            libelle: 'Examens',
            icone: Icons.assignment_turned_in_rounded,
            couleur: _rouge,
            construire: (_) => const ExamensScreen(),
          ),
          Destination(
            chemin: '/professeur/evaluations/baremes',
            libelle: 'Barèmes',
            icone: Icons.balance_rounded,
            couleur: _violet,
            construire: (_) => const BaremesScreen(),
          ),
        ],
      ),
    ),
    EntreeModule(
      ModuleMenu(
        cle: 'prof-encadrement',
        libelle: 'Encadrement',
        icone: Icons.supervisor_account_rounded,
        couleur: _vert,
        destinations: [
          Destination(
            chemin: '/professeur/tfc/sujets',
            libelle: 'Sujets de fin de cycle',
            icone: Icons.lightbulb_rounded,
            couleur: _jaune,
            construire: (_) => const SujetsTfcScreen(),
          ),
          Destination(
            chemin: '/professeur/tfc/encadrements',
            libelle: 'Encadrements',
            icone: Icons.supervisor_account_rounded,
            couleur: _vert,
            construire: (_) => const EncadrementsScreen(),
          ),
          Destination(
            chemin: '/professeur/tfc/suivi',
            libelle: 'Suivi TFC',
            icone: Icons.trending_up_rounded,
            couleur: _bleu,
            construire: (_) => const SuiviTfcScreen(),
          ),
          Destination(
            chemin: '/professeur/stages/validation',
            libelle: 'Stages à valider',
            icone: Icons.fact_check_rounded,
            couleur: _ambre,
            construire: (_) => const StagesValidationScreen(),
          ),
          Destination(
            chemin: '/professeur/stages/suivi',
            libelle: 'Suivi des stages',
            icone: Icons.route_rounded,
            couleur: _bleu,
            construire: (_) => const StagesSuiviScreen(),
          ),
          Destination(
            chemin: '/professeur/stages/rapports',
            libelle: 'Rapports de stage',
            icone: Icons.description_rounded,
            couleur: _violet,
            construire: (_) => const RapportsStagesScreen(),
          ),
        ],
      ),
    ),
    EntreeSimple(
      Destination(
        chemin: '/professeur/deliberation',
        libelle: 'Délibération',
        icone: Icons.balance_rounded,
        couleur: _violet,
        construire: (_) => const DeliberationProfesseurScreen(),
      ),
    ),
    EntreeModule(
      ModuleMenu(
        cle: 'prof-recherche',
        libelle: 'Recherche',
        icone: Icons.science_rounded,
        couleur: _bleu,
        destinations: [
          Destination(
            chemin: '/professeur/recherche/publications',
            libelle: 'Publications',
            icone: Icons.article_rounded,
            couleur: _bleu,
            construire: (_) => const PublicationsScreen(),
          ),
          Destination(
            chemin: '/professeur/recherche/projets',
            libelle: 'Projets',
            icone: Icons.science_rounded,
            couleur: _vert,
            construire: (_) => const ProjetsRechercheScreen(),
          ),
          Destination(
            chemin: '/professeur/recherche/conferences',
            libelle: 'Conférences',
            icone: Icons.campaign_rounded,
            couleur: _violet,
            construire: (_) => const ConferencesScreen(),
          ),
          Destination(
            chemin: '/professeur/recherche/laboratoires',
            libelle: 'Laboratoires',
            icone: Icons.biotech_rounded,
            couleur: _ambre,
            construire: (_) => const LaboratoiresScreen(),
          ),
        ],
      ),
    ),
    EntreeModule(
      ModuleMenu(
        cle: 'prof-rapports',
        libelle: 'Rapports',
        icone: Icons.bar_chart_rounded,
        couleur: _ambre,
        destinations: [
          Destination(
            chemin: '/professeur/rapports/reussite',
            libelle: 'Réussite',
            icone: Icons.emoji_events_rounded,
            couleur: _jaune,
            construire: (_) =>
                const RapportProfesseurScreen(type: TypeRapport.reussite),
          ),
          Destination(
            chemin: '/professeur/rapports/presences',
            libelle: 'Présences',
            icone: Icons.check_circle_rounded,
            couleur: _vert,
            construire: (_) =>
                const RapportProfesseurScreen(type: TypeRapport.presences),
          ),
          Destination(
            chemin: '/professeur/rapports/notes',
            libelle: 'Notes',
            icone: Icons.bar_chart_rounded,
            couleur: _bleu,
            construire: (_) =>
                const RapportProfesseurScreen(type: TypeRapport.notes),
          ),
        ],
      ),
    ),
    EntreeSimple(
      Destination(
        chemin: '/professeur/calendrier',
        libelle: 'Calendrier',
        icone: Icons.event_note_rounded,
        couleur: _bleu,
        construire: (_) => const CalendrierScreen(),
      ),
    ),
    EntreeSimple(
      Destination(
        chemin: '/professeur/messagerie',
        libelle: 'Messagerie',
        icone: Icons.mail_rounded,
        iconeContour: Icons.mail_outline_rounded,
        couleur: _bleu,
        construire: (_) => const MessagerieScreen(),
      ),
    ),
    EntreeSimple(
      Destination(
        chemin: '/professeur/bibliotheque',
        libelle: 'Bibliothèque',
        icone: Icons.local_library_rounded,
        couleur: _jaune,
        construire: (_) => const BibliothequeScreen(),
      ),
    ),
    EntreeModule(
      ModuleMenu(
        cle: 'prof-compte',
        libelle: 'Mon compte',
        icone: Icons.person_rounded,
        couleur: _bleu,
        destinations: [
          Destination(
            chemin: '/professeur/parametres',
            libelle: 'Paramètres',
            icone: Icons.settings_rounded,
            couleur: _gris,
            construire: (_) => const ParametresProfesseurScreen(),
          ),
          Destination(
            chemin: '/professeur/documents/contrats',
            libelle: 'Mes contrats',
            icone: Icons.assignment_ind_rounded,
            couleur: _ambre,
            construire: (_) => const MesContratsScreen(),
          ),
          Destination(
            chemin: '/professeur/mon-evaluation',
            libelle: 'Mon évaluation',
            icone: Icons.star_rounded,
            couleur: _jaune,
            construire: (_) => const MonEvaluationScreen(),
          ),
        ],
      ),
    ),
  ];

  // ═══════════════════════════════════════════════════════════
  // Destinations atteignables sans figurer au menu
  // ═══════════════════════════════════════════════════════════

  /// Pages ouvertes depuis un tableau de bord ou une notification, mais que le
  /// menu du web n'expose pas non plus. Elles sont routables : sans cela, une
  /// tuile du tableau de bord retomberait sur « écran inconnu ».
  static final List<Destination> horsMenu = [
    Destination(
      chemin: '/notifications',
      libelle: 'Notifications',
      icone: Icons.notifications_rounded,
      couleur: _ambre,
      construire: (_) => const NotificationsScreen(),
    ),
    Destination(
      chemin: '/etudiant/documents-officiels',
      libelle: 'Documents officiels',
      icone: Icons.verified_rounded,
      couleur: _vert,
      construire: (_) => const DocumentsOfficielsScreen(),
    ),
  ];
}
