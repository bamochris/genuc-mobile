import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/etudiant_academique_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/etat_widgets.dart';
import '../../../widgets/portail_widgets.dart';

/// Emploi du temps de l'étudiant : cours de la semaine, examens et événements.
///
/// Le web (`etudiant/horaire/Horaire.jsx`) dessine une grille jours × créneaux
/// de 6 colonnes. Cette grille est illisible sur 360 px : les mêmes séances
/// sont donc groupées par jour, dans l'ordre du calendrier, et les trois vues
/// du web (semaine / examens / événements) deviennent trois onglets.
class HoraireScreen extends StatefulWidget {
  const HoraireScreen({super.key});

  @override
  State<HoraireScreen> createState() => _HoraireScreenState();
}

/// Ordre des jours tel qu'affiché par le portail web.
const List<String> _joursSemaine = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

const Map<String, String> _jourTraduction = {
  'MONDAY': 'Lundi',
  'TUESDAY': 'Mardi',
  'WEDNESDAY': 'Mercredi',
  'THURSDAY': 'Jeudi',
  'FRIDAY': 'Vendredi',
  'SATURDAY': 'Samedi',
  'SUNDAY': 'Dimanche',
};

class _HoraireScreenState extends State<HoraireScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _onglets = TabController(length: 3, vsync: this);

  List<Fiche> _horaires = const [];
  List<Fiche> _examens = const [];
  List<Fiche> _evenements = const [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final inscriptionId = context.read<AuthProvider>().user?.inscriptionId;
    if (inscriptionId == null || inscriptionId.isEmpty) {
      setState(() {
        _chargement = false;
        _erreur = 'Aucune inscription active : horaire indisponible.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    final service = context.read<EtudiantAcademiqueService>();
    try {
      // Les trois routes sont indépendantes : le web les charge en parallèle
      // et tolère l'échec de chacune (`.catch(() => [])`). Une salle d'examen
      // absente ne doit pas vider l'emploi du temps.
      final resultats = await Future.wait([
        service.horaire(inscriptionId).catchError((_) => <Fiche>[]),
        service.examens(inscriptionId).catchError((_) => <Fiche>[]),
        service.evenements(inscriptionId).catchError((_) => <Fiche>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _horaires = resultats[0];
        _examens = resultats[1];
        _evenements = resultats[2];
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

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: 'Mon horaire',
      sousTitre: 'Cours, examens et événements',
      onRafraichir: _charger,
      bottomAppBar: TabBar(
        controller: _onglets,
        tabs: const [
          Tab(text: 'Semaine'),
          Tab(text: 'Examens'),
          Tab(text: 'Événements'),
        ],
      ),
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: false,
        onReessayer: _charger,
        enfant: TabBarView(
          controller: _onglets,
          children: [
            _VueSemaine(seances: _horaires),
            _VueListe(
              fiches: _examens,
              icone: Icons.assignment_rounded,
              messageVide: 'Aucun examen programmé.',
              titre: (f) => f.texte(
                'titre',
                alias: const ['cours', 'coursTitre', 'nomCours'],
                defaut: 'Examen',
              ),
              sousTitre: (f) => [
                formatDate(f.texteOuNul('date')),
                f.texte('heure', alias: const ['heureDebut']),
                f.texte('salle'),
              ].where((v) => v.isNotEmpty && v != '—').join(' · '),
              detail: (f) {
                final coef = f.decimalOuNul('coefficient');
                return coef == null ? null : 'Coefficient ${coef.toStringAsFixed(0)}';
              },
              couleur: AppTheme.statutRouge,
            ),
            _VueListe(
              fiches: _evenements,
              icone: Icons.event_rounded,
              messageVide: 'Aucun événement à venir.',
              titre: (f) => f.texte('titre', defaut: 'Événement'),
              sousTitre: (f) => [
                formatDate(f.texteOuNul('date')),
                f.texte('heure'),
                f.texte('lieu'),
              ].where((v) => v.isNotEmpty && v != '—').join(' · '),
              detail: (f) => f.texteOuNul('description'),
              couleur: AppTheme.statutViolet,
            ),
          ],
        ),
      ),
    );
  }
}

/// Séances groupées par jour, dans l'ordre du calendrier.
class _VueSemaine extends StatelessWidget {
  final List<Fiche> seances;

  const _VueSemaine({required this.seances});

  @override
  Widget build(BuildContext context) {
    if (seances.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
          const EtatVide(
            icon: Icons.calendar_month_rounded,
            titre: 'Aucune séance à votre horaire.',
          ),
        ],
      );
    }

    final parJour = <String, List<Fiche>>{};
    for (final seance in seances) {
      final jour = seance.texte('jour', defaut: 'AUTRE').toUpperCase();
      parJour.putIfAbsent(jour, () => []).add(seance);
    }

    // Les jours inconnus (données incohérentes) sont rejetés en fin de liste
    // plutôt que masqués : une séance invisible est pire qu'une séance mal
    // placée.
    final jours = parJour.keys.toList()
      ..sort((a, b) {
        final ia = _joursSemaine.indexOf(a);
        final ib = _joursSemaine.indexOf(b);
        return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
      });

    for (final liste in parJour.values) {
      liste.sort((a, b) =>
          a.texte('heureDebut').compareTo(b.texte('heureDebut')));
    }

    return ListView(
      padding: Responsive.margePage(context),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final jour in jours) ...[
          EnteteSection(
            titre: _libelleJour(jour),
            icone: Icons.calendar_today_rounded,
          ),
          for (final seance in parJour[jour]!) ...[
            _CarteSeance(seance: seance),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  static String _libelleJour(String code) {
    return _jourTraduction[code] ?? code;
  }
}

class _CarteSeance extends StatelessWidget {
  final Fiche seance;

  const _CarteSeance({required this.seance});

  @override
  Widget build(BuildContext context) {
    final debut = seance.texte('heureDebut');
    final fin = seance.texte('heureFin');
    final creneau = [debut, fin].where((h) => h.isNotEmpty).join(' – ');
    final accent = AppTheme.accentLisible(context, AppTheme.statutBleu);

    return CartePortail(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 46,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seance.texte(
                    'coursTitre',
                    alias: const ['titre', 'cours', 'nomCours'],
                    defaut: 'Séance',
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (creneau.isNotEmpty)
                      _Meta(icone: Icons.schedule_rounded, texte: creneau),
                    if (seance.texte('salle').isNotEmpty)
                      _Meta(
                        icone: Icons.room_rounded,
                        texte: seance.texte('salle'),
                      ),
                    if (seance.texte('professeur').isNotEmpty)
                      _Meta(
                        icone: Icons.person_rounded,
                        texte: seance.texte('professeur'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icone;
  final String texte;

  const _Meta({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 13, color: AppTheme.textMutedOf(context)),
        const SizedBox(width: 4),
        Text(
          texte,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context)),
        ),
      ],
    );
  }
}

/// Liste simple (examens, événements) : même carte, contenu déclaré par
/// l'appelant.
class _VueListe extends StatelessWidget {
  final List<Fiche> fiches;
  final IconData icone;
  final String messageVide;
  final String Function(Fiche) titre;
  final String Function(Fiche) sousTitre;
  final String? Function(Fiche) detail;
  final Color couleur;

  const _VueListe({
    required this.fiches,
    required this.icone,
    required this.messageVide,
    required this.titre,
    required this.sousTitre,
    required this.detail,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    if (fiches.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
          EtatVide(icon: icone, titre: messageVide),
        ],
      );
    }

    return ListView.separated(
      padding: Responsive.margePage(context),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: fiches.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final fiche = fiches[i];
        final complement = detail(fiche);
        return CartePortail(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconePlaque(icone: icone, couleur: couleur, taille: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre(fiche),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sousTitre(fiche),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                    if (complement != null && complement.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        complement,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMutedOf(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
