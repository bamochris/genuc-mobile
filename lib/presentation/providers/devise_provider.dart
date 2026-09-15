import 'package:flutter/foundation.dart';

import '../../core/utils/formatters.dart';
import '../../data/services/commun_service.dart';

/// Lecture de la devise d'un établissement. Un typedef, et non le service
/// entier : `CommunService` se construit sur le `DioClient` singleton, dont le
/// magasin de cookies sécurisé n'existe pas dans un test unitaire.
typedef LectureDevise = Future<String> Function(String universiteId);

/// Devise de facturation de l'établissement de l'utilisateur connecté.
///
/// ─── Pourquoi ce fournisseur existe ─────────────────────────────────────────
///
/// La devise est une COLONNE de `universite` (`devise` : « USD », « CDF »,
/// « USD/CDF »), administrée depuis le portail admin. Elle ne se suppose pas.
///
/// Le mobile l'écrivait pourtant en dur : `formatMontant` retombait sur
/// « USD » pour tout montant dont la charge utile ne portait pas de devise —
/// c'est-à-dire seize appels sur vingt-deux, dont « Mes paiements », le flux
/// TachPay, le bon de caisse et le solde du tableau de bord. Trois écrans
/// allaient plus loin et concaténaient « USD » à la main. Un établissement qui
/// facture en francs congolais annonçait donc des dollars à ses étudiants, sur
/// ses écrans de paiement.
///
/// Le portail web résout la même donnée depuis toujours, par le hook
/// `useDevise()` (`GET /api/universites/public` filtré sur `user.universiteId`).
///
/// ─── Ce qu'il fait ──────────────────────────────────────────────────────────
///
/// Source de vérité : `GET /api/universites/public/{id}` → `devise`. La route
/// est publique et rend UN établissement — inutile de rapatrier la liste
/// entière comme le fait le web, qui, lui, l'a déjà en cache.
///
/// La valeur est déposée dans [DeviseEtablissement], que `formatMontant`
/// consulte quand l'appelant ne passe pas de devise. Les écrans qui en ont une
/// dans leur charge utile (`paiement.devise`, `frais.devise`) continuent de la
/// passer : c'est elle qui fait foi.
///
/// [suivreSession] est appelée par le proxy de `main.dart` à chaque changement
/// de session. Un établissement différent, ou une déconnexion, efface la
/// valeur AVANT de recharger : sans cela, un poste partagé afficherait les
/// montants du compte précédent dans la devise du compte précédent.
class DeviseProvider extends ChangeNotifier {
  final LectureDevise _lire;

  DeviseProvider(CommunService commun) : _lire = commun.deviseEtablissement;

  /// Construit le fournisseur sur une lecture quelconque. **Réservé aux tests.**
  @visibleForTesting
  DeviseProvider.avecLecture(this._lire);

  String? _universiteId;
  String _devise = deviseParDefaut;
  bool _duServeur = false;
  bool _chargement = false;
  bool _jete = false;

  @override
  void dispose() {
    _jete = true;
    super.dispose();
  }

  /// Notifie sans jamais le faire pendant une construction d'arbre — le proxy
  /// appelle [suivreSession] depuis `update`, et un `notifyListeners` synchrone
  /// y déclencherait une reconstruction en pleine construction.
  void _notifierPlusTard() {
    Future.microtask(() {
      if (!_jete) notifyListeners();
    });
  }

  /// Devise à employer pour un montant qui n'en porte pas.
  String get devise => _devise;

  /// Étiquette d'affichage (« FC » pour le franc congolais).
  String get etiquette => etiquetteDevise(_devise);

  /// Faux tant que le serveur n'a pas répondu, ou si l'établissement n'a
  /// déclaré aucune devise : la valeur rendue est alors le repli déclaré.
  bool get duServeur => _duServeur;

  bool get chargement => _chargement;

  /// Suit l'établissement de la session courante. Sans effet si rien n'a
  /// changé — le proxy rappelle cette méthode à chaque notification de
  /// `AuthProvider`, y compris pour un simple rafraîchissement de profil.
  void suivreSession(String? universiteId) {
    final cible = (universiteId ?? '').trim();
    if (cible == (_universiteId ?? '')) return;

    _universiteId = cible.isEmpty ? null : cible;
    _devise = deviseParDefaut;
    _duServeur = false;
    DeviseEtablissement.oublier();

    if (_universiteId == null) {
      _notifierPlusTard();
      return;
    }
    _charger(_universiteId!);
  }

  Future<void> _charger(String universiteId) async {
    _chargement = true;
    try {
      final code = await _lire(universiteId);
      // La session a pu changer pendant l'appel : une réponse en retard ne
      // doit pas poser la devise d'un établissement qu'on a quitté.
      if (_universiteId != universiteId) return;
      if (code.isNotEmpty) {
        _devise = normaliserDevise(code);
        _duServeur = true;
        DeviseEtablissement.definir(code);
      }
    } catch (_) {
      // Échec de résolution : on garde le repli DÉCLARÉ plutôt que de
      // n'afficher aucune devise — un montant sans unité est pire qu'un
      // montant dans la devise dominante. Même arbitrage que le web.
    } finally {
      if (_universiteId == universiteId) {
        _chargement = false;
        _notifierPlusTard();
      }
    }
  }
}
