import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/export_liste.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/commun_service.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../../data/models/professeur/professeur_models.dart';
import '../../../../data/services/professeur_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/portail_widgets.dart';
import 'contenu_cours_screen.dart';
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

/// Un créneau du cours : jour, heure, salle, vacation.
///
/// ─── D'OÙ VIENT UN CRÉNEAU ──────────────────────────────────────────────────
///
/// Deux tables peuvent en porter un, et elles ne se remplissent pas au même
/// moment :
///
///   · `horaire`        — l'emploi du temps proprement dit, celui que lisent la
///                        grille de l'étudiant, celle de la promotion et celle
///                        de l'enseignant. Il porte AUSSI la vacation.
///   · `cours_vacation` — la composition du programme d'une vacation. Son
///                        `professeur_id` est FACULTATIF à la création.
///
/// Cet écran n'interrogeait que la seconde, filtrée sur `professeur_id` :
/// quand le secrétaire compose la vacation sans désigner l'enseignant sur la
/// ligne — le cas ordinaire — la réponse est VIDE. Le bloc « Mes cours par
/// vacation » n'était alors pas rendu du tout (condition `isNotEmpty`), et
/// l'absence passait inaperçue : l'enseignant qui a pourtant un emploi du
/// temps ne voyait ni créneau ni vacation, sans rien qui le lui dise.
///
/// On lit donc les DEUX sources et on les fusionne, l'emploi du temps d'abord.
class Creneau {
  final String coursId;
  final String? jour;
  final String? heureDebut;
  final String? heureFin;
  final String? salle;
  final String? vacationId;
  final String? vacationNom;

  const Creneau({
    required this.coursId,
    this.jour,
    this.heureDebut,
    this.heureFin,
    this.salle,
    this.vacationId,
    this.vacationNom,
  });

  /// Deux lignes décrivent la même séance quand elles portent le même cours,
  /// le même jour et la même heure de début.
  String get cle => '$coursId|${jour ?? ''}|${heureDebut ?? ''}';

