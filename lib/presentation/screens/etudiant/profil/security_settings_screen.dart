import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/two_factor_setup.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/genuc_scaffold.dart';

/// Écran des paramètres de sécurité
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  /// `true`/`false` une fois le statut chargé, `null` tant qu'il est inconnu.
  bool? _twoFactorEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _chargerStatut2fa());
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _chargerStatut2fa() async {
    try {
      final active = await context.read<AuthProvider>().statut2fa();
      if (mounted) setState(() => _twoFactorEnabled = active);
    } catch (_) {
      // Statut indisponible (hors ligne, session expirée…) : la tuile reste
      // visible et un appui relancera le chargement.
      if (mounted) setState(() => _twoFactorEnabled = null);
    }
  }

  String get _sousTitre2fa {
    switch (_twoFactorEnabled) {
      case null:
        return 'État indisponible — appuyez pour réessayer';
      case true:
        return 'Activée — un code est exigé à chaque connexion';
      case false:
        return 'Désactivée — appuyez pour l\'activer';
    }
  }

  void _onTap2fa() {
    final actif = _twoFactorEnabled;
    if (actif == null) {
      _chargerStatut2fa();
    } else if (actif) {
      _ouvrirDesactivation2fa();
    } else {
      _ouvrirActivation2fa();
    }
  }

  Future<void> _ouvrirActivation2fa() async {
    final activee = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DialogueActivation2fa(),
    );
    if (activee == true && mounted) {
      setState(() => _twoFactorEnabled = true);
      _showSuccessSnackBar('2FA activée — un code sera exigé à chaque connexion');
    }
  }

  Future<void> _ouvrirDesactivation2fa() async {
    final desactivee = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DialogueDesactivation2fa(),
    );
    if (desactivee == true && mounted) {
      setState(() => _twoFactorEnabled = false);
      _showSuccessSnackBar('2FA désactivée');
    }
  }

  Future<void> _changerMotDePasse() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez remplir tous les champs';
      });
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Les nouveaux mots de passe ne correspondent pas';
      });
      return;
    }

    if (_newPasswordController.text.length < 8) {
      setState(() {
        _errorMessage = 'Le mot de passe doit contenir au moins 8 caractères';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // POST /api/auth/changer-mot-de-passe : le backend applique la
      // politique complète (8 caractères, majuscule, chiffre, caractère
      // spécial, différence avec l'ancien) et révoque les autres sessions.
      await context.read<AuthProvider>().changerMotDePasse(
            ancien: _currentPasswordController.text,
            nouveau: _newPasswordController.text,
          );

      if (mounted) {
        setState(() {
          _successMessage =
              'Mot de passe modifié. Vos autres sessions ont été déconnectées.';
          _isLoading = false;
        });

        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        _showSuccessSnackBar(_successMessage!);
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
      _showErrorSnackBar(e.message);
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du changement de mot de passe : ${e.runtimeType}';
        _isLoading = false;
      });
      _showErrorSnackBar(_errorMessage!);
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
        title: const Text('Paramètres de sécurité'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_errorMessage != null)
            _ErreurBanner(message: _errorMessage!),
          if (_successMessage != null)
            _SuccessBanner(message: _successMessage!),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Changer le mot de passe',
            icon: Icons.lock_rounded,
            children: [
              _ChampMotDePasse(
                controller: _currentPasswordController,
                label: 'Mot de passe actuel',
                showPassword: _showCurrentPassword,
                onToggle: () {
                  setState(() {
                    _showCurrentPassword = !_showCurrentPassword;
                  });
                },
              ),
              const SizedBox(height: 16),
              _ChampMotDePasse(
                controller: _newPasswordController,
                label: 'Nouveau mot de passe',
                showPassword: _showNewPassword,
                onToggle: () {
                  setState(() {
                    _showNewPassword = !_showNewPassword;
                  });
                },
              ),
              const SizedBox(height: 16),
              _ChampMotDePasse(
                controller: _confirmPasswordController,
                label: 'Confirmer le nouveau mot de passe',
                showPassword: _showConfirmPassword,
                onToggle: () {
                  setState(() {
                    _showConfirmPassword = !_showConfirmPassword;
                  });
                },
              ),
              const SizedBox(height: 24),
              _CriteriaMotDePasse(password: _newPasswordController.text),
              const SizedBox(height: 24),
              _BoutonAction(
                label: 'Changer le mot de passe',
                isLoading: _isLoading,
                onPressed: _changerMotDePasse,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: 'Authentification à deux facteurs',
            icon: Icons.security_rounded,
            children: [
              _TwoFactorTile(
                title: '2FA par application',
                subtitle: _sousTitre2fa,
                isActive: _twoFactorEnabled == true,
                onTap: _onTap2fa,
              ),
              const SizedBox(height: 12),
              Text(
                'Un code à 6 chiffres généré par une application '
                'd\'authentification (Google Authenticator, Authy…) sera '
                'exigé à chaque connexion.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dialogue d'activation 2FA : démarre l'activation (secret + QR code), attend
/// le premier code de l'application d'authentification puis confirme.
class _DialogueActivation2fa extends StatefulWidget {
  const _DialogueActivation2fa();

  @override
  State<_DialogueActivation2fa> createState() => _DialogueActivation2faState();
}

class _DialogueActivation2faState extends State<_DialogueActivation2fa> {
  final _codeController = TextEditingController();
  TwoFactorSetup? _setup;
  String? _erreur;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _demarrer() async {
    try {
      final setup = await context.read<AuthProvider>().demarrerActivation2fa();
      // `_erreur` est effacé ici aussi : un réessai qui réussit doit quitter
      // l'état d'erreur (le premier `await` rend le setState sûr hors initState).
      if (mounted) {
        setState(() {
          _setup = setup;
          _erreur = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _erreur = 'Impossible de démarrer l\'activation : ${e.runtimeType}');
      }
    }
  }

  Future<void> _confirmer() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await context.read<AuthProvider>().confirmerActivation2fa(code);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _erreur = e.message;
          _enCours = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _erreur = 'Code invalide ou expiré';
          _enCours = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Activer la 2FA'),
      content: _contenu(),
      actions: [
        TextButton(
          onPressed: _enCours ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
      ],
    );
  }

  Widget _contenu() {
    if (_erreur != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _erreur!,
            style: const TextStyle(color: AppTheme.error),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _demarrer,
            child: const Text('Réessayer'),
          ),
        ],
      );
    }

    final setup = _setup;
    if (setup == null) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Scannez ce QR code dans votre application d\'authentification '
          '(Google Authenticator, Authy…), puis saisissez le code à 6 chiffres.',
        ),
        const SizedBox(height: 16),
        Center(child: _QrCodeImage(dataUri: setup.qrCodeImage)),
        const SizedBox(height: 12),
        SelectableText(
          'Secret : ${setup.secret}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: 'Code à 6 chiffres',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _enCours ? null : _confirmer,
          child: _enCours
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Activer la 2FA'),
        ),
      ],
    );
  }
}

