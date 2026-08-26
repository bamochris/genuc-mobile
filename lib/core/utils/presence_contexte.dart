import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/smart_presence/attendance_models.dart';

/// Contexte de présence transmis au serveur — pendant mobile de
/// `utils/presenceContexte.js` du portail web.
///
/// Rien de ce que produit ce service n'est une preuve. Un client peut mentir
/// sur sa position comme sur son identifiant ; le serveur les traite en
/// indices, qu'il confronte à ce qu'il sait de la séance. C'est pourquoi un
/// écart de position signale au professeur au lieu de refuser l'étudiant.
class PresenceContexteService {
  static const _cleAppareil = 'genuc.presence.appareil';

  final FlutterSecureStorage _storage;

  PresenceContexteService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Identifiant d'appareil, stable et propre à cette installation.
  ///
  /// Sert une seule question : deux comptes ont-ils validé leur présence depuis
  /// le même téléphone ? C'est la signature du prêt d'identifiants — la fraude
  /// la plus courante, et la seule que ni le réseau ni le GPS ne voient.
  ///
  /// Il ne contient aucune donnée personnelle : c'est un tirage aléatoire, que
  /// le serveur ne conserve que sous forme de condensat salé. Réinstaller
  /// l'application en produit un nouveau.
  Future<String?> identifiantAppareil() async {
    try {
      String? identifiant = await _storage.read(key: _cleAppareil);
      if (identifiant == null || identifiant.isEmpty) {
        identifiant = _genererIdentifiant();
        await _storage.write(key: _cleAppareil, value: identifiant);
      }
      return identifiant;
    } catch (_) {
      // Stockage refusé : on ne bloque pas l'étudiant, le serveur signalera
      // simplement « appareil non identifié ».
      return null;
    }
  }

  /// Position courante, ou `null` — jamais bloquant.
  ///
  /// Un refus de permission, un appareil sans GPS ou un délai dépassé sont des
  /// situations ordinaires : on rend `null` et la présence suit son cours,
  /// signalée au professeur qui tranchera.
  Future<Position?> positionCourante() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      if (!await Geolocator.checkPermission().then(_autorisationOk)) {
        final demande = await Geolocator.requestPermission();
        if (!_autorisationOk(demande)) return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  bool _autorisationOk(LocationPermission permission) {
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Contexte complet à joindre à une demande de présence.
  Future<ProximityProofRequest> contextePresence() async {
    final position = await positionCourante();
    return ProximityProofRequest(
      latitude: position?.latitude,
      longitude: position?.longitude,
      precisionMetres: position?.accuracy,
      identifiantAppareil: await identifiantAppareil(),
    );
  }

  String _genererIdentifiant() {
    final random = Random.secure();
    final octets = List<int>.generate(16, (_) => random.nextInt(256));
    return octets.map((o) => o.toRadixString(16).padLeft(2, '0')).join();
  }
}
