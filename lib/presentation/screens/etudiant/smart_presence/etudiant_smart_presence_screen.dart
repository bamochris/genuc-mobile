import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

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
enum _Phase { initial, verification, proximiteOk, proximiteKo, scanner }

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
        setState(() {
          final msg = e.toString();
          if (msg.contains('SESSION_FERMEE') || msg.contains('SESSION_EXPIREE')) {
            _erreur = 'Cette séance de présence est terminée.';
          } else if (msg.contains('PRESENCE_DEJA_ENREGISTREE')) {
            _erreur = 'Votre présence est déjà enregistrée pour cette séance.';
          } else if (msg.contains('HORS_PROMOTION')) {
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
      setState(() {
        _resultat = resultat;
        _proofToken = null;
        _fige = true;
      });
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        String message;
        if (msg.contains('PRESENCE_DEJA_ENREGISTREE')) {
          message = 'Votre présence est déjà enregistrée.';
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
                  if (_resultat != null)
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

class _CarteScannerState extends State<_CarteScanner> {
  MobileScannerController? _controller;
  bool _derniereDetection = false;
  String? _erreurCamera;

  @override
  void initState() {
    super.initState();
    _demarrerScan();
  }

  Future<void> _demarrerScan() async {
    if (!mounted) return;
    setState(() => _erreurCamera = null);

    final status = await Permission.camera.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      final requested = await Permission.camera.request();
      if (!requested.isGranted) {
        if (mounted) {
          setState(() {
            _erreurCamera = 'Permission caméra refusée. Autorisez l\'accès dans les paramètres.';
          });
        }
        return;
      }
    }

    try {
      final ctrl = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        autoStart: false,
      );
      await ctrl.start();
      if (mounted) {
        setState(() {
          _controller = ctrl;
          _erreurCamera = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erreurCamera = 'Impossible d\'accéder à la caméra. Utilisez la saisie manuelle.';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
            child: SizedBox(
              height: 280,
              child: _erreurCamera != null
                  ? Container(
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
                                _erreurCamera!,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _demarrerScan,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Réessayer'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : _controller == null
                      ? Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        )
                      : MobileScanner(
                          controller: _controller!,
                          onDetect: _onDetect,
                          errorBuilder: (context, error) => Container(
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
                                    const Text(
                                      'Caméra indisponible : utilisez la saisie manuelle.',
                                      style: TextStyle(color: Colors.white),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _demarrerScan,
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Réessayer'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
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
