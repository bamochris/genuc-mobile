import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/portail_widgets.dart';

/// Confier ses cours sans prêter son compte.
///
/// ─── Ce que cet écran remplace ──────────────────────────────────────────────
///
/// Un professeur absent donnait ses identifiants à son chef de travaux ou à
/// son assistant. Tout ce que faisait le remplaçant était alors signé du
/// titulaire : une note saisie, un cours publié, une présence validée
/// devenaient indéfendables en cas de contestation, et le mot de passe
/// circulait. La délégation nominative est l'alternative — le délégué se
/// connecte avec SON compte, sur les cours du titulaire, et chaque écriture
/// porte son identité réelle.
///
/// ─── Ce qui la borne ────────────────────────────────────────────────────────
///
/// Date de fin obligatoire, un an au plus. Révocation immédiate par le
/// titulaire, renoncement possible par le délégué. Portée : un cours précis ou
/// tous. Jamais hors de son établissement, jamais sur un cours qu'on ne porte
/// pas. Et LES NOTES RESTENT FERMÉES par défaut : enregistrer une note la place
/// en statut SOUMISE, elle part en validation et engage la délibération — le
/// titulaire ouvre ce droit explicitement, ou pas du tout.
///
/// Tous ces refus viennent du serveur : cet écran ne les rejoue pas, il montre
/// le message qu'il reçoit. Deux jeux de règles qui divergent valent moins
/// qu'un seul.
class DelegationsScreen extends StatefulWidget {
  const DelegationsScreen({super.key});

  @override
  State<DelegationsScreen> createState() => _DelegationsScreenState();
}

class _DelegationsScreenState extends State<DelegationsScreen> {
  List<Fiche> _confiees = const [];
  List<Fiche> _recues = const [];
  Map<String, String> _mesCours = const {};

  bool _chargement = true;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  ProfesseurPedagogieService get _service =>
      context.read<ProfesseurPedagogieService>();

  Future<void> _charger() async {
    final service = _service;
    final professeurId = context.read<AuthProvider>().user?.id ?? '';
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final confiees = await service.mesDelegations();
      final recues = await service.delegationsPourMoi();
      // La liste des cours n'est qu'une commodité du formulaire : son échec ne
      // doit pas priver l'écran de ce qu'il a pour objet de montrer.
      List<Fiche> cours = const [];
      try {
        cours = await service.mesCours(professeurId);
      } catch (_) {
        cours = const [];
      }
      if (!mounted) return;
      setState(() {
        _confiees = confiees;
        _recues = recues;
        _mesCours = {
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

  Future<void> _ouvrirFormulaire() async {
    final cree = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _NouvelleDelegationScreen(mesCours: _mesCours),
      ),
    );
    if (cree == true && mounted) {
      setState(() {
        _message = 'La délégation est ouverte.';
        _messageSucces = true;
      });
      await _charger();
    }
  }

  Future<void> _revoquer(Fiche delegation, {required bool jeSuisLeDelegue}) async {
    final qui = jeSuisLeDelegue
        ? delegation.texte('titulaireNom', defaut: 'ce collègue')
        : delegation.texte('delegueNom', defaut: 'ce collègue');
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.link_off_rounded, color: AppTheme.statutRouge),
        title: Text(jeSuisLeDelegue ? 'Renoncer' : 'Révoquer la délégation'),
        content: Text(
          jeSuisLeDelegue
              ? 'Vous n\'agirez plus pour $qui. L\'accès cesse immédiatement.'
              : '$qui n\'aura plus accès à vos cours. L\'effet est immédiat, '
                  'et ce qui a déjà été fait reste au journal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(jeSuisLeDelegue ? 'Renoncer' : 'Révoquer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    try {
      await _service.revoquerDelegation(delegation.id);
      if (!mounted) return;
      setState(() {
        _message = 'La délégation est révoquée.';
        _messageSucces = true;
      });
      await _charger();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _messageSucces = false;
      });
    }
  }

