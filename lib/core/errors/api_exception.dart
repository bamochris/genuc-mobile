import 'dart:convert';

import 'package:dio/dio.dart';

/// Erreur d'appel API portant un message affichable à l'utilisateur.
///
/// Le backend renvoie ses erreurs sous la forme `{"erreur": "...", "code":
/// "..."}`. Sans ce type, chaque échec (panne réseau, 403 CSRF, compte non
/// activé) remontait comme un `null` indifférencié et l'écran de connexion
/// affichait « Email ou mot de passe incorrect » dans tous les cas.
class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  const ApiException(this.message, {this.code, this.statusCode});

  bool get estNonAutorise => statusCode == 401;
  bool get estInterdit => statusCode == 403;

  /// Résultats ou document retenus parce que l'étudiant doit des frais.
  /// 402 et non 403 côté serveur : ce n'est pas un défaut de droit.
  bool get estFraisImpayes => statusCode == 402 || code == 'FRAIS_IMPAYES';

  /// Le corps d'erreur tel qu'il arrive : un Map en JSON, mais des OCTETS
  /// quand l'appel demandait un fichier (`ResponseType.bytes`) — le refus
  /// d'un PDF ne disait alors que « Erreur serveur (402) ».
  static Map? _corps(dynamic data) {
    if (data is Map) return data;
    try {
      final texte = data is List<int>
          ? utf8.decode(data, allowMalformed: true)
          : data is String
              ? data
              : null;
      if (texte == null || texte.isEmpty) return null;
      final decode = jsonDecode(texte);
      return decode is Map ? decode : null;
    } catch (_) {
      return null;
    }
  }

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final data = _corps(response?.data);

    if (data != null) {
      final message = (data['erreur'] ?? data['error'] ?? data['message']);
      if (message is String && message.isNotEmpty) {
        return ApiException(
          message,
          code: data['code'] as String?,
          statusCode: response?.statusCode,
        );
      }
    }

    final message = switch (error.type) {
      DioExceptionType.connectionTimeout => 'Délai de connexion dépassé',
      DioExceptionType.sendTimeout => 'Délai d\'envoi dépassé',
      DioExceptionType.receiveTimeout => 'Délai de réception dépassé',
      DioExceptionType.connectionError =>
        'Impossible de joindre le serveur. Vérifiez votre connexion.',
      DioExceptionType.badCertificate => 'Certificat du serveur invalide',
      DioExceptionType.cancel => 'Requête annulée',
      DioExceptionType.badResponse => switch (response?.statusCode) {
          401 => 'Session expirée, veuillez vous reconnecter',
          402 => 'Contenu retenu tant que vos frais ne sont pas réglés.',
          403 => 'Accès refusé',
          404 => 'Ressource introuvable',
          429 => 'Trop de tentatives. Réessayez dans quelques minutes.',
          // Le serveur reconnaît la requête mais ne sait pas encore l'honorer :
          // depuis le 03/09/2026 les modules qui ne persistent rien REFUSENT
          // les écritures au lieu de répondre « enregistré » (LMS, évaluation
          // des enseignants, emploi universitaire, réseau alumni). Le message
          // détaillé vient du corps, lu plus haut ; ce repli ne sert que s'il
          // est absent.
          501 => 'Cette fonctionnalité n\'est pas encore disponible.',
          _ => 'Erreur serveur (${response?.statusCode})',
        },
      _ => 'Une erreur est survenue',
    };

    return ApiException(message, statusCode: response?.statusCode);
  }

  @override
  String toString() => message;
}