/// Dialogue de désactivation 2FA : un code valide est exigé pour confirmer.
class _DialogueDesactivation2fa extends StatefulWidget {
  const _DialogueDesactivation2fa();

  @override
  State<_DialogueDesactivation2fa> createState() =>
      _DialogueDesactivation2faState();
}

class _DialogueDesactivation2faState extends State<_DialogueDesactivation2fa> {
  final _codeController = TextEditingController();
  String? _erreur;
  bool _enCours = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _desactiver() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await context.read<AuthProvider>().desactiver2fa(code);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _erreur = e.message;
          _enCours = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _erreur = 'Code invalide ou expiré';
          _enCours = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Désactiver la 2FA'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Saisissez le code actuel de votre application d\'authentification '
            'pour confirmer.',
          ),
          const SizedBox(height: 16),
          if (_erreur != null) ...[
            Text(
              _erreur!,
              style: const TextStyle(color: AppTheme.error),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'Code à 6 chiffres',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _enCours ? null : _desactiver,
            child: _enCours
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Désactiver la 2FA'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _enCours ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}

/// Affiche le QR code PNG (data URI base64) renvoyé par `/2fa/setup`.
class _QrCodeImage extends StatelessWidget {
  final String? dataUri;

  const _QrCodeImage({required this.dataUri});

  @override
  Widget build(BuildContext context) {
    final base64 = _qrcodeBase64(dataUri);
    if (base64 == null) {
      return Icon(
        Icons.qr_code_rounded,
        size: 120,
        color: AppTheme.textSecondaryOf(context),
      );
    }

    try {
      return Image.memory(
        base64Decode(base64),
        width: 180,
        height: 180,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    } catch (_) {
      return Icon(
        Icons.qr_code_rounded,
        size: 120,
        color: AppTheme.textSecondaryOf(context),
      );
    }
  }
}

/// Extrait la partie base64 d'une data URI `data:image/png;base64,…`.
String? _qrcodeBase64(String? dataUri) {
  if (dataUri == null) return null;
  const prefix = 'data:image/png;base64,';
  if (!dataUri.startsWith(prefix)) return null;
  return dataUri.substring(prefix.length);
}

class _ErreurBanner extends StatelessWidget {
  final String message;

  const _ErreurBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error),
      ),
      child: Row(
        children: [
          Icon(Icons.error_rounded, color: AppTheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  final String message;

  const _SuccessBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppTheme.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppTheme.success),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
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
          Row(
            children: [
              Icon(icon, color: AppTheme.primary),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _ChampMotDePasse extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool showPassword;
  final VoidCallback onToggle;

  const _ChampMotDePasse({
    required this.controller,
    required this.label,
    required this.showPassword,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !showPassword,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
          onPressed: onToggle,
        ),
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

class _CriteriaMotDePasse extends StatelessWidget {
  final String password;

  const _CriteriaMotDePasse({required this.password});

  @override
  Widget build(BuildContext context) {
    final hasMinLength = password.length >= 8;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasNumbers = password.contains(RegExp(r'[0-9]'));
    final hasSpecialChars = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Critères du mot de passe:',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _CritereItem(
          label: 'Au moins 8 caractères',
          isValid: hasMinLength,
        ),
        _CritereItem(
          label: 'Une lettre majuscule',
          isValid: hasUppercase,
        ),
        _CritereItem(
          label: 'Une lettre minuscule',
          isValid: hasLowercase,
        ),
        _CritereItem(
          label: 'Un chiffre',
          isValid: hasNumbers,
        ),
        _CritereItem(
          label: 'Un caractère spécial',
          isValid: hasSpecialChars,
        ),
      ],
    );
  }
}

class _CritereItem extends StatelessWidget {
  final String label;
  final bool isValid;

  const _CritereItem({
    required this.label,
    required this.isValid,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isValid ? AppTheme.success : AppTheme.textSecondaryOf(context),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isValid ? AppTheme.success : AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoutonAction extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _BoutonAction({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}

class _TwoFactorTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  const _TwoFactorTile({
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.success.withValues(alpha: 0.1)
              : AppTheme.borderOf(context).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppTheme.success : AppTheme.borderOf(context),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isActive ? AppTheme.success : AppTheme.textSecondaryOf(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.textSecondaryOf(context),
            ),
          ],
        ),
      ),
    );
  }
}
