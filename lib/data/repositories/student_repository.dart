import '../services/api_service.dart';
import '../services/etudiant_service.dart';
import '../models/etudiant/dashboard_data_backend.dart';
import '../models/etudiant/etudiant_profile_backend.dart';
import '../models/etudiant/cours.dart';
import '../models/etudiant/note.dart';
import '../models/etudiant/paiement.dart';

class StudentRepository {
  final ApiService api;
  final EtudiantService etudiantService;

  StudentRepository(this.api, this.etudiantService);

  Future<DashboardData> getDashboard(String inscriptionId) =>
      etudiantService.getDashboardData(inscriptionId);

  Future<List<Cours>> getCourses(String inscriptionId) =>
      etudiantService.getCours(inscriptionId);

  Future<CoursDetail> getCoursDetail(String inscriptionId, String coursId) =>
      etudiantService.getCoursDetail(inscriptionId, coursId);

  Future<void> marquerLeconComplete(
    String inscriptionId,
    String coursId,
    int leconId,
  ) =>
      etudiantService.marquerLeconComplete(inscriptionId, coursId, leconId);

  Future<NotesResultat> getNotes(String inscriptionId, {String? annee}) =>
      etudiantService.getNotes(inscriptionId, annee: annee);

  Future<ReleveNotes> getReleve(String inscriptionId, {String? annee}) =>
      etudiantService.getReleve(inscriptionId, annee: annee);

  Future<EtudiantProfile> getProfile(String inscriptionId) =>
      etudiantService.getProfil(inscriptionId);

  Future<EtudiantProfile> updateProfile(
    String inscriptionId,
    Map<String, dynamic> data,
  ) =>
      etudiantService.updateProfil(inscriptionId, data);

  Future<List<dynamic>> getTravaux(String inscriptionId) =>
      api.getTravaux(inscriptionId);

  Future<Map<String, dynamic>> getDocuments(String inscriptionId) =>
      api.getDocuments(inscriptionId);

  Future<List<dynamic>> getStages(String inscriptionId) =>
      api.getStages(inscriptionId);

  Future<SituationFinanciere> getSituationFinanciere() =>
      etudiantService.getSituationFinanciere();

  Future<List<FraisAcademique>> getFraisAPayer() =>
      etudiantService.getFraisAPayer();

  Future<List<Paiement>> getHistoriquePaiements() =>
      etudiantService.getHistoriquePaiements();

  Future<void> choisirVacation(String inscriptionId, int vacationId) =>
      etudiantService.choisirVacation(inscriptionId, vacationId);

  // Remboursements
  Future<void> demanderRemboursement({
    required int paiementId,
    required String motif,
  }) => etudiantService.demanderRemboursement(
    paiementId: paiementId,
    motif: motif,
  );
}
