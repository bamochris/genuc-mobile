import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../data/services/commun_service.dart';
import '../../domain/entities/user.dart';
import '../config/destinations.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/student_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/etudiant/notifications/notifications_screen.dart';
import '../widgets/genuc_scaffold.dart';
import '../widgets/portail_widgets.dart';

/// Habillage du portail, exposé aux écrans qu'il contient.
///
/// Les écrans sont des pages autonomes (`PagePortail`) : ils portent leur
/// propre barre de titre. Plutôt que de les envelopper dans un second
/// `Scaffold` — deux barres empilées, deux zones de défilement —, le shell
/// leur passe par ici ce qui relève de la navigation : le tiroir, les onglets
/// du module courant, la barre basse et les actions globales. Une page ouverte
/// par `Navigator.push` (fiche d'un cours, détail d'un paiement) n'est pas
/// descendante du shell : elle ne trouve pas ce scope et s'affiche donc avec
/// une simple flèche de retour, ce qui est le comportement attendu.
class PortailScope extends InheritedWidget {
  final Widget tiroir;
  final Widget? barreBasse;

  /// Bande de pastilles des volets du module courant, ou `null` hors module.
  final Widget? ongletsModule;

  /// Barre de raccourcis (Mon horaire, Mes cours, Messagerie), posée sous la
  /// barre de titre.
  final Widget? topbar;

  final List<Widget> actionsGlobales;

  /// Ouvre une destination par son chemin web.
  final void Function(String chemin) ouvrir;

  final String cheminCourant;

  /// Utilisateur de la session, pour les destinations qui en ont besoin.
  final User user;

  const PortailScope({
    super.key,
    required this.tiroir,
    required this.barreBasse,
    required this.ongletsModule,
    required this.topbar,
    required this.actionsGlobales,
    required this.ouvrir,
    required this.cheminCourant,
    required this.user,
    required super.child,
  });

  static PortailScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PortailScope>();

  /// Utilisateur porté par le shell, ou `null` hors portail.
  ///
  /// Les destinations le lisent ici plutôt que dans `AuthProvider` : le
  /// tableau de bord enseignant y faisait un `user!` qui transformait toute
  /// session non encore restaurée en écran rouge.
  static User? utilisateur(BuildContext context) => maybeOf(context)?.user;

