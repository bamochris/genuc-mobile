import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/api_exception.dart';
import '../../../data/services/api_service.dart';

/// Première connexion d'un étudiant dont le dossier vient d'une migration.
///
/// Correspond à `PremiereConnexion.jsx` puis `ActivationCompte.jsx` du web.
/// Ces étudiants n'ont jamais reçu de lien d'activation : leur registre
/// d'origine ne portait le plus souvent aucune adresse, et leur compte a été
/// créé fermé par l'import. Le matricule et la date de naissance rendent un
/// jeton de 30 minutes ; l'étudiant choisit alors son mot de passe, puis se
/// connecte normalement avec son matricule.
class PremiereConnexionScreen extends StatefulWidget {
  const PremiereConnexionScreen({super.key});

  @override
  State<PremiereConnexionScreen> createState() =>
      _PremiereConnexionScreenState();
}

class _PremiereConnexionScreenState extends State<PremiereConnexionScreen> {
  final _formIdentite = GlobalKey<FormState>();
  final _formMotDePasse = GlobalKey<FormState>();
  final _matriculeController = TextEditingController();
  final _motDePasseController = TextEditingController();
  final _confirmationController = TextEditingController();

  DateTime? _dateNaissance;
  String? _jeton;
  String? _nom;
  String? _erreur;
  bool _enCours = false;
  bool _masquer = true;

  @override
  void dispose() {
    _matriculeController.dispose();
    _motDePasseController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _lisible(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _choisirDate() async {
    final maintenant = DateTime.now();
    final choix = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime(maintenant.year - 20),
      firstDate: DateTime(1940),
      lastDate: maintenant,
      helpText: 'Date de naissance',
    );
    if (choix != null) setState(() => _dateNaissance = choix);
  }

  Future<void> _verifierIdentite() async {
    if (!_formIdentite.currentState!.validate()) return;
    if (_dateNaissance == null) {
      setState(() => _erreur = 'La date de naissance est obligatoire.');
      return;
    }
    await _appeler(() async {
      final reponse = await context.read<ApiService>().premiereConnexion(
            matricule: _matriculeController.text.trim().toUpperCase(),
            dateNaissance: _iso(_dateNaissance!),
          );
      final jeton = reponse['token']?.toString();
      if (jeton == null || jeton.isEmpty) {
        throw const ApiException(
            'Impossible de vérifier votre identité pour le moment.');
      }
      final nom = [reponse['prenom'], reponse['nom']]
          .where((p) => p != null && p.toString().isNotEmpty)
          .join(' ');
      setState(() {
        _jeton = jeton;
        _nom = nom.isEmpty ? null : nom;
      });
    });
  }

  Future<void> _creerMotDePasse() async {
    if (!_formMotDePasse.currentState!.validate()) return;
    await _appeler(() async {
      final reponse = await context.read<ApiService>().creerMotDePasse(
            token: _jeton!,
            motDePasse: _motDePasseController.text,
            confirmation: _confirmationController.text,
          );
      if (!mounted) return;
      final message = reponse['message']?.toString() ??
          'Compte activé. Connectez-vous avec votre matricule.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$message Utilisez votre matricule.')),
      );
      Navigator.of(context).pop(_matriculeController.text.trim().toUpperCase());
    });
  }

  /// Exécute un appel en affichant le refus du serveur tel quel : il dit
  /// « matricule ou date incorrects », « jeton expiré », ce qui manque au mot
  /// de passe — une erreur générique ferait réessayer à l'aveugle.
  Future<void> _appeler(Future<void> Function() appel) async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await appel();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _erreur = 'Impossible de vérifier votre identité pour le moment.');
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Première connexion')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _jeton == null
                        ? 'Votre dossier a été repris depuis les registres de '
                            'votre établissement. Identifiez-vous une première '
                            'fois pour ouvrir votre portail.'
                        : 'Bienvenue${_nom != null ? ', $_nom' : ''}. Choisissez '
                            'votre mot de passe. Vous vous connecterez ensuite '
                            'avec votre matricule.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  if (_erreur != null) ...[
                    Text(
                      _erreur!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_jeton == null) _identite() else _motDePasse(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _identite() {
    return Form(
      key: _formIdentite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _matriculeController,
            textCapitalization: TextCapitalization.characters,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              labelText: 'Matricule',
              helperText: 'Celui qui figure sur vos documents',
              prefixIcon: Icon(Icons.badge_rounded),
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Le matricule est obligatoire'
                : null,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _enCours ? null : _choisirDate,
            icon: const Icon(Icons.cake_rounded),
            label: Text(_dateNaissance == null
                ? 'Date de naissance'
                : 'Né(e) le ${_lisible(_dateNaissance!)}'),
          ),
          const SizedBox(height: 24),
          _bouton('Continuer', _verifierIdentite),
        ],
      ),
    );
  }

  Widget _motDePasse() {
    return Form(
      key: _formMotDePasse,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _motDePasseController,
            obscureText: _masquer,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                icon: Icon(_masquer
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded),
                tooltip: _masquer
                    ? 'Afficher le mot de passe'
                    : 'Masquer le mot de passe',
                onPressed: () => setState(() => _masquer = !_masquer),
              ),
            ),
            // La politique complète est vérifiée par le serveur, qui dit ce
            // qui manque ; seul le plancher de la connexion est rappelé ici.
            validator: (v) => v == null || v.length < 8
                ? 'Au moins 8 caractères'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmationController,
            obscureText: _masquer,
            decoration: const InputDecoration(
              labelText: 'Confirmer le mot de passe',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            validator: (v) => v != _motDePasseController.text
                ? 'Les mots de passe ne correspondent pas'
                : null,
          ),
          const SizedBox(height: 24),
          _bouton('Activer mon compte', _creerMotDePasse),
        ],
      ),
    );
  }

  Widget _bouton(String libelle, Future<void> Function() action) {
    return ElevatedButton(
      onPressed: _enCours ? null : action,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: _enCours
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(libelle),
    );
  }
}
