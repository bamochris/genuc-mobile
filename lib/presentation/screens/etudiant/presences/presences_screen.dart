import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/etudiant_academique_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/portail_widgets.dart';

/// Assiduité de l'étudiant : synthèse chiffrée, filtres et justification.
///
/// Transposition de `etudiant/presences/Presences.jsx`. Le taux affiché est
/// recalculé côté client — le web fait de même : la route rend les pointages
/// bruts, pas leur agrégat.
class PresencesEtudiantScreen extends StatefulWidget {
  const PresencesEtudiantScreen({super.key});

  @override
  State<PresencesEtudiantScreen> createState() =>
      _PresencesEtudiantScreenState();
}

/// Les trois états qu'un pointage peut prendre côté web.
enum _Etat { present, retard, absent }

class _PresencesEtudiantScreenState extends State<PresencesEtudiantScreen> {
  List<Fiche> _presences = const [];
  bool _chargement = true;
  String? _erreur;

  String _coursFiltre = '';
  _Etat? _etatFiltre;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final inscriptionId = context.read<AuthProvider>().user?.inscriptionId;
    if (inscriptionId == null || inscriptionId.isEmpty) {
      setState(() {
        _chargement = false;
        _erreur = 'Aucune inscription active : présences indisponibles.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final presences =
          await context.read<EtudiantAcademiqueService>().presences(inscriptionId);
      if (!mounted) return;
      setState(() {
        _presences = presences;
        _chargement = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _chargement = false;
      });
    }
  }

  static _Etat _etatDe(Fiche p) {
    if (p.booleen('retard')) return _Etat.retard;
    return p.booleen('present') ? _Etat.present : _Etat.absent;
  }

  List<Fiche> get _filtrees => _presences.where((p) {
        if (_coursFiltre.isNotEmpty && p.texte('coursId') != _coursFiltre) {
          return false;
        }
        if (_etatFiltre != null && _etatDe(p) != _etatFiltre) return false;
        return true;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final total = _presences.length;
    final presents = _presences.where((p) => _etatDe(p) == _Etat.present).length;
    final retards = _presences.where((p) => _etatDe(p) == _Etat.retard).length;
    final absents = _presences.where((p) => _etatDe(p) == _Etat.absent).length;
    // Un retard reste une présence : c'est le calcul du portail web, et
    // compter le retard comme absence ferait chuter le taux sans motif.
    final taux = total == 0 ? 0 : ((presents + retards) * 100 / total).round();

    return PagePortail(
      titre: 'Mes présences',
      sousTitre: 'Assiduité et justificatifs',
      onRafraichir: _charger,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _presences.isEmpty,
        onReessayer: _charger,
        messageVide: 'Aucun pointage enregistré pour le moment.',
        iconeVide: Icons.fact_check_rounded,
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            RangeeKpi(
              tuiles: [
                TuileKpi(
                  icone: Icons.percent_rounded,
                  valeur: '$taux %',
                  libelle: 'Taux de présence',
                  couleur: taux >= 75 ? AppTheme.statutVert : AppTheme.statutOrange,
                ),
                TuileKpi(
                  icone: Icons.check_circle_rounded,
                  valeur: '$presents',
                  libelle: 'Présences',
                  couleur: AppTheme.statutVert,
                ),
                TuileKpi(
                  icone: Icons.schedule_rounded,
                  valeur: '$retards',
                  libelle: 'Retards',
                  couleur: AppTheme.statutOrange,
                ),
                TuileKpi(
                  icone: Icons.cancel_rounded,
                  valeur: '$absents',
                  libelle: 'Absences',
                  couleur: AppTheme.statutRouge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            BarreFiltres(
              filtres: [
                FiltreDeroulant<String>(
                  libelle: 'Cours',
                  valeur: _coursFiltre.isEmpty ? null : _coursFiltre,
                  options: [
                    const DropdownMenuItem(value: '', child: Text('Tous')),
                    ..._coursDisponibles.entries.map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChange: (v) => setState(() => _coursFiltre = v ?? ''),
                ),
                FiltreDeroulant<_Etat?>(
                  libelle: 'État',
                  valeur: _etatFiltre,
                  options: const [
                    DropdownMenuItem(value: null, child: Text('Tous')),
                    DropdownMenuItem(value: _Etat.present, child: Text('Présent')),
                    DropdownMenuItem(value: _Etat.retard, child: Text('Retard')),
                    DropdownMenuItem(value: _Etat.absent, child: Text('Absent')),
                  ],
                  onChange: (v) => setState(() => _etatFiltre = v),
                ),
              ],
            ),
            if (_filtrees.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Aucun pointage ne correspond à ces filtres.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else
              for (final presence in _filtrees) ...[
                _CartePresence(presence: presence, etat: _etatDe(presence)),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  /// Cours présents dans les pointages : la liste des cours de l'étudiant
  /// contiendrait des cours sans aucun pointage, donc des filtres qui ne
  /// rendent jamais rien.
  Map<String, String> get _coursDisponibles {
    final carte = <String, String>{};
    for (final p in _presences) {
      final id = p.texte('coursId');
      if (id.isEmpty) continue;
      carte[id] = p.texte(
        'coursTitre',
        alias: const ['coursCode', 'cours'],
        defaut: 'Cours $id',
      );
    }
    return carte;
  }

}

class _CartePresence extends StatelessWidget {
  final Fiche presence;
  final _Etat etat;

  const _CartePresence({required this.presence, required this.etat});

  @override
  Widget build(BuildContext context) {
    final justifie = presence.booleen('justifie');
    final (libelle, couleur) = switch (etat) {
      _Etat.present => ('Présent', AppTheme.statutVert),
      _Etat.retard => ('Retard', AppTheme.statutOrange),
      _Etat.absent => (
          justifie ? 'Absence justifiée' : 'Absent',
          justifie ? AppTheme.statutBleu : AppTheme.statutRouge,
        ),
    };

    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  presence.texte(
                    'coursTitre',
                    alias: const ['cours'],
                    defaut: 'Séance',
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Pastille(texte: libelle, couleur: couleur),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              // `PresenceResponse` nomme le champ `dateCours`, pas `date` :
              // on lit ce nom sous lequel le contrôleur `/api/presences/**`
              // (et désormais `/api/etudiant/portal/{id}/presences`) sérialise
              // le pointage.
              formatDate(presence.texteOuNul('dateCours', alias: const ['date'])),
              if (presence.texte('coursCode').isNotEmpty)
                presence.texte('coursCode'),
              if (presence.texte('heureArrivee').isNotEmpty)
                'arrivée ${presence.texte('heureArrivee')}',
            ].join(' · '),
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          // Le web propose ici un bouton « Justifier » qui appelle une route
          // interdite à l'étudiant : il ne peut que renvoyer 403. Plutôt qu'un
          // bouton qui échoue toujours, la marche à suivre réelle est
          // indiquée — c'est l'enseignant qui lève l'absence.
          if (etat == _Etat.absent && !justifie) ...[
            const SizedBox(height: 8),
            Text(
              'Justificatif à présenter à l\'enseignant du cours : '
              'lui seul peut lever l\'absence.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppTheme.textMutedOf(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