  /// Ouvre une destination depuis n'importe où sous le shell.
  ///
  /// Depuis une page poussée par-dessus (hors scope), retombe sur une
  /// fermeture de la pile : l'utilisateur revient au portail, qui reste sur sa
  /// destination courante. Mieux que de ne rien faire du tout.
  static void naviguer(BuildContext context, String chemin) {
    final scope = maybeOf(context);
    if (scope != null) {
      scope.ouvrir(chemin);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  bool updateShouldNotify(PortailScope ancien) =>
      ancien.cheminCourant != cheminCourant ||
      ancien.ongletsModule != ongletsModule ||
      ancien.barreBasse != barreBasse;
}

/// Portail complet : menu, historique interne et écran courant.
///
/// Remplace l'ancien `HomeScreen`, qui n'affichait que le tableau de bord et
/// aiguillait le menu par comparaison de libellés — la moitié des entrées
/// tombant sur « écran à venir » alors que les écrans existaient.
class PortailShell extends StatefulWidget {
  final User user;

  const PortailShell({super.key, required this.user});

  @override
  State<PortailShell> createState() => _PortailShellState();
}

class _PortailShellState extends State<PortailShell> {
  late final String _role = widget.user.role?.toUpperCase() ?? '';

  /// Historique interne au portail : le bouton retour du système y recule
  /// avant de quitter l'application, comme le fait le navigateur sur le web.
  late List<String> _pile = [MenuPortail.accueil(_role)];

  /// Modules ouverts par l'établissement. Vide = tout est actif.
  Map<String, bool> _modules = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chargerEssentiels();
      _chargerModules();
    });
  }

  Future<void> _chargerEssentiels() async {
    final inscriptionId = widget.user.inscriptionId;
    final futures = <Future<void>>[
      context.read<NotificationProvider>().loadNotifications(),
    ];
    if (inscriptionId != null && inscriptionId.isNotEmpty) {
      futures.add(context.read<StudentProvider>().loadEssentiels(inscriptionId));
    }
    await Future.wait(futures);
  }

  /// Le menu du web est filtré par `universite.modulesActifs`. Sans ce
  /// chargement, le mobile proposerait la bibliothèque ou les stages à des
  /// établissements qui les ont fermés — et chaque clic finirait en 403.
  Future<void> _chargerModules() async {
    final universiteId = widget.user.universiteId;
    if (universiteId == null || universiteId.isEmpty) return;
    if (_role != 'ETUDIANT' && _role != 'PROFESSEUR') return;

    try {
      final modules =
          await context.read<CommunService>().modulesActifs(universiteId);
      if (!mounted) return;
      setState(() => _modules = modules);
    } catch (_) {
      // Échec = on n'ampute rien : un menu complet vaut mieux qu'un menu vide.
    }
  }

  List<EntreeMenu> get _entrees =>
      MenuPortail.filtrer(MenuPortail.pourRole(_role), _modules);

  String get _cheminCourant => _pile.last;

  void _ouvrir(String chemin) {
    if (chemin == _cheminCourant) return;
    setState(() {
      // Revenir sur une destination déjà visitée n'empile pas un doublon :
      // l'aller-retour tableau de bord → cours → tableau de bord laisserait
      // sinon une pile qui grossit sans fin.
      _pile.remove(chemin);
      _pile = [..._pile, chemin];
    });
  }

  void _reculer() {
    if (_pile.length <= 1) return;
    setState(() => _pile = _pile.sublist(0, _pile.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final destination = MenuPortail.destination(_cheminCourant);

    return PopScope(
      canPop: _pile.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _reculer();
      },
      child: PortailScope(
        cheminCourant: _cheminCourant,
        tiroir: _Tiroir(
          user: widget.user,
          entrees: _entrees,
          cheminCourant: _cheminCourant,
          onOuvrir: _ouvrir,
        ),
        barreBasse: _barreBasse(),
        ongletsModule: _ongletsModule(),
        topbar: _topbar(),
        actionsGlobales: _actionsGlobales(),
        ouvrir: _ouvrir,
        user: widget.user,
        // `Builder` : l'écran doit être construit **sous** le scope, sinon il
        // n'y trouve ni le tiroir ni l'utilisateur (le contexte du shell est
        // au-dessus de l'InheritedWidget qu'il vient de poser).
        child: KeyedSubtree(
          key: ValueKey(_cheminCourant),
          child: Builder(
            builder: (context) =>
                destination?.construire(context) ??
                _EcranInconnu(chemin: _cheminCourant, onAccueil: _reculer),
          ),
        ),
      ),
    );
  }

  Widget? _ongletsModule() {
    final module = MenuPortail.moduleDe(_role, _cheminCourant);
    if (module == null || module.destinations.length < 2) return null;
    return _OngletsModule(
      module: module,
      cheminCourant: _cheminCourant,
      onOuvrir: _ouvrir,
    );
  }

  /// Barre de raccourcis : les trois gestes fréquents accessibles depuis
  /// n'importe quelle page. Adapter les chemins au rôle, comme le fait
  /// `MenuPortail` pour le reste de la navigation.
  ///
  /// Ordre demandé : mon horaire, mes cours, messagerie. L'enseignant n'a pas
  /// d'« horaire » mais le planning de ses cours, qui joue le même rôle.
  Widget? _topbar() {
    final chemins = switch (_role) {
      'ETUDIANT' => [
          '/etudiant/horaire',
          '/etudiant/mes-cours',
          '/etudiant/messagerie',
        ],
      'PROFESSEUR' => [
          '/professeur/mes-cours/planning',
          '/professeur/mes-cours',
          '/professeur/messagerie',
        ],
      _ => const <String>[],
    };

    final destinations = chemins
        .map(MenuPortail.destination)
        .whereType<Destination>()
        .toList();
    if (destinations.isEmpty) return null;

    return _TopbarRapide(
      destinations: destinations,
      cheminCourant: _cheminCourant,
      onOuvrir: _ouvrir,
    );
  }

  Widget? _barreBasse() {
    final destinations = MenuPortail.barreBasse(_role);
    if (destinations.isEmpty) return null;

    // Une destination fermée par l'établissement disparaît de la barre : elle
    // y occuperait une place de choix pour n'ouvrir qu'un refus.
    final visibles = destinations
        .where((d) => MenuPortail.destinationActive(d.$1.chemin, _modules))
        .toList();
    if (visibles.isEmpty) return null;

    return _BarreBasse(
      destinations: visibles,
      cheminCourant: _cheminCourant,
      onOuvrir: _ouvrir,
    );
  }

  List<Widget> _actionsGlobales() {
    final estSombre = Theme.of(context).brightness == Brightness.dark;
    return [
      IconButton(
        icon: Icon(
          estSombre ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        ),
        tooltip: estSombre ? 'Thème clair' : 'Thème sombre',
        onPressed: () => context.read<ThemeProvider>().setThemeMode(
              estSombre ? ThemeMode.light : ThemeMode.dark,
            ),
      ),
      const _BoutonNotifications(),
      IconButton(
        icon: const Icon(Icons.logout_rounded),
        tooltip: 'Déconnexion',
        onPressed: _confirmerDeconnexion,
      ),
    ];
  }

  Future<void> _confirmerDeconnexion() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    // `_RacineAuthentifiee` ramène seule vers l'écran de connexion.
    await context.read<AuthProvider>().logout();
  }
}

