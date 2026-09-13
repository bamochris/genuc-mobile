// lib/presentation/screens/etudiant/paiements/tachpay_flow.dart
//
// Flux de paiement TachPay mobile — TROIS écrans, pas plus.
//
//   ① Mes frais        : ce que l'étudiant doit (cases à cocher)
//   ② Paiement         : opérateur mobile money + téléphone (pré-rempli)
//   ③ Confirmation     : référence, polling du statut, bon PDF
//
// Design : fond clair, logo TachPay en header, une action par écran.
// Le contenu du paiement n'est JAMAIS accessible sans session — tout le
// flux est atteint depuis l'app connectée.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/services/tachpay_service.dart';
import '../../../../core/utils/dio_client.dart';

/// Point d'entrée du flux — pousse les 3 écrans en séquence.
void ouvrirFluxTachPay(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const TachPayEcranFrais()),
  );
}

class TachPayEcranFrais extends StatefulWidget {
  const TachPayEcranFrais({super.key});

  @override
  State<TachPayEcranFrais> createState() => _TachPayEcranFraisState();
}

class _TachPayEcranFraisState extends State<TachPayEcranFrais> {
  // `DioClient()` est un SINGLETON (`_instance ??= …`) : on récupère donc le
  // client de l'application, avec son pot à cookies et ses intercepteurs de
  // session. Ce qui était écrit ici — `Dependencies.creer()` — construisait en
  // revanche un `CacheService` NEUF à chaque ouverture du flux, et celui-ci
  // arme un `Timer.periodic` dans son constructeur que personne ne libère :
  // un minuteur de plus à chaque visite de l'écran de paiement. Le commentaire
  // d'origine affirmait justement qu'on ne recréait rien.
  late final TachPayService _tach;

