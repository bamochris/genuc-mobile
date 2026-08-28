import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/services/appel_api.dart';
import '../../widgets/formulaire_dynamique.dart';
import '../../../core/utils/export_liste.dart';
import '../../widgets/portail_widgets.dart';

/// Comment présenter une fiche dans la liste.
class DescriptionFiche {
  final String Function(Fiche) titre;
  final String? Function(Fiche)? sousTitre;
  final List<LigneDetail> Function(Fiche)? details;
  final (String, Color)? Function(Fiche)? statut;
  final IconData icone;

  const DescriptionFiche({
    required this.titre,
    this.sousTitre,
    this.details,
    this.statut,
    this.icone = Icons.description_rounded,
  });
}

/// Écran « liste d'une ressource », avec recherche, création et suppression.
///
/// Vingt écrans des deux portails ont exactement cette forme — publications,
/// projets, conférences, laboratoires, interrogations, TP, examens, sujets de
/// TFC, clubs, offres… Les écrire un par un les faisait diverger : l'un
/// oubliait l'état d'erreur, l'autre le tiré-pour-rafraîchir, un troisième
/// n'avait pas d'état vide. Ils partagent donc ce gabarit et ne déclarent que
/// ce qui leur est propre : d'où viennent les données, comment les afficher,
/// et quels champs saisir pour en créer une.
class EcranRessource extends StatefulWidget {
  final String titre;
  final String? sousTitre;
  final Future<List<Fiche>> Function() charger;
  final DescriptionFiche description;

  /// Champs du formulaire de création. Vide = ressource en lecture seule.
  final List<ChampFormulaire> champsCreation;
  final Future<void> Function(Map<String, dynamic> valeurs)? onCreer;
  final String libelleCreation;

  /// Création confiée à un ÉCRAN dédié plutôt qu'à la boîte de dialogue.
  ///
  /// Le formulaire déclaratif ne sait pas enchaîner des listes dépendantes :
  /// ses options sont résolues une fois pour toutes avant l'ouverture. Or
  /// certaines saisies sont des cascades — établissement, puis filière, puis
  /// promotion —, chaque niveau ne pouvant être proposé qu'une fois le
  /// précédent choisi. Ces écrans-là fournissent [onNouveau] à la place de
  /// [champsCreation] : le bouton pousse leur page, et la liste se recharge à
  /// son retour.
  ///
  /// La valeur rendue par la page n'est pas lue : seul compte le fait qu'elle
  /// ait abouti — une page annulée rend {@code null} et la liste, rechargée,
  /// se retrouve identique.
  final Future<void> Function(BuildContext)? onNouveau;

  /// Options d'une liste déroulante à charger au serveur, par clé de champ.
  ///
  /// La quasi-totalité des formulaires enseignant commence par « choisissez un
  /// cours » : la liste vient de `/api/cours/professeur/{id}` et ne peut donc
  /// pas être déclarée en constante.
  final Map<String, Future<Map<String, String>> Function()> optionsDynamiques;

  final Future<void> Function(Fiche)? onSupprimer;
  final void Function(BuildContext, Fiche)? onOuvrir;

  /// Actions supplémentaires proposées sur chaque fiche.
  final List<ActionFiche> actions;

  /// Colonnes de l'export papier, quand la forme imprimée doit différer de
  /// l'affichage.
  ///
  /// Nulle, l'export est **déduit de [description]** : c'est ce que l'écran
  /// montre qui part sur le papier, colonne par colonne. Toute liste bâtie
  /// sur ce gabarit est donc imprimable sans rien déclarer — et le jour où
  /// l'affichage change, l'export suit, sans qu'on ait à y penser.
  ///
  /// À renseigner quand le papier veut autre chose : une liste d'appel veut
  /// le matricule et le nom en colonnes séparées, là où l'écran les réunit
  /// en un titre.
  final List<ColonneExport>? colonnesExport;

  /// Retire le bouton d'impression. Pour les rares listes qui n'ont pas de
  /// sens sur papier.
  final bool exportable;

  final String messageVide;
  final bool recherche;

  /// Bandeau facultatif affiché au-dessus de la liste (barème de référence,
  /// rappel de format…).
  final Widget Function(BuildContext)? entete;

  const EcranRessource({
    super.key,
    required this.titre,
    required this.charger,
    required this.description,
    this.sousTitre,
    this.champsCreation = const [],
    this.onCreer,
    this.libelleCreation = 'Nouveau',
    this.onNouveau,
    this.optionsDynamiques = const {},
    this.onSupprimer,
    this.onOuvrir,
    this.actions = const [],
    this.colonnesExport,
    this.exportable = true,
    this.messageVide = 'Aucun élément à afficher.',
    this.recherche = true,
    this.entete,
  });

  @override
  State<EcranRessource> createState() => _EcranRessourceState();
}