  String get libelleHoraire {
    final heures = [heureDebut, heureFin]
        .where((h) => h != null && h.isNotEmpty)
        .join('–');
    return [
      if (jour != null && jour!.isNotEmpty) libelleJour(jour!),
      if (heures.isNotEmpty) heures,
      if (salle != null && salle!.isNotEmpty) salle,
    ].join(' · ');
  }
}

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

  /// Créneaux fusionnés, indexés par identifiant de cours.
  ///
  /// La clé est normalisée en CHAÎNE : des deux côtés c'est un identifiant
  /// numérique, et un `Map` ne rapproche pas 12 de « 12 ».
  Map<String, List<Creneau>> _creneauxParCours = const {};

  /// Le type JOUR / SOIR se lit sur la vacation. L'emploi du temps n'en donne
  /// que le NOM : on l'indexe donc par id ET par nom, faute de quoi une séance
  /// d'horaire resterait sans vacation affichable.
  Map<String, String> _typeParVacationId = const {};
  Map<String, String> _typeParVacationNom = const {};

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
    final professeur = context.read<ProfesseurService>();
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

    // Créneaux : accessoires. Leur échec ne doit pas vider la liste des cours,
    // qui est l'information principale de l'écran.
    //
    // Chaque source est attendue SÉPARÉMENT : l'emploi du temps ne doit pas
    // disparaître parce que la liste des vacations a échoué, et inversement.
    // `catchError` ne conviendrait pas : ces méthodes rendent un type NON
    // nullable, et `(_) => null` ne compile pas. Un `try/catch` par source.
    List<JourPlanning>? planning;
    try {
      planning = await professeur.getPlanning(professeurId);
    } catch (_) {
      planning = null;
    }

    List<Fiche>? parVacation;
    try {
      parVacation = await service.coursParVacation(professeurId);
    } catch (_) {
      parVacation = null;
    }

    var vacations = <Fiche>[];
    if (universiteId != null) {
      try {
        vacations = await commun.vacationsActives(universiteId);
      } catch (_) {
        vacations = <Fiche>[];
      }
    }

    if (!mounted) return;

    final fusion = <String, List<Creneau>>{};
    final vus = <String>{};
    void ajouter(Creneau c) {
      if (c.coursId.isEmpty) return;
      if (!vus.add(c.cle)) return;
      fusion.putIfAbsent(c.coursId, () => []).add(c);
    }

    // 1. L'emploi du temps : la source principale.
    for (final jour in planning ?? const <JourPlanning>[]) {
      for (final seance in jour.seances) {
        if (seance.coursId == null) continue;
        ajouter(Creneau(
          coursId: '${seance.coursId}',
          jour: jour.jour,
          heureDebut: seance.heureDebut,
          heureFin: seance.heureFin,
          salle: seance.salle,
          vacationNom: seance.vacationNom,
        ));
      }
    }

    // 2. La composition des vacations, pour les lignes où l'enseignant EST
    //    désigné. Ce qui s'y trouve déjà au même jour et à la même heure n'est
    //    pas ajouté deux fois.
    for (final cv in parVacation ?? const <Fiche>[]) {
      final coursId = cv.texte('coursId');
      if (coursId.isEmpty) continue;
      ajouter(Creneau(
        coursId: coursId,
        jour: cv.texteOuNul('jour'),
        heureDebut: cv.texteOuNul('heureDebut'),
        heureFin: cv.texteOuNul('heureFin'),
        salle: cv.texteOuNul('salle'),
        vacationId: cv.texteOuNul('vacationId'),
        vacationNom: cv.texteOuNul('vacationNom'),
      ));
    }

    setState(() {
      _creneauxParCours = fusion;
      _typeParVacationId = {
        for (final v in vacations)
          if (v.id.isNotEmpty) v.id: v.texte('type'),
      };
      _typeParVacationNom = {
        for (final v in vacations)
          if (v.texte('nom').isNotEmpty) v.texte('nom'): v.texte('type'),
      };
    });

    if (planning == null && parVacation == null) {
      setState(() {
        _message = 'Vos créneaux n\'ont pas pu être chargés.';
        _messageSucces = false;
      });
    }
  }

  /// Type de vacation d'un créneau : par identifiant, sinon par nom.
  String? _typeVacation(Creneau c) {
    final parId = c.vacationId == null ? null : _typeParVacationId[c.vacationId];
    if (parId != null && parId.isNotEmpty) return parId;
    final parNom =
        c.vacationNom == null ? null : _typeParVacationNom[c.vacationNom];
    return parNom == null || parNom.isEmpty ? null : parNom;
  }

  /// Étiquette de vacation à afficher : « Jour » / « Soir » quand le type est
  /// connu, sinon le NOM de la vacation — mieux vaut « Vacation A » que rien.
  String? _libelleVacation(Creneau c) {
    final type = _typeVacation(c);
    if (type == 'JOUR') return 'Jour';
    if (type == 'SOIR') return 'Soir';
    final nom = c.vacationNom;
    return nom == null || nom.isEmpty ? null : nom;
  }

  List<Fiche> get _filtres {
    return _cours.where((c) {
      final terme = _recherche.toLowerCase();
      final correspond = terme.isEmpty ||
          c.texte('titre').toLowerCase().contains(terme) ||
          c.texte('code').toLowerCase().contains(terme);
      final statut = _filtreStatut == null || c.texte('statut') == _filtreStatut;
      final niveau = _filtreNiveau == null || c.texte('niveau') == _filtreNiveau;
      // Un cours est retenu dès qu'UN de ses créneaux est de la vacation
      // demandée : le même cours peut se donner en journée et en soirée.
      final vacation = _filtreVacation == null ||
          (_creneauxParCours[c.id] ?? const <Creneau>[])
              .any((cr) => _typeVacation(cr) == _filtreVacation);
      return correspond && statut && niveau && vacation;
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
                // Le bloc « Mes cours par vacation » a disparu : le créneau et
                // la vacation sont désormais portés par la ligne du cours
                // lui-même, et son filtre a rejoint cette barre. Une donnée,
                // un endroit — et surtout, un cours sans créneau se voit,
                // alors qu'un bloc rendu sous condition `isNotEmpty`
                // disparaissait en silence.
                FiltreDeroulant<String>(
                  libelle: 'Vacation',
                  valeur: _filtreVacation,
                  options: const [
                    DropdownMenuItem(value: null, child: Text('Toutes')),
                    DropdownMenuItem(value: 'JOUR', child: Text('Jour')),
                    DropdownMenuItem(value: 'SOIR', child: Text('Soir')),
                  ],
                  onChange: (v) => setState(() => _filtreVacation = v),
                ),
              ],
            ),
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
                  creneaux: _creneauxParCours[cours.id] ?? const [],
                  libelleVacation: _libelleVacation,
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

  /// Séances de ce cours, fusionnées depuis l'emploi du temps et la
  /// composition des vacations. Vide se DIT — c'est même le cas qu'il fallait
  /// rendre visible.
  final List<Creneau> creneaux;

  final String? Function(Creneau) libelleVacation;

  /// Nul quand la publication n'est pas offerte : rôle sans le droit, ou
  /// publication déjà en cours.
  final VoidCallback? onPublier;

  const _CarteCours({
    required this.cours,
    required this.creneaux,
    required this.libelleVacation,
    this.onPublier,
  });

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
          const SizedBox(height: 10),
          _BlocCreneaux(creneaux: creneaux, libelleVacation: libelleVacation),
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
                // Le contenu d'un cours appartient au cours : le web le
                // monte aussi sous `cours/:id/contenu`, pas au menu.
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
                // Le bouton « Suivi » a été RETIRÉ. Il ouvrait un tableau de
                // bord dont TOUTES les valeurs sont des zéros codés en dur
                // côté serveur : l'enseignant y lisait « 0 étudiant, 0 % » sur
                // un cours suivi et pouvait croire que personne ne le suivait.
                // Ce n'était pas un écran vide, c'était un écran faux. Le
                // suivi réel se lit sur les présences et sur « Travaux ».
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

/// Les créneaux d'un cours, sur sa carte.
///
/// Le VIDE est affiché, et c'est le point : quand cet écran n'interrogeait que
/// `cours_vacation`, un enseignant sans ligne nominative dans la composition
/// des vacations ne voyait ni créneau ni vacation, et rien ne le lui disait —
/// le bloc entier disparaissait. Il faut pouvoir constater qu'un cours n'a
/// aucune heure réservée : c'est une anomalie à signaler au secrétariat, pas
/// un détail à masquer.
class _BlocCreneaux extends StatelessWidget {
  final List<Creneau> creneaux;
  final String? Function(Creneau) libelleVacation;

  const _BlocCreneaux({required this.creneaux, required this.libelleVacation});

  @override
  Widget build(BuildContext context) {
    if (creneaux.isEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 15,
            color: AppTheme.textMutedOf(context),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Aucun créneau à l\'emploi du temps.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMutedOf(context),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final creneau in creneaux)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: AppTheme.iconAccent(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    creneau.libelleHoraire.isEmpty
                        ? 'Horaire non précisé'
                        : creneau.libelleHoraire,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ),
                if (libelleVacation(creneau) != null) ...[
                  const SizedBox(width: 6),
                  Pastille(
                    texte: libelleVacation(creneau)!,
                    couleur: libelleVacation(creneau) == 'Soir'
                        ? AppTheme.statutViolet
                        : AppTheme.statutVert,
                  ),
                ],
              ],
            ),
          ),
      ],
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

/// Jour en toutes lettres. L'emploi du temps rend un `DayOfWeek` Java
/// (« MONDAY ») ; la composition de vacation porte déjà un libellé. Un jour
/// inconnu est rendu tel quel plutôt qu'effacé.
String libelleJour(String code) => _joursFr[code.toUpperCase()] ?? code;