  CheckoutContext? _ctx;
  MoyensPaiement _moyens = const MoyensPaiement.aucun();
  final Set<int> _coches = {};
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _tach = TachPayService(DioClient().dio);
    _charger();
  }

  Future<void> _charger() async {
    try {
      final ctx = await _tach.checkoutContext();
      // Un échec de LECTURE des moyens de paiement ne doit pas fermer le
      // parcours : l'étudiant doit pouvoir aller jusqu'à la confirmation, où le
      // serveur tranche. On repart donc d'un état « rien de publié » plutôt que
      // de faire remonter l'erreur.
      MoyensPaiement moyens = const MoyensPaiement.aucun();
      if (ctx.universiteId.isNotEmpty) {
        try {
          moyens = await _tach.moyensPaiement(ctx.universiteId);
        } on ApiException catch (e) {
          TachPayService.debugLog('moyens de paiement illisibles : ${e.message}');
        }
      }
      if (!mounted) return;
      setState(() {
        _ctx = ctx;
        // Tout cocher par défaut : l'étudiant paie d'ordinaire la totalité ;
        // décocher reste possible en un tap.
        _coches.addAll(ctx.frais.map((f) => f.affectationId));
        _moyens = moyens;
        _chargement = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _erreur = e.message; _chargement = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _erreur = 'Erreur de chargement : $e'; _chargement = false; });
    }
  }

  double get _totalSelectionne {
    if (_ctx == null) return 0;
    return _ctx!.frais
        .where((f) => _coches.contains(f.affectationId))
        .fold(0, (somme, f) => somme + f.reste);
  }

  Future<void> _ouvrirPaiement() async {
    final reference = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => TachPayEcranPaiement(
          service: _tach,
          contexte: _ctx!,
          affectationIds: _coches.toList(),
          total: _totalSelectionne,
          moyens: _moyens,
        ),
      ),
    );
    if (reference != null && mounted) {
      // Paiement réussi → écran de confirmation avec bon téléchargeable.
      // Les affectations réglées sont celles qui viennent d'être payées : on
      // les transmet. Les redemander au serveur ne marche pas — voir
      // `TachPayEcranConfirmation`.
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => TachPayEcranConfirmation(
            service: _tach, reference: reference, affectationIds: _coches.toList()),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: Image.asset('assets/images/logo-tachpay.png', height: 34),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _erreur != null
              ? _VueErreur(message: _erreur!, onReessayer: _charger)
              : _contenu(),
    );
  }

  Widget _contenu() {
    final ctx = _ctx!;
    final estSombre = Theme.of(context).brightness == Brightness.dark;
    // Mode sombre : cartes relevées et textes TRÈS clairs pour une lecture
    // immédiate ; icônes de sélection en blanc pur quand cochées.
    final fondCarte = estSombre ? const Color(0xFF1B2534) : Colors.white;
    final textePrincipal = estSombre ? const Color(0xFFF7F9FC) : const Color(0xFF14213D);
    final texteSecondaire = estSombre ? const Color(0xFFAFC0D6) : Colors.grey.shade600;
    final bordureCarte = estSombre ? const Color(0xFF33415C) : Colors.grey.shade200;
    final fondPage = estSombre ? const Color(0xFF0D1420) : const Color(0xFFF6F8FB);

    return Scaffold(
      backgroundColor: fondPage,
      body: Column(
        children: [
          // Bandeau étudiant
        Container(
          width: double.infinity,
          color: fondCarte,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primary.withValues(alpha: .15),
              child: Text(
                ctx.nomComplet.isNotEmpty ? ctx.nomComplet[0].toUpperCase() : '?',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: estSombre
                        ? const Color(0xFFFFB74D)
                        : const Color(0xFF7FB2F0)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ctx.nomComplet, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textePrincipal)),
              const SizedBox(height: 2),
              Text('${ctx.matricule} · ${ctx.universiteNom}',
                  style: TextStyle(fontSize: 12, color: texteSecondaire)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Total dû', style: TextStyle(fontSize: 11, color: texteSecondaire)),
              Text(formatMontant(ctx.total),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      // Dark : orange clair (lisibilité + repère « à payer ») ;
                      // clair : bleu TachPay conservé.
                      color: estSombre
                          ? const Color(0xFFFFB74D)
                          : const Color(0xFF7FB2F0))),
            ]),
          ]),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Padding(padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text('Sélectionnez les frais à payer',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textePrincipal))),
              ...ctx.frais.map((f) => _carteFrais(f, fondCarte, textePrincipal, texteSecondaire, bordureCarte)),

              ],
            ),
          ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: fondCarte,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            Expanded(child: Text('Sélection : ${formatMontant(_totalSelectionne)}',
                style: TextStyle(fontWeight: FontWeight.w700, color: textePrincipal))),
            ElevatedButton(
              onPressed: _coches.isEmpty ? null : _ouvrirPaiement,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continuer', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _carteFrais(FraisDu f, Color fondCarte, Color textePrincipal,
      Color texteSecondaire, Color bordureCarte) {
    final coche = _coches.contains(f.affectationId);
    final estSombre = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => coche ? _coches.remove(f.affectationId) : _coches.add(f.affectationId)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fondCarte,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: coche
                  ? (estSombre ? const Color(0xFF7FB2F0) : AppTheme.primary)
                  : bordureCarte,
              width: coche ? 2 : 1),
        ),
        child: Row(children: [
          Icon(coche ? Icons.check_circle : Icons.radio_button_unchecked,
              color: coche
                  ? (estSombre ? Colors.white : AppTheme.primary)
                  : (estSombre ? Colors.grey.shade500 : Colors.grey.shade400)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.libelle, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textePrincipal)),
            if ((f.dateEcheance ?? '').isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 3),
                child: Text('Échéance ${f.dateEcheance}',
                    style: TextStyle(fontSize: 11.5, color: texteSecondaire))),
          ])),
          Text(formatMontant(f.reste), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textePrincipal)),
        ]),
      ),
    );
  }
}

// ═══ ÉCRAN ② — MOYEN DE PAIEMENT ═════════════════════════════

class TachPayEcranPaiement extends StatefulWidget {
  final TachPayService service;
  final CheckoutContext contexte;
  final List<int> affectationIds;
  final double total;
  final MoyensPaiement moyens;

  const TachPayEcranPaiement({
    super.key,
    required this.service,
    required this.contexte,
    required this.affectationIds,
    required this.total,
    required this.moyens,
  });

  /// Ce que l'écran propose de choisir.
  ///
  /// Quand l'établissement n'a publié aucun compte d'encaissement, le serveur
  /// rend une liste VIDE. L'écran affichait alors « Aucun opérateur configuré »
  /// en rouge, sans rien à cocher : plus aucun geste n'était possible, et le
  /// bouton « Confirmer et payer » répondait « Choisissez un opérateur » —
  /// indéfiniment. On retombe donc sur les opérateurs que le serveur sait
  /// initier : le parcours va jusqu'au bout, et c'est la confirmation qui
  /// prononce le refus, avec le motif du serveur.
  List<OperateurMobile> get operateursProposes =>
      moyens.operateurs.isEmpty ? OperateurMobile.connus : moyens.operateurs;

  @override
  State<TachPayEcranPaiement> createState() => _TachPayEcranPaiementState();
}