/// Action contextuelle sur une fiche (valider, télécharger, commenter…).
class ActionFiche {
  final String libelle;
  final IconData icone;
  final Color couleur;
  final Future<void> Function(BuildContext, Fiche) executer;
  final bool Function(Fiche)? visiblePour;

  const ActionFiche({
    required this.libelle,
    required this.icone,
    required this.executer,
    this.couleur = AppTheme.statutBleu,
    this.visiblePour,
  });
}

class _EcranRessourceState extends State<EcranRessource> {
  List<Fiche> _fiches = const [];
  bool _chargement = true;
  String? _erreur;
  String _recherche = '';
  String? _message;
  bool _messageSucces = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final fiches = await widget.charger();
      if (!mounted) return;
      setState(() {
        _fiches = fiches;
        _chargement = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.toString();
        _chargement = false;
      });
    }
  }

  List<Fiche> get _filtrees {
    if (_recherche.trim().isEmpty) return _fiches;
    final terme = _recherche.toLowerCase();
    return _fiches.where((f) {
      final titre = widget.description.titre(f).toLowerCase();
      final sous = widget.description.sousTitre?.call(f)?.toLowerCase() ?? '';
      return titre.contains(terme) || sous.contains(terme);
    }).toList();
  }

  /// Colonnes de l'export : celles déclarées, sinon celles que l'écran affiche.
  ///
  /// Les libellés des détails sont pris sur la PREMIÈRE fiche : ils sont bâtis
  /// à partir d'une liste fixe dans chaque écran, donc identiques d'une fiche
  /// à l'autre. Les valeurs, elles, sont relues fiche par fiche — et par
  /// position, puisque c'est l'ordre qui fait correspondre une valeur à sa
  /// colonne.
  List<ColonneExport>? get _colonnes {
    if (!widget.exportable) return null;
    if (widget.colonnesExport != null) return widget.colonnesExport;

    final fiches = _filtrees;
    if (fiches.isEmpty) return const [];

    final description = widget.description;
    final colonnes = <ColonneExport>[
      ColonneExport(
        libelle: 'Désignation',
        valeur: (l) => description.titre(Fiche(l)),
      ),
    ];

    if (description.sousTitre != null) {
      colonnes.add(ColonneExport(
        libelle: 'Référence',
        valeur: (l) => description.sousTitre!(Fiche(l)) ?? '',
      ));
    }

    final details = description.details?.call(fiches.first) ?? const [];
    for (var i = 0; i < details.length; i++) {
      final position = i;
      colonnes.add(ColonneExport(
        libelle: details[position].libelle,
        valeur: (l) {
          final lignes = description.details?.call(Fiche(l)) ?? const [];
          return position < lignes.length ? lignes[position].valeur : '';
        },
      ));
    }

    if (description.statut != null) {
      colonnes.add(ColonneExport(
        libelle: 'Statut',
        valeur: (l) => description.statut!(Fiche(l))?.$1 ?? '',
      ));
    }

    return colonnes;
  }

  @override
  Widget build(BuildContext context) {
    final peutCreer = widget.onNouveau != null
        || (widget.onCreer != null && widget.champsCreation.isNotEmpty);

    return PagePortail(
      titre: widget.titre,
      sousTitre: widget.sousTitre,
      onRafraichir: _charger,
      // L'export porte la liste TELLE QU'ELLE EST FILTREE : c'est ce que
      // l'utilisateur a sous les yeux qu'il veut sur papier.
      actions: _colonnes == null
          ? const []
          : [
              BoutonExportListe(
                titre: widget.titre,
                sousTitre: widget.sousTitre,
                colonnes: _colonnes!,
                lignes: _filtrees.map((f) => f.donnees).toList(),
                compact: true,
              ),
            ],
      floatingActionButton: peutCreer
          ? FloatingActionButton.extended(
              onPressed: () => widget.onNouveau != null
                  ? _ouvrirEcranCreation()
                  : _ouvrirCreation(),
              icon: const Icon(Icons.add_rounded),
              label: Text(widget.libelleCreation),
            )
          : null,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _fiches.isEmpty,
        onReessayer: _charger,
        messageVide: widget.messageVide,
        iconeVide: widget.description.icone,
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
            if (widget.entete != null) ...[
              widget.entete!(context),
              const SizedBox(height: 16),
            ],
            if (widget.recherche)
              BarreFiltres(
                indice: 'Rechercher…',
                onRecherche: (v) => setState(() => _recherche = v),
              ),
            if (_filtrees.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Aucun résultat pour cette recherche.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedOf(context)),
                ),
              )
            else
              for (final fiche in _filtrees) ...[
                _CarteFiche(
                  fiche: fiche,
                  description: widget.description,
                  actions: widget.actions,
                  onSupprimer: widget.onSupprimer == null
                      ? null
                      : () => _supprimer(fiche),
                  onOuvrir: widget.onOuvrir == null
                      ? null
                      : () => widget.onOuvrir!(context, fiche),
                  onAction: _executerAction,
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  /// Pousse l'écran de création, puis recharge la liste à son retour.
  Future<void> _ouvrirEcranCreation() async {
    try {
      await widget.onNouveau!(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = _messageErreur(e);
        _messageSucces = false;
      });
      return;
    }
    if (!mounted) return;
    await _charger();
  }

  Future<void> _ouvrirCreation() async {
    final champs = await _champsResolus();
    if (!mounted) return;

    final valeurs = await DialogueFormulaire.ouvrir(
      context,
      titre: widget.libelleCreation,
      champs: champs,
    );
    if (valeurs == null || !mounted) return;

    try {
      await widget.onCreer!(valeurs);
      if (!mounted) return;
      setState(() {
        _message = 'Enregistré.';
        _messageSucces = true;
      });
      await _charger();
    } catch (e) {
      // Toutes les exceptions, pas seulement les erreurs réseau : les
      // vérifications métier de l'appelant (somme des pondérations, dates
      // incohérentes) lèvent des `ArgumentError` qui doivent s'afficher au
      // même endroit plutôt que de remonter en écran rouge.
      if (!mounted) return;
      setState(() {
        _message = _messageErreur(e);
        _messageSucces = false;
      });
    }
  }

  static String _messageErreur(Object e) {
    if (e is ApiException) return e.message;
    if (e is ArgumentError) return e.message?.toString() ?? e.toString();
    return e.toString();
  }

  /// Remplit les listes déroulantes qui dépendent du serveur.
  ///
  /// Une liste vide n'est pas masquée : un formulaire dont le champ « Cours »
  /// disparaîtrait laisserait croire qu'il n'est pas requis, alors que le
  /// serveur refusera l'enregistrement.
  Future<List<ChampFormulaire>> _champsResolus() async {
    if (widget.optionsDynamiques.isEmpty) return widget.champsCreation;

    final charges = <String, Map<String, String>>{};
    for (final entree in widget.optionsDynamiques.entries) {
      try {
        charges[entree.key] = await entree.value();
      } catch (_) {
        charges[entree.key] = const {};
      }
    }

    return widget.champsCreation.map((champ) {
      final options = charges[champ.cle];
      if (options == null) return champ;
      return ChampFormulaire(
        cle: champ.cle,
        libelle: champ.libelle,
        type: TypeChamp.liste,
        obligatoire: champ.obligatoire,
        indice: champ.indice,
        valeurInitiale: champ.valeurInitiale,
        options: options,
      );
    }).toList();
  }

  Future<void> _supprimer(Fiche fiche) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text(
          'Supprimer « ${widget.description.titre(fiche)} » ? '
          'Cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    try {
      await widget.onSupprimer!(fiche);
      if (!mounted) return;
      setState(() {
        _message = 'Élément supprimé.';
        _messageSucces = true;
      });
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = _messageErreur(e);
        _messageSucces = false;
      });
    }
  }

  Future<void> _executerAction(ActionFiche action, Fiche fiche) async {
    try {
      await action.executer(context, fiche);
      if (!mounted) return;
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = _messageErreur(e);
        _messageSucces = false;
      });
    }
  }
}

