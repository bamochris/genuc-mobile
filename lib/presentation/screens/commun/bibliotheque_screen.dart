import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/services/appel_api.dart';
import '../../../data/services/commun_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/etat_widgets.dart';
import '../../widgets/portail_widgets.dart';

/// Bibliothèque universitaire : catalogue, réservation et emprunts.
///
/// Écran commun aux deux portails — les pages web
/// `etudiant/Bibliotheque.jsx` et `professeur/bibliotheque/*` appellent les
/// mêmes routes avec le même identifiant d'établissement. L'onglet
/// « Mes emprunts » n'apparaît que pour un compte étudiant : la route
/// `/mes-emprunts/{etudiantId}` n'a pas d'équivalent enseignant.
class BibliothequeScreen extends StatefulWidget {
  const BibliothequeScreen({super.key});

  @override
  State<BibliothequeScreen> createState() => _BibliothequeScreenState();
}

class _BibliothequeScreenState extends State<BibliothequeScreen>
    with SingleTickerProviderStateMixin {
  TabController? _onglets;

  List<Fiche> _ouvrages = const [];
  List<Fiche> _emprunts = const [];
  List<String> _categories = const [];
  String _recherche = '';
  String? _categorie;
  bool _chargement = true;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  bool get _estEtudiant =>
      (context.read<AuthProvider>().user?.role ?? '').toUpperCase() == 'ETUDIANT';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onglets = TabController(length: _estEtudiant ? 2 : 1, vsync: this);
      _charger();
    });
  }

  @override
  void dispose() {
    _onglets?.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final user = context.read<AuthProvider>().user;
    final universiteId = user?.universiteId ?? '';
    if (universiteId.isEmpty) {
      setState(() {
        _chargement = false;
        _erreur = 'Établissement inconnu : bibliothèque indisponible.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final service = context.read<CommunService>();
    try {
      final ouvrages = await service.ouvrages(universiteId);
      final categories = await service
          .categoriesBibliotheque(universiteId)
          .catchError((_) => <Fiche>[]);
      final emprunts = _estEtudiant && (user?.id ?? '').isNotEmpty
          ? await service.mesEmprunts(user!.id!).catchError((_) => <Fiche>[])
          : <Fiche>[];
      if (!mounted) return;
      setState(() {
        _ouvrages = ouvrages;
        _emprunts = emprunts;
        _categories = categories
            .map((c) => c.texte('nom', alias: const ['libelle']))
            .where((n) => n.isNotEmpty)
            .toList();
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

  List<Fiche> get _ouvragesFiltres {
    final terme = _recherche.trim().toLowerCase();
    return _ouvrages.where((o) {
      if (_categorie != null && o.texte('categorie') != _categorie) return false;
      if (terme.isEmpty) return true;
      return o.texte('titre').toLowerCase().contains(terme) ||
          o.texte('auteur').toLowerCase().contains(terme) ||
          o.texte('isbn').toLowerCase().contains(terme);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final onglets = _onglets;

    return PagePortail(
      titre: 'Bibliothèque',
      sousTitre: 'Catalogue de l\'établissement',
      onRafraichir: _charger,
      bottomAppBar: onglets == null || !_estEtudiant
          ? null
          : TabBar(
              controller: onglets,
              tabs: const [Tab(text: 'Catalogue'), Tab(text: 'Mes emprunts')],
            ),
      corps: EtatRequete(
        chargement: _chargement || onglets == null,
        erreur: _erreur,
        vide: false,
        onReessayer: _charger,
        enfant: Column(
          children: [
            if (_message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: BandeauMessage(
                  message: _message!,
                  succes: _messageSucces,
                  onFermer: () => setState(() => _message = null),
                ),
              ),
            Expanded(
              child: onglets == null
                  ? const SizedBox.shrink()
                  : (_estEtudiant
                      ? TabBarView(
                          controller: onglets,
                          children: [_catalogue(), _mesEmprunts()],
                        )
                      : _catalogue()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catalogue() {
    final resultats = _ouvragesFiltres;

    return ListView(
      padding: Responsive.margePage(context),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        BarreFiltres(
          indice: 'Titre, auteur ou ISBN…',
          onRecherche: (v) => setState(() => _recherche = v),
          filtres: [
            if (_categories.isNotEmpty)
              FiltreDeroulant<String>(
                libelle: 'Catégorie',
                valeur: _categorie,
                options: [
                  const DropdownMenuItem(value: null, child: Text('Toutes')),
                  ..._categories.map(
                    (c) => DropdownMenuItem(value: c, child: Text(c)),
                  ),
                ],
                onChange: (v) => setState(() => _categorie = v),
              ),
          ],
        ),
        if (resultats.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(
              _ouvrages.isEmpty
                  ? 'Le catalogue est vide.'
                  : 'Aucun ouvrage ne correspond à cette recherche.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMutedOf(context)),
            ),
          )
        else
          for (final ouvrage in resultats) ...[
            _CarteOuvrage(
              ouvrage: ouvrage,
              onReserver: _estEtudiant ? () => _reserver(ouvrage) : null,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _mesEmprunts() {
    if (_emprunts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          EtatVide(
            icon: Icons.book_rounded,
            titre: 'Vous n\'avez aucun emprunt en cours.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: Responsive.margePage(context),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _emprunts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final emprunt = _emprunts[i];
        final retour = emprunt.date('dateRetourPrevue', alias: const ['dateRetour']);
        final enRetard = retour != null && retour.isBefore(DateTime.now());

        return CartePortail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      emprunt.texte(
                        'titre',
                        alias: const ['livreTitre', 'ouvrageTitre'],
                        defaut: 'Emprunt',
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Pastille(
                    texte: enRetard ? 'En retard' : 'En cours',
                    couleur:
                        enRetard ? AppTheme.statutRouge : AppTheme.statutVert,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LigneDetail(
                libelle: 'Emprunté le',
                valeur: formatDate(emprunt.texteOuNul('dateEmprunt')),
              ),
              LigneDetail(
                libelle: 'À rendre avant le',
                valeur: formatDateObjet(retour),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _prolonger(emprunt),
                  icon: const Icon(Icons.more_time_rounded, size: 16),
                  label: const Text('Prolonger de 7 jours'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        AppTheme.accentLisible(context, AppTheme.statutBleu),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _reserver(Fiche ouvrage) async {
    // Le serveur exige `livreId` ET `etudiantId` : l'appel n'envoyait que
    // l'ouvrage et repartait en 400 — la réservation n'a jamais abouti depuis
    // l'application. L'étudiant est celui qui est connecté, jamais un autre :
    // le serveur le vérifie désormais.
    final etudiantId = context.read<AuthProvider>().user?.id ?? '';
    if (etudiantId.isEmpty) {
      setState(() {
        _message = 'Votre compte ne permet pas de réserver un ouvrage.';
        _messageSucces = false;
      });
      return;
    }
    try {
      await context.read<CommunService>().reserverOuvrage(ouvrage.id, etudiantId);
      if (!mounted) return;
      setState(() {
        _message = 'Réservation enregistrée pour « ${ouvrage.texte('titre')} ».';
        _messageSucces = true;
      });
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
    }
  }

  Future<void> _prolonger(Fiche emprunt) async {
    try {
      await context.read<CommunService>().prolongerEmprunt(emprunt.id);
      if (!mounted) return;
      setState(() {
        _message = 'Emprunt prolongé.';
        _messageSucces = true;
      });
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
    }
  }
}

class _CarteOuvrage extends StatelessWidget {
  final Fiche ouvrage;
  final VoidCallback? onReserver;

  const _CarteOuvrage({required this.ouvrage, this.onReserver});

  @override
  Widget build(BuildContext context) {
    final disponibles = ouvrage.entier('quantiteDisponible');

    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ouvrage.texte('titre', defaut: 'Ouvrage'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Pastille(
                texte: disponibles > 0 ? '$disponibles dispo.' : 'Indisponible',
                couleur: disponibles > 0
                    ? AppTheme.statutVert
                    : AppTheme.statutRouge,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ouvrage.texte('auteur', defaut: 'Auteur inconnu'),
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          if (ouvrage.texte('resume').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              ouvrage.texte('resume'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (ouvrage.texte('categorie').isNotEmpty)
                Chip(
                  label: Text(ouvrage.texte('categorie')),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              if (ouvrage.texte('typeOuvrage').isNotEmpty)
                Chip(
                  label: Text(ouvrage.texte('typeOuvrage')),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              if (ouvrage.texte('editeur').isNotEmpty)
                Chip(
                  label: Text(ouvrage.texte('editeur')),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          // Réserver un ouvrage à zéro exemplaire ne peut qu'échouer côté
          // serveur : le bouton disparaît plutôt que d'annoncer un refus.
          if (onReserver != null && disponibles > 0) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onReserver,
                icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                label: const Text('Réserver'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      AppTheme.accentLisible(context, AppTheme.statutBleu),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
