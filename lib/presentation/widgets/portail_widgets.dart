import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../navigation/portail_shell.dart';
import 'etat_widgets.dart';
import 'genuc_scaffold.dart';

/// Écran de portail standard : fond de marque, barre de titre, contenu centré
/// et limité en largeur, tiré-pour-rafraîchir.
///
/// Chaque page des portails web est bâtie sur le même gabarit (titre, sous-
/// titre, contenu à `max-width` centré). Le reproduire ici évite que chaque
/// écran mobile réinvente ses marges — c'est ce qui rendait l'application
/// hétérogène d'un écran à l'autre.
///
/// Quand la page est la destination courante du portail (et non une fiche
/// poussée par-dessus), elle récupère du [PortailScope] le tiroir, les onglets
/// de son module, la barre basse et les actions globales : c'est ce qui donne
/// la même navigation à tous les écrans sans qu'aucun n'ait à la déclarer.
class PagePortail extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final List<Widget> actions;
  final Widget corps;
  final Future<void> Function()? onRafraichir;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  /// Onglets propres à l'écran (`TabBar`). Malgré son nom, hérité de l'époque
  /// où il alimentait `AppBar.bottom`, il s'affiche désormais **sous** les
  /// raccourcis du portail et les volets du module.
  final PreferredSizeWidget? bottomAppBar;

  const PagePortail({
    super.key,
    required this.titre,
    required this.corps,
    this.sousTitre,
    this.actions = const [],
    this.onRafraichir,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.bottomAppBar,
  });

  @override
  Widget build(BuildContext context) {
    final portail = PortailScope.maybeOf(context);

    Widget contenu = ContenuCentre(child: corps);

    if (onRafraichir != null) {
      contenu = RefreshIndicator(onRefresh: onRafraichir!, child: contenu);
    }

    // Bandes empilées entre la barre de titre et le contenu, de la plus
    // générale à la plus locale : raccourcis du portail, volets du module,
    // puis onglets propres à l'écran.
    //
    // Les onglets de l'écran ne vont **pas** dans `AppBar.bottom` : ils s'y
    // affichaient au-dessus des raccourcis, si bien qu'en ouvrant « Mon
    // horaire » on lisait « Semaine · Examens · Événements » avant même le nom
    // de la page à laquelle ces volets appartiennent. Descendus ici, ils
    // suivent la page qu'ils découpent — et retrouvent au passage les couleurs
    // que `tabBarTheme` prévoit pour une surface de page, là où sur le bleu
    // nuit de la barre de titre le libellé actif était presque invisible.
    final bandes = <Widget>[
      ?portail?.topbar,
      ?portail?.ongletsModule,
      if (bottomAppBar != null) _BandeOnglets(onglets: bottomAppBar!),
    ];

    AppBar barreTitre() => AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titre, overflow: TextOverflow.ellipsis),
              if (sousTitre != null)
                Text(
                  sousTitre!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
          actions: [...actions, ...?portail?.actionsGlobales],
        );

    // La barre de raccourcis (Mon horaire, Mes cours, Messagerie) se pose
    // **sous** la barre de titre, en tête du corps — et non au-dessus d'elle.
    //
    // Elle a d'abord été posée en barre la plus haute, ce qui coûtait cher :
    // le titre perdait sa tranche `appBar` du Scaffold pour descendre dans une
    // `Column`, où un `AppBar` reçoit une hauteur infinie ; son `Flexible`
    // interne (posé dès qu'il y a des onglets) faisait alors sauter la mise en
    // page des sept écrans à onglets. Le titre repris dans sa tranche, ce
    // risque disparaît avec lui.
    return GenucScaffold(
      appBar: barreTitre(),
      drawer: portail?.tiroir,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar ?? portail?.barreBasse,
      body: SafeArea(
        child: bandes.isEmpty
            ? contenu
            : Column(children: [...bandes, Expanded(child: contenu)]),
      ),
    );
  }
}

/// Onglets d'un écran, posés sur leur bande, sous les raccourcis du portail.
///
/// Hauteur bornée depuis `preferredSize` : un `TabBar` placé nu dans une
/// `Column` se débrouille, mais rien ne garantit son intrinsèque quand il
/// porte des icônes ou deux lignes de libellé.
class _BandeOnglets extends StatelessWidget {
  final PreferredSizeWidget onglets;

  const _BandeOnglets({required this.onglets});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.glass(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: onglets.preferredSize.height, child: onglets),
          Divider(height: 1, thickness: 1, color: AppTheme.borderOf(context)),
        ],
      ),
    );
  }
}

/// Icône posée sur sa plaque : la présentation d'icône de l'application.
///
/// Une icône nue, seule sur un fond translucide, paraît molle et flotte sans
/// alignement d'une carte à l'autre. Elle est donc toujours posée sur un carré
/// à coins très arrondis — le « squircle » des icônes de Facebook ou d'iOS —,
/// teinté de sa propre couleur : dégradé léger du haut vers le bas, filet de
/// bordure, et un glyphe dimensionné à 52 % du côté pour garder la même masse
/// optique quelle que soit la taille demandée.
///
/// Toutes les icônes de l'application appartiennent par ailleurs à la famille
/// **Material Symbols Rounded** (`Icons.*_rounded`) : pleine et arrondie, elle
/// est la plus proche du jeu d'icônes des grandes applications grand public,
/// là où les variantes `_outlined` donnaient un trait fin et terne.
class IconePlaque extends StatelessWidget {
  final IconData icone;
  final Color couleur;

