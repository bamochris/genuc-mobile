import 'package:flutter/foundation.dart';

import '../../data/services/appel_api.dart';
import '../../data/services/commun_service.dart';

/// Années académiques de l'établissement de l'utilisateur connecté.
///
/// ─── Pourquoi ce fournisseur existe ─────────────────────────────────────────
///
/// L'année académique d'un établissement est une LIGNE de `annee_academique`
/// (une seule active à la fois, index partiel `uq_annee_active_par_universite`,
/// V43), administrée depuis le portail admin. Elle ne se DÉDUIT pas de
/// l'horloge de l'appareil.
///
/// Six écrans du portail enseignant la calculaient pourtant avec
/// `anneeAcademiqueCourante()` — bascule au 1er septembre, année civile ±1 — et
/// la posaient telle quelle dans l'URL (`/api/notes/cours/{coursId}/{annee}`).
/// Un établissement qui n'a pas encore ouvert 2026-2027, ou qui la nomme
/// autrement, recevait donc « aucune note » sans le moindre message, et sans
/// aucun moyen d'atteindre l'année qu'il enseigne : le champ n'offrait rien à
/// choisir, ou n'acceptait qu'une saisie libre au tiret près.
///
/// Le plus coûteux était la SAISIE DES NOTES, qui enregistre toute seule cinq
/// secondes après la dernière frappe : les notes d'un enseignant qui n'avait
/// jamais touché au champ partaient sous un libellé que personne n'avait
/// déclaré.
///
/// ─── Ce qu'il fait ──────────────────────────────────────────────────────────
///
/// Source de vérité : `GET /api/annees-academiques`, ouvert à tout compte
/// authentifié et déjà borné à l'établissement de l'appelant côté serveur.
/// Les rôles qui y ont droit (administration de l'établissement, chef de
/// département) passent par `/toutes`, qui rend AUSSI les années clôturées —
/// sans elles, consulter l'historique deviendrait impossible. Le portail
/// mobile étant celui de l'étudiant et de l'enseignant, on n'appelle `/toutes`
/// que pour ces rôles-là : le tenter partout garantirait un 403 à chaque
/// ouverture de session.
///
/// Le calendrier ne sert plus que de FILET, et uniquement quand l'établissement
/// n'a ouvert AUCUNE année : [anneeActive] reste alors vide, et les écrans
/// l'écrivent plutôt que de proposer une année jamais déclarée.
class AnneesAcademiquesProvider extends ChangeNotifier {
  final CommunService _commun;

  AnneesAcademiquesProvider(this._commun);

  List<Fiche> _entites = const [];
  String _anneeActive = '';
  bool _chargement = false;
  bool _chargee = false;
  bool _depuisReferentiel = false;
  String? _erreur;

  /// Libellés, du plus récent au plus ancien.
  List<String> get annees => _entites
      .map((e) => e.texte('libelle'))
      .where((l) => l.isNotEmpty)
      .toList();

  /// Année OUVERTE de l'établissement, ou chaîne vide s'il n'en a aucune.
  ///
  /// Vide n'est pas « inconnue » : c'est une réponse. Aucun écran ne doit la
  /// remplacer par un calcul — c'est précisément ce qui faisait écrire des
  /// notes dans un exercice clos.
  String get anneeActive => _anneeActive;

  bool get chargement => _chargement;
  String? get erreur => _erreur;

  /// Faux quand la liste vient du repli calendaire, l'établissement n'ayant
  /// déclaré aucune année.
  bool get depuisReferentiel => _depuisReferentiel;

  /// Valeur à poser par défaut dans un sélecteur : l'année ouverte, sinon la
  /// plus récente connue, sinon rien.
  String? get anneeParDefaut {
    if (_anneeActive.isNotEmpty) return _anneeActive;
    return annees.isEmpty ? null : annees.first;
  }

  /// Charge une fois pour toute la session ; [forcer] relit le référentiel.
  Future<void> charger({String? role, bool forcer = false}) async {
    if (_chargement) return;
    if (_chargee && !forcer) return;

    _chargement = true;
    _erreur = null;
    notifyListeners();

    try {
      final lignes = await _lire(role);
      if (lignes.isEmpty) {
        _replier();
      } else {
        // Décroissant : « 2026-2027 » avant « 2025-2026 ». Le serveur ne trie
        // que sur `/toutes`.
        final triees = [...lignes]..sort(
            (a, b) => b.texte('libelle').compareTo(a.texte('libelle')),
          );
        _entites = triees;
        _anneeActive = triees
            .firstWhere(
              (a) => a.booleen('active'),
              orElse: () => const Fiche({}),
            )
            .texte('libelle');
        _depuisReferentiel = true;
      }
    } catch (_) {
      _erreur =
          'Les années académiques de votre établissement n\'ont pas pu être '
          'chargées.';
      _replier();
    } finally {
      _chargee = true;
      _chargement = false;
      notifyListeners();
    }
  }

  Future<List<Fiche>> _lire(String? role) async {
    final r = (role ?? '').toUpperCase();
    if (r == 'ADMIN_UNIVERSITE' || r == 'CHEF_DEPARTEMENT') {
      try {
        return await _commun.anneesAcademiquesToutes();
      } catch (_) {
        // Le droit peut avoir été retiré depuis : on retombe sur la liste
        // ouverte à tous plutôt que de rendre l'écran inutilisable.
      }
    }
    return _commun.anneesAcademiques();
  }

  void _replier() {
    _entites = [
      for (final libelle in fenetreAnnees().reversed)
        Fiche({'libelle': libelle, 'active': false}),
    ];
    // On n'invente PAS d'année active : les écrans doivent pouvoir dire
    // « aucune année n'est ouverte » plutôt que d'en afficher une que
    // l'établissement n'a jamais déclarée.
    _anneeActive = '';
    _depuisReferentiel = false;
  }
}

/// Année académique du jour, bascule au 1er septembre.
///
/// ⚠️ REPLI UNIQUEMENT — la source de vérité est le référentiel ci-dessus. La
/// rentrée est en septembre, pas en janvier : au 9 septembre 2026, l'année en
/// cours est « 2026-2027 ».
String anneeCalendaire([DateTime? date]) {
  final d = date ?? DateTime.now();
  final debut = d.month >= 9 ? d.year : d.year - 1;
  return '$debut-${debut + 1}';
}

/// Fenêtre glissante de libellés, année À VENIR comprise, du plus ancien au
/// plus récent.
///
/// [enAvant] vaut 1, et c'est le point important : en août on prépare la
/// rentrée de septembre. Une liste qui s'arrête à l'année en cours interdit de
/// rien préparer.
List<String> fenetreAnnees({
  int enArriere = 4,
  int enAvant = 1,
  DateTime? date,
}) {
  final debut = int.parse(anneeCalendaire(date).split('-').first);
  return [
    for (var i = 0; i < enArriere + enAvant + 1; i++)
      '${debut - enArriere + i}-${debut - enArriere + i + 1}',
  ];
}
