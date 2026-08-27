import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/presence_contexte.dart';
import '../../../../data/models/smart_presence/attendance_models.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/portail_widgets.dart';

/// « Marquer ma présence » — deux gestes, rien à comprendre.
///
/// Aligné sur la version du portail web (`EtudiantSmartPresence.jsx`) après le
/// passage à la preuve de proximité :
///
///  1. la séance vient de `GET /sessions/mienne`. L'ancien écran la cherchait
///     dans `prochainsCours` du tableau de bord, que le serveur renvoie
///     toujours vide : il affichait « aucune séance » en permanence ;
///  2. un refus est un refus : `success:false` revient en HTTP 200 et doit
///     être lu, pas traité comme une erreur de requête ;
///  3. la preuve de proximité envoie position et identifiant d'appareil —
///     optionnels, jamais bloquants (le serveur les traite comme des indices
///     et signale la présence au professeur en cas de doute).
/// Phases du flux de marquage de présence.
///
/// [dejaPresent] remplace l'ancienne valeur `scanner`, qui n'était jamais
/// utilisée. Une présence déjà enregistrée n'est pas un échec : la traiter
/// comme tel — bandeau rouge, invitation à rescanner — poussait l'étudiant à
/// recommencer indéfiniment un geste que le serveur refusera toujours, la
/// contrainte d'unicité (séance, étudiant) étant précisément ce qui protège
/// sa présence.
enum _Phase { initial, verification, proximiteOk, proximiteKo, dejaPresent }

class EtudiantSmartPresenceScreen extends StatefulWidget {
  const EtudiantSmartPresenceScreen({super.key});

  @override
  State<EtudiantSmartPresenceScreen> createState() =>
      _EtudiantSmartPresenceScreenState();
}

