import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/fichiers.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';

/// Import de notes depuis un classeur Excel, en deux temps : analyser, puis
/// enregistrer.
///
/// L'import ENREGISTRE les lignes valides même quand d'autres échouent. Sur un
/// fichier de 200 notes dont 30 portent un matricule inconnu, l'enseignant
/// découvrait « 30 erreurs » après que les 170 autres soient passées en statut
/// « soumise » — sans savoir lesquelles, et sans pouvoir revenir en arrière.
/// L'analyse joue le même traitement sans rien écrire ; l'enregistrement n'est
/// proposé qu'après lecture du rapport.
class ImportNotesScreen extends StatefulWidget {
  const ImportNotesScreen({super.key});

  @override
  State<ImportNotesScreen> createState() => _ImportNotesScreenState();
}

class _ImportNotesScreenState extends State<ImportNotesScreen> {
  Map<String, String> _cours = const {};
  String? _coursId;
  late String _annee = anneeAcademiqueCourante();
  FichierChoisi? _fichier;

  Fiche? _rapport;

  /// Sélection sur laquelle le rapport a porté. Un rapport ne vaut que pour LE
  /// fichier, LE cours et L'année analysés : changer l'un des trois le périme.
  ({String coursId, String annee, String fichier})? _selectionAnalysee;

