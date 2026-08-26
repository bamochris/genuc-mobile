import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/formulaire_dynamique.dart';
import '../../../widgets/portail_widgets.dart';

/// Notes saisies pour un étudiant, avant envoi.
class _SaisieEtudiant {
  final String inscriptionId;
  final String nom;
  final String matricule;

  double? tp;
  double? interrogation;
  double? examen;

  _SaisieEtudiant({
    required this.inscriptionId,
    required this.nom,
    required this.matricule,
    this.tp,
    this.interrogation,
    this.examen,
  });

  /// Note finale indicative, avec la pondération 30 / 20 / 50 affichée par le
  /// portail web. Le calcul qui fait foi reste celui du serveur (le barème du
  /// cours peut être différent) : c'est une aide à la saisie, pas un résultat.
  double? get finale {
    if (tp == null || interrogation == null || examen == null) return null;
    return tp! * 0.3 + interrogation! * 0.2 + examen! * 0.5;
  }

  Map<String, dynamic> versJson(String professeurId) => {
        'inscriptionId': int.tryParse(inscriptionId) ?? inscriptionId,
        'noteTP': tp,
        'noteInterrogation': interrogation,
        'noteExamen': examen,
        'professeurId': professeurId,
      };
}

/// Encodage des notes d'un cours.
///
/// Reprend le comportement du portail web, y compris l'enregistrement
/// automatique cinq secondes après la dernière frappe : une session d'encodage
/// dure vingt minutes, et perdre la saisie sur un appel entrant est le
/// scénario le plus courant sur téléphone.
class SaisieNotesScreen extends StatefulWidget {
  const SaisieNotesScreen({super.key});

  @override
  State<SaisieNotesScreen> createState() => _SaisieNotesScreenState();
}

class _SaisieNotesScreenState extends State<SaisieNotesScreen> {
  Map<String, String> _cours = const {};
  String? _coursId;
  late String _annee = anneeAcademiqueCourante();

