import '../models/professeur/professeur_models.dart';
import '../services/professeur_service.dart';

class ProfesseurRepository {
  final ProfesseurService service;

  ProfesseurRepository(this.service);

  Future<StatsProfesseur> getStats(String professeurId) =>
      service.getStats(professeurId);

  Future<ResumePresences> getResumePresences(String professeurId) =>
      service.getResumePresences(professeurId);

  Future<List<SeanceProfesseur>> getScheduleToday(String professeurId) =>
      service.getScheduleToday(professeurId);

  Future<List<AlerteProfesseur>> getAlertes(String professeurId) =>
      service.getAlertes(professeurId);

  Future<List<JourPlanning>> getPlanning(String professeurId) =>
      service.getPlanning(professeurId);
}
