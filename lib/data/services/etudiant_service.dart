import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/utils/dio_client.dart';
import '../models/etudiant/dashboard_data_backend.dart';
import '../models/etudiant/etudiant_profile_backend.dart';
import '../models/etudiant/cours.dart';
import '../models/etudiant/note.dart';
import '../models/etudiant/paiement.dart';

/// Service pour interagir avec l'API étudiant du backend GENUC
class EtudiantService {
  final Dio _dio;

  EtudiantService(DioClient dioClient) : _dio = dioClient.dio;

  /// Récupère les données complètes du dashboard étudiant
  /// Correspond à GET /api/etudiant/portal/dashboard/{inscriptionId}
  Future<DashboardData> getDashboardData(String inscriptionId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.etudiantDashboard(inscriptionId),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return DashboardData.fromJson(data);
      } else {
        throw ApiException(
          'Erreur lors de la récupération du dashboard',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Récupère le profil étudiant
  /// Correspond à GET /api/etudiant/portal/profil/{inscriptionId}
  Future<EtudiantProfile> getProfil(String inscriptionId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.etudiantProfil(inscriptionId),
      );

      if (response.statusCode == 200) {
        return EtudiantProfile.fromJson(response.data);
      } else {
        throw ApiException(
          'Erreur lors de la récupération du profil',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Met à jour le profil étudiant
  /// Correspond à PUT /api/etudiant/portal/profil/{inscriptionId}
  Future<EtudiantProfile> updateProfil(
    String inscriptionId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.etudiantProfil(inscriptionId),
        data: data,
      );

      if (response.statusCode == 200) {
        // Le backend répond `{message: ...}` sans renvoyer le profil : on
        // relit le profil à jour pour que l'appelant ait une donnée fraîche.
        return getProfil(inscriptionId);
      } else {
        throw ApiException(
          'Erreur lors de la mise à jour du profil',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Récupère la liste des cours de l'étudiant (avec progression)
  /// Correspond à GET /api/etudiant/portal/{inscriptionId}/cours
  Future<List<Cours>> getCours(String inscriptionId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.etudiantCours(inscriptionId),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) => Cours.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          'Erreur lors de la récupération des cours',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Récupère les détails d'un cours
  /// Correspond à GET /api/etudiant/portal/{inscriptionId}/cours/{coursId}
  Future<CoursDetail> getCoursDetail(
    String inscriptionId,
    String coursId,
  ) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.etudiantCoursDetail(inscriptionId, coursId),
      );

      if (response.statusCode == 200) {
        return CoursDetail.fromJson(response.data);
      } else {
        throw ApiException(
          'Erreur lors de la récupération des détails du cours',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Marquer une leçon comme complète
  /// Correspond à POST /api/etudiant/portal/{inscriptionId}/cours/{coursId}/lecon/{leconId}/complete
  Future<void> marquerLeconComplete(
    String inscriptionId,
    String coursId,
    int leconId, {
    int tempsMinutes = 0,
  }) async {
    try {
      await _dio.post(
        '${ApiEndpoints.etudiantCours(inscriptionId)}/$coursId/lecon/$leconId/complete',
        data: tempsMinutes > 0 ? {'tempsMinutes': tempsMinutes} : null,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Récupère les notes de l'étudiant.
  /// Correspond à GET /api/etudiant/portal/{inscriptionId}/notes.
  /// Le backend renvoie un objet `{anneeAcademique, moyenneGenerale,
  /// creditsValides, notes:[...]}` — d'où [NotesResultat], pas une liste nue.
  Future<NotesResultat> getNotes(String inscriptionId, {String? annee}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.etudiantNotes(inscriptionId),
        queryParameters: annee != null ? {'annee': annee} : null,
      );

      if (response.statusCode == 200) {
        return NotesResultat.fromJson(response.data);
      } else {
        throw ApiException(
          'Erreur lors de la récupération des notes',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Récupère le relevé de notes
  /// Correspond à GET /api/etudiant/portal/{inscriptionId}/releve
  Future<ReleveNotes> getReleve(String inscriptionId, {String? annee}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.etudiantReleve(inscriptionId),
        queryParameters: annee != null ? {'annee': annee} : null,
      );

      if (response.statusCode == 200) {
        return ReleveNotes.fromJson(response.data);
      } else {
        throw ApiException(
          'Erreur lors de la récupération du relevé',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Situation financière complète.
  /// Correspond à GET /api/etudiant/frais/situation (objet, pas une liste).
  Future<SituationFinanciere> getSituationFinanciere() async {
    try {
      final response = await _dio.get(ApiEndpoints.fraisSituation);

      if (response.statusCode == 200) {
        return SituationFinanciere.fromJson(response.data);
      } else {
        throw ApiException(
          'Erreur lors de la récupération de la situation financière',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Liste des frais à payer (dettes actives).
  /// Correspond à GET /api/etudiant/frais/a-payer
  Future<List<FraisAcademique>> getFraisAPayer() async {
    try {
      final response = await _dio.get(ApiEndpoints.fraisAPayer);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) => FraisAcademique.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          'Erreur lors de la récupération des frais à payer',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Récupère l'historique des paiements
  /// Correspond à GET /api/etudiant/frais/historique
  Future<List<Paiement>> getHistoriquePaiements() async {
    try {
      final response = await _dio.get(ApiEndpoints.historiquePaiements);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) => Paiement.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          'Erreur lors de la récupération de l\'historique',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Effectue le choix rétroactif de vacation (Jour / Soir) pour un étudiant
  /// Correspond à POST /api/etudiant/portal/{inscriptionId}/choisir-vacation
  Future<void> choisirVacation(String inscriptionId, int vacationId) async {
    try {
      await _dio.post(
        '/api/etudiant/portal/$inscriptionId/choisir-vacation',
        data: {'vacationId': vacationId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Soumet une demande de remboursement pour un paiement validé.
  /// Correspond à POST /api/remboursements/demander
  Future<void> demanderRemboursement({
    required int paiementId,
    required String motif,
  }) async {
    try {
      await _dio.post(
        '/api/remboursements/demander',
        data: {
          'paiementId': paiementId,
          'motif': motif,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
