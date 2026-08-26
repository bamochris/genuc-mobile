import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/dio_client.dart';
import '../models/professeur/professeur_models.dart';

/// Service pour interagir avec l'API professeur du backend GENUC.
///
/// Chaque méthode correspond à une route de `ProfesseurController` ; le
/// professeur est identifié par son `id` utilisateur (les routes portent
/// `{professeurId}` dans le chemin).
class ProfesseurService {
  final Dio _dio;

  ProfesseurService(DioClient dioClient) : _dio = dioClient.dio;

  /// Statistiques clés du tableau de bord.
  /// `GET /api/professeur/stats/{professeurId}`.
  Future<StatsProfesseur> getStats(String professeurId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.professeurStats(professeurId),
      );
      if (response.statusCode == 200) {
        return StatsProfesseur.fromJson(response.data);
      }
      throw ApiException(
        'Erreur lors de la récupération des statistiques',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Résumé des présences (totaux + détail par cours).
  /// `GET /api/professeur/presences/{professeurId}`.
  Future<ResumePresences> getResumePresences(String professeurId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.professeurPresences(professeurId),
      );
      if (response.statusCode == 200) {
        return ResumePresences.fromJson(response.data);
      }
      throw ApiException(
        'Erreur lors de la récupération des présences',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Emploi du temps du jour.
  /// `GET /api/professeur/schedule/today/{professeurId}`.
  Future<List<SeanceProfesseur>> getScheduleToday(String professeurId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.professeurScheduleToday(professeurId),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) => SeanceProfesseur.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw ApiException(
        'Erreur lors de la récupération de l\'emploi du temps',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Alertes et actions urgentes.
  /// `GET /api/professeur/alertes/{professeurId}`.
  Future<List<AlerteProfesseur>> getAlertes(String professeurId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.professeurAlertes(professeurId),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) => AlerteProfesseur.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw ApiException(
        'Erreur lors de la récupération des alertes',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Emploi du temps hebdomadaire groupé par jour.
  /// `GET /api/professeur/planning/{professeurId}`.
  Future<List<JourPlanning>> getPlanning(String professeurId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.professeurPlanning(professeurId),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) => JourPlanning.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw ApiException(
        'Erreur lors de la récupération du planning',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
