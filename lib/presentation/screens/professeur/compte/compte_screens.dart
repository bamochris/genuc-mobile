import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/portail_widgets.dart';
import '../../commun/ecran_ressource.dart';
import '../../etudiant/profil/security_settings_screen.dart';

/// Calendrier académique, contrats, évaluation reçue et paramètres : le
/// « Mon compte » du portail enseignant.

// ─────────────────────────────────────────────────────────────
// Calendrier académique
// ─────────────────────────────────────────────────────────────

class CalendrierScreen extends StatelessWidget {
  const CalendrierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final universiteId = context.read<AuthProvider>().user?.universiteId ?? '';

    return EcranRessource(
      titre: 'Calendrier académique',
      sousTitre: 'Sessions, congés et échéances',
      messageVide: 'Aucune date publiée pour cette année.',
      charger: () => service.calendrier(universiteId),
      description: DescriptionFiche(
        icone: Icons.event_note_rounded,
        titre: (f) => f.texte('titre', alias: const ['libelle'], defaut: 'Échéance'),
        sousTitre: (f) => f.texteOuNul('description'),
        statut: (f) => _statutPeriode(f),
        details: (f) => [
          LigneDetail(
            libelle: 'Du',
            valeur: formatDate(f.texteOuNul('dateDebut', alias: const ['date'])),
          ),
          if (f.texteOuNul('dateFin') != null)
            LigneDetail(
              libelle: 'Au',
              valeur: formatDate(f.texteOuNul('dateFin')),
            ),
          if (f.texte('type').isNotEmpty)
            LigneDetail(
              libelle: 'Type',
              valeur: f.texte('type').replaceAll('_', ' '),
            ),
        ],
      ),
    );
  }

  /// Situe la période par rapport à aujourd'hui : c'est la seule information
  /// que l'enseignant cherche en ouvrant ce calendrier.
  static (String, Color)? _statutPeriode(Fiche f) {
    final debut = f.date('dateDebut', alias: const ['date']);
    final fin = f.date('dateFin') ?? debut;
    if (debut == null) return null;

    final maintenant = DateTime.now();
    if (fin != null && fin.isBefore(maintenant)) {
      return ('Passé', AppTheme.statutNavy);
    }
    if (debut.isAfter(maintenant)) return ('À venir', AppTheme.statutBleu);
    return ('En cours', AppTheme.statutVert);
  }
}

// ─────────────────────────────────────────────────────────────
// Mes contrats
// ─────────────────────────────────────────────────────────────

class MesContratsScreen extends StatelessWidget {
  const MesContratsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();

    return EcranRessource(
      titre: 'Mes contrats',
      sousTitre: 'Engagements avec l\'établissement',
      messageVide: 'Aucun contrat enregistré.',
      charger: service.mesContrats,
      description: DescriptionFiche(
        icone: Icons.assignment_ind_rounded,
        titre: (f) => f.texte(
          'intitule',
          alias: const ['type', 'poste'],
          defaut: 'Contrat',
        ),
        sousTitre: (f) => f.texteOuNul('numeroContrat', alias: const ['numero']),
        statut: (f) => _statutContrat(f.texte('statut')),
        details: (f) => [
          LigneDetail(
            libelle: 'Période',
            valeur: [
              formatDate(f.texteOuNul('dateDebut')),
              formatDate(f.texteOuNul('dateFin')),
            ].where((d) => d != '—').join(' → '),
          ),
          if (f.decimalOuNul('salaireBrut', alias: const ['salaire']) != null)
            LigneDetail(
              libelle: 'Rémunération',
              valeur: formatMontant(
                f.decimal('salaireBrut', alias: const ['salaire']),
                f.texte('devise', defaut: 'USD'),
              ),
            ),
          if (f.texte('departement').isNotEmpty)
            LigneDetail(libelle: 'Département', valeur: f.texte('departement')),
        ],
      ),
    );
  }

  static (String, Color)? _statutContrat(String code) =>
      switch (code.toUpperCase()) {
        'ACTIF' || 'EN_COURS' => ('Actif', AppTheme.statutVert),
        'EXPIRE' || 'TERMINE' => ('Expiré', AppTheme.statutNavy),
        'SUSPENDU' => ('Suspendu', AppTheme.statutOrange),
        'RESILIE' => ('Résilié', AppTheme.statutRouge),
        '' => null,
        _ => (code.replaceAll('_', ' '), AppTheme.statutNavy),
      };
}

// ─────────────────────────────────────────────────────────────
// Mon évaluation
// ─────────────────────────────────────────────────────────────

/// Ce que les étudiants ont répondu sur mes enseignements.
///
/// Les commentaires sont anonymes côté serveur : l'écran n'affiche donc aucun
/// nom, même si la charge utile en portait un.
class MonEvaluationScreen extends StatefulWidget {
  const MonEvaluationScreen({super.key});

  @override
  State<MonEvaluationScreen> createState() => _MonEvaluationScreenState();
}