  /// Côté de la plaque. Le glyphe et le rayon en découlent.
  final double taille;

  /// Plaque pleine (fond opaque, glyphe blanc) : réservée aux points forts —
  /// un en-tête, une action mise en avant.
  final bool pleine;

  const IconePlaque({
    super.key,
    required this.icone,
    required this.couleur,
    this.taille = 42,
    this.pleine = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentLisible(context, couleur);
    final rayon = taille * 0.32;

    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pleine
              ? [accent, Color.lerp(accent, Colors.black, 0.22)!]
              : [
                  accent.withValues(alpha: AppTheme.estSombre(context) ? 0.26 : 0.16),
                  accent.withValues(alpha: AppTheme.estSombre(context) ? 0.14 : 0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(rayon),
        border: pleine
            ? null
            : Border.all(color: accent.withValues(alpha: 0.22), width: 1),
        boxShadow: pleine
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: taille * 0.30,
                  offset: Offset(0, taille * 0.09),
                ),
              ]
            : null,
      ),
      child: Icon(
        icone,
        size: taille * 0.52,
        color: pleine ? Colors.white : accent,
      ),
    );
  }
}

/// Corps de page qui bascule entre chargement / erreur / vide / contenu.
///
/// Transposition de `<EtatRequete>` du frontend web : sans lui, chaque écran
/// réécrivait ses trois états et en oubliait au moins un — le plus souvent
/// l'erreur, qui restait un écran blanc.
class EtatRequete extends StatelessWidget {
  final bool chargement;
  final String? erreur;
  final bool vide;
  final Future<void> Function() onReessayer;
  final String messageVide;
  final IconData iconeVide;
  final Widget enfant;

  const EtatRequete({
    super.key,
    required this.chargement,
    required this.erreur,
    required this.vide,
    required this.onReessayer,
    required this.enfant,
    this.messageVide = 'Aucune donnée à afficher.',
    this.iconeVide = Icons.inbox_rounded,
  });

  @override
  Widget build(BuildContext context) {
    if (chargement) return const EtatChargement();
    if (erreur != null) return EtatErreur(message: erreur!, onRetry: onReessayer);
    if (vide) {
      // Reste défilable : sans quoi le tiré-pour-rafraîchir ne fonctionne plus
      // dès que la liste est vide — l'écran d'où l'on veut justement réessayer.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
          EtatVide(icon: iconeVide, titre: messageVide),
        ],
      );
    }
    return enfant;
  }
}

/// Tuile de statistique (KPI) : icône colorée, valeur, libellé, détail.
///
/// Reprend la `stat-card` des tableaux de bord web.
class TuileKpi extends StatelessWidget {
  final IconData icone;
  final String valeur;
  final String libelle;
  final String? detail;
  final Color couleur;
  final VoidCallback? onTap;

