import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/models/etudiant/seance_support.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/etudiant_academique_service.dart';
import '../../../../data/services/supports_cours.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/portail_widgets.dart';

/// Les supports déposés par les enseignants, rangés par cours de l'horaire.
///
/// Pendant de `etudiant/cours/SupportsEtudiant.jsx` sur le web. La liste part
/// des SÉANCES de l'inscription : c'est là que le support sert, et c'est le
/// seul rattachement qui existe entre un fichier déposé par un enseignant et
/// les étudiants qui le suivent. L'écran de détail d'un cours, lui, ne montre
/// que les cours publiés au catalogue en ligne — presque jamais ceux de
/// l'emploi du temps.
class SupportsEtudiantScreen extends StatefulWidget {
  /// Cours présélectionné quand on arrive depuis un créneau de l'horaire.
  final String? coursIdInitial;

  const SupportsEtudiantScreen({super.key, this.coursIdInitial});

  @override
  State<SupportsEtudiantScreen> createState() => _SupportsEtudiantScreenState();
}

/// Les mêmes libellés que la grille de l'horaire.
const Map<String, String> _semestres = {
  '': 'Toute l’année',
  'S1': 'Premier semestre',
  'S2': 'Second semestre',
};

const Map<String, String> _jours = {
  'MONDAY': 'Lundi',
  'TUESDAY': 'Mardi',
  'WEDNESDAY': 'Mercredi',
  'THURSDAY': 'Jeudi',
  'FRIDAY': 'Vendredi',
  'SATURDAY': 'Samedi',
  'SUNDAY': 'Dimanche',
};

class _SupportsEtudiantScreenState extends State<SupportsEtudiantScreen> {
  List<Fiche> _cours = const [];
  bool _chargement = true;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  /// Semestre demandé au serveur. Vide = toute l'année.
  String _semestre = '';

  /// Filtre local : ne montrer qu'un cours, quand on vient de l'horaire.
  late String? _coursFiltre = widget.coursIdInitial;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final inscriptionId = context.read<AuthProvider>().user?.inscriptionId;
    // Le service est saisi AVANT le premier `await` : passé celui-ci, le widget
    // peut avoir quitté l'arbre et le contexte n'est plus lisible.
    final academique = context.read<EtudiantAcademiqueService>();