// ─────────────────────────────────────────────────────────────
// Tiroir de navigation
// ─────────────────────────────────────────────────────────────

class _Tiroir extends StatelessWidget {
  final User user;
  final List<EntreeMenu> entrees;
  final String cheminCourant;
  final void Function(String) onOuvrir;

  const _Tiroir({
    required this.user,
    required this.entrees,
    required this.cheminCourant,
    required this.onOuvrir,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      child: Column(
        children: [
          _EnTeteTiroir(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final entree in entrees)
                  switch (entree) {
                    EntreeSimple(:final destination) => _LigneTiroir(
                        destination: destination,
                        actif: destination.chemin == cheminCourant,
                        onTap: () => _aller(context, destination.chemin),
                      ),
                    EntreeModule(:final module) => _ModuleTiroir(
                        module: module,
                        cheminCourant: cheminCourant,
                        onTap: (chemin) => _aller(context, chemin),
                      ),
                  },
              ],
            ),
          ),
          // `SafeArea(top: false)` : sans lui, la barre de navigation système
          // recouvrait le bas du tiroir et coupait le nom de l'étudiant.
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.borderOf(context)),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      _initiales(user.nomComplet ?? user.email),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.nomComplet ?? user.email ?? 'Utilisateur',
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          (user.role ?? 'Utilisateur').replaceAll('_', ' '),
                          style: textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _aller(BuildContext context, String chemin) {
    Navigator.of(context).pop();
    onOuvrir(chemin);
  }

  static String _initiales(String? nom) {
    if (nom == null || nom.trim().isEmpty) return '?';
    final parties = nom.trim().split(RegExp(r'\s+'));
    if (parties.length >= 2) {
      return '${parties.first[0]}${parties.last[0]}'.toUpperCase();
    }
    final seul = parties.first;
    return (seul.length >= 2 ? seul.substring(0, 2) : seul).toUpperCase();
  }
}

class _EnTeteTiroir extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primaryDark],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.secondaryLight.withValues(alpha: 0.8),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo-genuc.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.school_rounded,
                  size: 30,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'GENUC',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
          ),
        ],
      ),
    );
  }
}

class _LigneTiroir extends StatelessWidget {
  final Destination destination;
  final bool actif;
  final VoidCallback onTap;

  const _LigneTiroir({
    required this.destination,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: actif,
      selectedTileColor:
          AppTheme.fondPastille(context, AppTheme.iconAccent(context)),
      leading: IconePlaque(
        icone: destination.icone,
        couleur: destination.couleur,
        taille: 34,
      ),
      title: Text(
        destination.libelle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
            ),
      ),
      onTap: onTap,
    );
  }
}

class _ModuleTiroir extends StatelessWidget {
  final ModuleMenu module;
  final String cheminCourant;
  final void Function(String) onTap;

