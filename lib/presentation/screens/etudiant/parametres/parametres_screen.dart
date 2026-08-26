import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../data/services/appel_api.dart';
import '../../../../data/services/etudiant_academique_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/portail_widgets.dart';
import '../profil/edit_profil_screen.dart';
import '../profil/security_settings_screen.dart';

/// Paramètres du compte étudiant : coordonnées, préférences de notification,
/// apparence, et accès aux deux écrans qui existaient déjà (profil, sécurité).
///
/// Transposition de `etudiant/parametres/ParametresEtudiant.jsx`. Le
/// changement de mot de passe et la double authentification ne sont pas
/// redupliqués ici : ils vivent dans [SecuritySettingsScreen], et une seconde
/// implémentation aurait divergé à la première correction.
class ParametresEtudiantScreen extends StatefulWidget {
  const ParametresEtudiantScreen({super.key});

  @override
  State<ParametresEtudiantScreen> createState() =>
      _ParametresEtudiantScreenState();
}

class _ParametresEtudiantScreenState extends State<ParametresEtudiantScreen> {
  final _telephone = TextEditingController();
  final _adresse = TextEditingController();

  bool _notifications = true;
  bool _rappels = true;
  bool _newsletter = false;
  String _langue = 'fr';

  bool _chargement = true;
  bool _enregistrement = false;
  String? _erreur;
  String? _message;
  bool _messageSucces = true;

  String get _inscriptionId =>
      context.read<AuthProvider>().user?.inscriptionId ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  @override
  void dispose() {
    _telephone.dispose();
    _adresse.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    if (_inscriptionId.isEmpty) {
      setState(() {
        _chargement = false;
        _erreur = 'Aucune inscription active : préférences indisponibles.';
      });
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final prefs = await context
          .read<EtudiantAcademiqueService>()
          .preferences(_inscriptionId)
          .catchError((_) => const Fiche({}));
      if (!mounted) return;
      setState(() {
        _telephone.text = prefs.texte('telephone');
        _adresse.text = prefs.texte('adresse');
        // Valeurs par défaut alignées sur le web : notifications et rappels
        // actifs, lettre d'information non.
        _notifications = prefs.booleen('notifications', defaut: true);
        _rappels = prefs.booleen('rappels', defaut: true);
        _newsletter = prefs.booleen('newsletter');
        _langue = prefs.texte('langue', defaut: 'fr');
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
    final themeProvider = context.watch<ThemeProvider>();

    return PagePortail(
      titre: 'Paramètres',
      sousTitre: 'Compte, notifications et apparence',
      onRafraichir: _charger,
      corps: EtatRequete(
        chargement: _chargement,
        erreur: _erreur,
        vide: false,
        onReessayer: _charger,
        enfant: ListView(
          padding: Responsive.margePage(context),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_message != null)
              BandeauMessage(
                message: _message!,
                succes: _messageSucces,
                onFermer: () => setState(() => _message = null),
              ),

            // ─── Coordonnées ───
            const EnteteSection(
              titre: 'Mes coordonnées',
              icone: Icons.contact_mail_rounded,
            ),
            CartePortail(
              child: Column(
                children: [
                  TextField(
                    controller: _telephone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _adresse,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Adresse'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Notifications ───
            const EnteteSection(
              titre: 'Notifications',
              icone: Icons.notifications_rounded,
            ),
            CartePortail(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _notifications,
                    title: const Text('Notifications de l\'application'),
                    subtitle: const Text('Notes publiées, messages, décisions'),
                    onChanged: (v) => setState(() => _notifications = v),
                  ),
                  SwitchListTile(
                    value: _rappels,
                    title: const Text('Rappels'),
                    subtitle: const Text('Échéances de travaux et de paiement'),
                    onChanged: (v) => setState(() => _rappels = v),
                  ),
                  SwitchListTile(
                    value: _newsletter,
                    title: const Text('Lettre d\'information'),
                    subtitle: const Text('Actualités de l\'établissement'),
                    onChanged: (v) => setState(() => _newsletter = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Apparence ───
            const EnteteSection(
              titre: 'Apparence',
              icone: Icons.palette_rounded,
            ),
            CartePortail(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thème',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMutedOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('Système'),
                        icon: Icon(Icons.brightness_auto_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Clair'),
                        icon: Icon(Icons.light_mode_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Sombre'),
                        icon: Icon(Icons.dark_mode_rounded, size: 16),
                      ),
                    ],
                    selected: {themeProvider.themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (choix) =>
                        themeProvider.setThemeMode(choix.first),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _langue,
                    decoration: const InputDecoration(labelText: 'Langue'),
                    items: const [
                      DropdownMenuItem(value: 'fr', child: Text('Français')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) => setState(() => _langue = v ?? 'fr'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Compte ───
            const EnteteSection(
              titre: 'Mon compte',
              icone: Icons.person_rounded,
            ),
            CartePortail(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_rounded),
                    title: const Text('Modifier mon profil'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EditProfilScreen(),
                      ),
                    ),
                  ),
                  Divider(color: AppTheme.borderOf(context), height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_rounded),
                    title: const Text('Sécurité et mot de passe'),
                    subtitle: const Text('Double authentification, mot de passe'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SecuritySettingsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _enregistrement ? null : _enregistrer,
              icon: _enregistrement
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _enregistrement ? 'Enregistrement…' : 'Enregistrer mes préférences',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enregistrer() async {
    setState(() => _enregistrement = true);
    try {
      await context.read<EtudiantAcademiqueService>().majPreferences(
        _inscriptionId,
        {
          'telephone': _telephone.text.trim(),
          'adresse': _adresse.text.trim(),
          'notifications': _notifications,
          'rappels': _rappels,
          'newsletter': _newsletter,
          'langue': _langue,
        },
      );
      if (!mounted) return;
      setState(() {
        _message = 'Préférences enregistrées.';
        _messageSucces = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is ApiException ? e.message : e.toString();
        _messageSucces = false;
      });
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }
}
