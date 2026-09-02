import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/etudiant/etudiant_profile_backend.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/portail_widgets.dart';
import 'edit_profil_screen.dart';
import 'security_settings_screen.dart';

/// Écran principal du profil étudiant
class EtudiantProfilScreen extends StatefulWidget {
  const EtudiantProfilScreen({super.key});

  @override
  State<EtudiantProfilScreen> createState() => _EtudiantProfilScreenState();
}

class _EtudiantProfilScreenState extends State<EtudiantProfilScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _chargerProfil());
  }

  Future<void> _chargerProfil() async {
    final authProvider = context.read<AuthProvider>();
    final studentProvider = context.read<StudentProvider>();
    final inscriptionId = authProvider.user?.inscriptionId;

    if (inscriptionId != null && inscriptionId.isNotEmpty) {
      await studentProvider.loadProfile(inscriptionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final studentProvider = context.watch<StudentProvider>();

    return PagePortail(
      titre: 'Mon profil',
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded),
          tooltip: 'Modifier mon profil',
          onPressed: () {
            final profile = context.read<StudentProvider>().profile;
            if (profile == null) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EditProfilScreen(profile: profile),
              ),
            );
          },
        ),
      ],
      corps: studentProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : studentProvider.error != null
              ? _ErreurState(
                  message: studentProvider.error!,
                  onRetry: _chargerProfil,
                )
              : studentProvider.profile != null
                  ? _ContenuProfil(
                      profile: studentProvider.profile!,
                      user: authProvider.user,
                    )
                  : _ContenuVide(),
    );
  }
}

class _ContenuProfil extends StatelessWidget {
  final EtudiantProfile profile;
  final dynamic user;

  const _ContenuProfil({
    required this.profile,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final studentProvider = context.read<StudentProvider>();
        final authProvider = context.read<AuthProvider>();
        final inscriptionId = authProvider.user?.inscriptionId;
        if (inscriptionId != null) {
          await studentProvider.loadProfile(inscriptionId);
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PhotoSection(profile: profile),
          const SizedBox(height: 24),
          _InformationsPersonnelles(profile: profile),
          const SizedBox(height: 24),
          _InformationsAcademiques(profile: profile),
          const SizedBox(height: 24),
          _InformationsContact(profile: profile),
          const SizedBox(height: 24),
          _ActionsSection(),
        ],
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  final EtudiantProfile profile;

  const _PhotoSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary,
                    width: 3,
                  ),
                ),
                // `EtudiantProfile.photo` est un booléen (le backend ne fournit
                // pas d'URL ici) : on affiche les initiales par défaut.
                child: ClipOval(
                  child: _PhotoPlaceholder(
                    initials: _getInitials(profile),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            profile.nomComplet,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.matricule,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(EtudiantProfile profile) {
    return '${profile.prenom[0]}${profile.nom[0]}'.toUpperCase();
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final String initials;

  const _PhotoPlaceholder({required this.initials});

  @override
  Widget build(BuildContext context) {
    // Les initiales tenaient lieu de photo dans un disque teinté de bleu nuit,
    // peintes de ce même bleu nuit : 1,1:1 en thème sombre, c'est-à-dire un
    // disque vide. Même traitement qu'une pastille — le fond décide du texte.
    final (fond, accent) = AppTheme.pastilleDe(context, AppTheme.primary);

    return Container(
      color: fond,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: accent,
          ),
        ),
      ),
    );
  }
}

class _InformationsPersonnelles extends StatelessWidget {
  final EtudiantProfile profile;

  const _InformationsPersonnelles({required this.profile});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Informations Personnelles',
      icon: Icons.person_rounded,
      children: [
        _InfoRow(
          icon: Icons.badge_rounded,
          label: 'Matricule',
          value: profile.matricule,
        ),
        _InfoRow(
          icon: Icons.person_rounded,
          label: 'Nom',
          value: profile.nom,
        ),
        _InfoRow(
          icon: Icons.person_rounded,
          label: 'Prénom',
          value: profile.prenom,
        ),
        _InfoRow(
          icon: Icons.email_rounded,
          label: 'Email',
          value: profile.email,
        ),
        _InfoRow(
          icon: Icons.phone_rounded,
          label: 'Téléphone',
          value: profile.telephone,
        ),
      ],
    );
  }
}

class _InformationsAcademiques extends StatelessWidget {
  final EtudiantProfile profile;

  const _InformationsAcademiques({required this.profile});

  @override
  Widget build(BuildContext context) {
    // Le backend renvoie ces champs dans le profil (`getProfil`) : pas de
    // données en dur, contrairement à l'ancienne version de cet écran.
    return _SectionCard(
      title: 'Informations Académiques',
      icon: Icons.school_rounded,
      children: [
        _InfoRow(
          icon: Icons.account_balance_rounded,
          label: 'Université',
          value: profile.universite ?? '—',
        ),
        _InfoRow(
          icon: Icons.business_rounded,
          label: 'Département',
          value: profile.departement ?? '—',
        ),
        _InfoRow(
          icon: Icons.book_rounded,
          label: 'Filière',
          value: profile.filiere ?? '—',
        ),
        _InfoRow(
          icon: Icons.stars_rounded,
          label: 'Promotion',
          value: profile.promotion ?? '—',
        ),
        _InfoRow(
          icon: Icons.calendar_today_rounded,
          label: 'Année académique',
          value: profile.anneeAcademique ?? '—',
        ),
      ],
    );
  }
}

class _InformationsContact extends StatelessWidget {
  final EtudiantProfile profile;

  const _InformationsContact({required this.profile});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Informations de Contact',
      icon: Icons.contact_mail_rounded,
      children: [
        _InfoRow(
          icon: Icons.email_rounded,
          label: 'Email principal',
          value: profile.email,
        ),
        _InfoRow(
          icon: Icons.phone_rounded,
          label: 'Téléphone',
          value: profile.telephone,
        ),
        _InfoRow(
          icon: Icons.location_on_rounded,
          label: 'Adresse',
          value: profile.adresse ?? '—',
        ),
        if (profile.dateNaissance != null)
          _InfoRow(
            icon: Icons.cake_rounded,
            label: 'Date de naissance',
            value: profile.dateNaissance!,
          ),
        if (profile.lieuNaissance != null)
          _InfoRow(
            icon: Icons.place_rounded,
            label: 'Lieu de naissance',
            value: profile.lieuNaissance!,
          ),
      ],
    );
  }
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.edit_rounded,
          label: 'Modifier mon profil',
          color: AppTheme.primary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditProfilScreen(
                  profile: context.read<StudentProvider>().profile,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.security_rounded,
          label: 'Paramètres de sécurité',
          color: AppTheme.warning,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SecuritySettingsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.lock_rounded,
          label: 'Changer mon mot de passe',
          color: AppTheme.error,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SecuritySettingsScreen(),
              ),
            );
          },
        ),
      ],
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
              Icon(icon,
                  color: AppTheme.accentGraphique(context, AppTheme.primary)),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondaryOf(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
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
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContenuVide extends StatelessWidget {
  const _ContenuVide();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_rounded,
            size: 64,
            color: AppTheme.textSecondaryOf(context),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune information de profil',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErreurState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErreurState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_rounded,
              size: 64,
              color: AppTheme.errorOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.errorOf(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Sans surcharge de fond : le bleu nuit imposé ici privait le
            // bouton du libellé clair que le thème sombre lui associe, et
            // « Réessayer » retombait à 1,15:1.
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}