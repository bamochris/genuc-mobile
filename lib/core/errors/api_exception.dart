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

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final data = response?.data;

    if (data is Map) {
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
