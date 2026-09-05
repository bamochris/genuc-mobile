import '../../core/constants/api_endpoints.dart';
import '../../core/errors/api_exception.dart';
import '../../core/utils/fichiers.dart';
import 'appel_api.dart';

/// Ouverture d'un support de cours, pour les trois écrans qui en affichent :
/// le dépôt du professeur, le détail d'un cours et « Supports de cours » côté
/// étudiant.
///
/// ── Pourquoi ce fichier existe ──────────────────────────────────────────
///
/// Les écrans passaient `support.url` à `Fichiers.ouvrirLien`. Ce champ porte
/// le chemin de STOCKAGE — `/uploads/supports/<uuid>.pdf` — et non une URL :
/// ni schéma, ni hôte. `launchUrl` ne pouvait rien en faire, et son échec ne
/// remonte qu'un `false` que deux des trois écrans ignoraient. Aucun support
/// ne s'est jamais ouvert depuis l'application.
///
/// Le fichier n'est de toute façon pas servi en statique : le serveur refuse
/// `GET /uploads/**` hors identité visuelle publique. Il faut le demander avec
/// le jeton, l'écrire sur le disque, puis laisser le système choisir le
/// lecteur — c'est ce que fait `ouvrirSupport`.
extension SupportsDeCours on ServiceApi {
  /// Télécharge le support et l'ouvre avec l'application système.
  ///
  /// Lève une [ApiException] si le support ne porte pas d'identifiant : sans
  /// lui il n'y a pas de route, et échouer en silence est précisément le
  /// défaut que ce module corrige.
  Future<void> ouvrirSupport(Fiche support) async {
    if (support.id.isEmpty) {
      throw ApiException('Ce support ne porte aucun fichier téléchargeable.');
    }
    final octets = await octetsDe(
      ApiEndpoints.supportFichier(support.id),
      contexte: 'Le support n\'a pas pu être téléchargé.',
    );
    await Fichiers.enregistrerEtOuvrir(octets, nomFichierSupport(support));
  }
}

/// Nom sous lequel le support est écrit sur le téléphone.
///
/// Le nom de dépôt d'abord — c'est lui qui porte l'extension, et sans
/// extension aucun lecteur Android ne sait quoi ouvrir. À défaut, le titre
/// nettoyé de tout ce qu'un système de fichiers refuse.
String nomFichierSupport(Fiche support) {
  final nomDepot = support.texte('nomFichierOriginal');
  if (nomDepot.isNotEmpty) return _assaini(nomDepot);

  final titre = support.texte('titre', defaut: 'support');
  final extension = _extensionParType(support.texte('type'));
  return '${_assaini(titre)}$extension';
}

String _assaini(String nom) {
  final propre = nom.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return propre.isEmpty ? 'support' : propre;
}

/// Extension de repli quand le nom d'origine manque, déduite du type déclaré
/// à l'envoi (`SupportCours.TypeSupport`).
String _extensionParType(String type) {
  switch (type) {
    case 'PDF':
      return '.pdf';
    case 'VIDEO':
      return '.mp4';
    case 'PPT':
      return '.pptx';
    default:
      return '';
  }
}
