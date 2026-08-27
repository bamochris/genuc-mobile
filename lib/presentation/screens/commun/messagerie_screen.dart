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

/// Messagerie interne, commune aux deux portails.
///
/// La boîte de réception ne se lit pas à la même route selon le rôle
/// (`/messagerie/etudiant/{inscriptionId}` contre
/// `/messagerie/admin/{utilisateurId}`) : c'est la seule différence, le reste
/// — contacts, envoi, réponse, marquage — est identique.
class MessagerieScreen extends StatefulWidget {
  const MessagerieScreen({super.key});

  @override
  State<MessagerieScreen> createState() => _MessagerieScreenState();
}

class _MessagerieScreenState extends State<MessagerieScreen> {
  List<Fiche> _messages = const [];
  List<Fiche> _contacts = const [];
  bool _chargement = true;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

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
      final messages = estEtudiant
          ? await service.messagesEtudiant(cle)
          : await service.messagesPersonnel(cle);
      final contacts = (user?.universiteId ?? '').isEmpty
          ? <Fiche>[]
          : await service
              .contacts(user!.universiteId!)
              .catchError((_) => <Fiche>[]);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _contacts = contacts;
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
        vide: _messages.isEmpty,
        onReessayer: _charger,
        messageVide: 'Votre boîte de réception est vide.',
        iconeVide: Icons.mail_rounded,
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
            for (final message in _messages) ...[
              // Balayer pour supprimer : le geste que tout le monde essaie
              // d'abord sur une boîte de réception. La confirmation reste —
              // un balayage part vite, et la suppression est définitive.
              Dismissible(
                key: ValueKey('message-${message.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmerEtSupprimer(message),
                onDismissed: (_) => setState(
                    () => _messages.removeWhere((m) => m.id == message.id)),
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

  /// Identifiants dont la suppression est partie et n'est pas revenue.
  ///
  /// Rien n'empêchait de retaper la corbeille pendant l'appel : le second
  /// DELETE trouvait le message déjà retiré et son refus venait effacer le
  /// « Message supprimé » du premier. Sur un réseau lent — celui de nos
  /// utilisateurs — la double tape est la règle, pas l'exception.
  final Set<String> _suppressionsEnCours = <String>{};

  Future<void> _ouvrir(Fiche message) async {
    // Le marquage part sans être attendu : l'ouverture du fil ne doit pas
    // patienter sur une écriture accessoire, et son échec n'a pas d'effet
    // visible pour l'utilisateur.
    if (!message.booleen('lu')) {
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
    if (!mounted) return;
    if (action == 'supprimer') {
      await _supprimer(message);
      return;
    }
    if (action == null || action.isEmpty) return;

    try {
      await context.read<CommunService>().repondre(message.id, action);
      if (!mounted) return;
      setState(() {
        _message = 'Réponse envoyée.';
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

  /// Demande confirmation puis retire le message de la boîte. La garde
  /// serveur n'autorise que l'expéditeur, le destinataire ou le titulaire
  /// de la boîte étudiante — tout autre compte reçoit un refus.
  /// Confirme puis supprime. Ne retire RIEN de la liste : c'est l'appelant
  /// qui le fait, une fois l'animation de balayage terminée — retirer ici
  /// arracherait de l'arbre un `Dismissible` encore en train de s'effacer.
  ///
  /// @return vrai si le serveur a bien supprimé.
  Future<bool> _confirmerEtSupprimer(Fiche message) async {
    if (_suppressionsEnCours.contains(message.id)) return false;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le message ?'),
        content: Text(
          '« ${message.texte('sujet', defaut: '(sans objet)')} » '
          'disparaîtra de votre boîte de réception. Cette action est '
          'définitive.',
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
      setState(() {
        _message = 'Message supprimé.';
        _messageSucces = true;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
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
      setState(() => _messages.removeWhere((m) => m.id == message.id));
    }
  }

  Future<void> _composer() async {
    if (_contacts.isEmpty) {
      setState(() {
        _message = 'Aucun destinataire disponible pour votre établissement.';
        _messageSucces = false;
      });
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
      setState(() {
        _message = 'Message envoyé.';
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

class _CarteMessage extends StatelessWidget {
  final Fiche message;
  final VoidCallback onOuvrir;
  final VoidCallback onSupprimer;

  /// La suppression est partie et n'est pas revenue : le bouton devient un
  /// témoin d'attente et cesse de répondre.
  final bool suppressionEnCours;

  const _CarteMessage({
    required this.message,
    required this.onOuvrir,
    required this.onSupprimer,
    this.suppressionEnCours = false,
  });

  @override
  Widget build(BuildContext context) {
    final lu = message.booleen('lu');

    return CartePortail(
      onTap: onOuvrir,
      bordure: lu
          ? null
          : AppTheme.accentLisible(context, AppTheme.secondary)
              .withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!lu) ...[
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
                        fontWeight: lu ? FontWeight.w600 : FontWeight.w800,
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
              // Suppression : un geste secondaire, mais toujours à portée —
              // l'étudiant ne doit pas ouvrir le message pour faire le ménage.
              //
              // 44 px, pas 32 : la cible était plus petite que le minimum
              // tactile, collée à la date, sur une carte dont la moindre tape
              // à côté ouvre le message. Se tromper de cible coûte cher quand
              // l'action d'à côté est irréversible.
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
            'De : ${message.texte('expediteurNom', defaut: 'Établissement')}',
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
        ],
      ),
    );
  }
}

/// Lecture d'un message et rédaction de sa réponse, dans une feuille qui
/// occupe au plus 85 % de la hauteur — le clavier doit rester visible.
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
    final reponseExistante = message.texte('reponse');

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
                '${message.texte('expediteurNom', defaut: 'Établissement')} · '
                '${formatDate(message.texteOuNul('dateEnvoi'), avecHeure: true)}',
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
                        'Réponse de '
                        '${message.texte('reponseParNom', defaut: 'l\'établissement')}',
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
              TextField(
                controller: _reponse,
                maxLines: 4,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Répondre',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Suppression depuis la lecture : même destination que
                  // l'icône de la carte — la feuille renvoie l'intention,
                  // c'est l'écran qui confirme et exécute.
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, 'supprimer'),
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
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                  const SizedBox(width: 8),
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
                              [
                                c.texte('nom', alias: const ['nomComplet']),
                                if (c.texte('role').isNotEmpty)
                                  '(${c.texte('role').replaceAll('_', ' ')})',
                              ].join(' '),
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
