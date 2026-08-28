import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/models/professeur/professeur_models.dart';
import '../../../../data/services/professeur_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/portail_widgets.dart';

/// Emploi du temps hebdomadaire type de l'enseignant.
///
/// Le serveur renvoie la semaine GROUPÉE PAR JOUR, jours sans séance compris :
/// une semaine dont il manque le mercredi se lit comme une semaine où l'on n'a
/// pas vérifié le mercredi. On affiche donc les six jours, en indiquant
/// explicitement ceux qui sont libres.
///
/// Il n'y a pas de navigation « semaine précédente / suivante » : le serveur
/// rend la semaine TYPE, pas une semaine datée — le web avait des boutons qui
/// ne changeaient rien à l'affichage tout en affirmant le contraire.
class PlanningCoursScreen extends StatefulWidget {
  const PlanningCoursScreen({super.key});

  @override
  State<PlanningCoursScreen> createState() => _PlanningCoursScreenState();
}

/// Choix du sélecteur, alignés sur ceux de l'emploi du temps étudiant et de
/// `admin/GestionHoraires.jsx`.
///
/// `ANNUEL` n'est pas proposé : le demander ne rendrait que les cours portés
/// sur l'année, c'est-à-dire une grille amputée de tout le reste. La valeur
/// existe bien côté serveur, et un créneau annuel figure dans les deux
/// semestres — c'est le filtre qui n'aurait pas de sens, pas la donnée.
const Map<String, String> _semestres = {
  '': 'Toute l’année',
  'S1': 'Premier semestre',
  'S2': 'Second semestre',
};

class _PlanningCoursScreenState extends State<PlanningCoursScreen> {
  static const Map<String, String> _jours = {
    'MONDAY': 'Lundi',
    'TUESDAY': 'Mardi',
    'WEDNESDAY': 'Mercredi',
    'THURSDAY': 'Jeudi',
    'FRIDAY': 'Vendredi',
    'SATURDAY': 'Samedi',
  };

  List<JourPlanning> _planning = const [];
  bool _chargement = true;
  String? _erreur;

  /// Semestre demandé au serveur. Vide = l'année entière.
  ///
  /// Aucun défaut n'est posé, et c'est délibéré : rien dans le référentiel ne
  /// déclare le semestre EN COURS — ni `annee_academique`, qui ne porte que le
  /// libellé et l'indicateur `active`, ni le calendrier académique, dont les
  /// types vont de la rentrée aux délibérations sans découpage semestriel. Le
  /// déduire de la date du jour masquerait des séances réelles sur une règle
  /// que personne n'a déclarée.
  String _semestre = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final professeurId = context.read<AuthProvider>().user?.id ?? '';
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final planning = await context
          .read<ProfesseurService>()
          .getPlanning(professeurId, semestre: _semestre);
      if (!mounted) return;
      setState(() {
        _planning = planning;
        _chargement = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _planning = const [];
        _erreur = e.message;
        _chargement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final aucuneSeance = _planning.every((j) => j.seances.isEmpty);

    return PagePortail(
      titre: 'Planning des cours',
      sousTitre: 'Emploi du temps hebdomadaire type',
      onRafraichir: _charger,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        // Une semaine vide n'escamote plus la page : le sélecteur de semestre
        // doit rester atteignable, sans quoi on ne pourrait plus revenir du
        // semestre qui vient de la vider.
        vide: false,
        onReessayer: _charger,
        iconeVide: Icons.calendar_month_rounded,
        messageVide: 'Aucun horaire n\'est enregistré pour vos cours.',
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _FiltreSemestre(
              choisi: _semestre,
              onChoisir: (valeur) {
                if (valeur == _semestre) return;
                setState(() => _semestre = valeur);
                _charger();
              },
            ),
            if (aucuneSeance)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  _semestre.isEmpty
                      ? 'Aucun horaire n\'est enregistré pour vos cours.'
                      : 'Aucune séance au '
                          '${_semestres[_semestre]!.toLowerCase()}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else
              for (final entree in _jours.entries) ...[
                _CarteJour(
                  libelle: entree.value,
                  seances: _seancesDe(entree.key),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  List<SeanceProfesseur> _seancesDe(String codeJour) {
    for (final jour in _planning) {
      if (jour.jour == codeJour) {
        final seances = [...jour.seances]
          ..sort((a, b) => (a.heureDebut ?? '').compareTo(b.heureDebut ?? ''));
        return seances;
      }
    }
    return const [];
  }
}

/// Sélecteur de semestre de la semaine type.
class _FiltreSemestre extends StatelessWidget {
  final String choisi;
  final ValueChanged<String> onChoisir;

  const _FiltreSemestre({required this.choisi, required this.onChoisir});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entree in _semestres.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(entree.value),
                  selected: choisi == entree.key,
                  onSelected: (_) => onChoisir(entree.key),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CarteJour extends StatelessWidget {
  final String libelle;
  final List<SeanceProfesseur> seances;

  const _CarteJour({required this.libelle, required this.seances});

  @override
  Widget build(BuildContext context) {
    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  libelle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Pastille(
                texte: seances.isEmpty
                    ? 'Libre'
                    : '${seances.length} séance${seances.length > 1 ? 's' : ''}',
                couleur: seances.isEmpty
                    ? AppTheme.statutNavy
                    : AppTheme.statutBleu,
              ),
            ],
          ),
          if (seances.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Aucune séance ce jour.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMutedOf(context),
                ),
              ),
            )
          else
            for (final seance in seances)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceAlt(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${seance.heureDebut ?? '—'}\n${seance.heureFin ?? ''}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  seance.code ?? seance.titre,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (seance.libelleSemestre != null) ...[
                                const SizedBox(width: 6),
                                Pastille(
                                  texte: seance.libelleSemestre!,
                                  couleur: AppTheme.statutViolet,
                                ),
                              ],
                            ],
                          ),
                          // La classe avant la salle : c'est elle qui distingue
                          // deux séances autrement identiques, quand la même
                          // promotion se donne en Jour et en Soir.
                          if (seance.libelleClasse.isNotEmpty)
                            Text(
                              seance.libelleClasse,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                          Text(
                            [
                              if (seance.salle.isNotEmpty) seance.salle,
                              '${seance.nbEtudiants} étudiants',
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMutedOf(context),
                            ),
                          ),
                        ],
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
