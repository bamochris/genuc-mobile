import 'dart:convert';

import '../../core/constants/api_endpoints.dart';
import 'appel_api.dart';

/// Routes partagées par les deux portails : messagerie, bibliothèque et
/// référentiel (universités, filières, promotions, années académiques).
///
/// Les deux portails web appellent exactement les mêmes chemins, avec un
/// paramètre différent (`inscriptionId` pour l'étudiant, `id` utilisateur pour
/// l'enseignant) — d'où les deux entrées de `messages`.
class CommunService extends ServiceApi {
  CommunService(super.client);

  // ─── Messagerie ────────────────────────────────────────────

  /// Boîte de réception de l'étudiant.
  Future<List<Fiche>> messagesEtudiant(String inscriptionId) => listeDe(
        ApiEndpoints.messagerieEtudiant(inscriptionId),
        contexte: 'Vos messages n\'ont pas pu être chargés.',
      );

  /// Boîte de réception du personnel (enseignant compris).
  Future<List<Fiche>> messagesPersonnel(String utilisateurId) => listeDe(
        ApiEndpoints.messagerieAdmin(utilisateurId),
        contexte: 'Vos messages n\'ont pas pu être chargés.',
      );

  Future<List<Fiche>> contacts(String universiteId) =>
      listeDe(ApiEndpoints.messagerieContacts(universiteId));

  /// Cibles de diffusion (promotions, filières) — réservé au personnel.
  Future<List<Fiche>> ciblesDiffusion(String universiteId) =>
      listeDe(ApiEndpoints.messagerieCibles(universiteId));

  Future<Fiche> envoyerMessage(Map<String, dynamic> donnees) => poster(
        ApiEndpoints.messagerieEnvoyer,
        corps: donnees,
        contexte: 'Le message n\'a pas pu être envoyé.',
      );

  Future<Fiche> repondre(String messageId, String contenu) => poster(
        ApiEndpoints.messageRepondre(messageId),
        // Le serveur lit la clé `reponse` (`MessagerieController`) : lui envoyer
        // « contenu » produisait un 400 « reponse est requis ».
        corps: {'reponse': contenu},
        contexte: 'La réponse n\'a pas pu être envoyée.',
      );

  Future<void> supprimerMessage(String messageId) => supprimer(
        ApiEndpoints.messageSupprimer(messageId),
        contexte: 'Le message n\'a pas pu être supprimé.',
      );

  Future<Fiche> marquerMessageLu(String messageId) =>
      corriger(ApiEndpoints.messageMarquerLu(messageId));

  // ─── Bibliothèque ──────────────────────────────────────────

  Future<List<Fiche>> ouvrages(String universiteId, {String? recherche}) =>
      listeDe(
        ApiEndpoints.bibliothequeOuvrages(universiteId),
        parametres: recherche != null && recherche.isNotEmpty
            ? {'recherche': recherche}
            : null,
        contexte: 'La bibliothèque n\'a pas pu être chargée.',
      );

  Future<List<Fiche>> categoriesBibliotheque(String universiteId) =>
      listeDe(ApiEndpoints.bibliothequeCategories(universiteId));

  /// Réserve un ouvrage pour un étudiant.
  ///
  /// L'appel envoyait `{ouvrageId}` alors que le serveur exige `livreId` ET
  /// `etudiantId`, et répond 400 si l'un manque : la réservation n'a jamais
  /// fonctionné depuis l'application. Défaut antérieur aux corrections du
  /// 03/09/2026, révélé en alignant le contrat.
  ///
  /// L'étudiant est désormais borné côté serveur (`peutAccederEtudiant`) :
  /// réserver au nom d'un camarade laissait la dette et le retard sur lui.
  Future<Fiche> reserverOuvrage(String livreId, String etudiantId) => poster(
        ApiEndpoints.bibliothequeReserver,
        corps: {'livreId': livreId, 'etudiantId': etudiantId},
        contexte: 'La réservation a échoué.',
      );

  Future<List<Fiche>> livres(String universiteId) =>
      listeDe(ApiEndpoints.bibliothequeLivres(universiteId));

