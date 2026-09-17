import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/services/appel_api.dart';
import '../../../data/services/commun_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/portail_widgets.dart';

/// Messagerie interne, commune aux deux portails — alignée sur le portail web
/// (17/09/2026) : reçus ET envoyés, lu / non lu, réponse, suppression.
///
/// La boîte ne se lit pas à la même route selon le rôle : l'étudiant a une
/// seule route qui rend ses reçus et ses envois (`/messagerie/etudiant/
/// {inscriptionId}`), le personnel en a deux (`/admin/{id}` et
/// `/envoyes/{id}`). Chaque message porte son `sens` (« RECU » / « ENVOYE »).
///
/// Supprimer ne retire le message QUE de la boîte de l'appelant : l'autre
/// partie le conserve (le serveur ne détruisait autrefois la ligne que pour
/// tout le monde à la fois).
class MessagerieScreen extends StatefulWidget {
  const MessagerieScreen({super.key});

  @override
  State<MessagerieScreen> createState() => _MessagerieScreenState();
}

const String _recu = 'RECU';
const String _envoye = 'ENVOYE';

bool _estEnvoye(Fiche m) => m.texte('sens') == _envoye;

/// Le message, avec son sens (celui que rend le serveur prime).
@visibleForTesting
Fiche avecSens(Fiche m, String sensParDefaut) =>
    Fiche({...m.donnees, 'sens': m.texte('sens', defaut: sensParDefaut)});

/// État de lecture d'un envoi, vu de l'expéditeur : « Lu », « Non lu », ou
/// « 3/12 lus » pour un envoi groupé.
@visibleForTesting
String etatLectureEnvoi(Fiche m) {
  final nb = m.entier('nbDestinataires', defaut: 1);
  if (nb > 1) return '${m.entier('nbLus')}/$nb lus';
  return m.booleen('lu') ? 'Lu' : 'Non lu';
}

/// Contacts qui désignent réellement un destinataire.
///
/// La liste du serveur mêle trois sortes d'entrées : des services génériques
/// (`scolarite`, `caisse`… — le serveur les résout vers un compte), des
/// enseignants (identifiant de COMPTE), et les services déclarés par
/// l'établissement, dont l'identifiant numérique est celui du SERVICE. Envoyé
/// comme destinataire, ce dernier était lu comme un compte : le message
/// partait chez quelqu'un d'autre. Ces entrées-là sont écartées.
@visibleForTesting
List<Fiche> contactsJoignables(List<Fiche> contacts) => contacts.where((c) {
      final id = c.id;
      if (id.isEmpty) return false;
      final numerique = int.tryParse(id) != null;
      return !numerique || c.texte('type') == 'PROFESSEUR';
    }).toList();

const Map<String, String> _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ç': 'c', 'é': 'e', 'è': 'e',
  'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i', 'í': 'i', 'ô': 'o', 'ö': 'o',
  'ó': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', 'ÿ': 'y', 'œ': 'oe',
};

/// Forme comparable d'un texte : minuscules, sans accents.
String _plat(String texte) {
  final bas = texte.toLowerCase();
  final sortie = StringBuffer();
  for (final r in bas.runes) {
    final c = String.fromCharCode(r);
    sortie.write(_accents[c] ?? c);
  }
  return sortie.toString();
}

/// Le message contient-il tous les mots cherchés ?
@visibleForTesting
bool correspondRecherche(Fiche m, String recherche) {
  final mots = _plat(recherche).split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
  if (mots.isEmpty) return true;
  final foin = _plat([
    m.texte('sujet'),
    m.texte('contenu'),
    m.texte('expediteurNom'),
    m.texte('destinataireNom'),
  ].join(' '));
  return mots.every(foin.contains);
}

class _MessagerieScreenState extends State<MessagerieScreen> {
  List<Fiche> _messages = const [];
  List<Fiche> _contacts = const [];
  bool _chargement = true;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;
  String _onglet = _recu;
  String _recherche = '';
  bool _nonLusSeuls = false;

