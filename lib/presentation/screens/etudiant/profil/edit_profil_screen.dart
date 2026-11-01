import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
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
  final _dateNaissanceController = TextEditingController();
  final _lieuNaissanceController = TextEditingController();

  // Date et lieu de naissance : l'étudiant peut les COMPLÉTER tant qu'ils sont
  // vides (règle du serveur, `EtudiantPortalController.updateProfil`) ; une fois
  // renseignés, ils se corrigent au secrétariat. Figé à l'ouverture de l'écran.
  bool _dateNaissanceModifiable = false;
  bool _lieuNaissanceModifiable = false;
  DateTime? _dateNaissance;

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
    final date = widget.profile?.dateNaissance;
    final lieu = widget.profile?.lieuNaissance;
    _dateNaissanceModifiable = date == null || date.trim().isEmpty;
    _lieuNaissanceModifiable = lieu == null || lieu.trim().isEmpty;
    if (!_dateNaissanceModifiable) {
      _dateNaissance = DateTime.tryParse(date!);
      _dateNaissanceController.text =
          _dateNaissance != null ? _formaterDate(_dateNaissance!) : date;
    }
    if (!_lieuNaissanceModifiable) _lieuNaissanceController.text = lieu!;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _dateNaissanceController.dispose();
    _lieuNaissanceController.dispose();
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
        // Ni nom ni prénom : pour un étudiant, le serveur les IGNORE (état
        // civil, corrigé par l'administration). Les envoyer faisait annoncer
        // « Profil mis à jour » pour une modification jamais enregistrée.
        // Même raison pour le téléphone secondaire, retiré : le serveur ne le
        // lit pas.
        final data = <String, dynamic>{
          'email': _emailController.text.trim(),
          'telephone': _telephoneController.text.trim(),
        };
        // Envoyés seulement s'ils étaient vides et viennent d'être remplis :
        // une valeur déjà enregistrée renvoyée telle quelle est acceptée, mais
        // inutile ; une valeur modifiée serait refusée (403).
        if (_dateNaissanceModifiable && _dateNaissance != null) {
          data['dateNaissance'] = _dateIso(_dateNaissance!);
        }
        final lieu = _lieuNaissanceController.text.trim();
        if (_lieuNaissanceModifiable && lieu.isNotEmpty) {
          data['lieuNaissance'] = lieu;
        }

        await studentProvider.updateProfile(inscriptionId, data);

        if (mounted) {
          _showSuccessSnackBar('Profil mis à jour avec succès');
          Navigator.pop(context, true);
        }
      }
    } on ApiException catch (e) {
      // Le serveur dit POURQUOI il refuse (« adresse déjà utilisée »,
      // « adresse invalide ») : un message générique laissait retaper la
      // même valeur sans savoir ce qu'on lui reprochait.
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
      _showErrorSnackBar(e.message);
    } catch (e) {
      if (!mounted) return;
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

  Future<void> _choisirDateNaissance() async {
    final maintenant = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime(maintenant.year - 20),
      firstDate: DateTime(1900),
      lastDate: maintenant,
      helpText: 'Date de naissance',
    );
    if (choisie == null || !mounted) return;
    setState(() {
      _dateNaissance = choisie;
      _dateNaissanceController.text = _formaterDate(choisie);
    });
  }

  static String _deuxChiffres(int n) => n.toString().padLeft(2, '0');

  /// Format attendu par le serveur (`LocalDate.parse`).
  static String _dateIso(DateTime d) =>
      '${d.year}-${_deuxChiffres(d.month)}-${_deuxChiffres(d.day)}';

  static String _formaterDate(DateTime d) =>
      '${_deuxChiffres(d.day)}/${_deuxChiffres(d.month)}/${d.year}';

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accent, // confirmation : bleu, jamais vert
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
                  lectureSeule: true,
                ),
                const SizedBox(height: 16),
                _ChampTexte(
                  controller: _prenomController,
                  label: 'Prénom',
                  icon: Icons.person_rounded,
                  lectureSeule: true,
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
                  controller: _dateNaissanceController,
                  label: _dateNaissanceModifiable
                      ? 'Date de naissance (à compléter)'
                      : 'Date de naissance',
                  icon: Icons.cake_rounded,
                  lectureSeule: true,
                  verrouille: !_dateNaissanceModifiable,
                  onTap: _dateNaissanceModifiable ? _choisirDateNaissance : null,
                ),
                const SizedBox(height: 16),
                _ChampTexte(
                  controller: _lieuNaissanceController,
                  label: _lieuNaissanceModifiable
                      ? 'Lieu de naissance (à compléter)'
                      : 'Lieu de naissance',
                  icon: Icons.place_rounded,
                  lectureSeule: !_lieuNaissanceModifiable,
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
  final bool lectureSeule;
  // Cadenas affiché : par défaut, tout champ en lecture seule. Le sélecteur de
  // date est en lecture seule (saisie au calendrier) sans être verrouillé.
  final bool? verrouille;
  final VoidCallback? onTap;

  const _ChampTexte({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.lectureSeule = false,
    this.verrouille,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: lectureSeule,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: (verrouille ?? lectureSeule)
            ? const Icon(Icons.lock_outline_rounded, size: 18)
            : onTap != null
                ? const Icon(Icons.calendar_month_rounded, size: 18)
                : null,
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
              'Les modifications seront appliquées immédiatement à votre profil. '
              'Nom, prénom, date et lieu de naissance relèvent de l\'état civil : '
              'vous pouvez compléter la date et le lieu s\'ils sont vides ; '
              'une fois renseignés, ils se corrigent au secrétariat académique, sur pièce.',
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
