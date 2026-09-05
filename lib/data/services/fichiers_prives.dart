import '../../core/errors/api_exception.dart';
import '../../core/utils/fichiers.dart';
import 'appel_api.dart';

/// Ouverture d'un fichier désigné par le chemin que le serveur a stocké.
///
/// ── Ce que ce module corrige ────────────────────────────────────────────
///
/// Les pièces du dossier, les consignes d'un travail, la copie corrigée : le
/// serveur en rend le chemin de STOCKAGE, `/uploads/<dossier>/<nom>`. Ce
/// chemin n'ouvre rien. `SecurityConfig` refuse tout `GET /uploads/**` hors
/// identité visuelle publique, et le fichier ne s'obtient que par
/// `GET /api/fichiers/<dossier>/<nom>`, qui exige le jeton puis vérifie la
/// propriété (`FichierAccesService`).
///
/// Les écrans passaient pourtant ce chemin à `launchUrl` : une URI sans schéma
/// ni hôte, dont l'échec ne remonte qu'un `false` que personne ne lisait.
/// Aucune pièce ne s'est jamais ouverte depuis l'application.
///
/// ── Les deux formes acceptées ───────────────────────────────────────────
///
/// Une valeur peut aussi être une vraie adresse — `urlConsignes` et
/// `urlCorrection` sont saisies à la main par l'enseignant, et rien n'oblige
/// qu'elles désignent un fichier de la plateforme. Une adresse `http(s)` part
/// donc au navigateur, SANS le jeton : l'envoyer à un hôte étranger serait le
/// fuiter. Tout le reste est traité comme un chemin de stockage.
extension FichiersPrives on ServiceApi {
  Future<void> ouvrirRessource(String valeur, {String? nomPropose}) async {
    final chemin = valeur.trim();
    if (chemin.isEmpty) {
      throw ApiException('Aucun fichier n\'est rattaché à cet élément.');
    }

    if (chemin.startsWith('http://') || chemin.startsWith('https://')) {
      final ouvert = await Fichiers.ouvrirLien(chemin);
      if (!ouvert) {
        throw ApiException('Ce lien n\'a pas pu être ouvert.');
      }
      return;
    }

    final octets = await octetsDe(
      cheminApiFichier(chemin),
      contexte: 'Ce fichier n\'a pas pu être téléchargé.',
    );
    await Fichiers.enregistrerEtOuvrir(
      octets,
      nomFichierDepuisChemin(chemin, nomPropose: nomPropose),
    );
  }
}

/// « /uploads/documents/a.pdf » → « /api/fichiers/documents/a.pdf ».
///
/// Un chemin déjà servi par l'API passe tel quel : le préfixer une seconde
/// fois le transformerait en 404.
String cheminApiFichier(String chemin) {
  if (chemin.startsWith('/api/')) return chemin;
  final relatif = chemin.startsWith('/uploads/')
      ? chemin.substring('/uploads/'.length)
      : chemin.replaceFirst(RegExp(r'^/+'), '');
  return '/api/fichiers/$relatif';
}

/// Nom sous lequel le fichier est écrit sur le téléphone.
///
/// L'extension du chemin prime toujours : sans elle, aucun lecteur Android ne
/// sait quoi ouvrir. Le nom proposé par l'écran ne sert qu'à rendre le fichier
/// reconnaissable dans le dossier de téléchargement.
String nomFichierDepuisChemin(String chemin, {String? nomPropose}) {
  final segment = chemin.split('/').last.split('?').first;
  final point = segment.lastIndexOf('.');
  final extension = point > 0 ? segment.substring(point) : '';

  if (nomPropose == null || nomPropose.trim().isEmpty) {
    return segment.isEmpty ? 'fichier$extension' : segment;
  }
  final propre = nomPropose
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .trim();
  final base = propre.isEmpty ? 'fichier' : propre;
  return base.toLowerCase().endsWith(extension.toLowerCase())
      ? base
      : '$base$extension';
}
