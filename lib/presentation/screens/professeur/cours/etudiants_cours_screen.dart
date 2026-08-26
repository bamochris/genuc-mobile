import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/professeur_pedagogie_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/portail_widgets.dart';
import '../../commun/ecran_ressource.dart';

/// Étudiants inscrits à un cours donné (`/api/cours/{id}/etudiants`).
class EtudiantsCoursScreen extends StatelessWidget {
  final String coursId;
  final String titreCours;

  const EtudiantsCoursScreen({
    super.key,
    required this.coursId,
    required this.titreCours,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();

    return EcranRessource(
      titre: 'Étudiants du cours',
      sousTitre: titreCours,
      messageVide: 'Aucun étudiant inscrit à ce cours.',
      charger: () => service.etudiantsDuCours(coursId),
      description: DescriptionFiche(
        icone: Icons.groups_rounded,
        titre: (f) => [f.texte('prenom'), f.texte('nom')]
            .where((v) => v.isNotEmpty)
            .join(' '),
        sousTitre: (f) => f.texteOuNul('matricule'),
        details: (f) => [
          LigneDetail(libelle: 'Promotion', valeur: f.texte('promotion')),
          LigneDetail(libelle: 'Filière', valeur: f.texte('filiere')),
        ],
      ),
    );
  }
}

/// Tous les étudiants que l'enseignant peut atteindre, tous cours confondus
/// (`/api/professeur/etudiants/disponibles/{id}`).
class MesEtudiantsScreen extends StatelessWidget {
  const MesEtudiantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProfesseurPedagogieService>();
    final professeurId = context.read<AuthProvider>().user?.id ?? '';

    return EcranRessource(
      titre: 'Mes étudiants',
      sousTitre: 'Tous cours confondus',
      messageVide: 'Aucun étudiant trouvé.',
      charger: () => service.mesEtudiants(professeurId),
      description: DescriptionFiche(
        icone: Icons.school_rounded,
        titre: (f) => [f.texte('prenom'), f.texte('nom')]
            .where((v) => v.isNotEmpty)
            .join(' '),
        sousTitre: (f) => f.texteOuNul('matricule'),
        statut: (f) {
          final nb = f.entier('nbNotes');
          return (
            '$nb note${nb > 1 ? 's' : ''}',
            nb > 0 ? AppTheme.statutVert : AppTheme.statutNavy,
          );
        },
        details: (f) => [
          LigneDetail(libelle: 'Promotion', valeur: f.texte('promotion')),
          LigneDetail(libelle: 'Filière', valeur: f.texte('filiere')),
        ],
      ),
    );
  }
}