  bool _chargement = true;
  bool _traitement = false;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _chargerCours());
  }

  ProfesseurPedagogieService get _service =>
      context.read<ProfesseurPedagogieService>();

  String get _professeurId => context.read<AuthProvider>().user?.id ?? '';

  bool get _rapportPerime {
    final selection = _selectionAnalysee;
    if (selection == null) return false;
    return selection.coursId != _coursId ||
        selection.annee != _annee ||
        selection.fichier != _fichier?.nom;
  }

  Future<void> _chargerCours() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final cours = await _service.mesCours(_professeurId);
      if (!mounted) return;
      setState(() {
        _cours = {
          for (final c in cours)
            c.id: [c.texte('code'), c.texte('titre')]
                .where((v) => v.isNotEmpty)
                .join(' – '),
        };
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
      titre: 'Importer des notes',
      sousTitre: 'Classeur Excel (.xlsx, .xls)',
      onRafraichir: _chargerCours,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _cours.isEmpty,
        onReessayer: _chargerCours,
        iconeVide: Icons.menu_book_rounded,
        messageVide: 'Aucun cours ne vous est attribué.',
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
            SelecteurCours(
              valeur: _coursId,
              cours: _cours,
              onChange: (v) => setState(() => _coursId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _annee,
              decoration: const InputDecoration(
                labelText: 'Année académique',
                hintText: '2024-2025',
              ),
              onChanged: (v) => setState(() => _annee = v),
            ),
            const SizedBox(height: 16),
            CartePortail(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EnteteSection(
                    titre: 'Format attendu',
                    icone: Icons.info_rounded,
                  ),
                  Text(
                    '• Colonnes : MATRICULE, NOTE_TP, NOTE_INTERRO, '
                    'NOTE_EXAMEN, APPRECIATION\n'
                    '• Seul le MATRICULE est obligatoire, les notes sont '
                    'facultatives\n'
                    '• Le matricule doit correspondre exactement à celui du '
                    'système',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _telechargerModele,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Télécharger le modèle'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CartePortail(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EnteteSection(
                    titre: 'Fichier à importer',
                    icone: Icons.attach_file_rounded,
                  ),
                  if (_fichier != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '${_fichier!.nom} (${_fichier!.tailleLisible})',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.accentLisible(
                            context,
                            AppTheme.statutBleu,
                          ),
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _choisirFichier,
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: Text(
                      _fichier == null ? 'Choisir un fichier' : 'Changer',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _traitement ? null : _analyser,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(
                      _traitement ? 'Analyse en cours…' : 'Analyser le fichier',
                    ),
                  ),
                ],
              ),
            ),
            if (_rapport != null) ...[
              const SizedBox(height: 16),
              _CarteRapport(
                rapport: _rapport!,
                perime: _rapportPerime,
                traitement: _traitement,
                onConfirmer: _importer,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _choisirFichier() async {
    final fichier = await Fichiers.choisir(extensions: const ['xlsx', 'xls']);
    if (fichier == null || !mounted) return;
    setState(() {
      _fichier = fichier;
      // Changer de fichier invalide le rapport : sans cela, « Confirmer »
      // enregistrerait un fichier jamais analysé.
      _rapport = null;
      _selectionAnalysee = null;
    });
  }

  Future<void> _analyser() async {
    final coursId = _coursId;
    final fichier = _fichier;
    if (coursId == null || fichier == null) {
      setState(() {
        _message = 'Sélectionnez un cours et un fichier.';
        _messageSucces = false;
      });
      return;
    }

    setState(() {
      _traitement = true;
      _message = null;
      _rapport = null;
    });

    try {
      // `professeurId` retire : la route est bornee au cours et lit l'auteur
      // dans le jeton.
      final rapport = await _service.analyserFichierNotes(
        coursId: coursId,
        annee: _annee,
        cheminFichier: fichier.chemin,
        nomFichier: fichier.nom,
      );
      if (!mounted) return;
      setState(() {
        _rapport = rapport;
        _selectionAnalysee =
            (coursId: coursId, annee: _annee, fichier: fichier.nom);
        _traitement = false;
        _message = 'Analyse terminée — aucune note n\'a été enregistrée. '
            'Vérifiez le rapport avant de confirmer.';
        _messageSucces = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _traitement = false;
        _message = e.message;
        _messageSucces = false;
      });
    }
  }

  Future<void> _importer() async {
    final coursId = _coursId;
    final fichier = _fichier;
    if (coursId == null || fichier == null) return;

    setState(() => _traitement = true);
    try {
      final resultat = await _service.importerNotes(
        coursId: coursId,
        annee: _annee,
        cheminFichier: fichier.chemin,
        nomFichier: fichier.nom,
      );
      if (!mounted) return;
      setState(() {
        _rapport = resultat;
        _selectionAnalysee = null;
        _traitement = false;
        _message = 'Import terminé : les notes ont été enregistrées.';
        _messageSucces = true;
        _fichier = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _traitement = false;
        _message = e.message;
        _messageSucces = false;
      });
    }
  }

  Future<void> _telechargerModele() async {
    try {
      final octets = await _service.modeleImportNotes();
      await Fichiers.enregistrerEtOuvrir(octets, 'modele_import_notes.xlsx');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _messageSucces = false;
      });
    }
  }
}

class _CarteRapport extends StatelessWidget {
  final Fiche rapport;
  final bool perime;
  final bool traitement;
  final Future<void> Function() onConfirmer;

  const _CarteRapport({
    required this.rapport,
    required this.perime,
    required this.traitement,
    required this.onConfirmer,
  });

  @override
  Widget build(BuildContext context) {
    final simulation = rapport.booleen('simulation');
    final valides = rapport.entier('ligneImportees');
    final erreurs = rapport.entier('erreurs');
    final total = rapport.entier('totalLignes');
    final messages = rapport.listeTextes('erreursMessages');
    final resultats = rapport.liste('resultats');

    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EnteteSection(
            titre: simulation
                ? 'Rapport d\'analyse (aucune note enregistrée)'
                : 'Résultat de l\'import',
            icone: simulation ? Icons.search_rounded : Icons.task_alt_rounded,
          ),
          RangeeKpi(
            tuiles: [
              TuileKpi(
                icone: Icons.check_circle_rounded,
                valeur: '$valides',
                libelle: simulation ? 'Lignes valides' : 'Importées',
                couleur: AppTheme.statutVert,
              ),
              TuileKpi(
                icone: Icons.error_rounded,
                valeur: '$erreurs',
                libelle: 'Erreurs',
                couleur: AppTheme.statutRouge,
              ),
              TuileKpi(
                icone: Icons.list_alt_rounded,
                valeur: '$total',
                libelle: 'Lignes traitées',
                couleur: AppTheme.statutBleu,
              ),
            ],
          ),
          if (messages.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Détail des erreurs',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.accentLisible(context, AppTheme.error),
              ),
            ),
            const SizedBox(height: 6),
            for (final message in messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '• $message',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ),
              ),
          ],
          if (simulation) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderOf(context)),
              ),
              child: perime
                  ? Text(
                      'La sélection a changé depuis l\'analyse. '
                      'Relancez l\'analyse avant d\'enregistrer.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          erreurs > 0
                              ? '$erreurs ligne(s) seront ignorées. Les $valides '
                                  'lignes valides seront enregistrées en statut '
                                  '« soumise ».'
                              : 'Les $valides notes seront enregistrées en '
                                  'statut « soumise ».',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed:
                              traitement || valides == 0 ? null : onConfirmer,
                          icon: const Icon(Icons.upload_rounded, size: 18),
                          label: Text(
                            traitement
                                ? 'Enregistrement…'
                                : 'Confirmer et enregistrer',
                          ),
                        ),
                      ],
                    ),
            ),
          ],
          if (resultats.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              simulation
                  ? 'Notes qui seront enregistrées'
                  : 'Détail des notes importées',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TableauDefilant(
              entetes: const ['Matricule', 'Étudiant', 'Note', 'Mention'],
              largeurMin: 480,
              lignes: [
                for (final r in resultats.take(20))
                  [
                    Text(r.texte('matricule')),
                    Text(r.texte('nom')),
                    Text(r.texte('noteFinale')),
                    Text(r.texte('mention')),
                  ],
              ],
            ),
            if (resultats.length > 20)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '… et ${resultats.length - 20} autres',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Export des notes d'un cours vers un classeur Excel.
class ExportNotesScreen extends StatefulWidget {
  const ExportNotesScreen({super.key});

  @override
  State<ExportNotesScreen> createState() => _ExportNotesScreenState();
}

class _ExportNotesScreenState extends State<ExportNotesScreen> {
  Map<String, String> _cours = const {};
  String? _coursId;
  late String _annee = anneeAcademiqueCourante();

  bool _chargement = true;
  bool _export = false;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

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
      final cours =
          await context.read<ProfesseurPedagogieService>().mesCours(professeurId);
      if (!mounted) return;
      setState(() {
        _cours = {
          for (final c in cours)
            c.id: [c.texte('code'), c.texte('titre')]
                .where((v) => v.isNotEmpty)
                .join(' – '),
        };
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
      titre: 'Exporter les notes',
      sousTitre: 'Classeur Excel par cours et année',
      onRafraichir: _charger,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _cours.isEmpty,
        onReessayer: _charger,
        iconeVide: Icons.menu_book_rounded,
        messageVide: 'Aucun cours ne vous est attribué.',
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
            SelecteurCours(
              valeur: _coursId,
              cours: _cours,
              onChange: (v) => setState(() => _coursId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _annee,
              decoration: const InputDecoration(
                labelText: 'Année académique',
                hintText: '2024-2025',
              ),
              onChanged: (v) => _annee = v,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _export || _coursId == null ? null : _exporter,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(_export ? 'Export en cours…' : 'Exporter en Excel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exporter() async {
    final coursId = _coursId;
    if (coursId == null) return;

    setState(() => _export = true);
    try {
      final octets = await context
          .read<ProfesseurPedagogieService>()
          .exporterNotes(coursId, _annee);
      final code = _cours[coursId]?.split(' – ').first ?? coursId;
      await Fichiers.enregistrerEtOuvrir(octets, 'notes_${code}_$_annee.xlsx');
      if (!mounted) return;
      setState(() {
        _export = false;
        _message = 'Export terminé.';
        _messageSucces = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _export = false;
        _message = e.message;
        _messageSucces = false;
      });
    }
  }
}