class _TachPayEcranPaiementState extends State<TachPayEcranPaiement> {
  late final TextEditingController _tel = TextEditingController(
      // Pré-rempli avec le numéro du compte : l'étudiant ne tape rien s'il
      // paie depuis son propre numéro mobile money.
      text: widget.contexte.telephone ?? '');
  String? _operateurChoisi;
  bool _envoi = false;
  String? _erreur;
  /// Vrai quand rien de ce que l'étudiant peut saisir ne changera la réponse.
  bool _refusDefinitif = false;

  Future<void> _confirmer() async {
    final tel = _tel.text.trim();
    if (_operateurChoisi == null) { setState(() => _erreur = 'Choisissez un opérateur'); return; }
    if (tel.length < 9) { setState(() => _erreur = 'Numéro de téléphone invalide'); return; }

    setState(() { _envoi = true; _erreur = null; });
    try {
      final initie = await widget.service.payerMobile(
          affectationIds: widget.affectationIds,
          telephone: tel,
          operateur: _operateurChoisi!);

      if (!mounted) return;

      if (initie.echoue) {
        setState(() { _envoi = false; _erreur = initie.message; });
        return;
      }

      // Polling du statut : USSD de confirmation côté opérateur peut prendre
      // quelques dizaines de secondes. On interroge toutes les 4 s, 15 fois max.
      PaiementInitie dernier = initie;
      for (var i = 0; i < 15 && dernier.enAttente; i++) {
        await Future.delayed(const Duration(seconds: 4));
        try {
          dernier = await widget.service.statutPaiement(initie.reference);
        } on ApiException {
          continue; // erreur passagère réseau : on retente au prochain tour
        }
      }

      if (!mounted) return;
      if (dernier.succes) {
        Navigator.of(context).pop(initie.reference); // → écran confirmation
      } else if (dernier.echoue) {
        setState(() { _envoi = false; _erreur = 'Paiement refusé : ${dernier.message}'; });
      } else {
        // Toujours PENDING après ~60 s : le paiement vit côté opérateur,
        // on sort avec la référence pour ne pas bloquer l'utilisateur.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Toujours en attente — vérifiez plus tard (réf. ${initie.reference})'),
          duration: const Duration(seconds: 6)));
        Navigator.of(context).pop(initie.reference);
      }
    } on ApiException catch (e) {
      setState(() {
        _envoi = false;
        // Le message vient du serveur et nomme la cause réelle
        // (« Cet établissement n'a pas encore configuré ses moyens de
        // paiement », « … n'a pas activé l'encaissement en ligne »). Il était
        // jusqu'ici aplati en « Requête invalide » par le contrôleur, ce qui
        // envoyait l'étudiant corriger une saisie correcte.
        _erreur = e.estModePilote
            ? 'Les paiements en ligne ne sont pas encore activés — bientôt disponible.'
            : e.message;
        // Ce refus ne se corrige pas en retapant : il faut passer par la caisse.
        _refusDefinitif = widget.moyens.sansNumeroDEncaissement || e.estModePilote;
      });
    } catch (e) {
      setState(() { _envoi = false; _erreur = 'Erreur inattendue : $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final estSombre = Theme.of(context).brightness == Brightness.dark;
    final fondCarte = estSombre ? const Color(0xFF1B2534) : Colors.white;
    final textePrincipal = estSombre ? const Color(0xFFF7F9FC) : const Color(0xFF14213D);
    final bordureCarte = estSombre ? const Color(0xFF33415C) : Colors.grey.shade300;
    final fondPage = estSombre ? const Color(0xFF0D1420) : const Color(0xFFF6F8FB);
    return Scaffold(
      backgroundColor: fondPage,
      appBar: AppBar(title: const Text('Moyen de paiement'),
        backgroundColor: estSombre ? const Color(0xFF16202E) : Colors.white,
        foregroundColor: estSombre ? Colors.white : Colors.black87,
        elevation: 0.5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Total
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              const Text('Total à payer', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(formatMontant(widget.total),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
            ]),
          ),

          const SizedBox(height: 20),
          Text('OPÉRATEUR MOBILE MONEY',
              style: TextStyle(fontSize: 11.5, letterSpacing: .5,
                  color: estSombre ? Colors.grey.shade400 : Colors.grey, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          if (widget.moyens.sansNumeroDEncaissement) _avertissementEncaissement(estSombre),
          ...widget.operateursProposes.map(_carteOperateur),

          const SizedBox(height: 20),
          Text('NUMÉRO DE TÉLÉPHONE',
              style: TextStyle(fontSize: 11.5, letterSpacing: .5,
                  color: estSombre ? Colors.grey.shade400 : Colors.grey, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: textePrincipal),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[+\d ]'))],
            decoration: InputDecoration(
              hintText: '+243 XX XXX XXXX',
              hintStyle: TextStyle(color: estSombre ? Colors.grey.shade500 : Colors.grey.shade400),
              fillColor: fondCarte, filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: bordureCarte)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: bordureCarte)),
            ),
          ),
          if ((widget.contexte.telephone ?? '').isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text('Pré-rempli depuis votre profil',
                  style: TextStyle(fontSize: 11,
                      color: estSombre ? Colors.grey.shade500 : Colors.grey.shade500))),

          if (_erreur != null)
            Container(margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_erreur!, style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 13)),
                // Un message d'erreur qui ne dit pas quoi faire se lit comme une
                // panne de l'application. Ici la voie de règlement existe, elle
                // passe seulement par le guichet.
                if (_refusDefinitif) const Padding(padding: EdgeInsets.only(top: 8),
                  child: Text(
                      'Rien à corriger de votre côté : votre établissement doit d’abord '
                      'publier son compte d’encaissement. En attendant, réglez vos frais '
                      'à la caisse — votre reçu y sera enregistré de la même manière.',
                      style: TextStyle(color: Color(0xFF8C2F26), fontSize: 12.5, height: 1.4))),
              ])),

          const SizedBox(height: 24),
          SizedBox(height: 52,
            child: ElevatedButton.icon(
              icon: _envoi ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.lock_outline),
              label: Text(_envoi ? 'Traitement…' : 'Confirmer et payer',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              onPressed: _envoi ? null : _confirmer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
            ),
          ),
          const SizedBox(height: 10),
          Center(child: Text('Paiement sécurisé TachPay 🔒',
              style: TextStyle(fontSize: 11.5,
                  color: estSombre ? Colors.grey.shade400 : Colors.grey))),
        ]),
      ),
    );
  }

  /// Dit, AVANT la saisie, que ce paiement va probablement être refusé — et
  /// pourquoi. C'est la contrepartie du parcours laissé ouvert : on ne bloque
  /// plus l'étudiant, mais on ne lui laisse pas croire que tout est prêt.
  Widget _avertissementEncaissement(bool estSombre) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: estSombre ? const Color(0xFF3A2E12) : const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0A100).withValues(alpha: .45)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded, size: 19, color: Color(0xFFB26A00)),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'Votre établissement n’a pas encore publié son compte d’encaissement. '
          'Vous pouvez poursuivre : la demande sera vérifiée à la confirmation.',
          style: TextStyle(
              fontSize: 12.5, height: 1.4,
              color: estSombre ? const Color(0xFFF0D9A8) : const Color(0xFF7A4B00)),
        )),
      ]),
    );
  }

  Widget _carteOperateur(OperateurMobile o) {
    final choisi = _operateurChoisi == o.code;
    final estSombre = Theme.of(context).brightness == Brightness.dark;
    final fondCarte = estSombre ? const Color(0xFF1B2534) : Colors.white;
    final textePrincipal = estSombre ? const Color(0xFFF7F9FC) : const Color(0xFF14213D);
    final bordureCarte = estSombre ? const Color(0xFF33415C) : Colors.grey.shade300;
    return GestureDetector(
      onTap: () => setState(() => _operateurChoisi = o.code),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: fondCarte,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: choisi ? (estSombre ? const Color(0xFF7FB2F0) : AppTheme.primary) : bordureCarte,
              width: choisi ? 2 : 1),
        ),
        child: Row(children: [
          Icon(choisi ? Icons.check_circle : Icons.circle_outlined,
              color: choisi
                  ? (estSombre ? Colors.white : AppTheme.primary)
                  : (estSombre ? Colors.grey.shade500 : Colors.grey.shade400),
              size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.libelle,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: textePrincipal)),
            if (o.aUnNumeroDEncaissement)
              Padding(padding: const EdgeInsets.only(top: 3),
                child: Text('Encaissement : ${o.numero}',
                    style: TextStyle(fontSize: 11.5,
                        color: estSombre ? Colors.grey.shade400 : Colors.grey.shade600)))
            else
              Padding(padding: const EdgeInsets.only(top: 3),
                child: Text('Compte d’encaissement non encore publié',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFFB26A00)))),
          ])),
          Icon(Icons.chevron_right, color: estSombre ? Colors.grey.shade400 : Colors.grey),
        ]),
      ),
    );
  }
}