  const TuileKpi({
    super.key,
    required this.icone,
    required this.valeur,
    required this.libelle,
    required this.couleur,
    this.detail,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentLisible(context, couleur);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.glass(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Row(
          children: [
            IconePlaque(icone: icone, couleur: couleur, taille: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    valeur,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: accent,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    libelle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMutedOf(context),
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMutedOf(context),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rangée de KPI adaptative (2 colonnes sur téléphone, jusqu'à 4 au-delà).
class RangeeKpi extends StatelessWidget {
  final List<TuileKpi> tuiles;

  const RangeeKpi({super.key, required this.tuiles});

  @override
  Widget build(BuildContext context) {
    return GrilleAdaptative(
      largeurMinTuile: 170,
      ratio: 2.1,
      maxColonnes: 4,
      enfants: tuiles,
    );
  }
}

/// Titre de section avec action optionnelle à droite (« Voir tout »).
class EnteteSection extends StatelessWidget {
  final String titre;
  final IconData? icone;
  final Widget? action;

  const EnteteSection({
    super.key,
    required this.titre,
    this.icone,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icone != null) ...[
            Icon(icone, size: 18, color: AppTheme.iconAccent(context)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              titre,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Carte de contenu : la surface translucide sur laquelle repose chaque bloc.
class CartePortail extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? bordure;

  const CartePortail({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.bordure,
  });

  @override
  Widget build(BuildContext context) {
    final contenu = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.glass(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bordure ?? AppTheme.borderOf(context)),
      ),
      child: child,
    );

    if (onTap == null) return contenu;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: contenu,
    );
  }
}

/// Pastille de statut lisible dans les deux thèmes.
///
/// Les fonds pastel du web (`#E8F8F2`, `#FEF3C7`…) sont recalculés à partir de
/// la couleur au lieu d'être posés en dur : figés, ils devenaient des aplats
/// clairs sous texte clair en thème sombre.
class Pastille extends StatelessWidget {
  final String texte;
  final Color couleur;
  final IconData? icone;

  const Pastille({
    super.key,
    required this.texte,
    required this.couleur,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentLisible(context, couleur);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.fondPastille(context, accent),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 11, color: accent),
            const SizedBox(width: 5),
          ],
          Text(
            texte,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Champ de recherche + filtres déroulants, empilés sur téléphone.
class BarreFiltres extends StatelessWidget {
  final String indice;
  final ValueChanged<String>? onRecherche;
  final List<Widget> filtres;
  final TextEditingController? controleur;

  const BarreFiltres({
    super.key,
    this.indice = 'Rechercher…',
    this.onRecherche,
    this.filtres = const [],
    this.controleur,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          if (onRecherche != null)
            TextField(
              controller: controleur,
              onChanged: onRecherche,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: indice,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
            ),
          if (filtres.isNotEmpty) ...[
            if (onRecherche != null) const SizedBox(height: 10),
            // Défile horizontalement : trois filtres côte à côte débordaient
            // sur un écran de 360 px.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < filtres.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    filtres[i],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Filtre déroulant compact, dimensionné pour la [BarreFiltres].
class FiltreDeroulant<T> extends StatelessWidget {
  final String libelle;
  final T? valeur;
  final List<DropdownMenuItem<T>> options;
  final ValueChanged<T?> onChange;

  const FiltreDeroulant({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.options,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 260),
      child: DropdownButtonFormField<T>(
        initialValue: valeur,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: libelle,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        style: Theme.of(context).textTheme.bodyMedium,
        items: options,
        onChanged: onChange,
      ),
    );
  }
}

/// Tableau à défilement horizontal.
///
/// Les tableaux du web (notes, présences, étudiants) ont 5 à 8 colonnes :
/// comprimés à la largeur d'un téléphone, ils deviennent illisibles. Ils
/// défilent donc dans leur propre boîte, comme les `overflow-x: auto` du web.
class TableauDefilant extends StatelessWidget {
  final List<String> entetes;
  final List<List<Widget>> lignes;
  final double? largeurMin;

  const TableauDefilant({
    super.key,
    required this.entetes,
    required this.lignes,
    this.largeurMin,
  });

  @override
  Widget build(BuildContext context) {
    return CartePortail(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: largeurMin ?? 0),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                AppTheme.surfaceAlt(context),
              ),
              headingTextStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondaryOf(context),
              ),
              dataTextStyle: TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimaryOf(context),
              ),
              columnSpacing: 22,
              horizontalMargin: 16,
              columns: entetes.map((e) => DataColumn(label: Text(e))).toList(),
              rows: lignes
                  .map((l) => DataRow(cells: l.map(DataCell.new).toList()))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bandeau de message (succès, erreur, information) posé en tête de page.
class BandeauMessage extends StatelessWidget {
  final String message;
  final bool succes;
  final VoidCallback? onFermer;

  const BandeauMessage({
    super.key,
    required this.message,
    this.succes = true,
    this.onFermer,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = AppTheme.accentLisible(
      context,
      succes ? AppTheme.success : AppTheme.error,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.fondPastille(context, couleur),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            succes ? Icons.check_circle_rounded : Icons.error_rounded,
            color: couleur,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: couleur,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onFermer != null)
            IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: couleur),
              onPressed: onFermer,
              visualDensity: VisualDensity.compact,
              tooltip: 'Fermer',
            ),
        ],
      ),
    );
  }
}

/// Barre de progression annotée (progression d'un cours, d'un mémoire…).
class BarreProgression extends StatelessWidget {
  final double valeur; // 0..1
  final String? libelle;
  final Color couleur;

  const BarreProgression({
    super.key,
    required this.valeur,
    this.libelle,
    this.couleur = AppTheme.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentLisible(context, couleur);
    final pct = (valeur.clamp(0.0, 1.0) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (libelle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    libelle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ),
                Text(
                  '$pct %',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: valeur.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppTheme.surfaceAlt(context),
            valueColor: AlwaysStoppedAnimation(accent),
          ),
        ),
      ],
    );
  }
}

/// Ligne d'information dense (libellé à gauche, valeur à droite), pour les
/// fiches de détail. Passe en colonne si le texte est long.
class LigneDetail extends StatelessWidget {
  final String libelle;
  final String valeur;
  final IconData? icone;

  const LigneDetail({
    super.key,
    required this.libelle,
    required this.valeur,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 16, color: AppTheme.textMutedOf(context)),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: Text(
              libelle,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMutedOf(context),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              valeur.isEmpty ? '—' : valeur,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Action rapide : la tuile cliquable des tableaux de bord web
/// (`QuickActionsGrid`).
class ActionRapide extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final String? description;
  final Color couleur;
  final VoidCallback onTap;

  const ActionRapide({
    super.key,
    required this.icone,
    required this.libelle,
    required this.couleur,
    required this.onTap,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.glass(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconePlaque(icone: icone, couleur: couleur, taille: 40),
            const SizedBox(height: 10),
            Text(
              libelle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 3),
              Text(
                description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMutedOf(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