  Future<void> _ouvrirJournal(Fiche delegation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _JournalDelegationScreen(
          delegationId: delegation.id,
          titre: delegation.texte('delegueNom', defaut: 'le délégué'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: 'Délégation de mes cours',
      sousTitre: 'Confier ses cours sans prêter son compte',
      onRafraichir: _charger,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ouvrirFormulaire,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Déléguer'),
      ),
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: false,
        onReessayer: _charger,
        enfant: ListView(
          padding: Responsive.margePage(context).copyWith(bottom: 96),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_message != null) ...[
              BandeauMessage(
                message: _message!,
                succes: _messageSucces,
                onFermer: () => setState(() => _message = null),
              ),
              const SizedBox(height: 12),
            ],
            const _RappelPrincipe(),
            const SizedBox(height: 16),
            const EnteteSection(
              titre: 'Ce que j\'ai confié',
              icone: Icons.outbound_rounded,
            ),
            if (_confiees.isEmpty)
              _Vide(
                texte: 'Vous n\'avez confié aucun cours. Le bouton « Déléguer » '
                    'ouvre une délégation nominative, bornée dans le temps.',
              )
            else
              for (final d in _confiees) ...[
                _CarteDelegation(
                  delegation: d,
                  vueDuDelegue: false,
                  onRevoquer: () => _revoquer(d, jeSuisLeDelegue: false),
                  onJournal: () => _ouvrirJournal(d),
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 16),
            const EnteteSection(
              titre: 'Ce pour quoi j\'agis',
              icone: Icons.inbox_rounded,
            ),
            if (_recues.isEmpty)
              _Vide(
                texte: 'Aucun collègue ne vous a confié ses cours.',
              )
            else
              for (final d in _recues) ...[
                _CarteDelegation(
                  delegation: d,
                  vueDuDelegue: true,
                  onRevoquer: () => _revoquer(d, jeSuisLeDelegue: true),
                  onJournal: null,
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _RappelPrincipe extends StatelessWidget {
  const _RappelPrincipe();

  @override
  Widget build(BuildContext context) {
    return CartePortail(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_rounded,
            size: 20,
            // `statutBleu` posé en dur tombe à 2,32:1 sur la carte en thème
            // sombre. `accentGraphique` calcule la teinte lisible SUR CE
            // fond-là, à la cible des tracés (3:1).
            color: AppTheme.accentGraphique(context, AppTheme.statutBleu),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Votre délégué se connecte avec SON compte : tout ce qu\'il fait '
              'porte son nom, et vous en gardez le journal. Une délégation a '
              'toujours un terme — un an au plus — et vous pouvez la révoquer '
              'à tout moment. Le droit de saisir des notes reste fermé tant '
              'que vous ne l\'ouvrez pas.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  final String texte;

  const _Vide({required this.texte});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        texte,
        style: TextStyle(fontSize: 13, color: AppTheme.textMutedOf(context)),
      ),
    );
  }
}

class _CarteDelegation extends StatelessWidget {
  final Fiche delegation;

  /// Vraie sur « ce pour quoi j'agis » : c'est alors le TITULAIRE qu'il faut
  /// nommer, pas le délégué — sur cette liste-là, le délégué c'est moi.
  final bool vueDuDelegue;

  final VoidCallback onRevoquer;
  final VoidCallback? onJournal;

  const _CarteDelegation({
    required this.delegation,
    required this.vueDuDelegue,
    required this.onRevoquer,
    this.onJournal,
  });

  @override
  Widget build(BuildContext context) {
    final active = delegation.booleen('active');
    // `enVigueur` est calculé au SERVEUR : une délégation révoquée ce matin a
    // toujours des dates valides, et l'horloge de l'appareil n'est pas une
    // référence.
    final enVigueur = delegation.booleen('enVigueur');
    final notes = delegation.booleen('autoriseNotes');

    final qui = vueDuDelegue
        ? delegation.texte('titulaireNom', defaut: 'Collègue')
        : delegation.texte('delegueNom', defaut: 'Collègue');

    final (libelleEtat, couleurEtat) = enVigueur
        ? ('En vigueur', AppTheme.statutVert)
        : active
            ? ('À venir / échue', AppTheme.statutOrange)
            : ('Révoquée', AppTheme.statutNavy);

    return CartePortail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  qui,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Pastille(texte: libelleEtat, couleur: couleurEtat),
            ],
          ),
          const SizedBox(height: 8),
          _Ligne(
            icone: Icons.menu_book_rounded,
            // `coursTitre` absent = délégation SUR TOUS les cours. Le dire,
            // parce que la portée est ce qui distingue un remplacement
            // ponctuel d'une procuration générale.
            texte: delegation.texteOuNul('coursTitre') ?? 'Tous mes cours',
          ),
          _Ligne(
            icone: Icons.date_range_rounded,
            texte: 'Du ${formatDate(delegation.texteOuNul('dateDebut'))} '
                'au ${formatDate(delegation.texteOuNul('dateFin'))}',
          ),
          _Ligne(
            icone: notes ? Icons.edit_note_rounded : Icons.lock_rounded,
            texte: notes
                ? 'Saisie des notes AUTORISÉE'
                : 'Saisie des notes fermée',
            couleur: notes ? AppTheme.statutOrange : null,
          ),
          if (delegation.texte('motif').isNotEmpty)
            _Ligne(
              icone: Icons.notes_rounded,
              texte: delegation.texte('motif'),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (onJournal != null)
                TextButton.icon(
                  onPressed: onJournal,
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text('Journal'),
                ),
              const Spacer(),
              if (active)
                TextButton.icon(
                  onPressed: onRevoquer,
                  icon: const Icon(Icons.link_off_rounded, size: 16),
                  label: Text(vueDuDelegue ? 'Renoncer' : 'Révoquer'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.statutRouge,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  final IconData icone;
  final String texte;
  final Color? couleur;

  const _Ligne({required this.icone, required this.texte, this.couleur});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icone,
            size: 15,
            color: couleur ?? AppTheme.iconAccent(context),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texte,
              style: TextStyle(
                fontSize: 12,
                color: couleur ?? AppTheme.textSecondaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Ouvrir une délégation
// ─────────────────────────────────────────────────────────────

/// Écran dédié plutôt que boîte de dialogue : la saisie enchaîne une RECHERCHE
/// de collègue (dont les résultats viennent du serveur, deux caractères au
/// moins) puis deux dates. Le formulaire déclaratif résout ses options une fois
/// pour toutes avant l'ouverture ; il ne sait pas faire ça.
class _NouvelleDelegationScreen extends StatefulWidget {
  final Map<String, String> mesCours;

  const _NouvelleDelegationScreen({required this.mesCours});

  @override
  State<_NouvelleDelegationScreen> createState() =>
      _NouvelleDelegationScreenState();
}

class _NouvelleDelegationScreenState extends State<_NouvelleDelegationScreen> {
  final _recherche = TextEditingController();
  final _motif = TextEditingController();

  List<Fiche> _resultats = const [];
  Fiche? _delegue;
  String? _coursId;
  DateTime? _debut;
  DateTime? _fin;
  bool _autoriseNotes = false;

  bool _cherche = false;
  bool _envoi = false;
  String? _message;

  @override
  void dispose() {
    _recherche.dispose();
    _motif.dispose();
    super.dispose();
  }

  Future<void> _chercher() async {
    final terme = _recherche.text.trim();
    if (terme.length < 2) {
      setState(() {
        _resultats = const [];
        _message = 'Tapez au moins deux caractères.';
      });
      return;
    }
    setState(() {
      _cherche = true;
      _message = null;
    });
    try {
      final r = await context
          .read<ProfesseurPedagogieService>()
          .colleguesDelegation(terme);
      if (!mounted) return;
      setState(() {
        _resultats = r;
        _cherche = false;
        if (r.isEmpty) {
          _message = 'Aucun professeur de votre établissement ne correspond.';
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cherche = false;
        _message = e.message;
      });
    }
  }

  Future<void> _choisirDate({required bool debut}) async {
    final aujourdhui = DateTime.now();
    final initiale = (debut ? _debut : _fin) ?? aujourdhui;
    final date = await showDatePicker(
      context: context,
      initialDate: initiale,
      firstDate: DateTime(aujourdhui.year - 1),
      // Un an au plus : c'est la borne que le serveur applique, autant ne pas
      // laisser choisir une date qu'il refusera.
      lastDate: DateTime(aujourdhui.year + 2),
    );
    if (date == null || !mounted) return;
    setState(() {
      if (debut) {
        _debut = date;
      } else {
        _fin = date;
      }
    });
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _valider() async {
    final delegue = _delegue;
    final debut = _debut;
    final fin = _fin;
    if (delegue == null) {
      setState(() => _message = 'Choisissez la personne à qui vous déléguez.');
      return;
    }
    if (debut == null || fin == null) {
      setState(() => _message =
          'Une délégation a toujours une date de début et une date de fin.');
      return;
    }

    setState(() {
      _envoi = true;
      _message = null;
    });
    try {
      await context.read<ProfesseurPedagogieService>().ouvrirDelegation(
            delegueId: delegue.id,
            coursId: _coursId,
            dateDebut: _iso(debut),
            dateFin: _iso(fin),
            autoriseNotes: _autoriseNotes,
            motif: _motif.text.trim().isEmpty ? null : _motif.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Le serveur explique POURQUOI il refuse — hors établissement, cours non
      // porté, chevauchement, durée. Rejouer ces règles ici les ferait
      // diverger ; on montre son message.
      setState(() {
        _envoi = false;
        _message = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PagePortail(
      titre: 'Nouvelle délégation',
      sousTitre: 'Nominative, et bornée dans le temps',
      corps: ListView(
        padding: Responsive.margePage(context).copyWith(bottom: 40),
        children: [
          if (_message != null) ...[
            BandeauMessage(
              message: _message!,
              succes: false,
              onFermer: () => setState(() => _message = null),
            ),
            const SizedBox(height: 12),
          ],
          const EnteteSection(
            titre: 'À qui',
            icone: Icons.person_search_rounded,
          ),
          TextField(
            controller: _recherche,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Nom, prénom ou courriel',
              hintText: 'Deux caractères au moins',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Chercher ce collègue',
                onPressed: _cherche ? null : _chercher,
              ),
            ),
            onSubmitted: (_) => _chercher(),
          ),
          if (_cherche)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          // `RadioListTile` est déprécié depuis Flutter 3.32 au profit d'un
          // `RadioGroup` ancêtre. Une tuile cochée fait le même travail ici,
          // sans imposer un widget de groupe autour d'une liste construite au
          // fil de la recherche.
          for (final c in _resultats)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _delegue?.id == c.id
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: _delegue?.id == c.id
                    ? AppTheme.iconAccent(context)
                    : AppTheme.textMutedOf(context),
              ),
              title: Text(c.texte('nom', defaut: c.texte('email'))),
              subtitle: Text(
                c.texte('email'),
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => setState(() => _delegue = c),
            ),
          const SizedBox(height: 16),
          const EnteteSection(
            titre: 'Sur quoi',
            icone: Icons.menu_book_rounded,
          ),
          DropdownButtonFormField<String>(
            initialValue: _coursId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Portée'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Tous mes cours'),
              ),
              for (final e in widget.mesCours.entries)
                DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _coursId = v),
          ),
          const SizedBox(height: 16),
          const EnteteSection(
            titre: 'Jusqu\'à quand',
            icone: Icons.date_range_rounded,
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _choisirDate(debut: true),
                  icon: const Icon(Icons.event_rounded, size: 16),
                  label: Text(
                    _debut == null ? 'Début' : formatDate(_iso(_debut!)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _choisirDate(debut: false),
                  icon: const Icon(Icons.event_available_rounded, size: 16),
                  label: Text(_fin == null ? 'Fin' : formatDate(_iso(_fin!))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'La date de fin est obligatoire : une délégation sans terme est une '
            'cession de compte déguisée, elle survit à l\'absence qui l\'a '
            'motivée et personne ne pense à la fermer.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textMutedOf(context),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _autoriseNotes,
            onChanged: (v) => setState(() => _autoriseNotes = v),
            title: const Text('Autoriser la saisie des notes'),
            subtitle: const Text(
              'Fermé par défaut : une note enregistrée part en validation et '
              'engage la délibération.',
              style: TextStyle(fontSize: 11),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motif,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motif (facultatif)',
              hintText: 'Mission, congé, maladie…',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _envoi ? null : _valider,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(_envoi ? 'Ouverture…' : 'Ouvrir la délégation'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Journal des actes
// ─────────────────────────────────────────────────────────────

/// Ce qui a été fait en mon nom, pendant cette délégation.
///
/// C'est précisément ce que la cession d'identifiants rendait impossible. Le
/// journal ne rend que l'acte, l'objet et la date : le titulaire doit savoir ce
/// qui a été fait, pas d'où son collègue s'est connecté.
class _JournalDelegationScreen extends StatefulWidget {
  final String delegationId;
  final String titre;

  const _JournalDelegationScreen({
    required this.delegationId,
    required this.titre,
  });

  @override
  State<_JournalDelegationScreen> createState() =>
      _JournalDelegationScreenState();
}

class _JournalDelegationScreenState extends State<_JournalDelegationScreen> {
  List<Fiche> _actes = const [];
  bool _chargement = true;
  String? _erreur;

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
      final actes = await context
          .read<ProfesseurPedagogieService>()
          .actesDelegation(widget.delegationId);
      if (!mounted) return;
      setState(() {
        _actes = actes;
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
      titre: 'Journal de la délégation',
      sousTitre: widget.titre,
      onRafraichir: _charger,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: _actes.isEmpty,
        onReessayer: _charger,
        iconeVide: Icons.history_rounded,
        messageVide: 'Aucun acte posé pendant cette délégation.',
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            for (final acte in _actes) ...[
              CartePortail(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      acte.texte('action', defaut: 'Action'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        acte.texte('entityType'),
                        if (acte.texteOuNul('entityId') != null)
                          '#${acte.texte('entityId')}',
                      ].where((t) => t.isNotEmpty).join(' '),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDate(acte.texteOuNul('createdAt'), avecHeure: true),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMutedOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
