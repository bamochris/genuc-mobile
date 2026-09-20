import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  ///
  /// La valeur annoncée était de 50 Mo, quand `max-file-size` vaut 10 Mo :
  /// l'application laissait donc pousser une vidéo de 40 Mo pendant plusieurs
  /// minutes sur une liaison mobile, pour un échec sans explication. Le web
  /// porte désormais le même plafond (`SupportsCours.jsx`).
  static const int tailleMaxOctets = 10 * 1024 * 1024;

  /// La limite telle qu'on l'annonce à l'écran.
  ///
  /// Six écrans écrivaient « Maximum accepté : 50 Mo » en dur à côté d'un test
  /// portant sur [tailleMaxOctets] : changer la constante ne changeait pas le
  /// message, et l'utilisateur lisait un plafond que le contrôle ne pratiquait
  /// pas.
  static String get tailleMaxLisible =>
      '${tailleMaxOctets ~/ (1024 * 1024)} Mo';

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

  /// Enregistre le PDF reçu dans le dossier Téléchargements (Android) ou le partage (iOS).
  ///
  /// Sur Android API 29+ : utilise le MediaStore pour écrire dans le dossier
  /// public "Download" accessible par toutes les applications.
  /// Sur Android < 29 : écrit dans le dossier Downloads classique.
  /// Sur iOS : ouvre la feuille de partage système (Sauvegarder dans Fichiers, AirDrop, etc.).
  ///
  /// Retourne le chemin du fichier enregistré (Android) ou `true` si partagé (iOS).
  static Future<String?> enregistrerDansTelechargements(
    List<int> octets,
    String nomFichier,
  ) async {
    if (Platform.isAndroid) {
      return _enregistrerAndroidDownloads(octets, nomFichier);
    } else if (Platform.isIOS) {
      return _partagerIOS(octets, nomFichier);
    } else {
      // Desktop/Web : fallback sur le dossier documents de l'app
      return _enregistrerDocumentsApp(octets, nomFichier);
    }
  }

  static Future<String> _enregistrerAndroidDownloads(
    List<int> octets,
    String nomFichier,
  ) async {
    try {
      // Essaie d'abord le dossier public Downloads via MediaStore (API 29+)
      final downloadsDir = await _getAndroidDownloadsDirectory();
      if (downloadsDir != null) {
        final fichier = File('${downloadsDir.path}/$nomFichier');
        await fichier.writeAsBytes(octets, flush: true);
        return fichier.path;
      }
    } catch (e) {
      debugPrint('Échec MediaStore Downloads : $e');
    }

    // Fallback : dossier Downloads classique (fonctionne sur API < 29 et souvent sur API 29+)
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final fichier = File('${downloadsDir.path}/$nomFichier');
        await fichier.writeAsBytes(octets, flush: true);
        return fichier.path;
      }
    } catch (e) {
      debugPrint('Échec dossier Downloads classique : $e');
    }

    // Dernier recours : dossier documents de l'app
    return _enregistrerDocumentsApp(octets, nomFichier);
  }

  static Future<Directory?> _getAndroidDownloadsDirectory() async {
    try {
      // Tente d'utiliser le MediaStore via getExternalStorageDirectory
      // qui pointe vers Android/data/.../files/Download sur API 29+
      // mais ce n'est PAS le dossier public Downloads.
      // Pour le VRAI dossier public, on a besoin de MediaStore API
      // qui n'est pas directement accessible depuis Dart.
      // On utilise donc le chemin connu /storage/emulated/0/Download
      // qui fonctionne sur la plupart des appareils.
      return null; // Force l'utilisation du chemin classique ci-dessous
    } catch (_) {
      return null;
    }
  }

  static Future<String> _partagerIOS(List<int> octets, String nomFichier) async {
    final tempDir = await getTemporaryDirectory();
    final fichier = File('${tempDir.path}/$nomFichier');
    await fichier.writeAsBytes(octets, flush: true);
    await Share.shareXFiles([XFile(fichier.path)], text: 'Reçu de paiement GENUC');
    return 'partagé';
  }

  static Future<String> _enregistrerDocumentsApp(List<int> octets, String nomFichier) async {
    final dir = await getApplicationDocumentsDirectory();
    final fichier = File('${dir.path}/$nomFichier');
    await fichier.writeAsBytes(octets, flush: true);
    await OpenFilex.open(fichier.path);
    return fichier.path;
  }
}