class _EtudiantSmartPresenceScreenState
    extends State<EtudiantSmartPresenceScreen> {
  AttendanceSessionDto? _session;
  bool _chargement = true;
  bool _action = false;
  String? _erreur;
  String? _proofToken;
  ScanQrResponseDto? _resultat;
  Timer? _minuteur;
  bool _fige = false;
  _Phase _phase = _Phase.initial;

  @override
  void initState() {
    super.initState();
    _chargerSession();
    // Même cadence que le web : l'écran se met à jour tout seul.
    _minuteur = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_fige) _chargerSession();
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Future<void> _chargerSession() async {
    if (_fige) return;
    try {
      final api = context.read<StudentProvider>().repository.api;
      final data = await api.getSessionCouranteEtudiant();
      if (mounted) {
        setState(() {
          // 204 → aucune séance ouverte pour la promotion de l'étudiant.
          _session = data == null ? null : AttendanceSessionDto.fromJson(data);
          _erreur = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _session = null;
          // Afficher le message d'erreur réel du serveur au lieu de tout masquer.
          final msg = e.toString();
          if (msg.contains('500') || msg.contains('Internal')) {
            _erreur = 'Erreur serveur. Réessayez dans un instant.';
          } else if (msg.contains('401') || msg.contains('403')) {
            _erreur = 'Session expirée. Reconnectez-vous.';
          }
          // Autres erreurs : pas de message (réseau indisponible, etc.)
        });
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _marquerPresence() async {
    if (_session == null) return;

    setState(() {
      _action = true;
      _phase = _Phase.verification;
      _erreur = null;
      _resultat = null;
    });

    try {
      final api = context.read<StudentProvider>().repository.api;
      final contexte =
          await context.read<PresenceContexteService>().contextePresence();
      final res = await api.verifierProximite(_session!.sessionId,
          contexte: contexte);
      final proof = ProximityProofResponseDto.fromJson(res);

      if (!mounted) return;
      if (!proof.valide) {
        setState(() {
          _phase = _Phase.proximiteKo;
          _erreur = 'Proximité rejetée. Vous devez être en salle de cours.';
        });
        return;
      }
      setState(() {
        _proofToken = proof.proofToken;
        _phase = _Phase.proximiteOk;
      });
    } catch (e) {
      if (mounted) {
        // Le code métier fait foi : `ApiException` le porte (clé `code` de la
        // réponse). Chercher le code dans `toString()` marchait par accident
        // et cessait de marcher dès que le serveur reformulait son message.
        final code = e is ApiException ? e.code : null;
        if (code == 'PRESENCE_DEJA_ENREGISTREE') {
          setState(() {
            _phase = _Phase.dejaPresent;
            _erreur = null;
          });
          return;
        }
        // Un refus de proximité porte SON message : il nomme le lieu et la
        // distance. Le remplacer par « Impossible de démarrer la vérification »
        // effacerait la seule information utile à l'étudiant.
        if (code == 'PROXIMITE_REFUSEE') {
          setState(() {
            _erreur = e is ApiException ? e.message : e.toString();
            _phase = _Phase.proximiteKo;
          });
          return;
        }
        setState(() {
          final msg = e.toString();
          if (code == 'SESSION_FERMEE' || code == 'SESSION_EXPIREE'
              || msg.contains('SESSION_FERMEE') || msg.contains('SESSION_EXPIREE')) {
            _erreur = 'Cette séance de présence est terminée.';
          } else if (code == 'HORS_VACATION') {
            _erreur = 'Cette séance appartient à une autre vacation que la vôtre.';
          } else if (code == 'HORS_PROMOTION' || msg.contains('HORS_PROMOTION')) {
            _erreur = 'Ce cours ne fait pas partie de votre programme.';
          } else if (msg.contains('500') || msg.contains('Internal')) {
            _erreur = 'Erreur serveur. Réessayez dans un instant.';
          } else {
            _erreur = 'Impossible de démarrer la vérification. Réessayez.';
          }
          _phase = _Phase.proximiteKo;
        });
      }
    } finally {
      if (mounted) setState(() => _action = false);
    }
  }

  Future<void> _validerScan(String payload) async {
    if (payload.isEmpty || _proofToken == null || _session == null) return;

    setState(() {
      _action = true;
      _erreur = null;
    });

    try {
      final api = context.read<StudentProvider>().repository.api;
      final res = await api.scannerQr(
        _session!.sessionId,
        payload,
        _proofToken!,
      );
      final resultat = ScanQrResponseDto.fromJson(res);
      // Une preuve ne sert qu'une fois : la conserver ferait échouer un
      // éventuel second essai avec un message trompeur.
      if (resultat.code == 'PRESENCE_DEJA_ENREGISTREE') {
        setState(() {
          _phase = _Phase.dejaPresent;
          _proofToken = null;
          _fige = true;
          _erreur = null;
        });
        return;
      }
      setState(() {
        _resultat = resultat;
        _proofToken = null;
        _fige = true;
      });
    } catch (e) {
      if (mounted) {
        final code = e is ApiException ? e.code : null;
        if (code == 'PRESENCE_DEJA_ENREGISTREE') {
          setState(() {
            _phase = _Phase.dejaPresent;
            _proofToken = null;
            _fige = true;
            _erreur = null;
          });
          return;
        }
        final msg = e.toString();
        String message;
        if (code == 'HORS_VACATION') {
          message = 'Cette séance appartient à une autre vacation que la vôtre.';
        } else if (msg.contains('PRESENCE_REFUSEE') || msg.contains('refus')) {
          message = 'Présence refusée. Réessayez.';
        } else if (msg.contains('500') || msg.contains('Internal')) {
          message = 'Erreur serveur. Réessayez.';
        } else {
          message = 'Erreur lors du scan. Réessayez.';
        }
        setState(() {
          _erreur = message;
          _proofToken = null;
        });
      }
    } finally {
      if (mounted) setState(() => _action = false);
    }
  }

  void _recommencer() {
    setState(() {
      _resultat = null;
      _erreur = null;
      _proofToken = null;
      _fige = false;
      _phase = _Phase.initial;
    });
    _chargerSession();
  }

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: 'Marquer ma présence',
      corps: _chargement
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_erreur != null) _Bandeau(message: _erreur!, erreur: true),
                  // La présence déjà prise passe AVANT tout le reste : ni
                  // bouton, ni scanner, ni carte de résultat. Il n'y a plus
                  // rien à faire, et l'écran doit le dire au lieu de laisser
                  // croire à un échec qu'on pourrait rattraper.
                  if (_phase == _Phase.dejaPresent)
                    _CarteDejaPresent(
                      session: _session,
                      onActualiser: _recommencer,
                    )
                  else if (_resultat != null)
                    _CarteResultat(resultat: _resultat!, onRecommencer: _recommencer)
                  else if (_session != null) ...[
                    _CarteSession(session: _session!),
                    const SizedBox(height: 20),
                    if (_phase == _Phase.initial)
                      ElevatedButton.icon(
                        onPressed: _marquerPresence,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text(
                          'MARQUER MA PRÉSENCE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      )
                    else if (_phase == _Phase.verification)
                      _CarteVerificationProximite(
                        titre: 'Vérification de la proximité…',
                        sousTitre: 'Comparaison de votre position avec la salle de cours…',
                        icone: Icons.location_searching_rounded,
                        couleur: Colors.blue,
                        enCours: true,
                      )
                    else if (_phase == _Phase.proximiteOk) ...[
                      _CarteVerificationProximite(
                        titre: 'Proximité validée',
                        sousTitre: 'Vous êtes bien dans la salle. Scannez maintenant le QR.',
                        icone: Icons.check_circle_rounded,
                        couleur: Colors.green,
                        enCours: false,
                      ),
                      const SizedBox(height: 16),
                      _CarteScanner(
                        onScan: _validerScan,
                        enCours: _action,
                      ),
                    ]
                    else if (_phase == _Phase.proximiteKo)
                      ElevatedButton.icon(
                        onPressed: _marquerPresence,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text(
                          'RÉESSAYER LA VÉRIFICATION',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      )
                    else
                      _CarteScanner(
                        onScan: _validerScan,
                        enCours: _action,
                      ),
                  ] else
                    _AucuneSession(onActualiser: _chargerSession),
                ],
              ),
            ),
    );
  }
}

