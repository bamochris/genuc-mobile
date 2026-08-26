import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../data/models/professeur/professeur_models.dart';
import '../../data/repositories/professeur_repository.dart';

/// État du portail professeur.
///
/// Charge en parallèle ce dont le tableau de bord a besoin — statistiques,
/// présences, emploi du temps du jour et alertes — puis expose le tout aux
/// écrans. Même principe que [StudentProvider] : les appels partent en
/// parallèle pour ne pas cumuler les latences.
class ProfesseurProvider extends ChangeNotifier {
  final ProfesseurRepository repository;

  ProfesseurProvider(this.repository);

  bool _isLoading = false;
  String? _error;
  StatsProfesseur? _stats;
  ResumePresences? _presences;
  List<SeanceProfesseur> _scheduleToday = [];
  List<AlerteProfesseur> _alertes = [];
  List<JourPlanning> _planning = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  StatsProfesseur? get stats => _stats;
  ResumePresences? get presences => _presences;
  List<SeanceProfesseur> get scheduleToday => _scheduleToday;
  List<AlerteProfesseur> get alertes => _alertes;
  List<JourPlanning> get planning => _planning;

  /// Charge en une passe tout ce dont le tableau de bord a besoin.
  ///
  /// [professeurId] est l'`id` utilisateur du compte connecté (les routes
  /// `{professeurId}` du backend attendent cet identifiant, pas une
  /// inscription).
  Future<void> loadDashboard(String professeurId) async {
    _setLoading(true);
    _error = null;
    try {
      final resultats = await Future.wait([
        repository.getStats(professeurId),
        repository.getResumePresences(professeurId),
        repository.getScheduleToday(professeurId),
        repository.getAlertes(professeurId),
      ]);
      _stats = resultats[0] as StatsProfesseur;
      _presences = resultats[1] as ResumePresences;
      _scheduleToday = resultats[2] as List<SeanceProfesseur>;
      _alertes = resultats[3] as List<AlerteProfesseur>;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Erreur de chargement du tableau de bord : ${e.runtimeType}';
    } finally {
      _setLoading(false);
    }
  }

  /// Emploi du temps hebdomadaire (chargé à la demande, pas au dashboard).
  Future<void> loadPlanning(String professeurId) async {
    try {
      _planning = await repository.getPlanning(professeurId);
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur de chargement du planning : ${e.runtimeType}';
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
