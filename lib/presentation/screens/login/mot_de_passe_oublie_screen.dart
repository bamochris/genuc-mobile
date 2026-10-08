import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/services/api_service.dart';
import 'premiere_connexion_screen.dart';

/// « Mot de passe oublié » — correspond à `MotDePasseOublie.jsx` du web.
///
/// Le serveur envoie un lien à usage unique (30 minutes) à l'adresse DU
/// COMPTE ; le mot de passe actuel reste valable tant que le lien n'est pas
/// ouvert (il s'ouvre dans le navigateur, page /reinitialiser-mot-de-passe).
/// La réponse est toujours la même, que le compte existe ou non : rien ne
/// permet d'en déduire l'existence d'un matricule.
///
/// Un compte sans adresse réelle (étudiant repris des registres) ne se
/// récupère pas ici : c'est la « Première connexion », ou l'établissement.
class MotDePasseOublieScreen extends StatefulWidget {
  const MotDePasseOublieScreen({super.key});

  @override
  State<MotDePasseOublieScreen> createState() => _MotDePasseOublieScreenState();
}

class _MotDePasseOublieScreenState extends State<MotDePasseOublieScreen> {
  static const messageEnvoye =
      'Si cet identifiant correspond à un compte, un lien de réinitialisation '
      'a été envoyé à l\'adresse email associée. Ouvrez-le dans les 30 minutes.';

  final _form = GlobalKey<FormState>();
  final _identifiantController = TextEditingController();
  bool _enCours = false;
  bool _envoye = false;

  @override
  void dispose() {
    _identifiantController.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _enCours = true);
    try {
      // Le matricule n'est jamais passé en minuscules (cf. connexion).
      await context
          .read<ApiService>()
          .forgotPassword(identifiant: _identifiantController.text.trim());
    } catch (_) {
      // Même message en cas d'erreur : ne rien révéler sur le compte.
    } finally {
      if (mounted) {
        setState(() {
          _enCours = false;
          _envoye = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _envoye ? _confirmation(textTheme) : _formulaire(textTheme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulaire(TextTheme textTheme) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Saisissez votre matricule (étudiant) ou votre email (agent) : un '
            'lien pour choisir un nouveau mot de passe sera envoyé à l\'adresse '
            'de votre compte.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _identifiantController,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              labelText: 'Matricule ou email',
              prefixIcon: Icon(Icons.person_rounded),
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Saisissez votre matricule ou votre email'
                : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _enCours ? null : _envoyer,
            child: Text(_enCours ? 'Envoi…' : 'Recevoir un lien'),
          ),
          const SizedBox(height: 16),
          Text(
            'Votre compte n\'a pas d\'adresse email (dossier repris des '
            'registres) ? Utilisez la première connexion, ou adressez-vous au '
            'service des inscriptions de votre établissement.',
            style: textTheme.bodySmall,
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PremiereConnexionScreen()),
            ),
            child: const Text('Première connexion'),
          ),
        ],
      ),
    );
  }

  Widget _confirmation(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(messageEnvoye, style: textTheme.bodyMedium),
        const SizedBox(height: 12),
        Text(
          'Votre mot de passe actuel reste valable tant que vous n\'avez pas '
          'utilisé ce lien.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Retour à la connexion'),
        ),
      ],
    );
  }
}
