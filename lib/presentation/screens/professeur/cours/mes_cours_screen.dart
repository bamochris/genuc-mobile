import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/export_liste.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/commun_service.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/portail_widgets.dart';
import '../lms/lms_screens.dart';
import 'etudiants_cours_screen.dart';
import 'supports_screen.dart';

/// Statuts de cours et leurs couleurs, repris de `STATUT_STYLES`
/// (`pages/professeur/cours/MesCours.jsx`).
const Map<String, (String, Color, IconData)> statutsCours = {
  'PUBLIE': ('Publié', AppTheme.statutVert, Icons.check_circle_rounded),
  'EN_COURS': ('En cours', AppTheme.statutBleu, Icons.hourglass_bottom_rounded),
  'PLANIFIE': ('Planifié', AppTheme.statutOrange, Icons.schedule_rounded),
  'TERMINE': ('Terminé', AppTheme.statutNavy, Icons.check_circle_rounded),
  'BROUILLON': ('Brouillon', AppTheme.statutNavy, Icons.edit_rounded),
};

/// Volume horaire d'un cours, tel qu'il se lit sur une carte.
///
/// Deux chiffres, deux natures : le volume ANNUEL déclaré au programme
/// (« 60 h/an ») et les heures RÉSERVÉES chaque semaine à l'emploi du temps
/// (« 4 h/sem »), déduites des créneaux. Les deux sont montrés quand les deux
/// sont connus — ils ne disent pas la même chose, et l'écart entre eux est
/// justement ce qu'un enseignant veut voir.
///
/// Quand aucun n'est renseigné : « — h », jamais « 0 h ». Un zéro se lit « ce
/// cours n'a pas d'heures », ce qui est faux — il n'en a pas encore de
/// déclarées, et aucun créneau ne lui est réservé.
String libelleVolume(Fiche cours) {
  final parts = <String>[
    if (cours.entier('volumeHoraireAnnuel') > 0)
      '${cours.entier('volumeHoraireAnnuel')} h/an',
    if (cours.entier('heures') > 0) '${cours.entier('heures')} h/sem',
  ];
  return parts.isEmpty ? '— h' : parts.join(' · ');
}

/// Couleur par niveau (`NIVEAU_COLORS` côté web).
Color couleurNiveau(String niveau) => switch (niveau) {
      'L1' => AppTheme.statutBleu,
      'L2' => AppTheme.statutVert,
      'L3' => AppTheme.statutOrange,
      'M1' => AppTheme.statutViolet,
      'M2' => AppTheme.statutRouge,
      _ => AppTheme.statutNavy,
    };

/// Liste des cours attribués à l'enseignant.
///
/// Comme sur le web, aucune donnée de démonstration n'est affichée en cas
/// d'échec : un enseignant qui voit des cours inventés croit son affectation
/// faite, et peut y saisir des présences et des notes qui ne se rattachent à
/// rien.
class MesCoursProfesseurScreen extends StatefulWidget {
  const MesCoursProfesseurScreen({super.key});

  @override
  State<MesCoursProfesseurScreen> createState() =>
      _MesCoursProfesseurScreenState();
}

class _MesCoursProfesseurScreenState extends State<MesCoursProfesseurScreen> {
  List<Fiche> _cours = const [];
  List<Fiche> _coursVacation = const [];
  Map<String, String> _typeParVacation = const {};