    if (inscriptionId == null || inscriptionId.isEmpty) {
      setState(() {
        _chargement = false;
        _erreur = 'Aucune inscription active n\'est rattachée à votre compte.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final cours = await academique.supportsDeMesCours(
        inscriptionId,
        semestre: _semestre,
      );
      if (!mounted) return;
      setState(() {
        _cours = cours;
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

  Future<void> _ouvrir(Fiche support) async {
    final academique = context.read<EtudiantAcademiqueService>();
    setState(() {
      _message = 'Ouverture de « ${support.texte('titre', defaut: 'support')} »…';
      _messageSucces = true;
    });
    try {
      await academique.ouvrirSupport(support);
      if (mounted) setState(() => _message = null);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _messageSucces = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final affiches = _coursFiltre == null
        ? _cours
        : _cours.where((c) => c.texte('coursId') == _coursFiltre).toList();

    final total = affiches.fold<int>(
      0,
      (n, c) => n + c.liste('supports').length,
    );

    return PagePortail(
      titre: 'Supports de cours',
      sousTitre: 'Déposés par vos enseignants pour vos séances',
      onRafraichir: _charger,
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
            _FiltreSemestre(
              choisi: _semestre,
              onChoisir: (v) {
                if (v == _semestre) return;
                setState(() => _semestre = v);
                _charger();
              },
            ),
            if (_coursFiltre != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CartePortail(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Affichage limité au cours choisi depuis votre horaire.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _coursFiltre = null),
                        child: const Text('Tout voir'),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '$total support${total > 1 ? 's' : ''} · '
                '${affiches.length} cours',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMutedOf(context),
                ),
              ),
            ),
            if (affiches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  _cours.isEmpty
                      ? 'Aucune séance n\'est inscrite à votre horaire pour '
                          'cette période : sans séance, aucun support ne peut '
                          'vous être rattaché.'
                      : 'Ce cours ne figure pas à votre horaire.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else
              for (final cours in affiches) ...[
                _CarteCours(cours: cours, onOuvrir: _ouvrir),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

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

/// Un cours de l'horaire : ses créneaux, puis ses supports.
class _CarteCours extends StatelessWidget {
  final Fiche cours;
  final Future<void> Function(Fiche support) onOuvrir;

  const _CarteCours({required this.cours, required this.onOuvrir});

  @override
  Widget build(BuildContext context) {
    final supports = cours.liste('supports');
    final seances = cours.liste('seances');
    final code = cours.texte('coursCode');

    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cours.texte('coursTitre', defaut: 'Cours'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          Text(
            [
              if (code.isNotEmpty) code,
              cours.texte('professeurNom', defaut: 'Enseignant à désigner'),
            ].join(' · '),
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMutedOf(context),
            ),
          ),
          if (seances.isNotEmpty) ...[
            const SizedBox(height: 10),
            // Les créneaux : c'est ce qui dit QUAND ce support servira.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final seance in seances)
                  _Pastille(texte: _libelleSeance(seance)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (supports.isEmpty)
            Text(
              'Aucun support déposé pour ce cours à ce jour.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMutedOf(context),
              ),
            )
          else
            for (final support in supports)
              _LigneSupport(
                support: support,
                onOuvrir: () => onOuvrir(support),
              ),
        ],
      ),
    );
  }

  /// « Lundi 08:00 – 10:00 · Salle B12 »
  static String _libelleSeance(Fiche seance) {
    String hhmm(String cle) {
      final v = seance.texte(cle);
      return v.length >= 5 ? v.substring(0, 5) : v;
    }

    final jourBrut = seance.texte('jour');
    final creneau = [hhmm('heureDebut'), hhmm('heureFin')]
        .where((h) => h.isNotEmpty)
        .join(' – ');
    return [
      _jours[jourBrut] ?? jourBrut,
      creneau,
      seance.texte('salleNom'),
    ].where((v) => v.isNotEmpty).join(' · ');
  }
}

class _Pastille extends StatelessWidget {
  final String texte;

  const _Pastille({required this.texte});

  @override
  Widget build(BuildContext context) {
    // `pastilleDe` rend le couple (fond, texte) : c'est le fond teinté, et non
    // la carte nue, que le texte doit franchir. Les calculer séparément est ce
    // qui laissait passer des étiquettes à 3,2:1 en thème sombre.
    final (fond, texteCouleur) = AppTheme.pastilleDe(context, AppTheme.statutBleu);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: texteCouleur,
        ),
      ),
    );
  }
}

class _LigneSupport extends StatelessWidget {
  final Fiche support;
  final VoidCallback onOuvrir;

  const _LigneSupport({required this.support, required this.onOuvrir});

  @override
  Widget build(BuildContext context) {
    final type = support.texte('type', defaut: 'DOCUMENT');
    final description = support.texte('description');
    final creeLe = support.date('creeLe');
    final taille = support.donnees['tailleOctets'];
    final seance = SeanceSupport.depuis(support);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onOuvrir,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            IconePlaque(
              icone: _icone(type),
              couleur: AppTheme.statutBleu,
              taille: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    support.texte(
                      'titre',
                      alias: const ['nomFichierOriginal'],
                      defaut: 'Support',
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                  Text(
                    [
                      type,
                      if (taille is num) _tailleLisible(taille.toInt()),
                      if (creeLe != null) formatDateObjet(creeLe),
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMutedOf(context),
                    ),
                  ),
                  // Jusqu'ou l'enseignant est alle dans ce document.
                  //
                  // L'etudiant voit la borne ET peut lire tout le fichier : le
                  // lecteur du telephone ouvre le PDF entier. C'est dit en
                  // toutes lettres, parce qu'une borne sans explication se lit
                  // comme une interdiction.
                  if (seance != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Séance en cours : pages ${seance.debut} à ${seance.fin}'
                      '${seance.nombrePages != null ? ' sur ${seance.nombrePages}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.statutBleu,
                      ),
                    ),
                    Text(
                      'Vous pouvez lire tout le document ; au-delà de la page '
                      "${seance.fin}, cela n'a pas encore été enseigné.",
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMutedOf(context),
                      ),
                    ),
                    if (seance.pourcentage != null) ...[
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: seance.pourcentage! / 100,
                          minHeight: 5,
                          backgroundColor:
                              AppTheme.textMutedOf(context).withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            Icon(
              Icons.download_rounded,
              size: 20,
              color: AppTheme.textMutedOf(context),
            ),
          ],
        ),
      ),
    );
  }

  static String _tailleLisible(int octets) {
    if (octets < 1024) return '$octets o';
    if (octets < 1024 * 1024) return '${(octets / 1024).round()} Ko';
    return '${(octets / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  static IconData _icone(String type) => switch (type) {
        'PDF' => Icons.picture_as_pdf_rounded,
        'VIDEO' => Icons.play_circle_rounded,
        'PPT' => Icons.slideshow_rounded,
        _ => Icons.description_rounded,
      };
}
