import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/commun_service.dart';
import '../../../../data/services/etudiant_academique_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/portail_widgets.dart';
import '../demarches/demarches_screens.dart' show statutDemande;

/// Demande de réinscription pour l'année suivante.
///
/// Transposition de `etudiant/reinscription/Reinscription.jsx`. Le web
/// contrôle trois prérequis avant d'autoriser l'envoi — année ouverte, dossier
/// complet, dettes soldées — et les affiche un par un. Les reproduire ici est
/// le cœur de l'écran : sans eux, l'étudiant envoie une demande que le
/// secrétariat rejettera, sans savoir ce qui manquait.
class ReinscriptionScreen extends StatefulWidget {
  const ReinscriptionScreen({super.key});

  @override
  State<ReinscriptionScreen> createState() => _ReinscriptionScreenState();
}

class _ReinscriptionScreenState extends State<ReinscriptionScreen> {
  List<Fiche> _annees = const [];
  List<Fiche> _vacations = const [];
  List<Fiche> _documents = const [];
  Fiche? _demandeExistante;

  String? _anneeId;
  String? _vacationId;
  final _commentaire = TextEditingController();
  bool _declareBourse = false;

  bool _chargement = true;
  bool _envoi = false;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _commentaire.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final user = context.read<AuthProvider>().user;
    final inscriptionId = user?.inscriptionId ?? '';
    final universiteId = user?.universiteId ?? '';

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    final service = context.read<EtudiantAcademiqueService>();
    final commun = context.read<CommunService>();
    try {
      final demandes = await service.mesDemandes().catchError((_) => <Fiche>[]);
      final annees =
          await commun.anneesAcademiques().catchError((_) => <Fiche>[]);
      final vacations = universiteId.isEmpty
          ? <Fiche>[]
          : await commun
              .vacationsActives(universiteId)
              .catchError((_) => <Fiche>[]);
      final documents = inscriptionId.isEmpty
          ? <Fiche>[]
          : await service
              .documentsPersonnels(inscriptionId)
              .catchError((_) => <Fiche>[]);

      if (!mounted) return;
      setState(() {
        _annees = annees.where((a) => a.booleen('active', defaut: true)).toList();
        _vacations = vacations;
        _documents = documents;
        _demandeExistante = demandes
            .where((d) => d.texte('typeDemande') == 'REINSCRIPTION')
            .firstOrNull;
        _anneeId ??= _annees.isNotEmpty ? _annees.first.id : null;
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

  /// Solde restant dû, lu dans la situation financière déjà chargée par le
  /// portail : un second appel réseau pour une valeur déjà en mémoire.
  double get _soldeDu =>
      context.read<StudentProvider>().situationFinanciere?.totalReste ?? 0;

  bool get _dossierComplet => _documents.any(
        (d) => d.booleen('valide', alias: const ['approuve']) ||
            d.texte('statut').toUpperCase().startsWith('VALID'),
      );

  bool get _anneeOuverte => _annees.isNotEmpty;

  List<(String, bool)> get _prerequis => [
        ('Une année académique est ouverte à la réinscription', _anneeOuverte),
        ('Au moins une pièce de mon dossier est validée', _dossierComplet),
        ('Mes frais sont soldés', _soldeDu <= 0),
      ];

  bool get _peutEnvoyer =>
      _demandeExistante == null &&
      _anneeId != null &&
      _prerequis.every((p) => p.$2);

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: 'Réinscription',
      sousTitre: 'Demander mon inscription pour l\'année suivante',
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

            if (_demandeExistante != null) ...[
              CartePortail(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Demande déjà introduite',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        ?_pastilleStatut(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LigneDetail(
                      libelle: 'Numéro',
                      valeur: _demandeExistante!.texte('numeroDemande'),
                    ),
                    LigneDetail(
                      libelle: 'Introduite le',
                      valeur: formatDate(
                        _demandeExistante!.texteOuNul(
                          'creeLe',
                          alias: const ['dateCreation'],
                        ),
                      ),
                    ),
                    if (_demandeExistante!.texte('commentaireFinal').isNotEmpty)
                      LigneDetail(
                        libelle: 'Réponse',
                        valeur: _demandeExistante!.texte('commentaireFinal'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            const EnteteSection(
              titre: 'Conditions à remplir',
              icone: Icons.checklist_rounded,
            ),
            CartePortail(
              child: Column(
                children: [
                  for (final (libelle, rempli) in _prerequis)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Icon(
                            rempli ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 18,
                            color: AppTheme.accentLisible(
                              context,
                              rempli ? AppTheme.statutVert : AppTheme.statutRouge,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              libelle,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondaryOf(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_soldeDu > 0) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Reste dû : ${formatMontant(_soldeDu)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              AppTheme.accentLisible(context, AppTheme.error),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            const EnteteSection(
              titre: 'Ma demande',
              icone: Icons.edit_rounded,
            ),
            CartePortail(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _anneeId,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Année académique *'),
                    items: _annees
                        .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                a.texte('libelle', alias: const ['nom']),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _anneeId = v),
                  ),
                  if (_vacations.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _vacationId,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Vacation souhaitée'),
                      items: _vacations
                          .map((v) => DropdownMenuItem(
                                value: v.id,
                                child: Text(
                                  [
                                    v.texte('nom'),
                                    if (v.decimalOuNul('fraisInscription') != null)
                                      '(${formatMontant(v.decimal('fraisInscription'), v.texte('deviseFrais', defaut: 'USD'))})',
                                  ].join(' '),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _vacationId = v),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _commentaire,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Commentaire',
                      alignLabelWithHint: true,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _declareBourse,
                    title: const Text('Je suis boursier'),
                    subtitle: const Text(
                      'Le service social vérifiera votre dossier.',
                    ),
                    onChanged: (v) => setState(() => _declareBourse = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _peutEnvoyer && !_envoi ? _envoyer : null,
              icon: _envoi
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _demandeExistante != null
                    ? 'Demande déjà introduite'
                    : _envoi
                        ? 'Envoi…'
                        : 'Envoyer ma demande',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _pastilleStatut() {
    final statut = statutDemande(_demandeExistante!.texte('statut'));
    if (statut == null) return null;
    return Pastille(texte: statut.$1, couleur: statut.$2);
  }

  Future<void> _envoyer() async {
    final user = context.read<AuthProvider>().user;
    final service = context.read<EtudiantAcademiqueService>();

    setState(() => _envoi = true);
    try {
      // Deux temps, comme les autres démarches : la création rend un
      // brouillon, invisible du secrétariat tant qu'il n'est pas soumis.
      final creee = await service.creerDemande({
        'typeDemande': 'REINSCRIPTION',
        'anneeAcademiqueId': _anneeId,
        'vacationId': ?_vacationId,
        'commentaire': _commentaire.text.trim(),
        'declareBourse': _declareBourse,
        'etudiantId': user?.id,
        'universiteId': user?.universiteId,
      });
      final id = creee.id;
      if (id.isNotEmpty) await service.soumettreDemande(id);

      if (!mounted) return;
      setState(() {
        _message = 'Demande de réinscription envoyée.';
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
      if (mounted) setState(() => _envoi = false);
    }
  }
}