  bool _chargement = true;
  bool _publication = false;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;
  String _recherche = '';
  String? _filtreStatut;
  String? _filtreNiveau;
  String? _filtreVacation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final auth = context.read<AuthProvider>();
    final service = context.read<ProfesseurPedagogieService>();
    final commun = context.read<CommunService>();
    final professeurId = auth.user?.id ?? '';
    final universiteId = auth.user?.universiteId;

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final cours = await service.mesCours(professeurId);
      if (!mounted) return;
      setState(() {
        _cours = cours;
        _chargement = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cours = const [];
        _erreur = e.message;
        _chargement = false;
      });
    }

    // Vacations : accessoire. Leur échec ne doit pas vider la liste des cours,
    // qui est l'information principale de l'écran.
    try {
      final parVacation = await service.coursParVacation(professeurId);
      final vacations = universiteId == null
          ? <Fiche>[]
          : await commun.vacationsActives(universiteId);
      if (!mounted) return;
      setState(() {
        _coursVacation = parVacation;
        _typeParVacation = {
          for (final v in vacations) v.id: v.texte('type'),
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _coursVacation = const []);
    }
  }

  List<Fiche> get _filtres {
    return _cours.where((c) {
      final terme = _recherche.toLowerCase();
      final correspond = terme.isEmpty ||
          c.texte('titre').toLowerCase().contains(terme) ||
          c.texte('code').toLowerCase().contains(terme);
      final statut = _filtreStatut == null || c.texte('statut') == _filtreStatut;
      final niveau = _filtreNiveau == null || c.texte('niveau') == _filtreNiveau;
      return correspond && statut && niveau;
    }).toList();
  }

  /// Le serveur n'ouvre `PATCH /api/cours/{id}/publier` qu'à PROFESSEUR et
  /// ADMIN_UNIVERSITE. Afficher le bouton à quelqu'un d'autre serait lui
  /// promettre une action qui reviendrait en 403.
  bool get _peutPublier {
    final role =
        (context.read<AuthProvider>().user?.role ?? '').toUpperCase();
    return role == 'PROFESSEUR' || role == 'ADMIN_UNIVERSITE';
  }

  Future<void> _publier(Fiche cours) async {
    final titre = cours.texte('titre', defaut: 'ce cours');
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.public_rounded, color: AppTheme.statutVert),
        title: const Text('Publier le cours'),
        content: Text(
          '« $titre » deviendra visible par les étudiants de sa promotion, '
          'avec ses leçons et ses supports.\n\n'
          'Vérifiez son contenu avant : la publication est immédiate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publier'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    setState(() {
      _publication = true;
      _message = null;
    });
    try {
      await context
          .read<ProfesseurPedagogieService>()
          .publierCours(cours.id);
      if (!mounted) return;
      setState(() {
        _message = '« $titre » est publié : les étudiants le voient.';
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
      if (mounted) setState(() => _publication = false);
    }
  }

  String? _sousTitreExport() {
    final parts = <String>[
      if (_filtreNiveau != null) 'Niveau $_filtreNiveau',
      if (_filtreStatut != null) 'Statut $_filtreStatut',
      if (_recherche.isNotEmpty) 'Recherche « $_recherche »',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final niveaux = _cours
        .map((c) => c.texte('niveau'))
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final statuts = _cours
        .map((c) => c.texte('statut'))
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final totalEtudiants =
        _cours.fold<int>(0, (s, c) => s + c.entier('nbEtudiants'));
    final publies =
        _cours.where((c) => c.texte('statut') == 'PUBLIE').length;
    final credits = _cours.fold<int>(0, (s, c) => s + c.entier('credits'));

    return PagePortail(
      titre: 'Mes cours',
      sousTitre: '${_cours.length} cours attribué${_cours.length > 1 ? 's' : ''}',
      onRafraichir: _charger,
      actions: [
        BoutonExportListe(
          titre: 'Mes cours',
          sousTitre: _sousTitreExport(),
          colonnes: [
            ColonneExport(
                libelle: 'Code', valeur: (l) => '${l['code'] ?? ''}'),
            ColonneExport(
                libelle: 'Cours', valeur: (l) => '${l['titre'] ?? ''}'),
            ColonneExport(
                libelle: 'Niveau', valeur: (l) => '${l['niveau'] ?? ''}'),
            ColonneExport(
                libelle: 'Promotion',
                valeur: (l) => '${l['promotionLibelle'] ?? l['promotion'] ?? ''}'),
            ColonneExport(
                libelle: 'Crédits',
                valeur: (l) => '${l['credits'] ?? ''}',
                aDroite: true),
            ColonneExport(
                libelle: 'Étudiants',
                valeur: (l) => '${l['nbEtudiants'] ?? ''}',
                aDroite: true),
            ColonneExport(
                libelle: 'Statut', valeur: (l) => '${l['statut'] ?? ''}'),
          ],
          // La liste TELLE QU'ELLE EST FILTREE : c'est ce que l'enseignant a
          // sous les yeux qu'il veut sur papier.
          lignes: _filtres.map((c) => c.donnees).toList(),
          compact: true,
        ),
      ],
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _cours.isEmpty,
        onReessayer: _charger,
        iconeVide: Icons.menu_book_rounded,
        messageVide: 'Aucun cours ne vous est attribué pour le moment.',
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_message != null) ...[
              BandeauMessage(
                message: _message!,
                succes: _messageSucces,
                onFermer: () => setState(() => _message = null),
              ),
              const SizedBox(height: 12),
            ],
            RangeeKpi(
              tuiles: [
                TuileKpi(
                  icone: Icons.menu_book_rounded,
                  valeur: '${_cours.length}',
                  libelle: 'Total cours',
                  couleur: AppTheme.statutBleu,
                ),
                TuileKpi(
                  icone: Icons.check_circle_rounded,
                  valeur: '$publies',
                  libelle: 'Cours publiés',
                  couleur: AppTheme.statutVert,
                ),
                TuileKpi(
                  icone: Icons.groups_rounded,
                  valeur: '$totalEtudiants',
                  libelle: 'Total étudiants',
                  couleur: AppTheme.statutOrange,
                ),
                TuileKpi(
                  icone: Icons.workspace_premium_rounded,
                  valeur: '$credits',
                  libelle: 'Total crédits',
                  couleur: AppTheme.statutViolet,
                ),
              ],
            ),
            const SizedBox(height: 20),
            BarreFiltres(
              indice: 'Titre, code du cours…',
              onRecherche: (v) => setState(() => _recherche = v),
              filtres: [
                FiltreDeroulant<String>(
                  libelle: 'Statut',
                  valeur: _filtreStatut,
                  options: [
                    const DropdownMenuItem(value: null, child: Text('Tous')),
                    for (final s in statuts)
                      DropdownMenuItem(
                        value: s,
                        child: Text(statutsCours[s]?.$1 ?? s),
                      ),
                  ],
                  onChange: (v) => setState(() => _filtreStatut = v),
                ),
                FiltreDeroulant<String>(
                  libelle: 'Niveau',
                  valeur: _filtreNiveau,
                  options: [
                    const DropdownMenuItem(value: null, child: Text('Tous')),
                    for (final n in niveaux)
                      DropdownMenuItem(value: n, child: Text(n)),
                  ],
                  onChange: (v) => setState(() => _filtreNiveau = v),
                ),
              ],
            ),
            if (_coursVacation.isNotEmpty) ...[
              _SectionVacations(
                coursVacation: _coursVacation,
                typeParVacation: _typeParVacation,
                filtre: _filtreVacation,
                onFiltre: (v) => setState(() => _filtreVacation = v),
              ),
              const SizedBox(height: 20),
            ],
            if (_filtres.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Aucun cours ne correspond à vos filtres.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else
              for (final cours in _filtres) ...[
                _CarteCours(
                  cours: cours,
                  onPublier: _peutPublier && !_publication
                      ? () => _publier(cours)
                      : null,
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _CarteCours extends StatelessWidget {
  final Fiche cours;

  /// Nul quand la publication n'est pas offerte : rôle sans le droit, ou
  /// publication déjà en cours.
  final VoidCallback? onPublier;

  const _CarteCours({required this.cours, this.onPublier});

  @override
  Widget build(BuildContext context) {
    final niveau = cours.texte('niveau');
    final statut = statutsCours[cours.texte('statut')] ??
        statutsCours['BROUILLON']!;
    final teinteNiveau = couleurNiveau(niveau);

    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (niveau.isNotEmpty)
                      Pastille(texte: niveau, couleur: teinteNiveau),
                    if (cours.texte('code').isNotEmpty)
                      Pastille(
                        texte: cours.texte('code'),
                        couleur: AppTheme.statutNavy,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pastille(
                texte: statut.$1,
                couleur: statut.$2,
                icone: statut.$3,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            cours.texte('titre', defaut: 'Cours sans titre'),
            // Le nom du cours est CE qu'on cherche dans la carte : il passe
            // devant la pastille de niveau et le code, qui ne servent qu'a
            // trancher entre deux homonymes.
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (cours.texte('description').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              cours.texte('description'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _Meta(
                icone: Icons.groups_rounded,
                texte: '${cours.entier('nbEtudiants')} étudiants',
                couleur: teinteNiveau,
              ),
              _Meta(
                icone: Icons.workspace_premium_rounded,
                texte: '${cours.entier('credits')} crédit'
                    '${cours.entier('credits') > 1 ? 's' : ''}',
                couleur: teinteNiveau,
              ),
              _Meta(
                icone: Icons.schedule_rounded,
                texte: libelleVolume(cours),
                couleur: teinteNiveau,
              ),
              // Un meme cours peut etre donne a plusieurs promotions ET
              // plusieurs filieres : la promotion seule ne dit pas de quelle
              // cohorte il s'agit.
              if (cours.texte('filiereNom').isNotEmpty)
                _Meta(
                  icone: Icons.account_tree_rounded,
                  texte: cours.texte('filiereNom'),
                  couleur: teinteNiveau,
                ),
              _Meta(
                icone: Icons.menu_book_rounded,
                // `promotionLibelle` est la clé réellement rendue par le
                // serveur ; `promotion` n'a jamais existé dans CoursResponse,
                // et la ligne affichait « — » sur tous les cours.
                texte: cours.texte('promotionLibelle',
                    alias: const ['promotion', 'annee'], defaut: '—'),
                couleur: teinteNiveau,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Un cours naît en BROUILLON et reste invisible à sa promotion
          // tant qu'il n'est pas publié. Le geste n'existait que sur le
          // web : l'enseignant qui travaille depuis son téléphone voyait la
          // pastille « Brouillon » sans aucun moyen d'en sortir.
          if (onPublier != null && cours.texte('statut') == 'BROUILLON') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPublier,
                icon: const Icon(Icons.public_rounded, size: 18),
                label: const Text('Publier le cours'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ce cours est encore un brouillon : vos étudiants ne le voient '
              'pas.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Divider(color: AppTheme.borderOf(context), height: 1),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EtudiantsCoursScreen(
                        coursId: cours.id,
                        titreCours: cours.texte('titre'),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.groups_rounded, size: 16),
                  label: const Text('Étudiants'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SupportsCoursScreen(
                        coursIdInitial: cours.id,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.folder_rounded, size: 16),
                  label: const Text('Supports'),
                ),
                // Le contenu en ligne et son suivi appartiennent au cours :
                // le web les monte aussi sous `cours/:id/…`, pas au menu.
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ContenuCoursScreen(
                        coursId: cours.id,
                        coursTitre: cours.texte('titre'),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.auto_stories_rounded, size: 16),
                  label: const Text('Contenu'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StatistiquesApprentissageScreen(
                        coursId: cours.id,
                        coursTitre: cours.texte('titre'),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.insights_rounded, size: 16),
                  label: const Text('Suivi'),
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
  final Color couleur;

  const _Meta({
    required this.icone,
    required this.texte,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 13, color: AppTheme.accentLisible(context, couleur)),
        const SizedBox(width: 5),
        Text(
          texte,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textMutedOf(context),
          ),
        ),
      ],
    );
  }
}

/// Cours de l'enseignant vus par vacation (jour / soir).
///
/// Une même promotion peut suivre le même cours en journée et en soirée : ce
/// bloc dit lequel des deux, ce que la liste principale ne distingue pas.
class _SectionVacations extends StatelessWidget {
  final List<Fiche> coursVacation;
  final Map<String, String> typeParVacation;
  final String? filtre;
  final ValueChanged<String?> onFiltre;

  const _SectionVacations({
    required this.coursVacation,
    required this.typeParVacation,
    required this.filtre,
    required this.onFiltre,
  });

  @override
  Widget build(BuildContext context) {
    final visibles = filtre == null
        ? coursVacation
        : coursVacation
            .where((cv) => typeParVacation[cv.texte('vacationId')] == filtre)
            .toList();

    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EnteteSection(
            titre: 'Mes cours par vacation',
            icone: Icons.brightness_4_rounded,
            action: FiltreDeroulant<String>(
              libelle: 'Vacation',
              valeur: filtre,
              options: const [
                DropdownMenuItem(value: null, child: Text('Toutes')),
                DropdownMenuItem(value: 'JOUR', child: Text('Jour')),
                DropdownMenuItem(value: 'SOIR', child: Text('Soir')),
              ],
              onChange: onFiltre,
            ),
          ),
          if (visibles.isEmpty)
            Text(
              'Aucun cours pour ce filtre de vacation.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMutedOf(context),
              ),
            )
          else
            for (final cv in visibles)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cv.texte('coursTitre'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (typeParVacation[cv.texte('vacationId')] != null)
                          Pastille(
                            texte:
                                typeParVacation[cv.texte('vacationId')] == 'JOUR'
                                    ? 'Jour'
                                    : 'Soir',
                            couleur:
                                typeParVacation[cv.texte('vacationId')] == 'JOUR'
                                    ? AppTheme.statutVert
                                    : AppTheme.statutViolet,
                          ),
                      ],
                    ),
                    Text(
                      [
                        cv.texte('vacationNom'),
                        '${_libelleJour(cv.texte('jour'))} ${cv.texte('heureDebut')}'
                            '–${cv.texte('heureFin')}',
                        if (cv.texte('salle').isNotEmpty) cv.texte('salle'),
                        cv.texte('promotionNom', defaut: '—'),
                      ].where((t) => t.trim().isNotEmpty).join(' · '),
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
    );
  }
}

const Map<String, String> _joursFr = {
  'MONDAY': 'Lundi',
  'TUESDAY': 'Mardi',
  'WEDNESDAY': 'Mercredi',
  'THURSDAY': 'Jeudi',
  'FRIDAY': 'Vendredi',
  'SATURDAY': 'Samedi',
  'SUNDAY': 'Dimanche',
};

String _libelleJour(String code) => _joursFr[code.toUpperCase()] ?? code;
