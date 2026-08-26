import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fichier choisi par l'utilisateur : chemin sur disque + nom d'origine.
class FichierChoisi {
  final String chemin;
  final String nom;
  final int taille;

  const FichierChoisi({
    required this.chemin,
    required this.nom,
    required this.taille,
  });

  String get tailleLisible {
    if (taille < 1024) return '$taille o';
    if (taille < 1024 * 1024) return '${(taille / 1024).round()} Ko';
    return '${(taille / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}

/// Sélection, enregistrement et ouverture de fichiers.
///
/// Le portail web s'appuie sur `<input type=file>` et sur les
/// `URL.createObjectURL` du navigateur ; sur mobile, chacune de ces trois
/// étapes est un appel distinct. Les regrouper ici évite que chaque écran
/// réinvente le chemin d'écriture — et écrive dans un dossier que le
/// visualiseur système ne peut pas lire.
class Fichiers {
  Fichiers._();

  /// Limite de téléversement du backend (`spring.servlet.multipart`).
  ///
  /// Vérifiée AVANT l'envoi : au-delà, Nginx coupe la connexion et l'écran
  /// affiche « serveur déconnecté » au lieu de « fichier trop lourd ».
  static const int tailleMaxOctets = 50 * 1024 * 1024;

  /// Ouvre le sélecteur de fichiers. [extensions] sans point (`['xlsx']`).
  static Future<FichierChoisi?> choisir({
    List<String>? extensions,
  }) async {
    // `FilePicker.platform` a disparu en version 11 : les méthodes sont
    // statiques sur la classe elle-même.
    final resultat = await FilePicker.pickFiles(
      type: extensions == null ? FileType.any : FileType.custom,
      allowedExtensions: extensions,
      withData: false,
    );

    final fichier = resultat?.files.singleOrNull;
    final chemin = fichier?.path;
    if (fichier == null || chemin == null) return null;

    return FichierChoisi(
      chemin: chemin,
      nom: fichier.name,
      taille: fichier.size,
    );
  }

  /// Écrit des octets reçus du serveur dans un fichier temporaire et l'ouvre
  /// avec l'application système (PDF, tableur, image).
  static Future<void> enregistrerEtOuvrir(
    List<int> octets,
    String nomFichier,
  ) async {
    final dossier = await getTemporaryDirectory();
    final fichier = File('${dossier.path}/$nomFichier');
    await fichier.writeAsBytes(octets, flush: true);
    await OpenFilex.open(fichier.path);
  }

  /// Ouvre une URL externe (support de cours hébergé, lien de publication).
  static Future<bool> ouvrirLien(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Ouverture du lien impossible : $e');
      return false;
    }
  }
}