  Future<Fiche> emprunter(String livreId, String etudiantId) => poster(
        ApiEndpoints.bibliothequeEmprunter,
        corps: {'livreId': livreId, 'etudiantId': etudiantId},
        contexte: 'L\'emprunt a échoué.',
      );

  Future<List<Fiche>> mesEmprunts(String etudiantId) =>
      listeDe(ApiEndpoints.bibliothequeMesEmprunts(etudiantId));

  Future<Fiche> prolongerEmprunt(String empruntId, {int jours = 7}) => corriger(
        ApiEndpoints.bibliothequeProlonger(empruntId),
        parametres: {'jours': jours},
        contexte: 'La prolongation a échoué.',
      );

  // ─── Modules activés par l'université ──────────────────────

  /// Modules que l'établissement a ouverts dans ses paramètres.
  ///
  /// Le champ `modulesActifs` arrive sous forme de chaîne JSON (et non
  /// d'objet) : c'est ainsi que le portail web le reçoit et le parse. Une
  /// carte vide signifie « tout est actif » — c'est la compatibilité
  /// ascendante retenue côté web, à ne pas inverser.
  Future<Map<String, bool>> modulesActifs(String universiteId) async {
    final fiche = await ficheDe(ApiEndpoints.universitePublique(universiteId));
    final brut = fiche['modulesActifs'];

    Map<String, dynamic>? carte;
    if (brut is Map) {
      carte = Map<String, dynamic>.from(brut);
    } else if (brut is String && brut.trim().isNotEmpty) {
      try {
        final decode = jsonDecode(brut);
        if (decode is Map) carte = Map<String, dynamic>.from(decode);
      } catch (_) {
        return const {};
      }
    }
    if (carte == null) return const {};

    return carte.map((cle, valeur) => MapEntry(cle, valeur != false));
  }

  // ─── Référentiel ───────────────────────────────────────────

  Future<List<Fiche>> universites() => listeDe(ApiEndpoints.universites);

  Future<List<Fiche>> anneesAcademiques() => listeDe(
        ApiEndpoints.anneesAcademiques,
        contexte: 'Les années académiques n\'ont pas pu être chargées.',
      );

  /// Années actives ET clôturées — 403 pour qui n'administre pas
  /// l'établissement. L'appelant retombe alors sur [anneesAcademiques].
  Future<List<Fiche>> anneesAcademiquesToutes() => listeDe(
        ApiEndpoints.anneesAcademiquesToutes,
        contexte: 'Les années académiques n\'ont pas pu être chargées.',
      );

  /// Filières OUVERTES d'un établissement, quel qu'il soit.
  ///
  /// Visait `/api/filieres/universite/{id}`, réservée à l'administration —
  /// l'étudiant recevait un 403 sur les deux sélecteurs du formulaire de
  /// transfert, qui restait donc infranchissable. Ouvrir le rôle n'y aurait
  /// rien changé : cette route porte en plus un contrôle explicite qui refuse
  /// tout établissement autre que celui de l'appelant, or on demande ici les
  /// filières de l'établissement d'ACCUEIL. La route publique ne rend que les
  /// filières ouvertes — exactement la sémantique d'une destination.
  Future<List<Fiche>> filieres(String universiteId) => listeDe(
        ApiEndpoints.filieresDisponibles,
        parametres: {'universiteId': universiteId},
      );

  Future<List<Fiche>> promotionsDeFiliere(String filiereId) =>
      listeDe(ApiEndpoints.promotionsFiliere(filiereId));

  Future<List<Fiche>> promotionsUniversite(String universiteId) =>
      listeDe(ApiEndpoints.promotionsUniversite(universiteId));

  /// Vacations ouvertes par l'établissement (jour, soir, week-end…).
  ///
  /// Référentiel partagé : l'enseignant s'en sert pour filtrer ses cours,
  /// l'étudiant pour demander un changement de vacation.
  Future<List<Fiche>> vacationsActives(String universiteId) =>
      listeDe(ApiEndpoints.vacationsActives(universiteId));
}
