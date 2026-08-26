import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Service de mise à jour OTA (Over-The-Air) via Shorebird Code Push.
///
/// Permet de pousser des correctifs de code sans passer par les stores
/// (Google Play / App Store). Utile pour les hotfixes critiques et les
/// corrections de bugs mineurs.
///
/// **Setup requis :**
/// 1. Créer un compte Shorebird (shorebird.dev)
/// 2. `shorebird init` dans le projet Flutter
/// 3. `shorebird release android` / `shorebird release ios`
class ShorebirdUpdateService {
  final updater = ShorebirdUpdater();

  /// Vérifie si une mise à jour OTA est disponible.
  Future<bool> checkForUpdate() async {
    if (kIsWeb) return false;
    try {
      final status = await updater.checkForUpdate();
      return status == UpdateStatus.outdated;
    } catch (e) {
      debugPrint('[Shorebird] Erreur vérification update: $e');
      return false;
    }
  }

  /// Télécharge et installe la mise à jour OTA.
  /// Retourne true si le redémarrage est nécessaire.
  Future<bool> downloadUpdate() async {
    if (kIsWeb) return false;
    try {
      final status = await updater.checkForUpdate();
      if (status != UpdateStatus.outdated) return false;

      await updater.update();
      return true;
    } catch (e) {
      debugPrint('[Shorebird] Erreur téléchargement: $e');
      return false;
    }
  }

  /// Numéro du patch actuellement installé.
  Future<int?> get currentPatchNumber async {
    if (kIsWeb) return null;
    try {
      final patch = await updater.readCurrentPatch();
      return patch?.number;
    } catch (e) {
      return null;
    }
  }

  /// Vérifie et applique les mises à jour au démarrage de l'app.
  Future<void> checkOnStartup() async {
    if (kIsWeb) return;
    try {
      final available = await checkForUpdate();
      if (available) {
        debugPrint('[Shorebird] Mise à jour disponible — téléchargement...');
        await downloadUpdate();
        debugPrint('[Shorebird] Patch téléchargé. Redémarrage requis.');
      }
    } catch (e) {
      debugPrint('[Shorebird] Erreur au démarrage: $e');
    }
  }
}
