import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/models/etudiant/dashboard_data_backend.dart';
import '../../data/models/etudiant/etudiant_profile_backend.dart';
import '../../data/models/etudiant/cours.dart';
import '../../data/models/etudiant/note.dart';
import '../../data/models/etudiant/paiement.dart';

class StudentProvider extends ChangeNotifier {
  final StudentRepository repository;

  StudentProvider(this.repository);

  bool _isLoading = false;
  String? _error;
  DashboardData? _dashboard;
  List<Cours> _courses = [];
  NotesResultat? _notesResultat;
  ReleveNotes? _releve;
  List<dynamic> _travaux = [];
  List<dynamic> _stages = [];
  EtudiantProfile? _profile;
  Map<String, dynamic>? _documents;
  SituationFinanciere? _situationFinanciere;
  List<FraisAcademique> _fraisAPayer = [];
  List<Paiement> _historiquePaiements = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  DashboardData? get dashboard => _dashboard;
  List<Cours> get courses => _courses;
  NotesResultat? get notesResultat => _notesResultat;
  List<Note> get notes => _notesResultat?.notes ?? [];
  ReleveNotes? get releve => _releve;
  List<dynamic> get travaux => _travaux;
  List<dynamic> get stages => _stages;
  EtudiantProfile? get profile => _profile;
  Map<String, dynamic>? get documents => _documents;
  SituationFinanciere? get situationFinanciere => _situationFinanciere;
  List<FraisAcademique> get fraisAPayer => _fraisAPayer;
  List<Paiement> get historiquePaiements => _historiquePaiements;

  // Paiements validés éligibles pour un remboursement
  List<Paiement> get paiementsValides =>
      _historiquePaiements.where((p) => p.estValide).toList();

  /// Charge en une passe ce dont le tableau de bord a besoin.
  ///
  /// Les appels partent en parallèle : enchaînés, ils cumulaient leurs
  /// latences et chaque `notifyListeners` intermédiaire reconstruisait
  /// l'écran.
  Future<void> loadEssentiels(String inscriptionId) async {
    _setLoading(true);
    _error = null;
    try {
      final resultats = await Future.wait([
        repository.getDashboard(inscriptionId),
        repository.getCourses(inscriptionId),
        repository.getNotes(inscriptionId),
        repository.getProfile(inscriptionId),
        repository.getSituationFinanciere(),
      ]);
      _dashboard = resultats[0] as DashboardData;
      _courses = resultats[1] as List<Cours>;
      _notesResultat = resultats[2] as NotesResultat;
      _profile = resultats[3] as EtudiantProfile;
      _situationFinanciere = resultats[4] as SituationFinanciere;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Erreur de chargement : ${e.runtimeType}';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadDashboard(String inscriptionId) =>
      _charger(() async => _dashboard = await repository.getDashboard(inscriptionId));

  Future<void> loadCourses(String inscriptionId) =>
      _charger(() async => _courses = await repository.getCourses(inscriptionId));

  Future<void> loadNotes(String inscriptionId, {String? annee}) => _charger(
      () async => _notesResultat =
          await repository.getNotes(inscriptionId, annee: annee));

  Future<void> loadReleve(String inscriptionId, {String? annee}) => _charger(
      () async =>
          _releve = await repository.getReleve(inscriptionId, annee: annee));

  Future<void> loadProfile(String inscriptionId) =>
      _charger(() async => _profile = await repository.getProfile(inscriptionId));

  Future<void> loadSituationFinanciere() => _charger(() async {
        _situationFinanciere = await repository.getSituationFinanciere();
        _fraisAPayer = await repository.getFraisAPayer();
        _historiquePaiements = await repository.getHistoriquePaiements();
      });

  Future<void> loadTravaux(String inscriptionId) =>
      _charger(() async => _travaux = await repository.getTravaux(inscriptionId));

  Future<void> loadDocuments(String inscriptionId) =>
      _charger(() async => _documents = await repository.getDocuments(inscriptionId));

  Future<void> loadStages(String inscriptionId) =>
      _charger(() async => _stages = await repository.getStages(inscriptionId));

  /// Charge le détail d'un cours (leçons + progression) dans [_courses] en
  /// l'isolant : aucun autre état n'est touché.
  CoursDetail? _coursDetail;
  bool _coursDetailLoading = false;
  String? _coursDetailError;

  CoursDetail? get coursDetail => _coursDetail;
  bool get coursDetailLoading => _coursDetailLoading;
  String? get coursDetailError => _coursDetailError;

  Future<void> loadCoursDetail(String inscriptionId, String coursId) async {
    _coursDetailLoading = true;
    _coursDetailError = null;
    notifyListeners();
    try {
      _coursDetail = await repository.getCoursDetail(inscriptionId, coursId);
    } on ApiException catch (e) {
      _coursDetailError = e.message;
    } catch (e) {
      _coursDetailError = 'Erreur de chargement du cours : ${e.runtimeType}';
    } finally {
      _coursDetailLoading = false;
      notifyListeners();
    }
  }

  /// Marque une leçon comme complétée puis recharge le détail pour rafraîchir
  /// la progression.
  Future<void> marquerLeconComplete(
    String inscriptionId,
    String coursId,
    int leconId,
  ) async {
    try {
      await repository.marquerLeconComplete(inscriptionId, coursId, leconId);
      await loadCoursDetail(inscriptionId, coursId);
    } on ApiException catch (e) {
      _coursDetailError = e.message;
      notifyListeners();
    } catch (e) {
      _coursDetailError = 'Erreur de marquage : ${e.runtimeType}';
      notifyListeners();
    }
  }

  Future<void> updateProfile(
    String inscriptionId,
    Map<String, dynamic> data,
  ) {
    return _charger(() async {
      final result = await repository.updateProfile(inscriptionId, data);
      _profile = result;
    });
  }

  Future<void> choisirVacation(String inscriptionId, int vacationId) {
    return _charger(() async {
      await repository.choisirVacation(inscriptionId, vacationId);
      _dashboard = await repository.getDashboard(inscriptionId);
    });
  }

  Future<void> _charger(Future<void> Function() action) async {
    _setLoading(true);
    _error = null;
    try {
      await action();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Erreur de chargement : ${e.runtimeType}';
    } finally {
      _setLoading(false);
    }
  }

  // ─── Remboursements ────────────────────────────────────────

  /// Soumet une demande de remboursement pour un paiement validé.
  Future<void> demanderRemboursement({
    required int paiementId,
    required String motif,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      await repository.demanderRemboursement(
        paiementId: paiementId,
        motif: motif,
      );
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
