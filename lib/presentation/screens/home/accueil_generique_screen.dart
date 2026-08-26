import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../navigation/portail_shell.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/portail_widgets.dart';

/// Accueil des rôles sans portail mobile dédié (caissier, doyen, ministère…).
///
/// Le portail web leur donne des pages complètes ; le mobile n'en transpose
/// aucune. Plutôt qu'un écran vide, ce repli expose ce qui est commun à tout
/// compte — les cours suivis, les notes, les notifications, le profil — et dit
/// franchement que le reste passe par le portail web. C'est ce que faisait
/// déjà l'ancien `HomeScreen`, conservé ici sous la nouvelle navigation.
class AccueilGeneriqueScreen extends StatelessWidget {
  const AccueilGeneriqueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final prenom = user?.nomComplet?.split(' ').first ?? 'Utilisateur';

    return PagePortail(
      titre: 'Portail GENUC',
      corps: ListView(
        padding: Responsive.margePage(context),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenue, $prenom',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  user?.email ?? '',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (user?.role ?? 'Utilisateur').replaceAll('_', ' '),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const EnteteSection(titre: 'Accès rapides', icone: Icons.apps_rounded),
          GrilleAdaptative(
            largeurMinTuile: 165,
            ratio: 1.5,
            enfants: [
              ActionRapide(
                icone: Icons.menu_book_rounded,
                libelle: 'Mes cours',
                couleur: AppTheme.statutOrange,
                onTap: () =>
                    PortailScope.naviguer(context, '/etudiant/mes-cours'),
              ),
              ActionRapide(
                icone: Icons.bar_chart_rounded,
                libelle: 'Notes',
                couleur: AppTheme.statutBleu,
                onTap: () =>
                    PortailScope.naviguer(context, '/etudiant/resultats'),
              ),
              ActionRapide(
                icone: Icons.notifications_rounded,
                libelle: 'Notifications',
                couleur: AppTheme.statutViolet,
                onTap: () => PortailScope.naviguer(context, '/notifications'),
              ),
              ActionRapide(
                icone: Icons.person_rounded,
                libelle: 'Mon profil',
                couleur: AppTheme.statutVert,
                onTap: () => PortailScope.naviguer(context, '/etudiant/profil'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          CartePortail(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_rounded,
                  size: 18,
                  color: AppTheme.iconAccent(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Les fonctions propres à votre rôle ne sont pas encore '
                    'portées sur mobile : elles restent accessibles depuis le '
                    'portail web.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                    ),
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