class _MonEvaluationScreenState extends State<MonEvaluationScreen> {
  List<Fiche> _evaluations = const [];
  bool _chargement = true;
  String? _erreur;

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
      final evaluations = await context
          .read<ProfesseurPedagogieService>()
          .monEvaluation(professeurId);
      if (!mounted) return;
      setState(() {
        _evaluations = evaluations;
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

  static const Map<String, String> _criteres = {
    'noteContenu': 'Contenu',
    'notePedagogie': 'Pédagogie',
    'noteDisponibilite': 'Disponibilité',
    'noteEvaluation': 'Équité',
  };

  @override
  Widget build(BuildContext context) {
    final moyennes = _moyennesParCritere();
    final globale = moyennes.isEmpty
        ? null
        : moyennes.values.reduce((a, b) => a + b) / moyennes.length;

    return PagePortail(
      titre: 'Mon évaluation',
      sousTitre: 'Retours anonymes des étudiants',
      onRafraichir: _charger,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _evaluations.isEmpty,
        onReessayer: _charger,
        messageVide: 'Aucune évaluation reçue pour le moment.',
        iconeVide: Icons.star_rounded,
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            RangeeKpi(
              tuiles: [
                TuileKpi(
                  icone: Icons.star_rounded,
                  valeur: globale == null ? '—' : globale.toStringAsFixed(1),
                  libelle: 'Moyenne générale',
                  detail: 'sur 5',
                  couleur: AppTheme.statutOrange,
                ),
                TuileKpi(
                  icone: Icons.rate_review_rounded,
                  valeur: '${_evaluations.length}',
                  libelle: 'Évaluations reçues',
                  couleur: AppTheme.statutBleu,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const EnteteSection(
              titre: 'Par critère',
              icone: Icons.insights_rounded,
            ),
            for (final entree in _criteres.entries) ...[
              CartePortail(
                child: BarreProgression(
                  // Les notes sont sur 5 : la barre attend une fraction.
                  valeur: (moyennes[entree.key] ?? 0) / 5,
                  libelle: '${entree.value} — '
                      '${(moyennes[entree.key] ?? 0).toStringAsFixed(1)} / 5',
                  couleur: AppTheme.statutBleu,
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
            const EnteteSection(
              titre: 'Commentaires',
              icone: Icons.forum_rounded,
            ),
            ..._commentaires(context),
          ],
        ),
      ),
    );
  }

  Map<String, double> _moyennesParCritere() {
    final resultat = <String, double>{};
    for (final cle in _criteres.keys) {
      final valeurs = _evaluations
          .map((e) => e.decimalOuNul(cle))
          .whereType<double>()
          .toList();
      if (valeurs.isNotEmpty) {
        resultat[cle] = valeurs.reduce((a, b) => a + b) / valeurs.length;
      }
    }
    return resultat;
  }

  List<Widget> _commentaires(BuildContext context) {
    final textes = _evaluations
        .map((e) => e.texte('commentaire'))
        .where((c) => c.isNotEmpty)
        .toList();

    if (textes.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Aucun commentaire écrit.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMutedOf(context)),
          ),
        ),
      ];
    }

    return [
      for (final texte in textes) ...[
        CartePortail(
          child: Text(
            texte,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

// ─────────────────────────────────────────────────────────────
// Paramètres
// ─────────────────────────────────────────────────────────────

/// Paramètres du compte enseignant : coordonnées, apparence, sécurité.
class ParametresProfesseurScreen extends StatefulWidget {
  const ParametresProfesseurScreen({super.key});

  @override
  State<ParametresProfesseurScreen> createState() =>
      _ParametresProfesseurScreenState();
}

class _ParametresProfesseurScreenState
    extends State<ParametresProfesseurScreen> {
  final _telephone = TextEditingController();
  final _adresse = TextEditingController();
  final _bureau = TextEditingController();

  bool _chargement = true;
  bool _enregistrement = false;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  String get _utilisateurId => context.read<AuthProvider>().user?.id ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _telephone.dispose();
    _adresse.dispose();
    _bureau.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final compte = await context
          .read<ProfesseurPedagogieService>()
          .monCompte(_utilisateurId);
      if (!mounted) return;
      setState(() {
        _telephone.text = compte.texte('telephone');
        _adresse.text = compte.texte('adresse');
        _bureau.text = compte.texte('bureau');
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
    final themeProvider = context.watch<ThemeProvider>();
    final user = context.read<AuthProvider>().user;

    return PagePortail(
      titre: 'Paramètres',
      sousTitre: 'Compte et apparence',
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
            CartePortail(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.nomComplet ?? 'Enseignant',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const EnteteSection(
              titre: 'Mes coordonnées',
              icone: Icons.contact_mail_rounded,
            ),
            CartePortail(
              child: Column(
                children: [
                  TextField(
                    controller: _telephone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _bureau,
                    decoration: const InputDecoration(labelText: 'Bureau'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _adresse,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Adresse'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const EnteteSection(titre: 'Apparence', icone: Icons.palette_rounded),
            CartePortail(
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Système'),
                    icon: Icon(Icons.brightness_auto_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Clair'),
                    icon: Icon(Icons.light_mode_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Sombre'),
                    icon: Icon(Icons.dark_mode_rounded, size: 16),
                  ),
                ],
                selected: {themeProvider.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (choix) =>
                    themeProvider.setThemeMode(choix.first),
              ),
            ),
            const SizedBox(height: 20),
            const EnteteSection(titre: 'Sécurité', icone: Icons.lock_rounded),
            CartePortail(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.shield_rounded),
                title: const Text('Mot de passe et double authentification'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SecuritySettingsScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
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
              label: Text(_enregistrement ? 'Enregistrement…' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enregistrer() async {
    setState(() => _enregistrement = true);
    try {
      await context.read<ProfesseurPedagogieService>().majMonCompte(
        _utilisateurId,
        {
          'telephone': _telephone.text.trim(),
          'adresse': _adresse.text.trim(),
          'bureau': _bureau.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _message = 'Coordonnées enregistrées.';
        _messageSucces = true;
      });
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
}
