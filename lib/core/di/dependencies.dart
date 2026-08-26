import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/professeur_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/services/api_service.dart';
import '../../data/services/commun_service.dart';
import '../../data/services/etudiant_academique_service.dart';
import '../../data/services/etudiant_service.dart';
import '../../data/services/professeur_pedagogie_service.dart';
import '../../data/services/professeur_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../storage/session_storage.dart';
import '../utils/cache_service.dart';
import '../utils/dio_client.dart';
import '../utils/fcm_service.dart';
import '../utils/presence_contexte.dart';
import '../utils/shorebird_service.dart';

/// Assemblage des dépendances, construit une seule fois au démarrage.
///
/// Le point important est le [DioClient] unique : c'est lui qui porte le pot
/// à cookies de la session, et tous les services doivent partager le même.
class Dependencies {
  final DioClient dioClient;
  final ApiService apiService;
  final EtudiantService etudiantService;
  final EtudiantAcademiqueService etudiantAcademiqueService;
  final ProfesseurService professeurService;
  final ProfesseurPedagogieService professeurPedagogieService;
  final CommunService communService;
  final SessionStorage sessionStorage;
  final PresenceContexteService presenceContexte;
  final CacheService cacheService;
  final FCMService fcmService;
  final ShorebirdUpdateService shorebirdService;

  final AuthRepository authRepository;
  final StudentRepository studentRepository;
  final ProfesseurRepository professeurRepository;
  final NotificationRepository notificationRepository;
  final PaymentRepository paymentRepository;
  final DocumentRepository documentRepository;

  Dependencies._({
    required this.dioClient,
    required this.apiService,
    required this.etudiantService,
    required this.etudiantAcademiqueService,
    required this.professeurService,
    required this.professeurPedagogieService,
    required this.communService,
    required this.sessionStorage,
    required this.presenceContexte,
    required this.cacheService,
    required this.fcmService,
    required this.shorebirdService,
    required this.authRepository,
    required this.studentRepository,
    required this.professeurRepository,
    required this.notificationRepository,
    required this.paymentRepository,
    required this.documentRepository,
  });

  factory Dependencies.creer() {
    final dioClient = DioClient();
    final cacheService = CacheService();
    final apiService = ApiService(
      dio: dioClient.dio,
      cookieJar: dioClient.cookieJar,
      cache: cacheService,
    );
    final etudiantService = EtudiantService(dioClient);
    final etudiantAcademiqueService = EtudiantAcademiqueService(dioClient);
    final professeurService = ProfesseurService(dioClient);
    final professeurPedagogieService = ProfesseurPedagogieService(dioClient);
    final communService = CommunService(dioClient);
    final sessionStorage = SessionStorage();
    final presenceContexte = PresenceContexteService();
    final fcmService = FCMService(dioClient.dio);
    final shorebirdService = ShorebirdUpdateService();

    return Dependencies._(
      dioClient: dioClient,
      apiService: apiService,
      etudiantService: etudiantService,
      etudiantAcademiqueService: etudiantAcademiqueService,
      professeurService: professeurService,
      professeurPedagogieService: professeurPedagogieService,
      communService: communService,
      sessionStorage: sessionStorage,
      presenceContexte: presenceContexte,
      cacheService: cacheService,
      fcmService: fcmService,
      shorebirdService: shorebirdService,
      authRepository: AuthRepositoryImpl(
        api: apiService,
        sessionStorage: sessionStorage,
      ),
      studentRepository: StudentRepository(apiService, etudiantService),
      professeurRepository: ProfesseurRepository(professeurService),
      notificationRepository: NotificationRepository(apiService),
      paymentRepository: PaymentRepository(apiService),
      documentRepository: DocumentRepository(apiService),
    );
  }
}