  /// Identifiants dont la suppression est partie et n'est pas revenue.
  ///
  /// Rien n'empêchait de retaper la corbeille pendant l'appel : le second
  /// DELETE trouvait le message déjà retiré et son refus venait effacer le
  /// « Message supprimé » du premier. Sur un réseau lent — celui de nos
  /// utilisateurs — la double tape est la règle, pas l'exception.
  final Set<String> _suppressionsEnCours = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final user = context.read<AuthProvider>().user;
    final estEtudiant = (user?.role ?? '').toUpperCase() == 'ETUDIANT';
    final cle = estEtudiant ? (user?.inscriptionId ?? '') : (user?.id ?? '');
    if (cle.isEmpty) {
      setState(() {
        _chargement = false;
        _erreur = 'Compte incomplet : messagerie indisponible.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final service = context.read<CommunService>();
    try {
      final List<Fiche> messages;
      if (estEtudiant) {
        messages = [
          for (final m in await service.messagesEtudiant(cle)) avecSens(m, _recu),
        ];
      } else {
        final resultats = await Future.wait([
          service.messagesPersonnel(cle),
          service.messagesEnvoyes(cle),
        ]);
        messages = [
          for (final m in resultats[0]) avecSens(m, _recu),
          for (final m in resultats[1]) avecSens(m, _envoye),
        ];
      }
      final contacts = (user?.universiteId ?? '').isEmpty
          ? <Fiche>[]
          : await service
              .contacts(user!.universiteId!)
              .catchError((_) => <Fiche>[]);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _contacts = contactsJoignables(contacts);
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

  void _maj(String id, Map<String, dynamic> champs) {
    setState(() {
      _messages = [
        for (final m in _messages)
          m.id == id ? Fiche({...m.donnees, ...champs}) : m,
      ];
    });
  }

  void _signaler(String texte, {bool succes = true}) {
    setState(() {
      _message = texte;
      _messageSucces = succes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final recus = _messages.where((m) => !_estEnvoye(m)).toList();
    final envoyes = _messages.where(_estEnvoye).toList();
    final nbNonLus = recus.where((m) => !m.booleen('lu')).length;
    final affiches = (_onglet == _recu ? recus : envoyes)
        .where((m) => _onglet != _recu || !_nonLusSeuls || !m.booleen('lu'))
        .where((m) => correspondRecherche(m, _recherche))
        .toList();

    return PagePortail(
      titre: 'Messagerie',
      sousTitre: 'Échanges avec l\'établissement',
      onRafraichir: _charger,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _composer,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Écrire'),
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
            if (_message != null)
              BandeauMessage(
                message: _message!,
                succes: _messageSucces,
                onFermer: () => setState(() => _message = null),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(nbNonLus > 0
                      ? 'Reçus (${recus.length} · $nbNonLus non lu${nbNonLus > 1 ? 's' : ''})'
                      : 'Reçus (${recus.length})'),
                  selected: _onglet == _recu,
                  onSelected: (_) => setState(() => _onglet = _recu),
                ),
                ChoiceChip(
                  label: Text('Envoyés (${envoyes.length})'),
                  selected: _onglet == _envoye,
                  onSelected: (_) => setState(() => _onglet = _envoye),
                ),
              ],
            ),
            const SizedBox(height: 12),
            BarreFiltres(
              indice: 'Rechercher dans les messages…',
              onRecherche: (v) => setState(() => _recherche = v),
              filtres: [
                if (_onglet == _recu)
                  FilterChip(
                    label: const Text('Non lus seulement'),
                    selected: _nonLusSeuls,
                    onSelected: (v) => setState(() => _nonLusSeuls = v),
                  ),
              ],
            ),
            if (affiches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    _recherche.isNotEmpty || (_onglet == _recu && _nonLusSeuls)
                        ? 'Aucun message ne correspond.'
                        : _onglet == _recu
                            ? 'Aucun message reçu.'
                            : 'Aucun message envoyé.',
                    style: TextStyle(color: AppTheme.textMutedOf(context)),
                  ),
                ),
              ),
            for (final message in affiches) ...[
              // Balayer pour supprimer : le geste que tout le monde essaie
              // d'abord sur une boîte de réception. La confirmation reste —
              // un balayage part vite.
              Dismissible(
                key: ValueKey('message-${message.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmerEtSupprimer(message),
                onDismissed: (_) => setState(() => _messages = [
                      for (final m in _messages)
                        if (m.id != message.id) m,
                    ]),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      color: AppTheme.error, size: 26),
                ),
                child: _CarteMessage(
                  message: message,
                  onOuvrir: () => _ouvrir(message),
                  onSupprimer: () => _supprimer(message),
                  onBasculerLu: _estEnvoye(message)
                      ? null
                      : () => _basculerLu(message),
                  suppressionEnCours:
                      _suppressionsEnCours.contains(message.id),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _ouvrir(Fiche message) async {
    // Seul un message REÇU se marque lu. Le marquage part sans être attendu :
    // l'ouverture ne doit pas patienter sur une écriture accessoire.
    if (!_estEnvoye(message) && !message.booleen('lu')) {
      _maj(message.id, {'lu': true});
      context
          .read<CommunService>()
          .marquerMessageLu(message.id)
          .catchError((_) => const Fiche({}));
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FeuilleMessage(message: message),
    );
    if (!mounted || action == null || action.isEmpty) return;
    if (action == _actionSupprimer) {
      await _supprimer(message);
      return;
    }
    if (action == _actionNonLu) {
      await _basculerLu(Fiche({...message.donnees, 'lu': true}));
      return;
    }

    try {
      await context.read<CommunService>().repondre(message.id, action);
      if (!mounted) return;
      _signaler('Réponse envoyée.');
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _signaler(e is ApiException ? e.message : e.toString(), succes: false);
    }
  }

  Future<void> _basculerLu(Fiche message) async {
    final versLu = !message.booleen('lu');
    final service = context.read<CommunService>();
    try {
      if (versLu) {
        await service.marquerMessageLu(message.id);
      } else {
        await service.marquerMessageNonLu(message.id);
      }
      if (!mounted) return;
      _maj(message.id, {'lu': versLu});
    } catch (e) {
      if (!mounted) return;
      _signaler(e is ApiException ? e.message : e.toString(), succes: false);
    }
  }

  /// Confirme puis supprime. Ne retire RIEN de la liste : c'est l'appelant
  /// qui le fait, une fois l'animation de balayage terminée — retirer ici
  /// arracherait de l'arbre un `Dismissible` encore en train de s'effacer.
  ///
  /// @return vrai si le serveur a bien supprimé.
  Future<bool> _confirmerEtSupprimer(Fiche message) async {
    if (_suppressionsEnCours.contains(message.id)) return false;

    final envoye = _estEnvoye(message);
    final nb = message.entier('nbDestinataires', defaut: 1);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le message ?'),
        content: Text(
          '« ${message.texte('sujet', defaut: '(sans objet)')} » sera retiré '
          'de votre boîte${envoye && nb > 1 ? ' (envoi à $nb destinataires)' : ''}. '
          '${envoye ? 'Les destinataires le conservent.' : 'L\'expéditeur le conserve.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onError,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return false;

    setState(() => _suppressionsEnCours.add(message.id));
    try {
      await context.read<CommunService>().supprimerMessage(message.id);
      if (!mounted) return true;
      _signaler('Message supprimé.');
      return true;
    } catch (e) {
      if (!mounted) return false;
      _signaler(e is ApiException ? e.message : e.toString(), succes: false);
      return false;
    } finally {
      if (mounted) {
        setState(() => _suppressionsEnCours.remove(message.id));
      }
    }
  }

  /// Supprime depuis la corbeille de la carte ou depuis le message ouvert :
  /// aucune animation de balayage en cours, la ligne peut partir tout de suite.
  Future<void> _supprimer(Fiche message) async {
    if (await _confirmerEtSupprimer(message) && mounted) {
      setState(() => _messages = [
            for (final m in _messages)
              if (m.id != message.id) m,
          ]);
    }
  }

  Future<void> _composer() async {
    if (_contacts.isEmpty) {
      _signaler('Aucun destinataire disponible pour votre établissement.',
          succes: false);
      return;
    }

    final brouillon = await showModalBottomSheet<_Brouillon>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FeuilleComposition(contacts: _contacts),
    );
    if (brouillon == null || !mounted) return;

    try {
      await context.read<CommunService>().envoyerMessage({
        'destinataireId': brouillon.destinataireId,
        'sujet': brouillon.sujet,
        'contenu': brouillon.contenu,
      });
      if (!mounted) return;
      _signaler('Message envoyé.');
      await _charger();
    } catch (e) {
      if (!mounted) return;
      _signaler(e is ApiException ? e.message : e.toString(), succes: false);
    }
  }
}

const String _actionSupprimer = ' supprimer';
const String _actionNonLu = ' non-lu';

class _CarteMessage extends StatelessWidget {
  final Fiche message;
  final VoidCallback onOuvrir;
  final VoidCallback onSupprimer;

  /// Absent pour un message envoyé : « lu » y décrit le destinataire.
  final VoidCallback? onBasculerLu;

  /// La suppression est partie et n'est pas revenue : le bouton devient un
  /// témoin d'attente et cesse de répondre.
  final bool suppressionEnCours;

  const _CarteMessage({
    required this.message,
    required this.onOuvrir,
    required this.onSupprimer,
    this.onBasculerLu,
    this.suppressionEnCours = false,
  });

  @override
  Widget build(BuildContext context) {
    final envoye = _estEnvoye(message);
    final lu = message.booleen('lu');
    final nonLu = !envoye && !lu;

    return CartePortail(
      onTap: onOuvrir,
      bordure: nonLu
          ? AppTheme.accentLisible(context, AppTheme.secondary)
              .withValues(alpha: 0.5)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (nonLu) ...[
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5, right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentLisible(context, AppTheme.secondary),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  message.texte('sujet', defaut: '(sans objet)'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: nonLu ? FontWeight.w800 : FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatDate(message.texteOuNul('dateEnvoi')),
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMutedOf(context),
                ),
              ),
              // Actions toujours à portée, sans ouvrir le message. 44 px :
              // le minimum tactile, sur une carte dont la moindre tape à côté
              // ouvre le message.
              if (onBasculerLu != null)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    tooltip: lu ? 'Marquer non lu' : 'Marquer lu',
                    icon: Icon(lu
                        ? Icons.mark_email_unread_outlined
                        : Icons.mark_email_read_outlined),
                    onPressed: onBasculerLu,
                  ),
                ),
              SizedBox(
                width: 44,
                height: 44,
                child: suppressionEnCours
                    ? Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      )
                    : IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        tooltip: 'Supprimer',
                        color: Theme.of(context).colorScheme.error,
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: onSupprimer,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            envoye
                ? 'À : ${message.texte('destinataireNom', defaut: 'Administration')}'
                : 'De : ${message.texte('expediteurNom', defaut: 'Établissement')}',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message.texte('contenu'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMutedOf(context),
            ),
          ),
          if (nonLu || envoye || message.texte('reponse').isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (nonLu)
                  const Pastille(texte: 'Nouveau', couleur: AppTheme.warning),
                if (message.texte('reponse').isNotEmpty)
                  const Pastille(texte: 'Répondu', couleur: AppTheme.info),
                if (envoye)
                  Pastille(
                    texte: etatLectureEnvoi(message),
                    couleur: lu ? AppTheme.success : AppTheme.primaryLight,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Lecture d'un message et rédaction de sa réponse, dans une feuille qui
/// occupe au plus 85 % de la hauteur — le clavier doit rester visible.
///
/// Renvoie la réponse saisie, ou l'une des actions [_actionSupprimer] /
/// [_actionNonLu] : c'est l'écran qui confirme et exécute.
class _FeuilleMessage extends StatefulWidget {
  final Fiche message;

  const _FeuilleMessage({required this.message});

  @override
  State<_FeuilleMessage> createState() => _FeuilleMessageState();
}

class _FeuilleMessageState extends State<_FeuilleMessage> {
  final _reponse = TextEditingController();

  @override
  void dispose() {
    _reponse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final envoye = _estEnvoye(message);
    final reponseExistante = message.texte('reponse');
    // Un message automatique n'a personne derrière lui ; un envoi groupé se
    // répond destinataire par destinataire.
    final repondable = message.booleen('repondable', defaut: true);
    final correspondant = envoye
        ? message.texte('destinataireNom', defaut: 'le destinataire')
        : message.texte('expediteurNom', defaut: 'l\'expéditeur');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.texte('sujet', defaut: '(sans objet)'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                [
                  'De : ${message.texte('expediteurNom', defaut: 'Établissement')}',
                  'À : ${message.texte('destinataireNom', defaut: 'Administration')}',
                  formatDate(message.texteOuNul('dateEnvoi'), avecHeure: true),
                  if (envoye) etatLectureEnvoi(message),
                ].join(' · '),
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMutedOf(context),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message.texte('contenu'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (reponseExistante.isNotEmpty) ...[
                const SizedBox(height: 20),
                CartePortail(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          'Dernière réponse — '
                              '${message.texte('reponseParNom', defaut: 'l\'établissement')}',
                          if (message.texteOuNul('dateReponse') != null)
                            formatDate(message.texteOuNul('dateReponse'),
                                avecHeure: true),
                        ].join(', '),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reponseExistante,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (repondable)
                TextField(
                  controller: _reponse,
                  maxLines: 4,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Répondre à $correspondant',
                    alignLabelWithHint: true,
                  ),
                )
              else
                Text(
                  envoye
                      ? 'Envoi groupé : chaque destinataire vous répond individuellement.'
                      : 'Message automatique : il n\'attend pas de réponse.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, _actionSupprimer),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    label: Text(
                      'Supprimer',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  if (!envoye)
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context, _actionNonLu),
                      icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                      label: const Text('Marquer non lu'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                  if (repondable)
                    ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, _reponse.text.trim()),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Envoyer'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brouillon {
  final String destinataireId;
  final String sujet;
  final String contenu;

  const _Brouillon({
    required this.destinataireId,
    required this.sujet,
    required this.contenu,
  });
}

class _FeuilleComposition extends StatefulWidget {
  final List<Fiche> contacts;

  const _FeuilleComposition({required this.contacts});

  @override
  State<_FeuilleComposition> createState() => _FeuilleCompositionState();
}

class _FeuilleCompositionState extends State<_FeuilleComposition> {
  final _cleFormulaire = GlobalKey<FormState>();
  final _sujet = TextEditingController();
  final _contenu = TextEditingController();
  String? _destinataire;

  @override
  void dispose() {
    _sujet.dispose();
    _contenu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Form(
            key: _cleFormulaire,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nouveau message',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _destinataire,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Destinataire *'),
                  items: widget.contacts
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.texte('nom', alias: const ['nomComplet']),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Champ obligatoire' : null,
                  onChanged: (v) => setState(() => _destinataire = v),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _sujet,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Objet *'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Champ obligatoire'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contenu,
                  maxLines: 6,
                  minLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Message *',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Champ obligatoire'
                      : null,
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _envoyer,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Envoyer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _envoyer() {
    if (!(_cleFormulaire.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _Brouillon(
        destinataireId: _destinataire!,
        sujet: _sujet.text.trim(),
        contenu: _contenu.text.trim(),
      ),
    );
  }
}