// ═══ ÉCRAN ③ — CONFIRMATION + BON ════════════════════════════

class TachPayEcranConfirmation extends StatefulWidget {
  final TachPayService service;
  final String reference;

  /// Les affectations que ce paiement vient de régler.
  final List<int> affectationIds;

  const TachPayEcranConfirmation({
    super.key,
    required this.service,
    required this.reference,
    required this.affectationIds,
  });

  @override
  State<TachPayEcranConfirmation> createState() => _TachPayEcranConfirmationState();
}

class _TachPayEcranConfirmationState extends State<TachPayEcranConfirmation> {
  List<BonDePaiementInfo>? _bons;
  bool _generationBon = false;
  bool _telechargement = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    // Le bon se génère dès l'arrivée sur cet écran : l'étudiant n'a rien à
    // demander, il n'a qu'à le télécharger.
    _genererBon();
  }

  Future<void> _genererBon() async {
    setState(() => _generationBon = true);
    try {
      // ⚠ Les IDs viennent de l'écran précédent, PAS d'une relecture du
      // checkout. L'ancienne version rappelait `checkoutContext()` et gardait
      // les frais dont `reste <= 0` — or ce contexte ne liste que les dettes
      // ACTIVES (`findDettesActivesByInscription` : statut EN_ATTENTE ou
      // PARTIEL). Un frais qui vient d'être soldé passe à PAYE et DISPARAÎT de
      // la réponse : le filtre ne trouvait jamais rien, `genererBon([])` ne
      // rendait aucun bon, et l'écran affichait indéfiniment « Le bon sera
      // disponible dès la confirmation du paiement ». Le dernier geste du
      // parcours — repartir avec son reçu — n'a donc jamais fonctionné.
      final bons = await widget.service.genererBon(widget.affectationIds);
      if (!mounted) return;
      setState(() { _bons = bons; _generationBon = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _generationBon = false; _message = e.message; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _generationBon = false; _message = '$e'; });
    }
  }


  Future<void> _telechargerPdf(BonDePaiementInfo bon) async {
    setState(() => _telechargement = true);
    try {
      final octets = await widget.service.telechargerBonPdf(bon.numero);
      final dir = await getApplicationDocumentsDirectory();
      final fichier = File('${dir.path}/bon_paiement_${bon.numero}.pdf');
      await fichier.writeAsBytes(Uint8List.fromList(octets));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Bon enregistré : ${fichier.path}'),
          duration: const Duration(seconds: 5)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec du téléchargement : $e')));
    } finally {
      if (mounted) setState(() => _telechargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estSombre = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: estSombre ? const Color(0xFF0D1420) : const Color(0xFFF6F8FB),
      appBar: AppBar(title: Image.asset('assets/images/logo-tachpay.png', height: 30),
        backgroundColor: estSombre ? const Color(0xFF16202E) : Colors.white,
        elevation: 0.5, centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 92, height: 92,
              decoration: const BoxDecoration(color: Color(0xFFDFF0D8), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 56, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 18),
            const Text('Paiement initié', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Référence ${widget.reference}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 24),

            Container(width: double.infinity, padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: estSombre ? const Color(0xFF1B2534) : Colors.white,
                  borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                if (_generationBon) const Padding(padding: EdgeInsets.symmetric(vertical: 10),
                    child: CircularProgressIndicator(color: AppTheme.primary))
                else if (_bons == null || _bons!.isEmpty)
                  Text(_message ?? 'Le bon sera disponible dès la confirmation du paiement.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
                else
                  ..._bons!.map((bon) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFB71C1C), size: 30),
                        title: Text('Bon ${bon.numero}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(formatMontant(bon.montant)),
                        trailing: _telechargement
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : IconButton(
                                icon: const Icon(Icons.download_rounded,
                                    color: AppTheme.primary),
                                tooltip: 'Télécharger le bon ${bon.numero}',
                                onPressed: () => _telechargerPdf(bon)),
                      )),
              ]),
            ),

            const SizedBox(height: 28),
            SizedBox(width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                child: const Text('Terminer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              )),
          ]),
        ),
      ),
    );
  }
}

// ═══ ERREUR ══════════════════════════════════════════════════

class _VueErreur extends StatelessWidget {
  final String message;
  final VoidCallback onReessayer;
  const _VueErreur({required this.message, required this.onReessayer});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.grey),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black87)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: onReessayer,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white),
          child: const Text('Réessayer')),
      ])));
  }
}

// formatMontant importé de core/utils/formatters.dart.

// Référence utilisée indirectement (évite l'avertissement d'import inutilisé).
// ignore: unused_element
final _refAppConstants = AppConstants.appName;