class _CarteFiche extends StatelessWidget {
  final Fiche fiche;
  final DescriptionFiche description;
  final List<ActionFiche> actions;
  final VoidCallback? onSupprimer;
  final VoidCallback? onOuvrir;
  final Future<void> Function(ActionFiche, Fiche) onAction;

  const _CarteFiche({
    required this.fiche,
    required this.description,
    required this.actions,
    required this.onAction,
    this.onSupprimer,
    this.onOuvrir,
  });

  @override
  Widget build(BuildContext context) {
    final statut = description.statut?.call(fiche);
    final sousTitre = description.sousTitre?.call(fiche);
    final details = description.details?.call(fiche) ?? const <LigneDetail>[];
    final actionsVisibles = actions
        .where((a) => a.visiblePour?.call(fiche) ?? true)
        .toList();

    return CartePortail(
      onTap: onOuvrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  description.titre(fiche),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (statut != null) ...[
                const SizedBox(width: 10),
                Pastille(texte: statut.$1, couleur: statut.$2),
              ],
            ],
          ),
          if (sousTitre != null && sousTitre.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sousTitre,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...details,
          ],
          if (actionsVisibles.isNotEmpty || onSupprimer != null) ...[
            const SizedBox(height: 12),
            Divider(color: AppTheme.borderOf(context), height: 1),
            const SizedBox(height: 8),
            // Défile : quatre actions ne tiennent pas sur 360 px de large.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final action in actionsVisibles)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton.icon(
                        onPressed: () => onAction(action, fiche),
                        icon: Icon(action.icone, size: 16),
                        label: Text(action.libelle),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              AppTheme.accentLisible(context, action.couleur),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  if (onSupprimer != null)
                    TextButton.icon(
                      onPressed: onSupprimer,
                      icon: const Icon(Icons.delete_rounded, size: 16),
                      label: const Text('Supprimer'),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            AppTheme.accentLisible(context, AppTheme.error),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