  const _ModuleTiroir({
    required this.module,
    required this.cheminCourant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final contientCourant =
        module.destinations.any((d) => d.chemin == cheminCourant);

    return ExpansionTile(
      // Le module de la page ouverte est déplié : sinon, l'utilisateur qui
      // ouvre le tiroir depuis un volet ne voit pas où il se trouve.
      initiallyExpanded: contientCourant,
      leading: IconePlaque(
        icone: module.icone,
        couleur: module.couleur,
        taille: 34,
      ),
      title: Text(
        module.libelle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: contientCourant ? FontWeight.w800 : FontWeight.w600,
            ),
      ),
      iconColor: AppTheme.iconAccent(context),
      collapsedIconColor: AppTheme.iconAccent(context),
      childrenPadding: const EdgeInsets.only(left: 16),
      children: [
        for (final destination in module.destinations)
          ListTile(
            selected: destination.chemin == cheminCourant,
            selectedTileColor:
                AppTheme.fondPastille(context, AppTheme.iconAccent(context)),
            leading: IconePlaque(
              icone: destination.icone,
              couleur: destination.couleur,
              taille: 30,
            ),
            title: Text(
              destination.libelle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: destination.chemin == cheminCourant
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
            ),
            onTap: () => onTap(destination.chemin),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Onglets du module courant
// ─────────────────────────────────────────────────────────────

/// Pastilles des volets du module, posées au-dessus du contenu.
///
/// Pendant mobile de `ModuleTabs` : elles défilent horizontalement, une barre
/// d'onglets à six volets ne tenant pas sur 360 px.
class _OngletsModule extends StatelessWidget {
  final ModuleMenu module;
  final String cheminCourant;
  final void Function(String) onOuvrir;

  const _OngletsModule({
    required this.module,
    required this.cheminCourant,
    required this.onOuvrir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderOf(context)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.margePage(context).left,
        ),
        child: Row(
          children: [
            for (final destination in module.destinations) ...[
              _Pastille(
                destination: destination,
                actif: destination.chemin == cheminCourant,
                onTap: () => onOuvrir(destination.chemin),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  final Destination destination;
  final bool actif;
  final VoidCallback onTap;

  const _Pastille({
    required this.destination,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentLisible(context, destination.couleur);

    return InkWell(
      onTap: actif ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: actif
              ? AppTheme.fondPastille(context, accent)
              : AppTheme.surfaceAlt(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: actif ? accent : AppTheme.borderOf(context),
            width: actif ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              destination.icone,
              size: 15,
              color: actif ? accent : AppTheme.textMutedOf(context),
            ),
            const SizedBox(width: 6),
            Text(
              destination.libelle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                color: actif ? accent : AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Topbar — raccourcis supérieurs
// ─────────────────────────────────────────────────────────────

/// Repère de la barre de raccourcis. Ses libellés existent aussi dans le
/// tiroir et la barre basse : sans clé, un test ne saurait pas lequel des
/// trois « Mes cours » il vient de toucher.
const Key cleTopbar = Key('topbar-raccourcis');

/// Barre de raccourcis, posée juste sous la barre de titre : Mon horaire, Mes
/// cours et Messagerie, accessibles depuis n'importe quelle page du portail.
/// Chaque entrée ouvre sa destination via le chemin web, comme les tuiles et
/// la barre basse — pas de push de classe ici non plus.
class _TopbarRapide extends StatelessWidget {
  final List<Destination> destinations;
  final String cheminCourant;
  final void Function(String) onOuvrir;

  const _TopbarRapide({
    required this.destinations,
    required this.cheminCourant,
    required this.onOuvrir,
  });

  @override
  Widget build(BuildContext context) {
    // Posée sous la barre de titre, dont elle reprend le fond : les deux ne
    // font qu'un bloc d'en-tête bleu nuit. Sur une surface claire, la bande de
    // raccourcis découpait l'écran en tranches — bleu nuit, clair, contenu.
    //
    // Pas de décalage de barre d'état ici : la barre de titre, revenue dans sa
    // tranche du Scaffold, s'en charge déjà.
    final fond = Theme.of(context).appBarTheme.backgroundColor ??
        Theme.of(context).colorScheme.primary;

    return Container(
      key: cleTopbar,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: fond,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      child: SizedBox(
        // Hauteur fixe : le trait de l'onglet actif doit venir mourir sur la
        // bordure basse de la barre, ce qu'un contenu à hauteur libre ne
        // garantit pas d'un rôle à l'autre.
        height: 54,
        child: Row(
          children: [
            for (final destination in destinations)
              Expanded(
                child: _BoutonTopbar(
                  destination: destination,
                  actif: destination.chemin == cheminCourant,
                  onTap: () => onOuvrir(destination.chemin),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BoutonTopbar extends StatelessWidget {
  final Destination destination;
  final bool actif;
  final VoidCallback onTap;

  const _BoutonTopbar({
    required this.destination,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Le fond de la barre est le bleu nuit de marque dans les deux thèmes :
    // les teintes se lisent donc sur sombre, quel que soit le réglage.
    final accent = destination.couleur;
    final couleur = actif ? accent : Colors.white.withValues(alpha: 0.72);

    return InkWell(
      // L'onglet courant ne se rouvre pas : le geste n'aurait aucun effet et
      // l'encre laisserait croire le contraire.
      onTap: actif ? null : onTap,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(destination.glyphe(actif: actif), size: 21, color: couleur),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  destination.libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.1,
                    fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                    color: couleur,
                  ),
                ),
              ),
              const SizedBox(height: 5),
            ],
          ),
          // Trait de l'onglet actif, posé sur la bordure basse de la barre.
          // L'opacité s'anime plutôt que la largeur : dans un `Stack`, une
          // largeur interpolée vers `double.infinity` ne donne rien de
          // visible, l'enfant étant de toute façon borné par l'onglet.
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            opacity: actif ? 1 : 0,
            child: Container(
              height: 3,
              width: double.infinity,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Barre basse
// ─────────────────────────────────────────────────────────────

/// Les quatre gestes répétés, à portée de pouce, plus l'accès au menu complet.
class _BarreBasse extends StatelessWidget {
  final List<(Destination, String)> destinations;
  final String cheminCourant;
  final void Function(String) onOuvrir;

  const _BarreBasse({
    required this.destinations,
    required this.cheminCourant,
    required this.onOuvrir,
  });

  /// Le module reste allumé quand on passe d'un volet à l'autre : [racine]
  /// couvre tout le sous-arbre de la destination.
  bool _actif(String racine) =>
      cheminCourant == racine || cheminCourant.startsWith('$racine/');

  @override
  Widget build(BuildContext context) {
    // Sur tablette et au-delà, le tiroir tient à l'écran : la barre basse
    // ferait double emploi et mangerait de la hauteur.
    if (!Responsive.estTelephone(context)) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.glass(context),
        border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (final (destination, racine) in destinations)
                Expanded(
                  child: _BoutonBarre(
                    icone: destination.glyphe(actif: _actif(racine)),
                    libelle: destination.libelle,
                    actif: _actif(racine),
                    onTap: () => onOuvrir(destination.chemin),
                  ),
                ),
              Expanded(
                child: Builder(
                  builder: (context) => _BoutonBarre(
                    icone: Icons.menu_rounded,
                    libelle: 'Plus',
                    actif: false,
                    onTap: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoutonBarre extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  const _BoutonBarre({
    required this.icone,
    required this.libelle,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = actif
        ? AppTheme.iconAccent(context)
        : AppTheme.textMutedOf(context);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Alvéole teintée sous l'onglet courant : c'est elle, plus que la
          // couleur seule, qui fait ressortir l'onglet d'un coup d'œil.
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            decoration: BoxDecoration(
              color: actif
                  ? AppTheme.fondPastille(context, couleur)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icone, size: 21, color: couleur),
          ),
          const SizedBox(height: 2),
          Text(
            libelle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Divers
// ─────────────────────────────────────────────────────────────

class _BoutonNotifications extends StatelessWidget {
  const _BoutonNotifications();

  @override
  Widget build(BuildContext context) {
    final compte =
        context.select<NotificationProvider, int>((p) => p.unreadCount);

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_rounded),
          tooltip: 'Notifications',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        if (compte > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                compte > 99 ? '99+' : '$compte',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Chemin sans destination : ne devrait pas arriver, mais vaut mieux qu'un
/// écran blanc si une action rapide vise une route retirée du tableau.
class _EcranInconnu extends StatelessWidget {
  final String chemin;
  final VoidCallback onAccueil;

  const _EcranInconnu({required this.chemin, required this.onAccueil});

  @override
  Widget build(BuildContext context) {
    return GenucScaffold(
      appBar: AppBar(title: const Text('Page introuvable')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.explore_off_rounded,
                size: 48,
                color: AppTheme.textMutedOf(context),
              ),
              const SizedBox(height: 16),
              Text('Aucun écran pour « $chemin ».',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAccueil,
                child: const Text('Revenir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
