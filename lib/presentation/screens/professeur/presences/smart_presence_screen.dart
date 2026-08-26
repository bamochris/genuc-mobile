import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/presence_contexte.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/models/smart_presence/attendance_models.dart';
import '../../../../data/services/api_service.dart';
import '../../../widgets/portail_widgets.dart';

/// Smart Présence côté enseignant : ouvrir une séance, projeter le QR
/// tournant, suivre les pointages en direct, clore.
///
/// Le QR est régénéré côté serveur : sa charge utile n'est valable que
/// [AttendanceSessionDto.qrValiditeSecondes] secondes. L'écran redemande donc
/// l'état de la séance à cette cadence — un QR figé serait scannable après
/// coup depuis une photo, ce que la double preuve vise précisément à empêcher.
class SmartPresenceProfesseurScreen extends StatefulWidget {
  const SmartPresenceProfesseurScreen({super.key});

  @override
  State<SmartPresenceProfesseurScreen> createState() =>
      _SmartPresenceProfesseurScreenState();
}

class _SmartPresenceProfesseurScreenState
    extends State<SmartPresenceProfesseurScreen> {
  AttendanceSessionDto? _session;
  List<AttendanceRecordDto> _pointages = const [];
  List<Map<String, dynamic>> _seancesDuJour = const [];

  bool _chargement = true;
  bool _action = false;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;
  Timer? _minuteur;

  /// Notifier pour le QR plein écran : le route recevra ce notifier et
  /// s'abonnera aux mises à jour du payload quand le minuteur tourne.
  final ValueNotifier<String?> _qrPayloadNotifier = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _qrPayloadNotifier.dispose();
    super.dispose();
  }

  ApiService get _api => context.read<ApiService>();

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final courante = await _api.getSessionCouranteProfesseur();
      if (!mounted) return;

      if (courante == null) {
        // Aucune séance ouverte : proposer celles du jour.
        final seances = await _api.getSeancesDuJour().catchError((_) => []);
        if (!mounted) return;
        setState(() {
          _session = null;
          _pointages = const [];
          _seancesDuJour = seances
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);
          _chargement = false;
        });
        _minuteur?.cancel();
        return;
      }

      final session = AttendanceSessionDto.fromJson(courante);
      final records = await _api
          .getRecords(session.sessionId)
          .catchError((_) => <dynamic>[]);
      if (!mounted) return;
      setState(() {
        _session = session;
        _pointages = records
            .whereType<Map<String, dynamic>>()
            .map(AttendanceRecordDto.fromJson)
            .toList();
        _chargement = false;
      });
      _qrPayloadNotifier.value = session.qrPayload;
      _programmerRafraichissement(session);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _chargement = false;
      });
    }
  }

  /// Recale le minuteur sur la durée de validité annoncée par le serveur.
  ///
  /// Une cadence figée en dur se désynchroniserait dès que le backend change
  /// `qrValiditeSecondes` — le QR affiché resterait périmé une partie du temps.
  void _programmerRafraichissement(AttendanceSessionDto session) {
    _minuteur?.cancel();
    if (session.statut != 'ACTIVE') return;
    final periode = session.qrValiditeSecondes.clamp(5, 120);
    _minuteur = Timer.periodic(
      Duration(seconds: periode),
      (_) => _rafraichirSilencieux(),
    );
  }

  /// Mise à jour sans écran de chargement : le QR resterait blanc à chaque
  /// cycle, et l'enseignant projette cet écran.
  Future<void> _rafraichirSilencieux() async {
    final session = _session;
    if (session == null || !mounted) return;
    try {
      final statut = await _api.getStatutSession(session.sessionId);
      final records = await _api
          .getRecords(session.sessionId)
          .catchError((_) => <dynamic>[]);
      if (!mounted) return;
      final maj = AttendanceSessionDto.fromJson(statut);
      setState(() {
        _session = maj;
        _pointages = records
            .whereType<Map<String, dynamic>>()
            .map(AttendanceRecordDto.fromJson)
            .toList();
      });
      _qrPayloadNotifier.value = maj.qrPayload;
      if (maj.statut != 'ACTIVE') _minuteur?.cancel();
    } catch (_) {
      // Un aléa réseau ne doit pas effacer l'écran projeté : la prochaine
      // itération réessaiera.
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return PagePortail(
      titre: 'Smart Présence',
      sousTitre: session?.coursTitre ?? 'Séance à double preuve',
      onRafraichir: _charger,
      actions: [
        if (session != null && session.statut == 'ACTIVE')
          IconButton(
            icon: const Icon(Icons.stop_circle_rounded),
            tooltip: 'Clore la séance',
            onPressed: _action ? null : _clore,
          ),
      ],
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: false,
        onReessayer: _charger,
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_message != null)
              BandeauMessage(
                message: _message!,
                succes: _messageSucces,
                onFermer: () => setState(() => _message = null),
              ),
            if (session == null)
              _choixSeance()
            else ...[
              _enTeteSession(session),
              const SizedBox(height: 16),
              if (session.statut == 'ACTIVE') ...[
                _carteQr(session),
                const SizedBox(height: 16),
              ],
              _kpiSession(session),
              const SizedBox(height: 20),
              const EnteteSection(
                titre: 'Pointages',
                icone: Icons.how_to_reg_rounded,
              ),
              if (_pointages.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Aucun étudiant n\'a encore pointé.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMutedOf(context)),
                  ),
                )
              else
                for (final pointage in _pointages) ...[
                  _CartePointage(pointage: pointage),
                  const SizedBox(height: 8),
                ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _choixSeance() {
    if (_seancesDuJour.isEmpty) {
      return CartePortail(
        child: Column(
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 40,
              color: AppTheme.textMutedOf(context),
            ),
            const SizedBox(height: 12),
            Text(
              'Aucune séance à ouvrir aujourd\'hui.',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Smart Présence s\'ouvre depuis une séance inscrite à votre '
              'horaire du jour.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EnteteSection(
          titre: 'Séances du jour',
          icone: Icons.today_rounded,
        ),
        for (final seance in _seancesDuJour) ...[
          CartePortail(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${seance['coursTitre'] ?? 'Séance'}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    seance['salleNom'],
                    seance['heureDebut'],
                    seance['promotionLibelle'],
                  ].where((v) => v != null && '$v'.isNotEmpty).join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _action ? null : () => _ouvrir(seance),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Ouvrir la séance'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _enTeteSession(AttendanceSessionDto session) {
    final actif = session.statut == 'ACTIVE';
    return CartePortail(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.coursTitre,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    session.salleNom,
                    session.promotionLibelle,
                    if (session.dateDebut != null)
                      formatDate(session.dateDebut, avecHeure: true),
                  ].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          Pastille(
            texte: actif ? 'En cours' : _libelleStatut(session.statut),
            couleur: actif ? AppTheme.statutVert : AppTheme.statutNavy,
            icone: actif ? Icons.circle_rounded : null,
          ),
        ],
      ),
    );
  }

  Widget _carteQr(AttendanceSessionDto session) {
    final charge = session.qrPayload;
    if (charge == null || charge.isEmpty) {
      return CartePortail(
        child: Text(
          'Le code de cette séance n\'est pas disponible. '
          'Rouvrez l\'écran ou vérifiez vos droits sur ce cours.',
          style: TextStyle(color: AppTheme.textSecondaryOf(context)),
        ),
      );
    }

    return CartePortail(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'À projeter — le code change toutes les '
                '${session.qrValiditeSecondes} s',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _ouvrirQrPleinEcran(session),
                child: Icon(
                  Icons.fullscreen_rounded,
                  size: 20,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fond blanc et marge imposés : un QR posé sur la surface ardoise du
          // thème sombre n'est pas décodable par une caméra.
          GestureDetector(
            onTap: () => _ouvrirQrPleinEcran(session),
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: QrImageView(
                data: charge,
                size: 240,
                backgroundColor: Colors.white,
                // Correction élevée : le code est lu de loin, souvent de biais,
                // sur un vidéoprojecteur mal réglé.
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiSession(AttendanceSessionDto session) {
    return RangeeKpi(
      tuiles: [
        TuileKpi(
          icone: Icons.check_circle_rounded,
          valeur: '${session.presents}',
          libelle: 'Présents',
          detail: 'sur ${session.totalAttendus}',
          couleur: AppTheme.statutVert,
        ),
        TuileKpi(
          icone: Icons.schedule_rounded,
          valeur: '${session.retards}',
          libelle: 'Retards',
          couleur: AppTheme.statutOrange,
        ),
        TuileKpi(
          icone: Icons.cancel_rounded,
          valeur: '${session.absents}',
          libelle: 'Absents',
          couleur: AppTheme.statutRouge,
        ),
        TuileKpi(
          icone: Icons.warning_amber_rounded,
          valeur: '${session.verificationsRequises}',
          libelle: 'À vérifier',
          detail: '${session.tentativesRefusees} refus',
          couleur: AppTheme.statutViolet,
        ),
      ],
    );
  }

  void _ouvrirQrPleinEcran(AttendanceSessionDto session) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, navigation) => _QrPleinEcran(
          session: session,
          payloadNotifier: _qrPayloadNotifier,
          validiteSecondes: session.qrValiditeSecondes,
        ),
        transitionsBuilder: (context, animation, navigation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  static String _libelleStatut(String code) => switch (code) {
        'FERMEE' => 'Close',
        'EXPIREE' => 'Expirée',
        _ => code,
      };

  Future<void> _ouvrir(Map<String, dynamic> seance) async {
    final coursId = seance['coursId'];
    if (coursId is! int) {
      setState(() {
        _message = 'Cette séance n\'est pas rattachée à un cours identifiable.';
        _messageSucces = false;
      });
      return;
    }

    setState(() => _action = true);
    try {
      // La position n'est pas obligatoire : elle sert d'indice de proximité
      // pour les scans à venir. Un refus de permission, ou un GPS coupé, ne
      // doit jamais empêcher d'ouvrir la séance.
      ProximityProofRequest? contexte;
      try {
        contexte = await context.read<PresenceContexteService>().contextePresence();
      } catch (_) {
        contexte = null;
      }
      if (!mounted) return;

      await _api.demarrerSession(
        coursId,
        salleId: seance['salleId'] is int ? seance['salleId'] as int : null,
        horaireId: seance['horaireId'] is int ? seance['horaireId'] as int : null,
        latitude: contexte?.latitude,
        longitude: contexte?.longitude,
        precisionMetres: contexte?.precisionMetres,
      );
      if (!mounted) return;
      setState(() {
        _message = 'Séance ouverte.';
        _messageSucces = true;
      });
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
    } finally {
      if (mounted) setState(() => _action = false);
    }
  }

  Future<void> _clore() async {
    final session = _session;
    if (session == null) return;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clore la séance'),
        content: const Text(
          'Plus aucun étudiant ne pourra pointer. '
          'Les absents seront enregistrés comme tels.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Clore'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    setState(() => _action = true);
    try {
      await _api.fermerSession(session.sessionId);
      if (!mounted) return;
      setState(() {
        _message = 'Séance close.';
        _messageSucces = true;
      });
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
    } finally {
      if (mounted) setState(() => _action = false);
    }
  }
}

class _CartePointage extends StatelessWidget {
  final AttendanceRecordDto pointage;

  const _CartePointage({required this.pointage});

  @override
  Widget build(BuildContext context) {
    final (libelle, couleur) = switch (pointage.statut) {
      'PRESENT' => ('Présent', AppTheme.statutVert),
      'RETARD' => ('Retard', AppTheme.statutOrange),
      'REFUSE' => ('Refusé', AppTheme.statutRouge),
      'ABSENT' => ('Absent', AppTheme.statutRouge),
      _ => ('En attente', AppTheme.statutNavy),
    };

    return CartePortail(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${pointage.etudiantPrenom} ${pointage.etudiantNom}'.trim(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Pastille(texte: libelle, couleur: couleur),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _Preuve(
                actif: pointage.qrVerifie,
                libelle: 'QR',
                icone: Icons.qr_code_2_rounded,
              ),
              _Preuve(
                actif: pointage.proximiteVerifiee,
                libelle: 'Proximité',
                icone: Icons.wifi_tethering_rounded,
              ),
              if (pointage.distanceMetres != null)
                Text(
                  '${pointage.distanceMetres!.round()} m',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
              if (pointage.verifieA != null)
                Text(
                  formatDate(pointage.verifieA, avecHeure: true),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
            ],
          ),
          // Le motif est ce qui permet à l'enseignant de trancher : une
          // présence signalée sans sa raison ne lui apprend rien.
          if (pointage.verificationRequise &&
              (pointage.motifVerification ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'À vérifier : ${pointage.motifVerification}',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.accentLisible(context, AppTheme.warning),
              ),
            ),
          ],
          if ((pointage.motifRefus ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Refus : ${pointage.motifRefus}',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.accentLisible(context, AppTheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Preuve extends StatelessWidget {
  final bool actif;
  final String libelle;
  final IconData icone;

  const _Preuve({
    required this.actif,
    required this.libelle,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = actif
        ? AppTheme.accentLisible(context, AppTheme.statutVert)
        : AppTheme.textMutedOf(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 13, color: couleur),
        const SizedBox(width: 3),
        Text(libelle, style: TextStyle(fontSize: 11, color: couleur)),
      ],
    );
  }
}

/// Écran plein écran du QR tournant, destiné à la projection.
///
/// Le route reçoit le même [ValueNotifier] que le parent : à chaque fois que
/// le minuteur côté professeur régénère le payload, le QR se met à jour
/// automatiquement ici aussi, même en plein écran.
class _QrPleinEcran extends StatelessWidget {
  final AttendanceSessionDto session;
  final ValueNotifier<String?> payloadNotifier;
  final int validiteSecondes;

  const _QrPleinEcran({
    required this.session,
    required this.payloadNotifier,
    required this.validiteSecondes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // QR centré, blanc sur fond noir.
          Center(
            child: ValueListenableBuilder<String?>(
              valueListenable: payloadNotifier,
              builder: (context, payload, _) {
                if (payload == null || payload.isEmpty) {
                  return const Text(
                    'QR non disponible',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  );
                }
                return Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: QrImageView(
                    data: payload,
                    size: MediaQuery.of(context).size.shortestSide * 0.7,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                  ),
                );
              },
            ),
          ),
          // Bandeau info en haut.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.black54,
                child: ValueListenableBuilder<String?>(
                  valueListenable: payloadNotifier,
                  builder: (context, payload, _) {
                    final reste = payload != null ? 'Actif' : 'En attente…';
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'QR actif — change toutes les $validiteSecondes s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          reste,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // Bouton fermer en haut à droite.
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                tooltip: 'Quitter le plein écran',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
