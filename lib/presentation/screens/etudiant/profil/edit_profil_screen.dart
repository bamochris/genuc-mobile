import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/etudiant/etudiant_profile_backend.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/genuc_scaffold.dart';

/// Écran d'édition du profil étudiant
class EditProfilScreen extends StatefulWidget {
  final EtudiantProfile? profile;

  const EditProfilScreen({super.key, this.profile});

  @override
  State<EditProfilScreen> createState() => _EditProfilScreenState();
}

class _EditProfilScreenState extends State<EditProfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _telephoneSecondaireController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.profile != null) {
      _nomController.text = widget.profile!.nom;
      _prenomController.text = widget.profile!.prenom;
      _emailController.text = widget.profile!.email;
      _telephoneController.text = widget.profile!.telephone;
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _telephoneSecondaireController.dispose();
    super.dispose();
  }

  Future<void> _sauvegarder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final studentProvider = context.read<StudentProvider>();
      final inscriptionId = authProvider.user?.inscriptionId;

      if (inscriptionId != null) {
        final data = {
          'nom': _nomController.text.trim(),
          'prenom': _prenomController.text.trim(),
          'email': _emailController.text.trim(),
          'telephone': _telephoneController.text.trim(),
          'telephoneSecondaire': _telephoneSecondaireController.text.trim(),
        };

        await studentProvider.updateProfile(inscriptionId, data);

        if (mounted) {
          _showSuccessSnackBar('Profil mis à jour avec succès');
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la mise à jour : ${e.runtimeType}';
      });
      _showErrorSnackBar(_errorMessage!);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GenucScaffold(
      appBar: AppBar(
        title: const Text('Modifier mon profil'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _sauvegarder,
              child: const Text('Sauvegarder'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMessage != null)
              _ErreurBanner(message: _errorMessage!),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Informations Personnelles',
              children: [
                _ChampTexte(
                  controller: _nomController,
                  label: 'Nom',
                  icon: Icons.person_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le nom est requis';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _ChampTexte(
                  controller: _prenomController,
                  label: 'Prénom',
                  icon: Icons.person_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le prénom est requis';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _ChampTexte(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'L\'email est requis';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _ChampTexte(
                  controller: _telephoneController,
                  label: 'Téléphone principal',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le téléphone est requis';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _ChampTexte(
                  controller: _telephoneSecondaireController,
                  label: 'Téléphone secondaire (optionnel)',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _InfoSection(),
          ],
        ),
      ),
    );
  }
}

class _ErreurBanner extends StatelessWidget {
  final String message;

  const _ErreurBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.fondPastilleOpaque(context, AppTheme.errorOf(context)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorOf(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_rounded, color: _rouge(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: _rouge(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _ChampTexte extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _ChampTexte({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[100],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_rounded, color: AppTheme.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les modifications seront appliquées immédiatement à votre profil.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rouge d'un encart d'erreur, mesuré sur le fond de l'encart lui-même.
///
/// Le voile rouge à dix pour cent éclaircit la surface : le texte n'a plus le
/// fond de la page sous lui mais celui de l'encart, et c'est celui-là qu'il
/// doit franchir.
Color _rouge(BuildContext context) => AppTheme.lisibleSur(
      AppTheme.errorOf(context),
      AppTheme.fondPastilleOpaque(context, AppTheme.errorOf(context)),
    );