class _Bandeau extends StatelessWidget {
  final String message;
  final bool erreur;

  const _Bandeau({required this.message, required this.erreur});

  @override
  Widget build(BuildContext context) {
    final couleur = erreur ? AppTheme.error : AppTheme.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(color: couleur, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CarteVerificationProximite extends StatelessWidget {
  final String titre;
  final String sousTitre;
  final IconData icone;
  final Color couleur;
  final bool enCours;

  const _CarteVerificationProximite({
    required this.titre,
    required this.sousTitre,
    required this.icone,
    required this.couleur,
    required this.enCours,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        children: [
          if (enCours)
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: couleur,
              ),
            )
          else
            Icon(icone, size: 48, color: couleur),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: couleur,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  sousTitre,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteSession extends StatelessWidget {
  final AttendanceSessionDto session;

  const _CarteSession({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.coursTitre,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (session.coursCode != null && session.coursCode!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              session.coursCode!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
          ],
          const SizedBox(height: 12),
          if (session.professeurNom != null)
            _Ligne(icon: Icons.person_rounded, texte: session.professeurNom!),
          if (session.salleNom != null)
            _Ligne(
                icon: Icons.place_rounded,
                texte: session.salleNom!,
                fallback: 'Salle à confirmer'),
          if (session.promotionLibelle != null)
            _Ligne(
                icon: Icons.school_rounded, texte: session.promotionLibelle!),
          if (session.dateDebut != null)
            _Ligne(
              icon: Icons.schedule_rounded,
              texte: 'Depuis ${_heure(session.dateDebut!)}',
            ),
        ],
      ),
    );
  }

  String _heure(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Ligne extends StatelessWidget {
  final IconData icon;
  final String texte;
  final String? fallback;

  const _Ligne({required this.icon, required this.texte, this.fallback});

  @override
  Widget build(BuildContext context) {
    final affiche = texte.isEmpty ? (fallback ?? '—') : texte;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondaryOf(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              affiche,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AucuneSession extends StatelessWidget {
  final VoidCallback onActualiser;

  const _AucuneSession({required this.onActualiser});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.schedule_rounded, size: 48, color: AppTheme.textSecondaryOf(context)),
          const SizedBox(height: 16),
          Text(
            'Aucune présence en cours',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Votre professeur n\'a pas encore ouvert la présence. '
            'Cet écran se met à jour tout seul.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onActualiser,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualiser'),
          ),
        ],
      ),
    );
  }
}

/// Scanner caméra + repli « je n'arrive pas à scanner » (saisie manuelle),
/// comme sur le portail web.
class _CarteScanner extends StatefulWidget {
  final void Function(String payload) onScan;
  final bool enCours;

  const _CarteScanner({required this.onScan, required this.enCours});

  @override
  State<_CarteScanner> createState() => _CarteScannerState();
}

class _CarteScannerState extends State<_CarteScanner>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _derniereDetection = false;
  String? _erreurCamera;
  bool _permissionBloquee = false;
  bool _enCoursDemarrage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_demarrerScan());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    _controller = null;
    super.dispose();
  }

  /// Le système reprend la caméra dès que l'application passe en arrière-plan :
  /// sans ce relais, l'aperçu revient figé en noir. `MobileScanner` ne pose son
  /// propre observateur que lorsqu'il fabrique lui-même le contrôleur, ce qui
  /// n'est pas le cas ici.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null ||
        _enCoursDemarrage ||
        !controller.value.hasCameraPermission) {
      return;
    }

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        unawaited(_reprendre(controller));
      case AppLifecycleState.inactive:
        unawaited(_suspendre(controller));
    }
  }

  Future<void> _reprendre(MobileScannerController controller) async {
    try {
      await controller.start();
    } on MobileScannerException {
      // Rien à signaler ici : `errorBuilder` affiche déjà l'état de la caméra.
    }
  }

  Future<void> _suspendre(MobileScannerController controller) async {
    try {
      await controller.stop();
    } on MobileScannerException {
      // La caméra était déjà arrêtée.
    }
  }

  /// Demande la permission puis confie le démarrage au widget `MobileScanner`.
  ///
  /// Le contrôleur ne doit **pas** être démarré ici : depuis `mobile_scanner` 7,
  /// `start()` attend d'abord (500 ms) que le contrôleur soit rattaché à un
  /// widget `MobileScanner`. Démarrer avant de construire ce widget était donc
  /// un blocage circulaire — l'attente expirait en `controllerNotAttached`, les
  /// trois tentatives échouaient et la caméra ne s'ouvrait jamais, quel que
  /// soit l'appareil.
  Future<void> _demarrerScan() async {
    if (_enCoursDemarrage) return;
    setState(() {
      _enCoursDemarrage = true;
      _erreurCamera = null;
      _permissionBloquee = false;
    });

    // Retirer l'aperçu de l'arbre avant de libérer l'ancien contrôleur : le
    // greffon ne gère qu'une seule session caméra, une libération tardive
    // couperait celle qu'on vient d'ouvrir.
    final ancien = _controller;
    if (ancien != null) {
      setState(() => _controller = null);
      await WidgetsBinding.instance.endOfFrame;
      await ancien.dispose();
      if (!mounted) return;
    }

    var statut = await Permission.camera.status;
    if (statut.isDenied) {
      statut = await Permission.camera.request();
    }
    if (!mounted) return;

    if (!statut.isGranted && !statut.isLimited) {
      setState(() {
        _permissionBloquee = statut.isPermanentlyDenied || statut.isRestricted;
        _erreurCamera = _permissionBloquee
            ? 'Accès à la caméra bloqué. Autorisez la caméra dans les '
                'paramètres de l\'application, puis réessayez.'
            : 'Permission caméra refusée. Autorisez l\'accès pour scanner le QR.';
        _enCoursDemarrage = false;
      });
      return;
    }

    setState(() {
      _derniereDetection = false;
      // `autoStart` reste à sa valeur par défaut (true) : c'est `MobileScanner`
      // qui démarre le contrôleur une fois qu'il s'y est rattaché.
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
      _enCoursDemarrage = false;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (widget.enCours || _derniereDetection) return;
    final codes = capture.barcodes;
    if (codes.isEmpty) return;
    final raw = codes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _derniereDetection = true;
    widget.onScan(raw);
  }

  Future<void> _saisieManuelle() async {
    final controller = TextEditingController();
    final payload = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Saisie manuelle du QR'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Collez le contenu du QR (GENUC:SMART:…)',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (payload != null && payload.isNotEmpty) {
      widget.onScan(payload);
    }
  }

  /// Message lisible pour un échec remonté par le greffon — le détail brut est
  /// conservé pour que l'utilisateur puisse le rapporter.
  String _messageErreur(MobileScannerException erreur) {
    if (erreur.errorCode == MobileScannerErrorCode.permissionDenied) {
      return 'Accès à la caméra refusé. Autorisez la caméra dans les '
          'paramètres de l\'application.';
    }
    if (erreur.errorCode == MobileScannerErrorCode.unsupported) {
      return 'Cet appareil ne prend pas en charge le scan : utilisez la '
          'saisie manuelle.';
    }
    final details = erreur.errorDetails?.message;
    return details == null || details.isEmpty
        ? 'Caméra indisponible : utilisez la saisie manuelle.'
        : 'Caméra indisponible : $details';
  }

  Widget _voletNoir({required String message, required bool parametres}) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded,
                  color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _enCoursDemarrage ? null : _demarrerScan,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
                  if (parametres)
                    TextButton.icon(
                      onPressed: () => unawaited(openAppSettings()),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.settings_rounded),
                      label: const Text('Ouvrir les paramètres'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _apercu() {
    final erreur = _erreurCamera;
    if (erreur != null) {
      return _voletNoir(message: erreur, parametres: _permissionBloquee);
    }

    final controller = _controller;
    if (controller == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return MobileScanner(
      key: ValueKey(controller),
      controller: controller,
      onDetect: _onDetect,
      placeholderBuilder: (context) => const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      errorBuilder: (context, error) => _voletNoir(
        message: _messageErreur(error),
        parametres: error.errorCode == MobileScannerErrorCode.permissionDenied,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        children: [
          Text(
            'Scannez le QR affiché par votre professeur',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(height: 280, child: _apercu()),
          ),
          if (widget.enCours) ...[
            const SizedBox(height: 12),
            Text(
              'Validation…',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: widget.enCours ? null : _saisieManuelle,
            icon: const Icon(Icons.keyboard_rounded),
            label: const Text('Je n\'arrive pas à scanner'),
          ),
        ],
      ),
    );
  }
}

/// « Vous avez déjà marqué votre présence » — un aboutissement, pas une erreur.
///
/// Une présence ne se prend qu'une fois par séance : la contrainte d'unicité
/// (séance, étudiant) est ce qui empêche qu'on la lui reprenne ou qu'on la
/// double. L'écran affichait pourtant un bandeau rouge et un bouton de
/// reprise, si bien que l'étudiant rescannait — en vain, et en croyant que
/// sa présence n'était pas passée.
class _CarteDejaPresent extends StatelessWidget {
  final AttendanceSessionDto? session;
  final VoidCallback onActualiser;

  const _CarteDejaPresent({required this.session, required this.onActualiser});

  @override
  Widget build(BuildContext context) {
    final cours = session?.coursTitre;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Icon(Icons.verified_rounded, size: 56, color: AppTheme.success),
          const SizedBox(height: 14),
          Text(
            'Présence déjà enregistrée',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.success,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            cours == null || cours.isEmpty
                ? 'Vous avez déjà marqué votre présence pour cette séance. '
                    'Une présence ne se prend qu\'une seule fois : il n\'y a '
                    'rien de plus à faire.'
                : 'Vous avez déjà marqué votre présence pour « $cours ». '
                    'Une présence ne se prend qu\'une seule fois : il n\'y a '
                    'rien de plus à faire.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Si vous pensez qu\'il s\'agit d\'une erreur, signalez-le à votre '
            'enseignant : lui seul peut arbitrer une présence.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMutedOf(context),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onActualiser,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualiser'),
          ),
        ],
      ),
    );
  }
}

class _CarteResultat extends StatelessWidget {
  final ScanQrResponseDto resultat;
  final VoidCallback onRecommencer;

  const _CarteResultat({
    required this.resultat,
    required this.onRecommencer,
  });

  @override
  Widget build(BuildContext context) {
    final ok = resultat.success;
    final couleur = ok ? AppTheme.success : AppTheme.error;
    final titre = ok
        ? (resultat.estRetard ? 'Présence enregistrée (retard)' : 'Présence confirmée')
        : 'Présence non confirmée';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: couleur.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: couleur, size: 56),
          const SizedBox(height: 12),
          Text(
            titre,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: couleur, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            resultat.message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
          ),
          if (ok) ...[
            const SizedBox(height: 12),
            if (resultat.coursTitre != null)
              Text(
                resultat.coursTitre!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            if (resultat.salleNom != null)
              Text(
                resultat.salleNom!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (resultat.heureArrivee != null)
              Text(
                _heure(resultat.heureArrivee!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
              ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onRecommencer,
            child: Text(ok ? 'Fermer' : 'Réessayer'),
          ),
        ],
      ),
    );
  }

  String _heure(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
