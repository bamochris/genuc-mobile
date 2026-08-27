import 'dart:typed_data';

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
import 'smart_presence_screen.dart';

/// Module « Présences » du portail enseignant : saisie manuelle, QR imprimé,
/// historique et statistiques.
///
/// Smart Présence (séance à double preuve) reste dans son propre écran : elle
/// n'a ni le même modèle de données ni le même cycle de vie que la feuille de
/// présence classique.

// ─────────────────────────────────────────────────────────────
// Saisie manuelle
// ─────────────────────────────────────────────────────────────

/// Feuille d'appel d'une séance : un cours, une date, la liste des inscrits.
///
/// Le serveur rend `{presences: [{etudiantId, nom, prenom, present, justifie,
/// presenceId}]}` ; l'écran repose sur cette forme et renvoie le lot complet.
class SaisiePresencesScreen extends StatefulWidget {
  const SaisiePresencesScreen({super.key});

  @override
  State<SaisiePresencesScreen> createState() => _SaisiePresencesScreenState();
}

class _SaisiePresencesScreenState extends State<SaisiePresencesScreen> {
  Map<String, String> _cours = const {};
  String? _coursId;
  String _date = dateIsoDuJour();

  List<Fiche> _lignes = const [];
  final Map<String, bool> _presents = {};
  bool _chargementCours = true;
  bool _chargementFeuille = false;
  bool _enregistrement = false;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _chargerCours());
  }

  Future<void> _chargerCours() async {
    final professeurId = context.read<AuthProvider>().user?.id ?? '';
    setState(() {
      _chargementCours = true;
      _erreur = null;
    });
    try {
      final cours = await context
          .read<ProfesseurPedagogieService>()
          .mesCours(professeurId);
      if (!mounted) return;
      setState(() {
        _cours = {
          for (final c in cours)
            c.id: c.texte('titre', alias: const ['nom', 'intitule'], defaut: '—'),
        };
        _chargementCours = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _chargementCours = false;
      });
    }
  }

  Future<void> _chargerFeuille() async {
    final coursId = _coursId;
    if (coursId == null) return;

    setState(() {
      _chargementFeuille = true;
      _message = null;
    });
    try {
      final tableau = await context
          .read<ProfesseurPedagogieService>()
          .tableauPresences(coursId, _date);
      if (!mounted) return;
      final lignes = tableau.liste('presences');
      setState(() {
        _lignes = lignes;
        _presents
          ..clear()
          ..addEntries(
            lignes.map(
              (l) => MapEntry(_cleEtudiant(l), l.booleen('present')),
            ),
          );
        _chargementFeuille = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lignes = const [];
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
        _chargementFeuille = false;
      });
    }
  }

  static String _cleEtudiant(Fiche ligne) =>
      ligne.texte('etudiantId', alias: const ['inscriptionId', 'id']);

  @override
  Widget build(BuildContext context) {
    final presents = _presents.values.where((p) => p).length;

    return PagePortail(
      titre: 'Saisie des présences',
      sousTitre: 'Feuille d\'appel',
      onRafraichir: _chargerCours,
      floatingActionButton: _lignes.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _enregistrement ? null : _enregistrer,
              icon: _enregistrement
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_enregistrement ? 'Envoi…' : 'Enregistrer'),
            ),
      corps: EtatRequete(
        chargement: _chargementCours,
        erreur: _erreur,
        vide: false,
        onReessayer: _chargerCours,
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
            CartePortail(
              child: Column(
                children: [
                  SelecteurCours(
                    valeur: _coursId,
                    cours: _cours,
                    onChange: (v) {
                      setState(() => _coursId = v);
                      _chargerFeuille();
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    readOnly: true,
                    controller: TextEditingController(text: _date),
                    decoration: const InputDecoration(
                      labelText: 'Date de la séance',
                      suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                    onTap: _choisirDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_chargementFeuille)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_coursId == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Choisissez un cours pour afficher la feuille d\'appel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else if (_lignes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Aucun étudiant inscrit à ce cours pour cette date.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$presents présent(s) sur ${_lignes.length}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _toutMarquer(true),
                    child: const Text('Tous présents'),
                  ),
                  TextButton(
                    onPressed: () => _toutMarquer(false),
                    child: const Text('Tous absents'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final ligne in _lignes) _LignePresence(
                ligne: ligne,
                present: _presents[_cleEtudiant(ligne)] ?? false,
                onChange: (v) => setState(
                  () => _presents[_cleEtudiant(ligne)] = v,
                ),
                onJustifier: ligne.texte('presenceId').isEmpty
                    ? null
                    : () => _justifier(ligne),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _choisirDate() async {
    final maintenant = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date) ?? maintenant,
      firstDate: DateTime(maintenant.year - 1),
      lastDate: maintenant,
      locale: const Locale('fr'),
    );
    if (choisie == null) return;
    setState(() => _date = choisie.toIso8601String().substring(0, 10));
    await _chargerFeuille();
  }

  void _toutMarquer(bool present) {
    setState(() {
      for (final ligne in _lignes) {
        _presents[_cleEtudiant(ligne)] = present;
      }
    });
  }

  Future<void> _enregistrer() async {
    final coursId = _coursId;
    if (coursId == null) return;

    setState(() => _enregistrement = true);
    try {
      final lot = _lignes
          .map((ligne) => {
                'etudiantId': _cleEtudiant(ligne),
                'present': _presents[_cleEtudiant(ligne)] ?? false,
                'date': _date,
              })
          .toList();
      await context
          .read<ProfesseurPedagogieService>()
          .saisirPresences(coursId: coursId, presences: lot);
      if (!mounted) return;
      setState(() {
        _message = 'Feuille d\'appel enregistrée.';
        _messageSucces = true;
      });
      await _chargerFeuille();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  Future<void> _justifier(Fiche ligne) async {
    try {
      await context
          .read<ProfesseurPedagogieService>()
          .justifierPresence(ligne.texte('presenceId'));
      if (!mounted) return;
      setState(() {
        _message = 'Absence justifiée.';
        _messageSucces = true;
      });
      await _chargerFeuille();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
    }
  }
}

class _LignePresence extends StatelessWidget {
  final Fiche ligne;
  final bool present;
  final ValueChanged<bool> onChange;
  final VoidCallback? onJustifier;

  const _LignePresence({
    required this.ligne,
    required this.present,
    required this.onChange,
    this.onJustifier,
  });

  @override
  Widget build(BuildContext context) {
    final justifie = ligne.booleen('justifie');
    final nom = [ligne.texte('prenom'), ligne.texte('nom')]
        .where((v) => v.isNotEmpty)
        .join(' ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CartePortail(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nom.isEmpty ? 'Étudiant' : nom,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (ligne.texte('matricule').isNotEmpty)
                    Text(
                      ligne.texte('matricule'),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMutedOf(context),
                      ),
                    ),
                ],
              ),
            ),
            if (justifie)
              const Pastille(
                texte: 'Justifiée',
                couleur: AppTheme.statutBleu,
              )
            else if (!present && onJustifier != null)
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                tooltip: 'Justifier l\'absence',
                onPressed: onJustifier,
              ),
            Switch(value: present, onChanged: onChange),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// QR de présence imprimable
// ─────────────────────────────────────────────────────────────

/// Génère le QR fixe d'une séance, destiné à être imprimé ou affiché.
///
/// **Ce n'est pas l'écran de projection.** Le code produit ici est une image
/// figée, sans preuve de proximité : photographié, il reste valable. Il rend
/// service quand la salle n'a ni réseau ni vidéoprojecteur, et rien d'autre.
/// La projection en séance, avec un code renouvelé toutes les quinze
/// secondes, appartient à [SmartPresenceProfesseurScreen] — l'écran y renvoie
/// désormais, parce que son ancien sous-titre « code à projeter » conduisait
/// les enseignants ici, devant un QR immobile.
class GenererQrScreen extends StatefulWidget {
  const GenererQrScreen({super.key});

  @override
  State<GenererQrScreen> createState() => _GenererQrScreenState();
}

class _GenererQrScreenState extends State<GenererQrScreen> {
  Map<String, String> _cours = const {};
  String? _coursId;
  Uint8List? _image;
  bool _chargement = true;
  bool _generation = false;
  String? _erreur;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _chargerCours());
  }

  Future<void> _chargerCours() async {
    final professeurId = context.read<AuthProvider>().user?.id ?? '';
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final cours = await context
          .read<ProfesseurPedagogieService>()
          .mesCours(professeurId);
      if (!mounted) return;
      setState(() {
        _cours = {
          for (final c in cours)
            c.id: c.texte('titre', alias: const ['nom'], defaut: '—'),
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
      titre: 'QR imprimable',
      sousTitre: 'Code fixe, à imprimer ou afficher en salle',
      onRafraichir: _chargerCours,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: false,
        onReessayer: _chargerCours,
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_message != null)
              BandeauMessage(
                message: _message!,
                succes: false,
                onFermer: () => setState(() => _message = null),
              ),
            _AiguillageSmartPresence(
              onOuvrir: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SmartPresenceProfesseurScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            CartePortail(
              child: SelecteurCours(
                valeur: _coursId,
                cours: _cours,
                onChange: (v) => setState(() {
                  _coursId = v;
                  _image = null;
                }),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _coursId == null || _generation ? null : _generer,
              icon: _generation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.qr_code_2_rounded),
              label: Text(_generation ? 'Génération…' : 'Générer le QR'),
            ),
            if (_image != null) ...[
              const SizedBox(height: 24),
              CartePortail(
                child: Column(
                  children: [
                    // Fond blanc imposé : un QR sur surface ardoise n'est pas
                    // décodable par la caméra en thème sombre.
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Image.memory(_image!, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _partager,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Ouvrir / imprimer'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generer() async {
    setState(() => _generation = true);
    try {
      final octets = await context
          .read<ProfesseurPedagogieService>()
          .genererQrPresence(_coursId!);
      if (!mounted) return;
      setState(() => _image = Uint8List.fromList(octets));
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _generation = false);
    }
  }

  Future<void> _partager() async {
    final image = _image;
    if (image == null) return;
    await Fichiers.enregistrerEtOuvrir(image, 'qr-presence.png');
  }
}

/// Renvoie vers l'écran de projection quand c'est lui qui est cherché.
///
/// Deux entrées de menu portent un QR ; celle-ci annonçait « code à
/// projeter » et rendait une image immobile. Plutôt que de laisser
/// l'enseignant conclure que la rotation du code est en panne, l'écran dit
/// laquelle des deux fait quoi.
class _AiguillageSmartPresence extends StatelessWidget {
  final VoidCallback onOuvrir;

  const _AiguillageSmartPresence({required this.onOuvrir});

  @override
  Widget build(BuildContext context) {
    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cast_rounded, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vous cherchez le code à projeter ?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Le code de cette page est fixe : il sert à être imprimé ou '
            'affiché en salle, et ne change jamais.\n\n'
            'Pour la projection en séance, ouvrez Smart Présence : le code y '
            'se renouvelle toutes les quinze secondes, ce qui rend une photo '
            'du tableau inutilisable.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOuvrir,
              icon: const Icon(Icons.fingerprint_rounded, size: 18),
              label: const Text('Ouvrir Smart Présence'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Historique et statistiques
// ─────────────────────────────────────────────────────────────

/// Séances déjà tenues, et taux d'assiduité qui s'en déduit.
///
/// Le web en fait deux pages ; elles lisent la même route
/// (`/api/professeur/presences/historique/{id}`) et l'une n'est que l'agrégat
/// de l'autre. Deux onglets, un seul chargement.
class HistoriquePresencesScreen extends StatefulWidget {
  /// Ouvre directement l'onglet des statistiques.
  final bool statistiques;

  const HistoriquePresencesScreen({super.key, this.statistiques = false});

  @override
  State<HistoriquePresencesScreen> createState() =>
      _HistoriquePresencesScreenState();
}

class _HistoriquePresencesScreenState extends State<HistoriquePresencesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _onglets = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.statistiques ? 1 : 0,
  );

  List<Fiche> _seances = const [];
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
    final professeurId = context.read<AuthProvider>().user?.id ?? '';
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final seances = await context
          .read<ProfesseurPedagogieService>()
          .historiquePresences(professeurId);
      if (!mounted) return;
      setState(() {
        _seances = seances;
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
      titre: 'Présences',
      sousTitre: 'Historique et assiduité',
      onRafraichir: _charger,
      bottomAppBar: TabBar(
        controller: _onglets,
        tabs: const [Tab(text: 'Historique'), Tab(text: 'Statistiques')],
      ),
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _seances.isEmpty,
        onReessayer: _charger,
        messageVide: 'Aucune séance enregistrée.',
        iconeVide: Icons.history_rounded,
        enfant: TabBarView(
          controller: _onglets,
          children: [_historique(), _statistiques()],
        ),
      ),
    );
  }

  Widget _historique() {
    return ListView.separated(
      padding: Responsive.margePage(context),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _seances.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final seance = _seances[i];
        final total = seance.entier('total', alias: const ['effectif']);
        final presents = seance.entier('presents');
        final taux = total == 0 ? 0.0 : presents / total;

        return CartePortail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      seance.texte(
                        'coursTitre',
                        alias: const ['cours', 'titre'],
                        defaut: 'Séance',
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    formatDate(seance.texteOuNul('date')),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMutedOf(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              BarreProgression(
                valeur: taux,
                libelle: '$presents présent(s) sur $total',
                couleur: taux >= 0.75
                    ? AppTheme.statutVert
                    : AppTheme.statutOrange,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statistiques() {
    // Agrégat par cours : le web affiche un tableau à quatre colonnes, ici une
    // carte par cours, pour rester lisible sur téléphone.
    final parCours = <String, (int, int)>{};
    for (final seance in _seances) {
      final cours = seance.texte(
        'coursTitre',
        alias: const ['cours'],
        defaut: 'Cours',
      );
      final total = seance.entier('total', alias: const ['effectif']);
      final presents = seance.entier('presents');
      final courant = parCours[cours] ?? (0, 0);
      parCours[cours] = (courant.$1 + presents, courant.$2 + total);
    }

    final totalPresents =
        parCours.values.fold<int>(0, (somme, v) => somme + v.$1);
    final totalAttendus =
        parCours.values.fold<int>(0, (somme, v) => somme + v.$2);
    final tauxGlobal =
        totalAttendus == 0 ? 0 : (totalPresents * 100 / totalAttendus).round();

    return ListView(
      padding: Responsive.margePage(context),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        RangeeKpi(
          tuiles: [
            TuileKpi(
              icone: Icons.percent_rounded,
              valeur: '$tauxGlobal %',
              libelle: 'Assiduité globale',
              couleur: tauxGlobal >= 75
                  ? AppTheme.statutVert
                  : AppTheme.statutOrange,
            ),
            TuileKpi(
              icone: Icons.event_available_rounded,
              valeur: '${_seances.length}',
              libelle: 'Séances tenues',
              couleur: AppTheme.statutBleu,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const EnteteSection(titre: 'Par cours', icone: Icons.menu_book_rounded),
        for (final entree in parCours.entries) ...[
          CartePortail(
            child: BarreProgression(
              valeur: entree.value.$2 == 0
                  ? 0
                  : entree.value.$1 / entree.value.$2,
              libelle: entree.key,
              couleur: AppTheme.statutBleu,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