  List<_SaisieEtudiant> _etudiants = [];
  bool _chargement = true;
  bool _chargementEtudiants = false;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  Timer? _minuterieAutoEnregistrement;
  bool _enregistrementAuto = false;
  DateTime? _dernierEnregistrement;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _chargerCours());
  }

  @override
  void dispose() {
    _minuterieAutoEnregistrement?.cancel();
    super.dispose();
  }

  ProfesseurPedagogieService get _service =>
      context.read<ProfesseurPedagogieService>();

  String get _professeurId => context.read<AuthProvider>().user?.id ?? '';

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

  Future<void> _chargerEtudiants() async {
    final coursId = _coursId;
    if (coursId == null) {
      setState(() {
        _message = 'Sélectionnez d\'abord un cours.';
        _messageSucces = false;
      });
      return;
    }

    setState(() {
      _chargementEtudiants = true;
      _message = null;
    });

    try {
      final inscrits = await _service.etudiantsDuCours(coursId);
      final notes = await _service.notesDuCours(coursId, _annee);

      final parInscription = <String, Fiche>{
        for (final n in notes) n.texte('inscriptionId'): n,
      };

      if (!mounted) return;
      setState(() {
        _etudiants = inscrits.map((e) {
          final note = parInscription[e.id];
          return _SaisieEtudiant(
            inscriptionId: e.id,
            nom: [e.texte('prenom'), e.texte('nom')]
                .where((v) => v.isNotEmpty)
                .join(' '),
            matricule: e.texte('matricule'),
            tp: note?.decimalOuNul('noteTP'),
            interrogation: note?.decimalOuNul('noteInterrogation'),
            examen: note?.decimalOuNul('noteExamen'),
          );
        }).toList();
        _chargementEtudiants = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _etudiants = [];
        _chargementEtudiants = false;
        _message = e.message;
        _messageSucces = false;
      });
    }
  }

  void _programmerEnregistrementAuto() {
    _minuterieAutoEnregistrement?.cancel();
    _minuterieAutoEnregistrement = Timer(
      const Duration(seconds: 5),
      () => _enregistrer(automatique: true),
    );
  }

  Future<void> _enregistrer({bool automatique = false}) async {
    final coursId = _coursId;
    if (coursId == null || _etudiants.isEmpty) return;
    _minuterieAutoEnregistrement?.cancel();

    if (automatique) setState(() => _enregistrementAuto = true);

    try {
      await _service.enregistrerNotes(
        coursId: coursId,
        annee: _annee,
        notes: _etudiants.map((e) => e.versJson(_professeurId)).toList(),
      );
      if (!mounted) return;
      setState(() {
        _dernierEnregistrement = DateTime.now();
        _enregistrementAuto = false;
        if (!automatique) {
          _message = 'Toutes les notes ont été enregistrées.';
          _messageSucces = true;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _enregistrementAuto = false;
        // Même en enregistrement automatique, l'échec est signalé : silencieux,
        // il laisserait croire la saisie sauvegardée alors qu'elle ne l'est pas.
        _message = automatique
            ? 'Enregistrement automatique impossible : ${e.message}'
            : e.message;
        _messageSucces = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: 'Saisie des notes',
      sousTitre: 'Encodage par cours et année académique',
      onRafraichir: _chargerCours,
      floatingActionButton: _etudiants.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _enregistrer(),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Enregistrer'),
            ),
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _cours.isEmpty,
        onReessayer: _chargerCours,
        iconeVide: Icons.menu_book_rounded,
        messageVide: 'Aucun cours ne vous est attribué.',
        enfant: ListView(
          padding: Responsive.margePage(context).copyWith(bottom: 96),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_message != null)
              BandeauMessage(
                message: _message!,
                succes: _messageSucces,
                onFermer: () => setState(() => _message = null),
              ),
            _EtatEnregistrement(
              enCours: _enregistrementAuto,
              dernier: _dernierEnregistrement,
            ),
            SelecteurCours(
              valeur: _coursId,
              cours: _cours,
              onChange: (v) => setState(() {
                _coursId = v;
                _etudiants = [];
              }),
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
            const SizedBox(height: 12),
            LigneOuColonne(
              enfants: [
                ElevatedButton.icon(
                  onPressed: _chargementEtudiants ? null : _chargerEtudiants,
                  icon: const Icon(Icons.groups_rounded, size: 18),
                  label: Text(
                    _chargementEtudiants
                        ? 'Chargement…'
                        : 'Charger les étudiants',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_etudiants.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  _coursId == null
                      ? 'Sélectionnez un cours puis chargez ses étudiants.'
                      : 'Aucun étudiant chargé pour ce cours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else ...[
              EnteteSection(
                titre: '${_etudiants.length} étudiant'
                    '${_etudiants.length > 1 ? 's' : ''}',
                icone: Icons.edit_note_rounded,
              ),
              for (final etudiant in _etudiants) ...[
                _LigneSaisie(
                  etudiant: etudiant,
                  onChange: () {
                    setState(() {});
                    _programmerEnregistrementAuto();
                  },
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Bandeau discret de l'enregistrement automatique.
class _EtatEnregistrement extends StatelessWidget {
  final bool enCours;
  final DateTime? dernier;

  const _EtatEnregistrement({required this.enCours, required this.dernier});

  @override
  Widget build(BuildContext context) {
    if (!enCours && dernier == null) return const SizedBox.shrink();

    final heure = dernier == null
        ? ''
        : '${dernier!.hour.toString().padLeft(2, '0')}:'
            '${dernier!.minute.toString().padLeft(2, '0')}:'
            '${dernier!.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            enCours ? Icons.sync_rounded : Icons.check_circle_rounded,
            size: 15,
            color: AppTheme.accentLisible(
              context,
              enCours ? AppTheme.warning : AppTheme.success,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              enCours
                  ? 'Enregistrement automatique…'
                  : 'Enregistré automatiquement à $heure',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMutedOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne de saisie : trois notes sur 20 et le total indicatif.
///
/// Le tableau à six colonnes du web ne tient pas sur un téléphone : chaque
/// étudiant occupe une carte, ses trois champs sur une ligne qui passe en
/// colonne quand la largeur manque.
class _LigneSaisie extends StatelessWidget {
  final _SaisieEtudiant etudiant;
  final VoidCallback onChange;

  const _LigneSaisie({required this.etudiant, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final finale = etudiant.finale;

    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etudiant.nom,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      etudiant.matricule,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMutedOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Pastille(
                texte: finale == null
                    ? '—'
                    : '${finale.toStringAsFixed(2)}/20',
                couleur: finale == null
                    ? AppTheme.statutNavy
                    : (finale >= 10 ? AppTheme.statutVert : AppTheme.statutRouge),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LigneOuColonne(
            espacement: 10,
            seuil: 420,
            enfants: [
              _ChampNote(
                libelle: 'TP',
                valeur: etudiant.tp,
                onChange: (v) {
                  etudiant.tp = v;
                  onChange();
                },
              ),
              _ChampNote(
                libelle: 'Interro',
                valeur: etudiant.interrogation,
                onChange: (v) {
                  etudiant.interrogation = v;
                  onChange();
                },
              ),
              _ChampNote(
                libelle: 'Examen',
                valeur: etudiant.examen,
                onChange: (v) {
                  etudiant.examen = v;
                  onChange();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChampNote extends StatefulWidget {
  final String libelle;
  final double? valeur;
  final ValueChanged<double?> onChange;

  const _ChampNote({
    required this.libelle,
    required this.valeur,
    required this.onChange,
  });

  @override
  State<_ChampNote> createState() => _ChampNoteState();
}

class _ChampNoteState extends State<_ChampNote> {
  late final TextEditingController _controleur = TextEditingController(
    text: widget.valeur?.toString() ?? '',
  );

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controleur,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: '${widget.libelle} /20',
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: (texte) {
        if (texte.trim().isEmpty) {
          widget.onChange(null);
          return;
        }
        final valeur = double.tryParse(texte.replaceAll(',', '.'));
        // Une note hors 0–20 n'est pas transmise : le serveur la refuserait en
        // bloc, et toute la session d'encodage serait perdue avec elle.
        if (valeur == null || valeur < 0 || valeur > 20) return;
        widget.onChange(valeur);
      },
    );
  }
}
